import 'trading_position.dart';

/// 트레이딩 전략 유형
///
/// 확장 가능한 매매법을 위한 열거형
enum TradingStrategy {
  /// 알파 사이클 매매법 (현재 구현)
  alphaCycle,

  /// DCA (Dollar Cost Averaging) - 미래 확장용
  dca,

  /// 그리드 트레이딩 - 미래 확장용
  gridTrading,

  /// 사용자 정의 전략 - 미래 확장용
  custom,
}

/// 전략 기반 트레이딩 포지션 인터페이스
///
/// 특정 매매 전략을 따르는 포지션이 구현해야 하는 인터페이스.
/// TradingPosition을 확장하여 전략별 신호 및 추천 기능을 추가합니다.
abstract class StrategyPosition extends TradingPosition {
  /// 적용된 트레이딩 전략
  TradingStrategy get strategy;

  /// 전략이 활성 상태인지 여부
  bool get isStrategyActive;

  /// 현재 가격 기준 매매 신호 조회
  ///
  /// [currentPrice] - 현재 주가 (USD)
  /// 반환값: 매매 신호 유형 (hold, buy, sell 등 전략에 따라 다름)
  String getSignal(double currentPrice);

  /// 전략별 설정 정보
  ///
  /// 각 전략의 매개변수를 Map 형태로 반환
  /// 예: 알파 사이클의 경우 buyTrigger, sellTrigger 등
  Map<String, dynamic> get strategyConfig;

  /// 전략별 권장 행동 메시지
  ///
  /// [currentPrice] - 현재 주가 (USD)
  /// 반환값: 사용자에게 표시할 권장 행동 메시지
  String? getRecommendationMessage(double currentPrice);
}
