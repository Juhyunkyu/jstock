import 'package:hive_flutter/hive_flutter.dart';
import '../models/rsi_watch_point.dart';

/// RSI 감시점 저장소
class RsiWatchPointRepository {
  static const String _boxName = 'rsiWatchPoints';
  late Box<RsiWatchPoint> _box;

  /// 저장소 초기화
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(27)) {
      Hive.registerAdapter(RsiWatchPointAdapter());
    }
    _box = await Hive.openBox<RsiWatchPoint>(_boxName);
  }

  /// 모든 감시점 가져오기 (생성일 기준 정렬)
  List<RsiWatchPoint> getAll() {
    final points = _box.values.toList();
    points.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return points;
  }

  /// 활성 감시점만 가져오기
  List<RsiWatchPoint> getActive() {
    return _box.values.where((p) => p.isActive).toList();
  }

  /// 특정 티커의 감시점 가져오기
  List<RsiWatchPoint> getByTicker(String ticker) {
    return _box.values.where((p) => p.ticker == ticker).toList();
  }

  /// ID로 감시점 찾기
  RsiWatchPoint? getById(String id) {
    try {
      return _box.values.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 감시점 추가
  Future<void> add(RsiWatchPoint point) async {
    await _box.put(point.id, point);
  }

  /// 감시점 삭제
  Future<void> remove(String id) async {
    await _box.delete(id);
  }

  /// 감시점 업데이트
  Future<void> update(RsiWatchPoint point) async {
    await _box.put(point.id, point);
  }

  /// 전체 삭제
  Future<void> clear() async {
    await _box.clear();
  }

  /// 감시점 수
  int get count => _box.length;
}
