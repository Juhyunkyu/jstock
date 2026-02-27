import 'package:hive/hive.dart';
import '../models/chart_drawing.dart';

/// 차트 드로잉 데이터 저장소
class ChartDrawingRepository {
  static const String _boxName = 'chart_drawings';

  Box<ChartDrawing>? _box;

  /// Box 열기
  Future<void> init() async {
    _box = await Hive.openBox<ChartDrawing>(_boxName);
  }

  /// Box 가져오기
  Box<ChartDrawing> get box {
    if (_box == null || !_box!.isOpen) {
      throw StateError('ChartDrawingRepository가 초기화되지 않았습니다. init()을 먼저 호출하세요.');
    }
    return _box!;
  }

  /// 특정 심볼의 드로잉 조회
  List<ChartDrawing> getBySymbol(String symbol) {
    return box.values.where((d) => d.symbol == symbol).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// 드로잉 추가
  Future<void> add(ChartDrawing drawing) async {
    await box.put(drawing.id, drawing);
  }

  /// 드로잉 업데이트
  Future<void> update(ChartDrawing drawing) async {
    await box.put(drawing.id, drawing);
  }

  /// 드로잉 삭제
  Future<void> remove(String id) async {
    await box.delete(id);
  }

  /// 전체 삭제
  Future<void> clearAll() async {
    await box.clear();
  }

  /// Box 닫기
  Future<void> close() async {
    await _box?.close();
  }
}
