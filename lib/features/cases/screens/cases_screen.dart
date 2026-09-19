import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_widgets.dart';
import '../../../providers/balance_provider.dart';
import '../models/case_model.dart';
import '../providers/cases_provider.dart';

class CasesScreen extends ConsumerStatefulWidget {
  const CasesScreen({super.key});
  @override
  ConsumerState<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends ConsumerState<CasesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(casesListProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final casesState = ref.watch(casesListProvider);
    final user = ref.watch(userProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: ScreenHeader(
                          title: l10n.t('cases_title'),
                          subtitle: l10n.t('cases_sub'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF101814) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.brandGreen.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.monetization_on, color: Color(0xFFFFC107), size: 18),
                          const SizedBox(width: 6),
                          Text('${user.balanceNc} NC', style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF101410), decoration: TextDecoration.none)),
                        ]),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF101814) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(children: [
                          const Icon(Icons.account_balance_wallet, color: AppColors.brandGreen, size: 16),
                          const SizedBox(width: 6),
                          Text('${user.balanceCoins}', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF6B7280), fontSize: 13, decoration: TextDecoration.none)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Row(
                    children: [
                      Container(width: 3, height: 18, decoration: BoxDecoration(color: AppColors.brandGreen, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 10),
                      Text(l10n.t('cases_special'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.6, color: isDark ? Colors.white : const Color(0xFF101410), decoration: TextDecoration.none)),
                    ],
                  ),
                ),
              ),
              casesState.when(
                loading: () => const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))),
                error: (e, _) => SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Ошибка загрузки', style: TextStyle(decoration: TextDecoration.none))))),
                data: (list) {
                  if (list.isEmpty) return const SliverToBoxAdapter(child: Center(child: Text('Кейсов пока нет', style: TextStyle(decoration: TextDecoration.none))));
                  // Разделяем: сверху Мусор+Ежедневный вдвоём, чуть ниже 3 платных (McLaren, Офис, Бурж)
                  final trash = list.where((c) => c.id == 'case_trash').toList();
                  final daily = list.where((c) => c.id == 'case_daily').toList();
                  final paid = list.where((c) => c.id != 'case_trash' && c.id != 'case_daily').toList();
                  // fallback если id другие
                  final topTwo = [...trash, ...daily];
                  if (topTwo.length < 2 && list.length >= 2) {
                    // если мусор/дэйли не найдены — берём первые два как топ
                    topTwo.clear();
                    topTwo.addAll(list.take(2));
                    paid.clear();
                    paid.addAll(list.skip(2));
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    sliver: SliverList.list(
                      children: [
                        // Верхний ряд — 2 карточки (Мусор и Ежедневный) — компактные, фото крупнее
                        if (topTwo.isNotEmpty)
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.25,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: topTwo.length,
                            itemBuilder: (context, i) {
                              final c = topTwo[i];
                              return EntranceAnim(index: i, child: _CaseCard(caseModel: c, onTap: () => context.push('/cases/${c.id}'), compact: true));
                            },
                          ),
                        const SizedBox(height: 12),
                        // Нижний ряд — 3 платных — ещё компактнее
                        if (paid.isNotEmpty)
                          LayoutBuilder(builder: (context, cons) {
                            final w = MediaQuery.of(context).size.width;
                            final cols = w >= 700 ? 3 : 2;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                childAspectRatio: 1.25,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: paid.length,
                              itemBuilder: (context, i) {
                                final c = paid[i];
                                return EntranceAnim(index: 2 + i, child: _CaseCard(caseModel: c, onTap: () => context.push('/cases/${c.id}'), compact: true));
                              },
                            );
                          }),
                        // если есть ещё кейсы сверх 5 — показываем остальные так же
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  final CaseModel caseModel;
  final VoidCallback onTap;
  final bool compact;
  const _CaseCard({required this.caseModel, required this.onTap, this.compact = false});

  String _priceText(BuildContext context) {
    if (caseModel.id == 'case_trash') return context.l10n.t('case_trash_free');
    if (caseModel.id == 'case_daily') return context.l10n.t('case_daily_free');
    if (caseModel.priceNc == 0) return context.l10n.t('case_price_free');
    return '${caseModel.priceNc} NC';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Ещё уменьшены — как на скрине, но фото внутри увеличено
    final imageSize = compact ? 88.0 : 78.0;
    final circleSize = compact ? 90.0 : 80.0;
    return BrandCard(
      onTap: onTap,
      borderRadius: 12,
      padding: EdgeInsets.all(compact ? 6 : 8),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: isDark ? [AppColors.brandGreen.withOpacity(0.14), Colors.transparent] : [AppColors.brandGreen.withOpacity(0.10), Colors.transparent]),
                  ),
                ),
                Image.asset(
                  caseModel.imageAsset ?? 'assets/case/${caseModel.id}.png',
                  width: imageSize,
                  height: imageSize,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/iconmainmenu/case.png',
                    width: imageSize * 0.85,
                    height: imageSize * 0.85,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: imageSize * 0.75,
                      height: imageSize * 0.75,
                      decoration: BoxDecoration(color: const Color(0xFF0C120E), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.brandNeon, width: 1.6)),
                      alignment: Alignment.center,
                      child: const Text('CASE', style: TextStyle(color: AppColors.brandNeon, fontWeight: FontWeight.w900, fontSize: 12, decoration: TextDecoration.none)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(caseModel.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: compact ? 11 : 12, color: isDark ? Colors.white : const Color(0xFF101410), decoration: TextDecoration.none), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stars, color: Color(0xFFFFC107), size: 11),
              const SizedBox(width: 3),
              Text(_priceText(context), style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.w800, fontSize: 10, decoration: TextDecoration.none)),
            ],
          ),
        ],
      ),
    );
  }
}
