import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../core/widgets/top_notify.dart';
import '../../providers/session_provider.dart';
import '../../services/api_client.dart';

/// Поддержка: тикеты + кнопка Telegram-саппорта.
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.tickets();
      if (!mounted) return;
      setState(() {
        _tickets = ((res['tickets'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (_) {
      if (mounted) {
        TopNotify.show(context, context.l10n.t('error_network'), success: false);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openTg(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _create() {
    final l10n = context.l10n;
    final subject = TextEditingController();
    final text = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.t('sup_new_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subject,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: l10n.t('sup_subject'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: text,
              maxLines: 4,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: l10n.t('sup_desc'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              if (subject.text.trim().isEmpty || text.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ApiClient.instance.createTicket(
                  subject: subject.text.trim(),
                  text: text.text.trim(),
                );
                await _load();
              } on ApiException {
                if (mounted) {
                  TopNotify.show(context, context.l10n.t('sup_fail_create'), success: false);
                }
              }
            },
            child: Text(l10n.t('sup_send')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    final l10n = context.l10n;
    final supportTg = ref.watch(appSettingsProvider.select((s) => s['support_tg'] ?? ''));

    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ScreenHeader(
                  title: l10n.t('sup_title'),
                  subtitle: l10n.t('sup_sub'),
                  showBack: true,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: EntranceAnim(
                    index: 0,
                    child: BrandCard(
                      highlighted: true,
                      onTap: supportTg.isNotEmpty ? () => _openTg(supportTg) : null,
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF229ED9).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: const Text('✈️', style: TextStyle(fontSize: 26)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.t('sup_tg_title'),
                                    style: const TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w800)),
                                SizedBox(height: 3),
                                Text(l10n.t('sup_tg_sub'),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          const GreenArrowBtn(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverToBoxAdapter(
                  child: EntranceAnim(
                    index: 1,
                    child: BrandCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('🎫',
                                  style: TextStyle(fontSize: 18)),
                              SizedBox(width: 8),
                              Text(l10n.t('sup_tickets'),
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800)),
                              Spacer(),
                              GestureDetector(
                                onTap: _create,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: green,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(l10n.t('sup_new'),
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_loading)
                            const Center(
                                child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator())),
                          if (!_loading && _tickets.isEmpty)
                            Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Text(l10n.t('sup_empty'),
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 13)),
                              ),
                            ),
                          for (final t in _tickets)
                            _TicketTile(
                              ticket: t,
                              onTap: () async {
                                await context.push('/support/${t['id']}');
                                _load();
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onTap;
  const _TicketTile({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final status = ticket['status'].toString();
    final color = switch (status) {
      'open' => isDark ? AppColors.brandNeon : AppColors.brandGreenDeep,
      'answered' => const Color(0xFFFFC107),
      _ => Colors.grey,
    };
    final text = switch (status) {
      'open' => l10n.t('sup_status_open'),
      'answered' => l10n.t('sup_status_answered'),
      _ => l10n.t('sup_status_closed'),
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF3F6F1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE3E8E3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ticket['subject'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    (ticket['last_text']?.toString() ?? '').isEmpty
                        ? '—'
                        : ticket['last_text'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(text,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Переписка по тикету.
class TicketDetailScreen extends ConsumerStatefulWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  ConsumerState<TicketDetailScreen> createState() =>
      _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  Map<String, dynamic>? _ticket;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.ticket(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _ticket = Map<String, dynamic>.from(res['ticket'] as Map);
        _messages = ((res['messages'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (_) {
      if (mounted) {
        TopNotify.show(context, context.l10n.t('error_network'), success: false);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ApiClient.instance.sendTicketMessage(widget.ticketId, text);
      _ctrl.clear();
      await _load();
    } catch (_) {
      if (mounted) {
        TopNotify.show(context, context.l10n.t('sup_fail_send'), success: false);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _close() async {
    try {
      await ApiClient.instance.closeTicket(widget.ticketId);
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppColors.brandNeon : AppColors.brandGreenDeep;
    final l10n = context.l10n;
    final closed = _ticket?['status'] == 'closed';
    final statusKey = switch (_ticket?['status']) {
      'open' => 'sup_status_open',
      'answered' => 'sup_status_answered',
      'closed' => 'sup_status_closed',
      _ => null,
    };

    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(
                title: _ticket?['subject']?.toString() ?? l10n.t('sup_title'),
                subtitle: statusKey != null
                    ? l10n.f('sup_status_label',
                        {'s': l10n.t(statusKey)})
                    : l10n.t('loading'),
                showBack: true,
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(20, 4, 20, 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final m = _messages[i];
                          final admin = m['is_admin'] == true;
                          return Align(
                            alignment: admin
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Container(
                              margin:
                                  const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 13, vertical: 10),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width *
                                        0.75,
                              ),
                              decoration: BoxDecoration(
                                color: admin
                                    ? green.withOpacity(0.14)
                                    : (isDark
                                        ? Colors.white.withOpacity(0.07)
                                        : const Color(0xFFF1F4F1)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: admin
                                      ? green.withOpacity(0.4)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    admin
                                        ? l10n.t('sup_agent')
                                        : l10n.t('sup_you'),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: admin
                                          ? green
                                          : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(m['text'].toString(),
                                      style: const TextStyle(
                                          fontSize: 13.5)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (!closed)
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          maxLength: 2000,
                          decoration: InputDecoration(
                            hintText: l10n.t('sup_msg_hint'),
                            counterText: '',
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _send,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: green,
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: _sending
                              ? const Padding(
                                  padding: EdgeInsets.all(13),
                                  child:
                                      CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black),
                                )
                              : const Icon(Icons.send_rounded,
                                  color: Colors.black, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!closed)
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: TextButton(
                    onPressed: _close,
                    child: Text(l10n.t('sup_close'),
                        style: const TextStyle(color: Colors.grey)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
