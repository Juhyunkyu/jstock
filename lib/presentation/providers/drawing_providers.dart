import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/chart_drawing.dart';
import '../../data/repositories/chart_drawing_repository.dart';
import 'core/repository_providers.dart';

/// 차트 드로잉 상태 관리 Notifier
///
/// 수동 load 패턴 (WatchlistNotifier와 동일)
/// - invalidate() 후 loadForSymbol() 명시 호출 필요
class ChartDrawingNotifier extends StateNotifier<List<ChartDrawing>> {
  final ChartDrawingRepository _repository;

  ChartDrawingNotifier(this._repository) : super([]);

  /// 특정 심볼의 드로잉 로드
  void loadForSymbol(String symbol) {
    state = _repository.getBySymbol(symbol);
  }

  /// 드로잉 추가
  Future<void> addDrawing(ChartDrawing drawing) async {
    await _repository.add(drawing);
    state = [...state, drawing];
  }

  /// 드래그 중 State만 변경 (Hive 미저장, 성능)
  void updateDrawingLocal(ChartDrawing drawing) {
    state = [
      for (final d in state)
        if (d.id == drawing.id) drawing else d,
    ];
  }

  /// 드래그 완료 시 State + Hive 저장
  Future<void> updateDrawing(ChartDrawing drawing) async {
    await _repository.update(drawing);
    state = [
      for (final d in state)
        if (d.id == drawing.id) drawing else d,
    ];
  }

  /// 드로잉 삭제
  Future<void> removeDrawing(String id) async {
    await _repository.remove(id);
    state = state.where((d) => d.id != id).toList();
  }
}

/// 차트 드로잉 Provider
final chartDrawingProvider =
    StateNotifierProvider<ChartDrawingNotifier, List<ChartDrawing>>((ref) {
  final repo = ref.watch(chartDrawingRepositoryProvider);
  return ChartDrawingNotifier(repo);
});
