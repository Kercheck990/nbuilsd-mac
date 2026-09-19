import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/top_notify.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/balance_provider.dart';
import '../../services/api_client.dart';

/// Пополнение баланса реальными деньгами.
///
/// Как это работает:
///   1. Клиент просит сервер создать счёт: POST /api/payments/create
///   2. Сервер обращается к провайдеру (Stripe / Crypto Pay / Telegram
///      Stars), сохраняет платёж в БД со статусом `pending` и возвращает
///      ссылку на оплату.
///   3. Клиент открывает ссылку во внешнем браузере/приложении.
///   4. Провайдер присылает вебхук на сервер, сервер проверяет подпись и
///      ТОЛЬКО ТОГДА начисляет монеты (идемпотентно, по payment_id).
///   5. Клиент опрашивает GET /api/payments/:id и обновляет баланс.
///
/// Важно: клиент никогда не начисляет монеты сам — иначе баланс можно
/// накрутить, подменив ответ приложения.
class TopUpScreen extends ConsumerStatefulWidget {
  const TopUpScreen({super.key});

  @override
  ConsumerState<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends ConsumerState<TopUpScreen> {
  static const int minAmount = 100;
  static const _presets = [100, 500, 1000, 2500, 5000, 10000];

  int _amount = 500;
  String _provider = 'crypto';
  bool _busy = false;
  String? _paymentId;
  Timer? _poll;
  String? _statusKey;
  final _promo = TextEditingController();
  bool _promoBusy = false;

  @override
  void dispose() {
    _poll?.cancel();
    _promo.dispose();
    super.dispose();
  }

  /// Ввод промокода: мгновенное начисление монет.
  Future<void> _redeem() async {
    final l10n = context.l10n;
    final code = _promo.text.trim();
    if (code.isEmpty || _promoBusy) return;
    setState(() => _promoBusy = true);
    try {
      final res = await ApiClient.instance.redeemPromocode(code);
      final coins = (res['coins'] as num?)?.toInt() ?? 0;
      final balance = (res['balance_coins'] as num?)?.toInt();
      if (balance != null) {
        ref.read(userProvider.notifier).setBalance(balance);
      }
      if (!mounted) return;
      _promo.clear();
      _snack(l10n.f('promo_success', {'coins': '$coins'}));
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(l10n.t(switch (e.code) {
        'invalid_code' => 'promo_invalid',
        'expired' => 'promo_expired',
        'exhausted' => 'promo_exhausted',
        'already_used' => 'promo_used',
        'error_network' => 'error_network',
        _ => 'error_generic',
      }));
    } finally {
      if (mounted) setState(() => _promoBusy = false);
    }
  }

  Future<void> _pay() async {
    // Упрощено: донат только через ТГ менеджера
    final uri = Uri.parse('https://t.me/nftgrademanager');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    _snack('Напиши менеджеру @nftgrademanager для пополнения');
  }

  /// Опрос статуса раз в 3 секунды, максимум 5 минут.
  void _startPolling() {
    _poll?.cancel();
    var ticks = 0;
    _poll = Timer.periodic(const Duration(seconds: 3), (t) async {
      ticks++;
      if (ticks > 100 || _paymentId == null) {
        t.cancel();
        if (mounted) setState(() => _busy = false);
        return;
      }
      await _checkOnce(silent: true);
    });
  }

  Future<void> _checkOnce({bool silent = false}) async {
    if (_paymentId == null) return;
    final l10n = context.l10n;
    try {
      final res = await ApiClient.instance.paymentStatus(_paymentId!);
      final status = res['status'] as String?;
      if (status == 'paid') {
        _poll?.cancel();
        final balance = (res['balance_coins'] as num?)?.toInt();
        if (balance != null) {
          ref.read(userProvider.notifier).setBalance(balance);
        }
        if (!mounted) return;
        setState(() {
          _busy = false;
          _statusKey = null;
          _paymentId = null;
        });
        _snack(l10n.f('topup_success', {'amount': '$_amount'}));
        Navigator.of(context).maybePop();
      } else if (status == 'failed' || status == 'expired') {
        _poll?.cancel();
        if (!mounted) return;
        setState(() {
          _busy = false;
          _statusKey = null;
        });
        _snack(l10n.t('topup_failed'));
      }
    } on ApiException {
      if (!silent) _snack(l10n.t('error_network'));
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    TopNotify.show(context, text, success: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final methods = [
      ('card', l10n.t('topup_method_card'), Icons.credit_card_outlined),
      ('crypto', l10n.t('topup_method_crypto'), Icons.currency_bitcoin),
      ('stars', l10n.t('topup_method_stars'), Icons.star_outline),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('topup_title'))),
      body: Container(
        decoration: AppTheme.backgroundDecoration(Theme.of(context).brightness),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.45)),
              ),
              child: Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFFFC107), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.stars_rounded, color: Colors.black)),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('NPC · NFT Premium Coin', style: TextStyle(fontWeight: FontWeight.w800)), Text('Донат валюта для Shop, бустов, кейсов. Покупка через крипту (USDT/TON) — реальные деньги.', style: TextStyle(fontSize: 11, color: Colors.grey))])),
              ]),
            ),
            const SizedBox(height: 16),
            Text(l10n.t('topup_amount'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presets.map((p) {
                final selected = p == _amount;
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _busy ? null : () => setState(() => _amount = p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accentYellow.withOpacity(0.16)
                          : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? AppColors.accentYellow
                            : Colors.grey.withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.monetization_on,
                            size: 15,
                            color: selected ? AppColors.accentYellow : Colors.grey),
                        const SizedBox(width: 6),
                        Text('$p',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: selected ? AppColors.accentYellow : null,
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(l10n.t('topup_method'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...methods.map((m) {
              final (id, label, icon) = m;
              final selected = id == _provider;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? AppColors.accentYellow
                        : Colors.grey.withOpacity(0.2),
                  ),
                ),
                child: RadioListTile<String>(
                  value: id,
                  groupValue: _provider,
                  onChanged: _busy ? null : (v) => setState(() => _provider = v!),
                  activeColor: AppColors.accentYellow,
                  title: Row(
                    children: [
                      Icon(icon, size: 20),
                      const SizedBox(width: 10),
                      Text(label),
                    ],
                  ),
                ),
              );
            }),
            if (_provider == 'crypto') const _CryptoWalletCard(),
            if (_provider == 'card' || _provider == 'stars') const _TelegramPayCard(),
            const _RatesCard(),
            const SizedBox(height: 8),
            if (_statusKey != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(l10n.t(_statusKey!),
                          style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentYellow,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _pay,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  'Написать @nftgrademanager — $_amount NPC',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(l10n.t('promo_title'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promo,
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _redeem(),
                    decoration: InputDecoration(
                      hintText: 'PROMO-2024',
                      prefixIcon: const Icon(Icons.card_giftcard_outlined, size: 19),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _promoBusy ? null : _redeem,
                    child: _promoBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(l10n.t('promo_apply')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _PaymentNote(),
          ],
        ),
      ),
    );
  }
}

class _CryptoWalletCard extends StatelessWidget {
  const _CryptoWalletCard();
  @override
  Widget build(BuildContext context) {
    const wallet = 'UQCAW2p8UQ6hyCrimP0yFrO3R9GjOwZJmoSfWMb-qRfhJ_pV';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2B7FFF).withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.currency_bitcoin, size: 16, color: Color(0xFF2B7FFF)), SizedBox(width: 6), Text('Крипто кошелёк (TON)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, decoration: TextDecoration.none))]),
        const SizedBox(height: 6),
        SelectableText(wallet, style: const TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'monospace')),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () { Clipboard.setData(const ClipboardData(text: wallet)); TopNotify.show(context, 'Кошелек скопирован', success: true); }, icon: const Icon(Icons.copy_rounded, size: 14), label: const Text('Копировать', style: TextStyle(fontSize: 12)))),
      ]),
    );
  }
}

class _TelegramPayCard extends StatelessWidget {
  const _TelegramPayCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2B7FFF).withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.send_rounded, size: 16, color: Color(0xFF2B7FFF)), SizedBox(width: 6), Text('Оплата на карту / Telegram Stars', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, decoration: TextDecoration.none))]),
        const SizedBox(height: 6),
        const Text('Пиши менеджеру: @nftgrademanager', style: TextStyle(fontSize: 12, color: Colors.white, decoration: TextDecoration.none)),
        const SizedBox(height: 6),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () async { final uri = Uri.parse('https://t.me/nftgrademanager'); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); }, icon: const Icon(Icons.open_in_new_rounded, size: 14), label: const Text('Открыть @nftgrademanager', style: TextStyle(fontSize: 12)))),
      ]),
    );
  }
}

class _RatesCard extends StatelessWidget {
  const _RatesCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey), SizedBox(width: 6), Text('Курс', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, decoration: TextDecoration.none))]),
        SizedBox(height: 6),
        Text('1 ⭐ Telegram Stars = 0.3 NPC\n1 ₴ гривна = 1.5 NPC', style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4, decoration: TextDecoration.none)),
      ]),
    );
  }
}

/// Короткое пояснение, почему баланс появляется не мгновенно.
class _PaymentNote extends StatelessWidget {
  const _PaymentNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.t('topup_note'),
              style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
