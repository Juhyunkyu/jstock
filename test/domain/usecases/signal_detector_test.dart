import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_cycle/data/models/cycle.dart';
import 'package:alpha_cycle/domain/usecases/signal_detector.dart';

void main() {
  late Cycle testCycle;

  setUp(() {
    // 테스트용 사이클 생성
    // 시드 1억, 초기진입가 $100, 환율 1400원
    testCycle = Cycle(
      id: 'test-cycle-1',
      ticker: 'TQQQ',
      cycleNumber: 1,
      seedAmount: 100000000, // 1억원
      initialEntryPrice: 100.0, // $100
      exchangeRate: 1400.0,
    );

    // 초기 진입 시뮬레이션 (20%)
    // 2000만원 / 1400 / 100 = 142.86주
    testCycle.recordBuy(
      price: 100.0,
      shares: 142.86,
      amountKrw: 20000000,
      isPanic: false,
    );
  });

  group('SignalDetector.detectSignal', () {
    test('HOLD - 손실률 0~-20% 구간', () {
      // 현재가 $90 → 손실률 -10%
      expect(
        SignalDetector.detectSignal(testCycle, 90),
        equals(TradingSignal.hold),
      );
    });

    test('WEIGHTED_BUY - 손실률 -20% 이하', () {
      // 현재가 $80 → 손실률 -20%
      expect(
        SignalDetector.detectSignal(testCycle, 80),
        equals(TradingSignal.weightedBuy),
      );

      // 현재가 $78 → 손실률 -22%
      expect(
        SignalDetector.detectSignal(testCycle, 78),
        equals(TradingSignal.weightedBuy),
      );
    });

    test('PANIC_BUY - 손실률 -50% 이하, 미사용', () {
      // 현재가 $50 → 손실률 -50%
      expect(
        SignalDetector.detectSignal(testCycle, 50),
        equals(TradingSignal.panicBuy),
      );
    });

    test('WEIGHTED_BUY - 손실률 -50% 이하지만 승부수 이미 사용', () {
      testCycle.panicUsed = true;

      // 승부수 사용 후에는 가중 매수만
      expect(
        SignalDetector.detectSignal(testCycle, 50),
        equals(TradingSignal.weightedBuy),
      );
    });

    test('TAKE_PROFIT - 수익률 +20% 이상', () {
      // 평균단가 $100 기준, 현재가 $120 → 수익률 +20%
      expect(
        SignalDetector.detectSignal(testCycle, 120),
        equals(TradingSignal.takeProfit),
      );
    });

    test('TAKE_PROFIT 우선순위 - 수익률이 익절 조건이면 익절', () {
      // 추가 매수로 평균단가를 크게 낮춤
      // 현재: 평균단가 $100, 보유 142.86주
      testCycle.recordBuy(
        price: 50.0,
        shares: 400,
        amountKrw: 28000000,
        isPanic: true,
      );

      // 새 평균단가 계산:
      // 총 투자(USD) = (20,000,000 + 28,000,000) / 1400 = 34,285.71
      // 총 수량 = 142.86 + 400 = 542.86
      // 평균단가 = 34,285.71 / 542.86 ≈ $63.16

      // 현재가 $76 → 평균단가 대비 +20.3% → 익절
      // 손실률(초기진입가 기준): ($76-$100)/$100 = -24%

      final signal = SignalDetector.detectSignal(testCycle, 76);

      // 수익률이 익절 조건(+20%)을 넘으므로 익절이 우선
      expect(signal, equals(TradingSignal.takeProfit));
    });
  });

  group('SignalDetector.getRecommendation', () {
    test('HOLD 권장 정보', () {
      final rec = SignalDetector.getRecommendation(testCycle, 90);

      expect(rec.signal, equals(TradingSignal.hold));
      expect(rec.recommendedAmount, equals(0.0));
      expect(rec.needsAction, isFalse);
      expect(rec.message, contains('관망'));
    });

    test('WEIGHTED_BUY 권장 금액', () {
      // 현재가 $75 → 손실률 -25%
      final rec = SignalDetector.getRecommendation(testCycle, 75);

      expect(rec.signal, equals(TradingSignal.weightedBuy));
      expect(rec.isBuySignal, isTrue);
      expect(rec.lossRate, equals(-25.0));

      // 가중 매수 금액: 2000만 × 25 ÷ 1000 = 50만원
      expect(rec.recommendedAmount, equals(500000.0));
    });

    test('PANIC_BUY 권장 금액 (승부수 + 가중매수)', () {
      // 현재가 $50 → 손실률 -50%
      final rec = SignalDetector.getRecommendation(testCycle, 50);

      expect(rec.signal, equals(TradingSignal.panicBuy));
      expect(rec.isBuySignal, isTrue);
      expect(rec.lossRate, equals(-50.0));

      // 승부수: 1000만원 + 가중매수: 100만원 = 1100만원
      expect(rec.recommendedAmount, equals(11000000.0));
      expect(rec.message, contains('승부수'));
    });

    test('TAKE_PROFIT 권장 정보', () {
      // 현재가 $120 → 수익률 +20%
      final rec = SignalDetector.getRecommendation(testCycle, 120);

      expect(rec.signal, equals(TradingSignal.takeProfit));
      expect(rec.isSellSignal, isTrue);
      expect(rec.returnRate, closeTo(20.0, 0.1)); // 부동소수점 오차 허용
      expect(rec.message, contains('익절'));
    });
  });

  group('TradingRecommendation', () {
    test('signalDisplayName', () {
      expect(
        TradingRecommendation(
          signal: TradingSignal.hold,
          recommendedAmount: 0,
          estimatedShares: 0,
          lossRate: 0,
          returnRate: 0,
        ).signalDisplayName,
        equals('보유'),
      );
    });

    test('signalEmoji', () {
      expect(
        TradingRecommendation(
          signal: TradingSignal.panicBuy,
          recommendedAmount: 0,
          estimatedShares: 0,
          lossRate: 0,
          returnRate: 0,
        ).signalEmoji,
        equals('🔴'),
      );
    });
  });
}
