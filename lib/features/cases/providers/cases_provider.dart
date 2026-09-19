import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/api_client.dart';
import '../models/case_model.dart';

final casesListProvider = StateNotifierProvider<CasesNotifier, AsyncValue<List<CaseModel>>>((ref) => CasesNotifier());

class CasesNotifier extends StateNotifier<AsyncValue<List<CaseModel>>> {
  CasesNotifier() : super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final res = await ApiClient.instance.cases();
      final raw = res['cases'] as List? ?? [];
      final list = raw.where((e) => e != null).map((e) => CaseModel.fromJson((e as Map).cast<String, dynamic>())).toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

class CaseDetailState {
  final CaseModel? info;
  final List<CaseItemModel> items;
  final bool loading;
  final String? error;
  final int dailyUsed;
  final int dailyRemaining;
  final DateTime? dailyNextReset;
  const CaseDetailState({this.info, this.items = const [], this.loading = false, this.error, this.dailyUsed = 0, this.dailyRemaining = 10, this.dailyNextReset});
  CaseDetailState copyWith({CaseModel? info, List<CaseItemModel>? items, bool? loading, String? error, int? dailyUsed, int? dailyRemaining, DateTime? dailyNextReset}) =>
      CaseDetailState(info: info ?? this.info, items: items ?? this.items, loading: loading ?? this.loading, error: error, dailyUsed: dailyUsed ?? this.dailyUsed, dailyRemaining: dailyRemaining ?? this.dailyRemaining, dailyNextReset: dailyNextReset ?? this.dailyNextReset);
}

final caseDetailProvider = StateNotifierProvider.family<CaseDetailNotifier, CaseDetailState, String>((ref, caseId) => CaseDetailNotifier(caseId));

class CaseDetailNotifier extends StateNotifier<CaseDetailState> {
  final String caseId;
  CaseDetailNotifier(this.caseId) : super(const CaseDetailState(loading: true));

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await ApiClient.instance.caseDetail(caseId);
      final caseJson = res['case'];
      if (caseJson == null) throw Exception('Кейс не найден (null): $res');
      final c = CaseModel.fromJson((caseJson as Map).cast<String, dynamic>());
      final itemsRaw = res['items'] as List? ?? [];
      final items = itemsRaw.where((e) => e != null).map((e) => CaseItemModel.fromJson((e as Map).cast<String, dynamic>())).toList();
      final daily = res['daily'] as Map?;
      int used = 0, remaining = 10;
      DateTime? nextReset;
      if (daily != null) {
        used = (daily['used'] as num?)?.toInt() ?? 0;
        remaining = (daily['remaining'] as num?)?.toInt() ?? (10 - used);
        nextReset = daily['next_reset'] != null ? DateTime.tryParse(daily['next_reset'].toString()) : null;
      }
      state = CaseDetailState(info: c, items: items, loading: false, dailyUsed: used, dailyRemaining: remaining, dailyNextReset: nextReset);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

class CaseOpenState {
  final bool opening;
  final List<CaseOpenWon> won;
  final String? error;
  const CaseOpenState({this.opening = false, this.won = const [], this.error});
}

final caseOpenProvider = StateNotifierProvider<CaseOpenNotifier, CaseOpenState>((ref) => CaseOpenNotifier());

class CaseOpenNotifier extends StateNotifier<CaseOpenState> {
  CaseOpenNotifier() : super(const CaseOpenState());
  Future<List<CaseOpenWon>> open(String caseId, int count) async {
    state = const CaseOpenState(opening: true);
    try {
      final res = await ApiClient.instance.openCase(caseId, count: count);
      final wonRaw = res['won'] as List?;
      if (wonRaw == null) throw ApiException('error_generic', 'Пустой ответ сервера: $res');
      final won = wonRaw.where((e) => e != null).map((e) => CaseOpenWon.fromJson((e as Map).cast<String, dynamic>())).toList();
      if (won.isEmpty) throw ApiException('error_generic', 'Сервер не вернул призы');
      state = CaseOpenState(won: won);
      return won;
    } catch (e) {
      final msg = e is ApiException ? e.message : e.toString();
      state = CaseOpenState(error: msg);
      rethrow;
    }
  }

  void clear() => state = const CaseOpenState();
}
