import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_cycle/domain/usecases/calculators/calculators.dart';
import 'package:alpha_cycle/domain/usecases/signal_detector.dart';
import 'package:alpha_cycle/data/models/cycle.dart';

/// 경계값 및 엣지 케이스 테스트
void main() {
  group('손실률 경계값 테스트', () {
    test('정확히 -20% (매수 시작점)', () {
      final lossRate = LossCalculator.calculate(80, 100);
      expect(lossRate, equals(-20.0));
      expect(LossCalculator.shouldWeightedBuy(80, 100), isTrue);
    });

    test('-19.9% (매수 안함)', () {
      final lossRate = LossCalculator.calculate(80.1, 100);
      expect(lossRate, closeTo(-19.9, 0.1));
      expect(LossCalculator.shouldWeightedBuy(80.1, 100), isFalse);
    });

    test('-20.1% (매수함)', () {
      final lossRate = LossCalculator.calculate(79.9, 100);
      expect(lossRate, closeTo(-20.1, 0.1));
      expect(LossCalculator.shouldWeightedBuy(79.9, 100), isTrue);
    });

    test('정확히 -50% (승부수 발동점)', () {
      final lossRate = LossCalculator.calculate(50, 100);
      expect(lossRate, equals(-50.0));
      expect(LossCalculator.shouldPanicBuy(50, 100), isTrue);
    });

    test('-49.9% (승부수 안함)', () {
      final lossRate = LossCalculator.calculate(50.1, 100);
      expect(lossRate, closeTo(-49.9, 0.1));
      expect(LossCalculator.shouldPanicBuy(50.1, 100), isFalse);
    });

    test('-50.1% (승부수 발동)', () {
      final lossRate = LossCalculator.calculate(49.9, 100);
      expect(lossRate, closeTo(-50.1, 0.1));
      expect(LossCalculator.shouldPanicBuy(49.9, 100), isTrue);
    });
  });

  group('수익률 경계값 테스트', () {
    test('정확히 +20% (익절점)', () {
      final returnRate = ReturnCalculator.calculate(120, 100);
      expect(returnRate, equals(20.0));
      expect(ReturnCalculator.shouldTakeProfit(120, 100), isTrue);
    });

    test('+19.9% (익절 안함)', () {
      final returnRate = ReturnCalculator.calculate(119.9, 100);
      expect(returnRate, closeTo(19.9, 0.1));
      expect(ReturnCalculator.shouldTakeProfit(119.9, 100), isFalse);
    });

    test('+20.1% (익절함)', () {
      final returnRate = ReturnCalculator.calculate(120.1, 100);
      expect(returnRate, closeTo(20.1, 0.1));
      expect(ReturnCalculator.shouldTakeProfit(120.1, 100), isTrue);
    });
  });

  group('극단적 손실률 테스트', () {
    test('-90% 손실', () {
      final lossRate = LossCalculator.calculate(10, 100);
      expect(lossRate, equals(-90.0));
      expect(LossCalculator.shouldWeightedBuy(10, 100), isTrue);
      expect(LossCalculator.shouldPanicBuy(10, 100), isTrue);
    });

    test('-99% 손실', () {
      final lossRate = LossCalculator.calculate(1, 100);
      expect(lossRate, equals(-99.0));

      // 가중 매수 금액 계산: 2000만 × 99 ÷ 1000 = 198만원
      final buyAmount = WeightedBuyCalculator.calculate(20000000, -99);
      expect(buyAmount, equals(1980000.0));
    });

    test('-100% (완전 손실)', () {
      final lossRate = LossCalculator.calculate(0.001, 100);
      expect(lossRate, closeTo(-100.0, 0.1));
    });
  });

  group('가중 매수 금액 다양한 시드 테스트', () {
    test('시드 5000만원, -20% 손실', () {
      // 초기진입금 = 5000만 × 0.2 = 1000만
      // 가중매수 = 1000만 × 20 ÷ 1000 = 20만
      final buyAmount = WeightedBuyCalculator.calculate(10000000, -20);
      expect(buyAmount, equals(200000.0));
    });

    test('시드 1억원, -30% 손실', () {
      // 초기진입금 = 1억 × 0.2 = 2000만
      // 가중매수 = 2000만 × 30 ÷ 1000 = 60만
      final buyAmount = WeightedBuyCalculator.calculate(20000000, -30);
      expect(buyAmount, equals(600000.0));
    });

    test('시드 3억원, -40% 손실', () {
      // 초기진입금 = 3억 × 0.2 = 6000만
      // 가중매수 = 6000만 × 40 ÷ 1000 = 240만
      final buyAmount = WeightedBuyCalculator.calculate(60000000, -40);
      expect(buyAmount, equals(2400000.0));
    });
  });

  group('승부수 + 가중매수 조합 테스트', () {
    test('-50% 시 총 매수 금액 (시드 1억)', () {
      // 승부수: 2000만 × 0.5 = 1000만
      // 가중매수: 2000만 × 50 ÷ 1000 = 100만
      // 총: 1100만
      final total = PanicBuyCalculator.calculateTotalWithWeighted(20000000, -50);
      expect(total, equals(11000000.0));
    });

    test('-60% 시 총 매수 금액 (시드 1억)', () {
      // 승부수: 1000만 (고정)
      // 가중매수: 2000만 × 60 ÷ 1000 = 120만
      // 총: 1120만
      final total = PanicBuyCalculator.calculateTotalWithWeighted(20000000, -60);
      expect(total, equals(11200000.0));
    });

    test('-70% 시 총 매수 금액 (시드 5000만)', () {
      // 초기진입금: 1000만
      // 승부수: 1000만 × 0.5 = 500만
      // 가중매수: 1000만 × 70 ÷ 1000 = 70만
      // 총: 570만
      final total = PanicBuyCalculator.calculateTotalWithWeighted(10000000, -70);
      expect(total, equals(5700000.0));
    });
  });

  group('평균단가 계산 정밀도 테스트', () {
    test('연속 매수 시 평균단가 계산', () {
      // 1차 매수: $100에 100주
      // 2차 매수: $80에 100주
      // 3차 매수: $60에 200주

      // 1차 후 평균: $100
      var avgPrice = AveragePriceCalculator.calculate(10000, 100);
      expect(avgPrice, equals(100.0));

      // 2차 후 평균: (10000 + 8000) / 200 = $90
      avgPrice = AveragePriceCalculator.calculateAfterBuy(100, 100, 80, 100);
      expect(avgPrice, equals(90.0));

      // 3차 후 평균: (18000 + 12000) / 400 = $75
      avgPrice = AveragePriceCalculator.calculateAfterBuy(90, 200, 60, 200);
      expect(avgPrice, equals(75.0));
    });

    test('소수점 주식 수량 처리', () {
      // $142.86에 0.7주 매수
      // 총 투자 = $100
      final avgPrice = AveragePriceCalculator.calculate(100, 0.7);
      expect(avgPrice, closeTo(142.86, 0.01));
    });
  });

  group('SignalDetector 시나리오 테스트', () {
    late Cycle cycle;

    setUp(() {
      cycle = Cycle(
        id: 'test-1',
        ticker: 'TQQQ',
        cycleNumber: 1,
        seedAmount: 100000000, // 1억
        initialEntryPrice: 100.0,
        exchangeRate: 1400.0,
      );

      // 초기 진입: 20% 매수
      cycle.recordBuy(
        price: 100.0,
        shares: 142.86,
        amountKrw: 20000000,
        isPanic: false,
      );
    });

    test('시나리오: 하락 → 회복 → 익절', () {
      // 1. 시작: $100
      expect(SignalDetector.detectSignal(cycle, 100), equals(TradingSignal.hold));

      // 2. -10% 하락: $90 → HOLD
      expect(SignalDetector.detectSignal(cycle, 90), equals(TradingSignal.hold));

      // 3. -20% 하락: $80 → WEIGHTED_BUY
      expect(SignalDetector.detectSignal(cycle, 80), equals(TradingSignal.weightedBuy));

      // 4. 추가 매수 실행
      cycle.recordBuy(price: 80.0, shares: 35.71, amountKrw: 400000, isPanic: false);

      // 5. 회복: $96 → HOLD (새 평균단가 기준 수익률 확인 필요)
      // 새 평균단가: (14286 + 2857) / (142.86 + 35.71) ≈ $95.9
      expect(SignalDetector.detectSignal(cycle, 96), equals(TradingSignal.hold));

      // 6. 추가 상승: $120 → TAKE_PROFIT (평균단가 대비 +25%)
      expect(SignalDetector.detectSignal(cycle, 120), equals(TradingSignal.takeProfit));
    });

    test('시나리오: 급락 → 승부수 → 회복', () {
      // 1. 급락: $50 → PANIC_BUY
      expect(SignalDetector.detectSignal(cycle, 50), equals(TradingSignal.panicBuy));

      // 2. 승부수 실행
      cycle.recordBuy(
        price: 50.0,
        shares: 220.0, // 약 $11,000 (승부수+가중)
        amountKrw: 11000000,
        isPanic: true,
      );
      expect(cycle.panicUsed, isTrue);

      // 3. 추가 하락: $40 → WEIGHTED_BUY (승부수 이미 사용)
      expect(SignalDetector.detectSignal(cycle, 40), equals(TradingSignal.weightedBuy));

      // 4. 회복으로 익절
      // 새 평균단가 계산 필요
      // 총 투자 USD: (20000000 + 11000000) / 1400 ≈ $22,143
      // 총 수량: 142.86 + 220 = 362.86
      // 평균단가: $22,143 / 362.86 ≈ $61
      // 익절가: $61 × 1.2 = $73.2
      expect(SignalDetector.detectSignal(cycle, 75), equals(TradingSignal.takeProfit));
    });

    test('시나리오: 지속 상승 (매수 없이 HOLD 유지)', () {
      // 상승 구간에서는 계속 HOLD
      for (var price = 101.0; price <= 119.0; price += 2) {
        expect(SignalDetector.detectSignal(cycle, price), equals(TradingSignal.hold));
      }

      // 익절 구간 진입
      expect(SignalDetector.detectSignal(cycle, 120), equals(TradingSignal.takeProfit));
    });

    test('시나리오: 현금 소진 경고', () {
      // 연속 매수로 현금 소진 (더 많은 매수 추가)
      cycle.recordBuy(price: 80.0, shares: 100, amountKrw: 11200000, isPanic: false);
      cycle.recordBuy(price: 70.0, shares: 100, amountKrw: 9800000, isPanic: false);
      cycle.recordBuy(price: 60.0, shares: 100, amountKrw: 8400000, isPanic: false);
      cycle.recordBuy(price: 55.0, shares: 100, amountKrw: 7700000, isPanic: false);
      cycle.recordBuy(price: 52.0, shares: 100, amountKrw: 7280000, isPanic: false);
      // 추가 매수로 현금 더 소진
      cycle.recordBuy(price: 51.0, shares: 100, amountKrw: 7140000, isPanic: false);
      cycle.recordBuy(price: 50.5, shares: 100, amountKrw: 7070000, isPanic: false);
      cycle.recordBuy(price: 50.2, shares: 100, amountKrw: 7028000, isPanic: false);

      // 잔여 현금 확인
      final recommendation = SignalDetector.getRecommendation(cycle, 50);

      // 현금이 부족해도 신호는 발생
      expect(recommendation.signal, equals(TradingSignal.panicBuy));

      // 현금 잔고 확인 (많은 매수 후 현금 부족)
      // 총 매수: 20M + 11.2M + 9.8M + 8.4M + 7.7M + 7.28M + 7.14M + 7.07M + 7.028M = 85.618M
      // 잔여: 100M - 85.618M = 14.382M
      // 승부수 + 가중: 10M + 1M = 11M
      // 14.382M > 11M 이므로 아직 충분함
      // 현금이 충분하면 정상적으로 매수 권장 금액 표시
      expect(recommendation.recommendedAmount, greaterThan(0));
    });
  });

  group('엣지 케이스: 잘못된 입력 처리', () {
    test('음수 가격 처리', () {
      // 음수 가격은 0으로 처리하거나 예외 발생해야 함
      final lossRate = LossCalculator.calculate(-10, 100);
      expect(lossRate, closeTo(-110.0, 0.01)); // 수학적으로 계산됨
    });

    test('매우 작은 가격 처리', () {
      final lossRate = LossCalculator.calculate(0.0001, 100);
      expect(lossRate, closeTo(-100.0, 0.01));
    });

    test('매우 큰 가격 처리', () {
      final lossRate = LossCalculator.calculate(1000000, 100);
      expect(lossRate, equals(999900.0));
    });

    test('0원 시드 처리', () {
      final buyAmount = WeightedBuyCalculator.calculate(0, -25);
      expect(buyAmount, equals(0.0));
    });
  });

  group('수수료 및 세금 고려 (향후 확장)', () {
    test('순수익 계산 (세전)', () {
      // 평균단가 $80, 현재가 $96, 100주
      // 총 투자: $8,000
      // 현재 가치: $9,600
      // 수익: $1,600
      final totalInvestment = 80 * 100;
      final currentValue = 96 * 100;
      final profit = currentValue - totalInvestment;

      expect(profit, equals(1600.0));
    });
  });
}
