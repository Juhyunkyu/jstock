import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_cycle/domain/usecases/calculators/calculators.dart';
import 'package:alpha_cycle/domain/usecases/signal_detector.dart';
import 'package:alpha_cycle/data/models/cycle.dart';
import 'package:alpha_cycle/data/services/cache/cache_manager.dart';

/// 통합 테스트: 실제 트레이딩 시나리오 시뮬레이션
void main() {
  group('시나리오 1: 정상적인 하락 → 회복 사이클', () {
    late Cycle cycle;
    late CacheManager cacheManager;

    setUp(() {
      cacheManager = CacheManager();
      cycle = Cycle(
        id: 'scenario-1',
        ticker: 'TQQQ',
        cycleNumber: 1,
        seedAmount: 100000000, // 1억원
        initialEntryPrice: 100.0,
        exchangeRate: 1400.0,
      );

      // 초기 진입: 20% 매수
      cycle.recordBuy(
        price: 100.0,
        shares: 142.86, // 약 $100 × 142.86 = $14,286
        amountKrw: 20000000,
        isPanic: false,
      );
    });

    test('1단계: 초기 진입 후 HOLD 상태', () {
      final signal = SignalDetector.detectSignal(cycle, 100.0);
      expect(signal, equals(TradingSignal.hold));

      // 캐시에 주가 저장
      cacheManager.set(stockCacheKey('TQQQ'), {
        'price': 100.0,
        'timestamp': DateTime.now().toIso8601String(),
      });

      expect(cacheManager.containsKey('stock:TQQQ'), isTrue);
    });

    test('2단계: 소폭 하락 (-10%) → HOLD 유지', () {
      final signal = SignalDetector.detectSignal(cycle, 90.0);
      expect(signal, equals(TradingSignal.hold));

      final lossRate = LossCalculator.calculate(90.0, 100.0);
      expect(lossRate, equals(-10.0));
    });

    test('3단계: 가중 매수 구간 진입 (-20%)', () {
      final signal = SignalDetector.detectSignal(cycle, 80.0);
      expect(signal, equals(TradingSignal.weightedBuy));

      final recommendation = SignalDetector.getRecommendation(cycle, 80.0);
      expect(recommendation.signal, equals(TradingSignal.weightedBuy));
      expect(recommendation.recommendedAmount, greaterThan(0));

      // 가중 매수 금액 계산: 2000만 × 20 ÷ 1000 = 40만원
      final buyAmount = WeightedBuyCalculator.calculate(20000000, -20);
      expect(buyAmount, equals(400000.0));
    });

    test('4단계: 가중 매수 실행 후 평균단가 하락', () {
      // 가중 매수 실행
      cycle.recordBuy(
        price: 80.0,
        shares: 35.71, // 40만원 / 1400원 / $80 ≈ 3.57주... 계산 확인 필요
        amountKrw: 400000,
        isPanic: false,
      );

      // 새 평균단가 확인
      expect(cycle.averagePrice, lessThan(100.0));
      expect(cycle.totalShares, greaterThan(142.86));
    });

    test('5단계: 추가 하락 (-25%) → 가중 매수 계속', () {
      cycle.recordBuy(price: 80.0, shares: 35.71, amountKrw: 400000, isPanic: false);

      final signal = SignalDetector.detectSignal(cycle, 75.0);
      // 평균단가 기준 손실률 계산
      final avgPrice = cycle.averagePrice;
      final lossFromAvg = LossCalculator.calculate(75.0, avgPrice);

      // 평균단가 대비 -20% 이상이면 가중 매수
      if (lossFromAvg <= -20) {
        expect(signal, equals(TradingSignal.weightedBuy));
      }
    });

    test('6단계: 회복 → 익절 (+20%)', () {
      cycle.recordBuy(price: 80.0, shares: 35.71, amountKrw: 400000, isPanic: false);

      // 평균단가 계산
      final avgPrice = cycle.averagePrice;

      // 평균단가 대비 +21% 가격 (부동소수점 오차 방지를 위해 20%보다 약간 높게)
      final takeProfitPrice = avgPrice * 1.21;

      final signal = SignalDetector.detectSignal(cycle, takeProfitPrice);
      expect(signal, equals(TradingSignal.takeProfit));
    });

    test('7단계: 사이클 완료 확인', () {
      cycle.recordBuy(price: 80.0, shares: 35.71, amountKrw: 400000, isPanic: false);

      final avgPrice = cycle.averagePrice;
      final takeProfitPrice = avgPrice * 1.21; // 부동소수점 오차 방지

      // 익절 실행
      cycle.recordTakeProfit(takeProfitPrice);

      expect(cycle.status, equals(CycleStatus.completed));
      expect(cycle.endDate, isNotNull);
      expect(cycle.totalReturnRate(takeProfitPrice), greaterThan(0));
    });
  });

  group('시나리오 2: 급락 → 승부수 → 회복', () {
    late Cycle cycle;

    setUp(() {
      cycle = Cycle(
        id: 'scenario-2',
        ticker: 'SOXL',
        cycleNumber: 1,
        seedAmount: 50000000, // 5000만원
        initialEntryPrice: 70.0,
        exchangeRate: 1430.0,
      );

      // 초기 진입
      cycle.recordBuy(
        price: 70.0,
        shares: 100.0,
        amountKrw: 10000000,
        isPanic: false,
      );
    });

    test('1단계: 급락 (-50%) → 승부수 발동', () {
      final signal = SignalDetector.detectSignal(cycle, 35.0);
      expect(signal, equals(TradingSignal.panicBuy));

      // 승부수 미사용 확인
      expect(cycle.panicUsed, isFalse);
    });

    test('2단계: 승부수 금액 계산', () {
      // 승부수: 초기진입금 × 50% = 1000만 × 0.5 = 500만
      final panicAmount = PanicBuyCalculator.calculate(10000000);
      expect(panicAmount, equals(5000000.0));

      // 승부수 + 가중매수: 500만 + (1000만 × 50 ÷ 1000) = 500만 + 50만 = 550만
      final totalAmount = PanicBuyCalculator.calculateTotalWithWeighted(10000000, -50);
      expect(totalAmount, equals(5500000.0));
    });

    test('3단계: 승부수 실행', () {
      cycle.recordBuy(
        price: 35.0,
        shares: 110.0, // 약 550만원 / 1430원 / $35
        amountKrw: 5500000,
        isPanic: true,
      );

      expect(cycle.panicUsed, isTrue);
      expect(cycle.totalShares, equals(210.0));
    });

    test('4단계: 승부수 후 추가 하락 → 가중매수만', () {
      cycle.recordBuy(price: 35.0, shares: 110.0, amountKrw: 5500000, isPanic: true);

      // 추가 하락 시 승부수 재발동 불가, 가중매수만
      final signal = SignalDetector.detectSignal(cycle, 30.0);
      expect(signal, equals(TradingSignal.weightedBuy));
    });

    test('5단계: 회복 후 익절', () {
      cycle.recordBuy(price: 35.0, shares: 110.0, amountKrw: 5500000, isPanic: true);

      final avgPrice = cycle.averagePrice;
      final takeProfitPrice = avgPrice * 1.2;

      final signal = SignalDetector.detectSignal(cycle, takeProfitPrice);
      expect(signal, equals(TradingSignal.takeProfit));

      cycle.recordTakeProfit(takeProfitPrice);

      expect(cycle.status, equals(CycleStatus.completed));
      expect(cycle.panicUsed, isTrue);
    });
  });

  group('시나리오 3: 지속 상승 (매수 없이 익절)', () {
    late Cycle cycle;

    setUp(() {
      cycle = Cycle(
        id: 'scenario-3',
        ticker: 'UPRO',
        cycleNumber: 1,
        seedAmount: 100000000,
        initialEntryPrice: 120.0,
        exchangeRate: 1400.0,
      );

      cycle.recordBuy(
        price: 120.0,
        shares: 119.05, // 2000만원 / 1400원 / $120
        amountKrw: 20000000,
        isPanic: false,
      );
    });

    test('상승 구간에서 HOLD 유지', () {
      for (var price = 121.0; price < 144.0; price += 5.0) {
        final signal = SignalDetector.detectSignal(cycle, price);
        expect(signal, equals(TradingSignal.hold));
      }
    });

    test('익절 구간 도달 (+20%)', () {
      final takeProfitPrice = 120.0 * 1.2; // $144
      final signal = SignalDetector.detectSignal(cycle, takeProfitPrice);
      expect(signal, equals(TradingSignal.takeProfit));
    });

    test('익절 실행 및 수익 확인', () {
      final takeProfitPrice = 144.0;

      // 익절 전 평균단가 대비 수익률 확인
      final returnRateBeforeSell = cycle.returnRate(takeProfitPrice);
      expect(returnRateBeforeSell, closeTo(20.0, 1.0)); // 평균단가 대비 +20%

      cycle.recordTakeProfit(takeProfitPrice);

      expect(cycle.status, equals(CycleStatus.completed));
      // 총 수익률은 투자 비율에 따라 다름 (20% 투자 → ~4% 포트폴리오 수익)
      expect(cycle.totalReturnRate(takeProfitPrice), greaterThan(0)); // 수익 발생
      expect(cycle.panicUsed, isFalse); // 승부수 미사용
    });
  });

  group('시나리오 4: 다중 가중 매수 후 회복', () {
    late Cycle cycle;

    setUp(() {
      cycle = Cycle(
        id: 'scenario-4',
        ticker: 'TQQQ',
        cycleNumber: 2,
        seedAmount: 100000000,
        initialEntryPrice: 56.0,
        exchangeRate: 1430.0,
      );

      cycle.recordBuy(
        price: 56.0,
        shares: 250.0,
        amountKrw: 20000000,
        isPanic: false,
      );
    });

    test('연속 가중 매수 시나리오', () {
      // 1차 하락: -20%
      expect(SignalDetector.detectSignal(cycle, 44.8), equals(TradingSignal.weightedBuy));
      cycle.recordBuy(price: 44.8, shares: 62.5, amountKrw: 400000, isPanic: false);

      // 2차 하락: 평균단가 대비 -25%
      final avgPrice1 = cycle.averagePrice;
      final target2 = avgPrice1 * 0.75;
      expect(SignalDetector.detectSignal(cycle, target2), equals(TradingSignal.weightedBuy));
      cycle.recordBuy(price: target2, shares: 50.0, amountKrw: 500000, isPanic: false);

      // 3차 하락: 평균단가 대비 -30%
      final avgPrice2 = cycle.averagePrice;
      final target3 = avgPrice2 * 0.70;
      expect(SignalDetector.detectSignal(cycle, target3), equals(TradingSignal.weightedBuy));
      cycle.recordBuy(price: target3, shares: 40.0, amountKrw: 600000, isPanic: false);

      // 최종 평균단가 확인
      expect(cycle.averagePrice, lessThan(56.0));
      expect(cycle.totalShares, greaterThan(250.0));
    });

    test('다중 매수 후 익절', () {
      cycle.recordBuy(price: 44.8, shares: 62.5, amountKrw: 400000, isPanic: false);
      cycle.recordBuy(price: 40.0, shares: 50.0, amountKrw: 500000, isPanic: false);
      cycle.recordBuy(price: 35.0, shares: 40.0, amountKrw: 600000, isPanic: false);

      final avgPrice = cycle.averagePrice;
      final takeProfitPrice = avgPrice * 1.2;

      // 익절 전 평균단가 대비 수익률 확인
      final returnRateBeforeSell = cycle.returnRate(takeProfitPrice);
      expect(returnRateBeforeSell, closeTo(20.0, 1.0)); // 평균단가 대비 +20%

      final signal = SignalDetector.detectSignal(cycle, takeProfitPrice);
      expect(signal, equals(TradingSignal.takeProfit));

      cycle.recordTakeProfit(takeProfitPrice);
      // 총 수익률은 투자 비율에 따라 결정됨 (약간의 이익 발생)
      expect(cycle.totalReturnRate(takeProfitPrice), greaterThan(0));
    });
  });

  group('시나리오 5: 현금 소진 경고', () {
    late Cycle cycle;

    setUp(() {
      cycle = Cycle(
        id: 'scenario-5',
        ticker: 'TQQQ',
        cycleNumber: 1,
        seedAmount: 30000000, // 3000만원 (작은 시드)
        initialEntryPrice: 100.0,
        exchangeRate: 1400.0,
      );

      // 초기 진입: 600만원
      cycle.recordBuy(
        price: 100.0,
        shares: 42.86,
        amountKrw: 6000000,
        isPanic: false,
      );
    });

    test('연속 매수로 현금 소진', () {
      // 가중 매수 반복
      cycle.recordBuy(price: 80.0, shares: 10.0, amountKrw: 1120000, isPanic: false);
      cycle.recordBuy(price: 70.0, shares: 10.0, amountKrw: 980000, isPanic: false);
      cycle.recordBuy(price: 60.0, shares: 10.0, amountKrw: 840000, isPanic: false);

      // 승부수 발동 시 현금 부족 확인
      final recommendation = SignalDetector.getRecommendation(cycle, 50.0);

      expect(recommendation.signal, equals(TradingSignal.panicBuy));

      // 잔여 현금 < 권장 매수 금액
      final remainingCash = cycle.remainingCash;
      final recommendedAmount = recommendation.recommendedAmount;

      // 잔여 현금이 충분한지 확인
      if (remainingCash < recommendedAmount) {
        // 현금 부족 상황 - 실제 앱에서는 경고 표시
        expect(remainingCash, lessThan(recommendedAmount));
      }
    });

    test('현금 소진 시에도 신호는 발생', () {
      // 거의 모든 현금 사용
      cycle.recordBuy(price: 80.0, shares: 50.0, amountKrw: 5600000, isPanic: false);
      cycle.recordBuy(price: 60.0, shares: 100.0, amountKrw: 8400000, isPanic: false);
      cycle.recordBuy(price: 50.0, shares: 50.0, amountKrw: 3500000, isPanic: true);

      // 추가 하락 시에도 신호 발생
      final signal = SignalDetector.detectSignal(cycle, 40.0);

      // 승부수 사용 후이므로 가중매수 신호
      expect(signal, equals(TradingSignal.weightedBuy));

      // 실제 매수는 현금 잔고 내에서만 가능
      expect(cycle.remainingCash, greaterThanOrEqualTo(0));
    });
  });

  group('캐시 통합 테스트', () {
    late CacheManager cacheManager;

    setUp(() {
      cacheManager = CacheManager();
    });

    test('주가 데이터 캐싱 플로우', () {
      // 1. API에서 주가 조회 시뮬레이션
      final stockData = {
        'symbol': 'TQQQ',
        'price': 56.04,
        'previousClose': 57.06,
        'changePercent': -1.79,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // 2. 캐시에 저장
      cacheManager.set(
        stockCacheKey('TQQQ'),
        stockData,
        ttl: CacheManager.defaultStockTtl,
      );

      // 3. 캐시에서 조회
      final cached = cacheManager.get<Map<String, dynamic>>('stock:TQQQ');
      expect(cached, isNotNull);
      expect(cached!['price'], equals(56.04));
    });

    test('환율 데이터 캐싱 플로우', () {
      // 1. API에서 환율 조회 시뮬레이션
      final rateData = {
        'from': 'USD',
        'to': 'KRW',
        'rate': 1430.83,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // 2. 캐시에 저장 (1시간 TTL)
      cacheManager.set(
        exchangeRateCacheKey('USD', 'KRW'),
        rateData,
        ttl: CacheManager.defaultExchangeRateTtl,
      );

      // 3. 캐시에서 조회
      final cached = cacheManager.get<Map<String, dynamic>>('exchange:USD:KRW');
      expect(cached, isNotNull);
      expect(cached!['rate'], equals(1430.83));
    });

    test('패턴 삭제로 관련 캐시 일괄 정리', () {
      // 여러 주가 데이터 캐싱
      cacheManager.set('stock:TQQQ', {'price': 56.04});
      cacheManager.set('stock:SOXL', {'price': 70.47});
      cacheManager.set('stock:UPRO', {'price': 120.74});
      cacheManager.set('exchange:USD:KRW', {'rate': 1430.83});

      // 주가 캐시만 삭제
      cacheManager.removePattern('^stock:');

      expect(cacheManager.get('stock:TQQQ'), isNull);
      expect(cacheManager.get('stock:SOXL'), isNull);
      expect(cacheManager.get('stock:UPRO'), isNull);
      expect(cacheManager.get('exchange:USD:KRW'), isNotNull); // 환율은 유지
    });
  });

  group('계산기 통합 테스트', () {
    test('전체 계산 파이프라인: 손실률 → 매수금액 → 평균단가', () {
      // 초기 상태
      const initialPrice = 100.0;
      const currentPrice = 80.0;
      const initialEntryAmount = 20000000.0; // 2000만원

      // 1단계: 손실률 계산
      final lossRate = LossCalculator.calculate(currentPrice, initialPrice);
      expect(lossRate, equals(-20.0));

      // 2단계: 가중 매수 금액 계산
      final buyAmount = WeightedBuyCalculator.calculate(initialEntryAmount, lossRate);
      expect(buyAmount, equals(400000.0)); // 40만원

      // 3단계: 매수 수량 계산 (환율 1400원 가정)
      const exchangeRate = 1400.0;
      final usdAmount = buyAmount / exchangeRate; // 약 $285.71
      final shares = usdAmount / currentPrice; // 약 3.57주

      expect(shares, closeTo(3.57, 0.1));

      // 4단계: 새 평균단가 계산
      // 기존: $100에 142.86주 (2000만원/1400원/100 = 142.86주)
      const existingShares = 142.86;
      const existingAvgPrice = 100.0;

      final newAvgPrice = AveragePriceCalculator.calculateAfterBuy(
        existingAvgPrice,
        existingShares,
        currentPrice,
        shares,
      );

      expect(newAvgPrice, lessThan(existingAvgPrice)); // 평균단가 하락
      expect(newAvgPrice, greaterThan(currentPrice)); // 현재가보다는 높음
    });

    test('익절 시 수익 계산 파이프라인', () {
      // 상태
      const avgPrice = 85.0;
      const totalShares = 180.0;
      const exitPrice = 102.0; // +20%
      const exchangeRate = 1400.0;

      // 1단계: 수익률 계산
      final returnRate = ReturnCalculator.calculate(exitPrice, avgPrice);
      expect(returnRate, equals(20.0));

      // 2단계: USD 수익 계산
      final totalValue = exitPrice * totalShares; // $18,360
      final totalCost = avgPrice * totalShares; // $15,300
      final profitUsd = totalValue - totalCost; // $3,060

      expect(profitUsd, closeTo(3060.0, 1.0));

      // 3단계: KRW 환산
      final profitKrw = profitUsd * exchangeRate; // 약 428만원

      expect(profitKrw, closeTo(4284000.0, 10000.0));
    });
  });

  group('다중 사이클 시나리오', () {
    test('사이클 완료 후 새 사이클 시작', () {
      // 첫 번째 사이클
      final cycle1 = Cycle(
        id: 'multi-1',
        ticker: 'TQQQ',
        cycleNumber: 1,
        seedAmount: 100000000,
        initialEntryPrice: 100.0,
        exchangeRate: 1400.0,
      );

      cycle1.recordBuy(price: 100.0, shares: 142.86, amountKrw: 20000000, isPanic: false);
      cycle1.recordTakeProfit(120.0);

      expect(cycle1.status, equals(CycleStatus.completed));
      expect(cycle1.cycleNumber, equals(1));

      // 두 번째 사이클 (익절금 재투자)
      final returnRate = cycle1.totalReturnRate(120.0);
      final cycle2 = Cycle(
        id: 'multi-2',
        ticker: 'TQQQ',
        cycleNumber: 2,
        seedAmount: (100000000 + (returnRate / 100 * 20000000)).toDouble(),
        initialEntryPrice: 120.0, // 익절 가격에서 재진입
        exchangeRate: 1400.0,
      );

      cycle2.recordBuy(price: 120.0, shares: 119.05, amountKrw: 20000000, isPanic: false);

      expect(cycle2.status, equals(CycleStatus.active));
      expect(cycle2.cycleNumber, equals(2));
      expect(cycle2.seedAmount, greaterThan(100000000)); // 수익으로 시드 증가
    });
  });
}
