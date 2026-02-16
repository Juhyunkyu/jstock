import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_cycle/domain/usecases/calculators/calculators.dart';

void main() {
  group('LossCalculator', () {
    test('손실률 계산 - 기본 케이스', () {
      // 초기진입가 $100, 현재가 $80 → -20%
      expect(LossCalculator.calculate(80, 100), equals(-20.0));
    });

    test('손실률 계산 - 상승 케이스', () {
      // 초기진입가 $100, 현재가 $120 → +20%
      expect(LossCalculator.calculate(120, 100), equals(20.0));
    });

    test('손실률 계산 - 50% 하락', () {
      // 초기진입가 $100, 현재가 $50 → -50%
      expect(LossCalculator.calculate(50, 100), equals(-50.0));
    });

    test('손실률 계산 - 변동 없음', () {
      expect(LossCalculator.calculate(100, 100), equals(0.0));
    });

    test('손실률 계산 - 초기진입가 0 예외 처리', () {
      expect(LossCalculator.calculate(80, 0), equals(0.0));
    });

    test('가중 매수 조건 판단', () {
      // -20% 이하일 때 true
      expect(LossCalculator.shouldWeightedBuy(80, 100), isTrue);
      expect(LossCalculator.shouldWeightedBuy(79, 100), isTrue);
      // -20% 초과일 때 false
      expect(LossCalculator.shouldWeightedBuy(81, 100), isFalse);
      expect(LossCalculator.shouldWeightedBuy(100, 100), isFalse);
    });

    test('승부수 조건 판단', () {
      // -50% 이하일 때 true
      expect(LossCalculator.shouldPanicBuy(50, 100), isTrue);
      expect(LossCalculator.shouldPanicBuy(49, 100), isTrue);
      // -50% 초과일 때 false
      expect(LossCalculator.shouldPanicBuy(51, 100), isFalse);
    });
  });

  group('ReturnCalculator', () {
    test('수익률 계산 - 기본 케이스', () {
      // 평균단가 $75, 현재가 $90 → +20%
      expect(ReturnCalculator.calculate(90, 75), equals(20.0));
    });

    test('수익률 계산 - 손실 케이스', () {
      // 평균단가 $75, 현재가 $60 → -20%
      expect(ReturnCalculator.calculate(60, 75), equals(-20.0));
    });

    test('수익률 계산 - 평균단가 0 예외 처리', () {
      expect(ReturnCalculator.calculate(90, 0), equals(0.0));
    });

    test('익절 조건 판단', () {
      // +20% 이상일 때 true
      expect(ReturnCalculator.shouldTakeProfit(90, 75), isTrue);
      expect(ReturnCalculator.shouldTakeProfit(91, 75), isTrue);
      // +20% 미만일 때 false
      expect(ReturnCalculator.shouldTakeProfit(89, 75), isFalse);
    });

    test('목표 익절가 계산', () {
      // 평균단가 $75, 목표 수익률 20% → $90
      expect(ReturnCalculator.calculateTargetPrice(75, 20), equals(90.0));
      // 평균단가 $100, 목표 수익률 20% → $120
      expect(ReturnCalculator.calculateTargetPrice(100, 20), equals(120.0));
    });
  });

  group('WeightedBuyCalculator', () {
    test('가중 매수 금액 계산 - 기본 케이스', () {
      // 초기진입금 2,000만원, 손실률 -25% → 50만원
      // 공식: 2000만 × 25 ÷ 1000 = 50만
      expect(
        WeightedBuyCalculator.calculate(20000000, -25),
        equals(500000.0),
      );
    });

    test('가중 매수 금액 계산 - 20% 손실', () {
      // 초기진입금 2,000만원, 손실률 -20% → 40만원
      expect(
        WeightedBuyCalculator.calculate(20000000, -20),
        equals(400000.0),
      );
    });

    test('가중 매수 금액 계산 - 50% 손실', () {
      // 초기진입금 2,000만원, 손실률 -50% → 100만원
      expect(
        WeightedBuyCalculator.calculate(20000000, -50),
        equals(1000000.0),
      );
    });

    test('가중 매수 테이블 생성', () {
      final table = WeightedBuyCalculator.generateBuyTable(20000000);

      expect(table[-20], equals(400000.0));
      expect(table[-22], equals(440000.0));
      expect(table[-50], equals(1000000.0));
    });
  });

  group('PanicBuyCalculator', () {
    test('승부수 금액 계산', () {
      // 초기진입금 2,000만원 → 1,000만원
      expect(
        PanicBuyCalculator.calculate(20000000),
        equals(10000000.0),
      );
    });

    test('승부수 조건 판단', () {
      // 손실률 -50% 이하, 미사용 → true
      expect(PanicBuyCalculator.canExecute(-50, false), isTrue);
      expect(PanicBuyCalculator.canExecute(-60, false), isTrue);

      // 이미 사용 → false
      expect(PanicBuyCalculator.canExecute(-50, true), isFalse);

      // 손실률 부족 → false
      expect(PanicBuyCalculator.canExecute(-49, false), isFalse);
    });

    test('승부수 + 가중매수 총액 계산', () {
      // 초기진입금 2,000만원, 손실률 -50%
      // 승부수: 1,000만원 + 가중매수: 100만원 = 1,100만원
      expect(
        PanicBuyCalculator.calculateTotalWithWeighted(20000000, -50),
        equals(11000000.0),
      );
    });
  });

  group('AveragePriceCalculator', () {
    test('평균 단가 계산', () {
      // 총 투자 $10,000, 100주 → $100
      expect(
        AveragePriceCalculator.calculate(10000, 100),
        equals(100.0),
      );
    });

    test('추가 매수 후 평균 단가 계산', () {
      // 현재: 평균 $100, 100주
      // 추가: $80에 50주
      // 새 평균: (10000 + 4000) / 150 = $93.33...
      final newAvg = AveragePriceCalculator.calculateAfterBuy(100, 100, 80, 50);
      expect(newAvg, closeTo(93.33, 0.01));
    });

    test('0 수량 예외 처리', () {
      expect(AveragePriceCalculator.calculate(10000, 0), equals(0.0));
    });
  });
}
