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
              // NC баланс pill как в меню?
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
                          Text('${user.balanceNc} NC', style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF101410))),
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
                          Text('${user.balanceCoins}', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF6B7280), fontSize: 13)),
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
                      Text(l10n.t('cases_special'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.6, color: isDark ? Colors.white : const Color(0xFF101410))),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                sliver: casesState.when(
                  loading: () => const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))),
                  error: (e, _) => SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Ошибка загрузки')))),
                  data: (list) {
                    if (list.isEmpty) return const SliverToBoxAdapter(child: Center(child: Text('Кейсов пока нет')));
                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).size.width >= 980 ? 4 : MediaQuery.of(context).size.width >= 700 ? 3 : 2,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      delegate: SliverChildBuilderDelegate((context, i) {
                        final c = list[i];
                        return EntranceAnim(index: i, child: _CaseCard(caseModel: c, onTap: () => context.push('/cases/${c.id}')));
                      }, childCount: list.length),
                    );
                  },
                ),
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
  const _CaseCard({required this.caseModel, required this.onTap});

  String _priceText(BuildContext context) {
    if (caseModel.id == 'case_trash') return context.l10n.t('case_trash_free');
    if (caseModel.id == 'case_daily') return context.l10n.t('case_daily_free');
    if (caseModel.priceNc == 0) return context.l10n.t('case_price_free');
    return '${caseModel.priceNc} NC';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Кейсы стали компактнее: меньше картинка и отступы
    return BrandCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: isDark ? [AppColors.brandGreen.withOpacity(0.18), Colors.transparent] : [AppColors.brandGreen.withOpacity(0.12), Colors.transparent]),
                  ),
                ),
                Image.asset(
                  caseModel.imageAsset ?? 'assets/case/${caseModel.id}.png',
                  width: 78,
                  height: 78,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/iconmainmenu/case.png',
                    width: 64,
                    height: 64,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: const Color(0xFF0C120E), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.brandNeon, width: 1.6)),
                      alignment: Alignment.center,
                      child: const Text('CASE', style: TextStyle(color: AppColors.brandNeon, fontWeight: FontWeight.w900, fontSize: 13)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(caseModel.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF101410)), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stars, color: Color(0xFFFFC107), size: 13),
              const SizedBox(width: 4),
              Text(_priceText(context), style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.w800, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
