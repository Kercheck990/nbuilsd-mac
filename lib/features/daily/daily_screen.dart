import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../core/widgets/top_notify.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_client.dart';

class DailyScreen extends ConsumerStatefulWidget {
  const DailyScreen({super.key});
  @override
  ConsumerState<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends ConsumerState<DailyScreen> {
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.dailyTasks();
      if (!mounted) return;
      setState(() => _tasks = ((res['tasks'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (_) {} finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _claim(String id) async {
    try {
      await ApiClient.instance.claimDaily(id);
      TopNotify.show(context, 'Награда получена 🎉', success: true);
      _load();
    } catch (e) {
      final msg = e is ApiException ? e.message : e.toString();
      TopNotify.show(context, msg, success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: ScreenHeader(title: 'Ежедневные задания', subtitle: 'Выполняй и получай монеты/гифты', showBack: true)),
              if (_loading) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                sliver: SliverList.list(children: [
                  for (int i = 0; i < _tasks.length; i++)
                    EntranceAnim(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: BrandCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.brandGreen.withOpacity(0.14), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.task_alt_rounded, color: AppColors.brandGreenDeep, size: 20)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(_tasks[i]['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800))),
                              if (_tasks[i]['claimed'] == true)
                                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(99)), child: const Text('Получено', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green))),
                            ]),
                            const SizedBox(height: 8),
                            Text(_tasks[i]['description']?.toString() ?? '', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF8A94A6))),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: ((_tasks[i]['progress'] as num?)?.toDouble() ?? 0) / ((_tasks[i]['requirement_count'] as num?)?.toDouble() ?? 1).clamp(0.01, 1000),
                                minHeight: 8,
                                backgroundColor: isDark ? Colors.white10 : const Color(0xFFE3E8E3),
                                valueColor: AlwaysStoppedAnimation(AppColors.brandGreen),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(children: [
                              Text('${_tasks[i]['progress']}/${_tasks[i]['requirement_count']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              const Spacer(),
                              Text(
                                _tasks[i]['reward_item_id'] != null ? '🎁 +${_tasks[i]['reward_coins']} монет' : '+${_tasks[i]['reward_coins']} монет',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.brandGreenDeep),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: (_tasks[i]['completed'] == true && _tasks[i]['claimed'] != true) ? () => _claim(_tasks[i]['id'].toString()) : null,
                                child: Text(_tasks[i]['claimed'] == true ? 'Выполнено' : _tasks[i]['completed'] == true ? 'Забрать' : 'В процессе'),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
