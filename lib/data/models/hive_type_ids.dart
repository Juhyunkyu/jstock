/// Hive TypeId 레지스트리
///
/// 새 모델 추가 시 반드시 여기에 등록하여 충돌을 방지한다.
/// TypeId는 0~223 범위 (Hive 제한).
///
/// 이 파일은 문서 목적이며, 실제 @HiveType 어노테이션은
/// 각 모델 파일에 존재한다.
abstract class HiveTypeIds {
  // ── 기본 모델 ──────────────────────────────────────
  /// [Stock] — lib/data/models/stock.dart
  static const int stock = 0;

  /// [Cycle] — lib/data/models/cycle.dart
  static const int cycle = 1;

  /// [Trade] — lib/data/models/trade.dart
  static const int trade = 2;

  /// [Settings] — lib/data/models/settings.dart
  static const int settings = 3;

  // ── 차트 드로잉 ────────────────────────────────────
  /// [DrawingType] enum — lib/data/models/chart_drawing.dart
  static const int drawingType = 4;

  /// [ChartDrawing] — lib/data/models/chart_drawing.dart
  static const int chartDrawing = 5;

  // ── 6~9: 미사용 (예약) ─────────────────────────────

  // ── Cycle 관련 enum ────────────────────────────────
  /// [CycleStatus] enum — lib/data/models/cycle.dart
  static const int cycleStatus = 10;

  /// [TradeAction] enum — lib/data/models/trade.dart
  static const int tradeAction = 11;

  // ── 보유 (Holding) ─────────────────────────────────
  /// [Holding] — lib/data/models/holding.dart
  static const int holding = 12;

  /// [HoldingTransaction] — lib/data/models/holding_transaction.dart
  static const int holdingTransaction = 13;

  /// [HoldingTransactionType] enum — lib/data/models/holding_transaction.dart
  static const int holdingTransactionType = 14;

  // ── 관심종목 / 알림 ───────────────────────────────
  /// [WatchlistItem] — lib/data/models/watchlist_item.dart
  static const int watchlistItem = 15;

  /// [NotificationRecord] — lib/data/models/notification_record.dart
  static const int notificationRecord = 16;

  // ── 17~19: 미사용 (예약) ───────────────────────────

  // ── 전략 / 거래 enum ──────────────────────────────
  /// [StrategyType] enum — lib/data/models/cycle.dart
  static const int strategyType = 20;

  /// [TradeSignal] enum — lib/data/models/trade.dart
  static const int tradeSignal = 21;

  // ── 그룹 / 최근 보기 ──────────────────────────────
  /// [WatchlistGroup] — lib/data/models/watchlist_group.dart
  static const int watchlistGroup = 22;

  /// [RecentViewItem] — lib/data/models/recent_view_item.dart
  static const int recentViewItem = 23;

  /// [SteadyVersion] enum — lib/data/models/cycle.dart
  static const int steadyVersion = 24;

  // ── 메모 ───────────────────────────────────────────
  /// [Memo] — lib/data/models/memo.dart
  static const int memo = 25;

  /// [MemoCategory] enum — lib/data/models/memo.dart
  static const int memoCategory = 26;

  // ── 다음 사용 가능 ID: 27 ─────────────────────────
}
