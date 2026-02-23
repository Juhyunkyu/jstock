/// 알림 방향 enum
///
/// 목표가/공포탐욕지수 알림의 '이상/이하' 방향을 통일하는 enum.
/// Hive에 저장된 int 값은 유지하되, 매직넘버 대신 enum으로 변환하여 사용.
///
/// **Hive 호환성**:
/// - Target: 0=above, 1=below (기존 WatchlistItem.alertTargetDirection)
/// - FearGreed: 0=below, 1=above (기존 Settings.fearGreedAlertDirection)
/// → 기존 데이터와 호환되도록 from/to 변환 메서드 분리.
enum AlertDirection {
  above,
  below;

  /// 한글 라벨
  String get label => this == above ? '이상' : '이하';

  /// 한글 라벨 + 기호
  String get labelWithSymbol => this == above ? '이상 (≥)' : '이하 (≤)';

  // -- Target (WatchlistItem) 변환 --

  /// Hive int → enum (Target: 0=above, 1=below)
  static AlertDirection fromTargetInt(int? value) =>
      value == 1 ? below : above;

  /// enum → Hive int (Target: above=0, below=1)
  int get toTargetInt => this == above ? 0 : 1;

  // -- Fear & Greed 변환 --

  /// Hive int → enum (FearGreed: 0=below, 1=above)
  static AlertDirection fromFearGreedInt(int value) =>
      value == 1 ? above : below;

  /// enum → Hive int (FearGreed: below=0, above=1)
  int get toFearGreedInt => this == above ? 1 : 0;
}
