import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_cycle/domain/trading/trading_math.dart';

void main() {
  // =========================================================================
  // returnRate — 수익률 계산
  // =========================================================================
  group('TradingMath.returnRate', () {
    test('양의 수익률 계산', () {
      // 100에서 매수 → 120으로 상승 = +20%
      expect(TradingMath.returnRate(120, 100), closeTo(20.0, 0.0001));
    });

    test('음의 수익률 계산', () {
      // 100에서 매수 → 80으로 하락 = -20%
      expect(TradingMath.returnRate(80, 100), closeTo(-20.0, 0.0001));
    });

    test('변동 없는 경우 0% 반환', () {
      expect(TradingMath.returnRate(50, 50), closeTo(0.0, 0.0001));
    });

    test('소수점 정밀도 확인 — 실제 주가 시나리오', () {
      // TQQQ $56.04 매수 → $58.27 현재가
      // (58.27 - 56.04) / 56.04 * 100 = 3.9793...%
      final rate = TradingMath.returnRate(58.27, 56.04);
      expect(rate, closeTo(3.9793, 0.001));
    });

    test('큰 수익률 (2배 상승)', () {
      expect(TradingMath.returnRate(200, 100), closeTo(100.0, 0.0001));
    });

    test('averagePrice가 0이면 0.0 반환 (Zero-guard)', () {
      expect(TradingMath.returnRate(100, 0), equals(0.0));
    });

    test('currentPrice가 0일 때 -100% 반환', () {
      // 주가가 0이면 전액 손실
      expect(TradingMath.returnRate(0, 50), closeTo(-100.0, 0.0001));
    });

    test('매우 작은 평균단가에서 정밀도', () {
      // 페니주: $0.01 → $0.02 = +100%
      expect(TradingMath.returnRate(0.02, 0.01), closeTo(100.0, 0.0001));
    });

    test('음수 가격은 수학적으로 처리 (방어적)', () {
      // 실제 주가에서 발생하지 않지만 메서드는 수학적으로 동작
      final rate = TradingMath.returnRate(-10, 100);
      expect(rate, closeTo(-110.0, 0.0001));
    });
  });

  // =========================================================================
  // evaluatedAmount — 평가금액 (KRW)
  // =========================================================================
  group('TradingMath.evaluatedAmount', () {
    test('기본 평가금액 계산', () {
      // 10주 x $50 x 1300원 = 650,000원
      expect(
        TradingMath.evaluatedAmount(10, 50, 1300),
        closeTo(650000.0, 0.01),
      );
    });

    test('실제 시나리오 — TQQQ 보유 평가', () {
      // 175.3주 x $56.04 x 1,372.50원
      final result = TradingMath.evaluatedAmount(175.3, 56.04, 1372.50);
      // 175.3 * 56.04 * 1372.50
      expect(result, closeTo(175.3 * 56.04 * 1372.50, 1.0));
    });

    test('0주 보유 시 0원', () {
      expect(TradingMath.evaluatedAmount(0, 56.04, 1372.50), equals(0.0));
    });

    test('주가 0일 때 0원', () {
      expect(TradingMath.evaluatedAmount(10, 0, 1372.50), equals(0.0));
    });

    test('환율 0일 때 0원', () {
      expect(TradingMath.evaluatedAmount(10, 56.04, 0), equals(0.0));
    });

    test('소수 주식 수량 (fractional shares)', () {
      // 0.5주 x $100 x 1300원 = 65,000원
      expect(
        TradingMath.evaluatedAmount(0.5, 100, 1300),
        closeTo(65000.0, 0.01),
      );
    });

    test('곱셈 교환법칙 확인 — 순서 무관', () {
      final a = TradingMath.evaluatedAmount(10, 50, 1300);
      final b = TradingMath.evaluatedAmount(50, 10, 1300);
      // 10*50*1300 == 50*10*1300
      expect(a, closeTo(b, 0.001));
    });
  });

  // =========================================================================
  // recalcAveragePrice — 평균단가 재계산 (매수 후)
  // =========================================================================
  group('TradingMath.recalcAveragePrice', () {
    test('첫 매수 — 이전 보유 없을 때', () {
      // 이전 보유: 0주, 0원
      // 신규 매수: 130만원, 주가 $50, 환율 1300원
      // → 신규 주식수: 1,300,000 / (50 * 1300) = 20주
      // → 평균단가: 1,300,000 / (20 * 1300) = $50
      final avg = TradingMath.recalcAveragePrice(
        prevTotalCostKrw: 0,
        prevTotalShares: 0,
        newBuyAmountKrw: 1300000,
        newBuyPrice: 50,
        exchangeRate: 1300,
      );
      expect(avg, closeTo(50.0, 0.0001));
    });

    test('추가 매수 — 평균단가 하락 (물타기)', () {
      // 기존: 10주 x $60 x 1300원 = 780,000원 보유
      // 추가 매수: 780,000원 @ $40, 환율 1300원
      // → 추가 주식수: 780,000 / (40 * 1300) = 15주
      // → 총 보유: 25주, 총 비용: 1,560,000원
      // → 평균단가: 1,560,000 / (25 * 1300) = $48
      final avg = TradingMath.recalcAveragePrice(
        prevTotalCostKrw: 780000,
        prevTotalShares: 10,
        newBuyAmountKrw: 780000,
        newBuyPrice: 40,
        exchangeRate: 1300,
      );
      expect(avg, closeTo(48.0, 0.0001));
    });

    test('추가 매수 — 같은 가격이면 평균단가 유지', () {
      // 기존: 10주 x $50 x 1300원 = 650,000원
      // 추가: 650,000원 @ $50, 환율 1300원 → 10주 추가
      // → 총 20주, 총 비용: 1,300,000원
      // → 평균: 1,300,000 / (20 * 1300) = $50
      final avg = TradingMath.recalcAveragePrice(
        prevTotalCostKrw: 650000,
        prevTotalShares: 10,
        newBuyAmountKrw: 650000,
        newBuyPrice: 50,
        exchangeRate: 1300,
      );
      expect(avg, closeTo(50.0, 0.0001));
    });

    test('추가 매수 — 더 높은 가격 (평균단가 상승)', () {
      // 기존: 10주 x $40 x 1300 = 520,000원
      // 추가: 780,000원 @ $60, 환율 1300원 → 10주 추가
      // → 총 20주, 총 비용: 1,300,000원
      // → 평균: 1,300,000 / (20 * 1300) = $50
      final avg = TradingMath.recalcAveragePrice(
        prevTotalCostKrw: 520000,
        prevTotalShares: 10,
        newBuyAmountKrw: 780000,
        newBuyPrice: 60,
        exchangeRate: 1300,
      );
      expect(avg, closeTo(50.0, 0.0001));
    });

    test('newBuyPrice가 0이면 0.0 반환 (Zero-guard)', () {
      final avg = TradingMath.recalcAveragePrice(
        prevTotalCostKrw: 650000,
        prevTotalShares: 10,
        newBuyAmountKrw: 650000,
        newBuyPrice: 0,
        exchangeRate: 1300,
      );
      expect(avg, equals(0.0));
    });

    test('exchangeRate가 0이면 0.0 반환 (Zero-guard)', () {
      final avg = TradingMath.recalcAveragePrice(
        prevTotalCostKrw: 650000,
        prevTotalShares: 10,
        newBuyAmountKrw: 650000,
        newBuyPrice: 50,
        exchangeRate: 0,
      );
      expect(avg, equals(0.0));
    });

    test('모든 값이 0이면 0.0 반환', () {
      final avg = TradingMath.recalcAveragePrice(
        prevTotalCostKrw: 0,
        prevTotalShares: 0,
        newBuyAmountKrw: 0,
        newBuyPrice: 0,
        exchangeRate: 0,
      );
      expect(avg, equals(0.0));
    });

    test('newBuyAmountKrw가 0이면 기존 평균단가 유지', () {
      // 기존: 10주 x $50 x 1300 = 650,000원
      // 추가 매수 금액 0 → 주식 추가 없음 → 평균단가 유지
      final avg = TradingMath.recalcAveragePrice(
        prevTotalCostKrw: 650000,
        prevTotalShares: 10,
        newBuyAmountKrw: 0,
        newBuyPrice: 50,
        exchangeRate: 1300,
      );
      // totalCost: 650,000, totalShares: 10, → 650000 / (10 * 1300) = 50
      expect(avg, closeTo(50.0, 0.0001));
    });

    test('소수점 정밀도 — 실제 거래 시나리오', () {
      // 기존: 5.7주 x $56.04 x 1372.50원 = 438,501.3원
      // 추가: 200,000원 @ $53.20, 환율 1372.50원
      // → 추가 주식수: 200,000 / (53.20 * 1372.50) = 2.73972...주
      // → 총 주식수: 5.7 + 2.73972 = 8.43972주
      // → 평균: 638,501.3 / (8.43972 * 1372.50)
      final avg = TradingMath.recalcAveragePrice(
        prevTotalCostKrw: 438501.3,
        prevTotalShares: 5.7,
        newBuyAmountKrw: 200000,
        newBuyPrice: 53.20,
        exchangeRate: 1372.50,
      );
      // 수동 검증: newShares = 200000 / (53.20 * 1372.50) = 2.73972...
      // totalShares = 5.7 + 2.73972 = 8.43972
      // totalCost = 438501.3 + 200000 = 638501.3
      // avg = 638501.3 / (8.43972 * 1372.50) = 55.1256...
      expect(avg, closeTo(55.126, 0.01));
    });

    test('환율 변동 시 평균단가 변화', () {
      // 같은 USD 매수지만 환율이 다르면 KRW 평균이 달라짐
      // 기존: 10주, 총 비용 650,000원 (환율 1300 기준 $50)
      // 신규: 680,000원 @ $50, 환율 1360원 → 10주 추가
      // → 총 20주, 총 비용: 1,330,000원
      // → 평균: 1,330,000 / (20 * 1360) = $48.897...
      // 환율이 올랐으므로 새 환율 기준 평균단가가 기존보다 낮아짐
      final avg = TradingMath.recalcAveragePrice(
        prevTotalCostKrw: 650000,
        prevTotalShares: 10,
        newBuyAmountKrw: 680000,
        newBuyPrice: 50,
        exchangeRate: 1360,
      );
      expect(avg, closeTo(48.897, 0.01));
    });
  });
}
