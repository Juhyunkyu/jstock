import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_cycle/data/services/api/yahoo_finance_service.dart';
import 'package:alpha_cycle/data/services/api/exchange_rate_service.dart';
import 'package:alpha_cycle/data/services/api/api_exception.dart';

/// API 서비스 단위 테스트
void main() {
  group('StockQuote 모델 테스트', () {
    test('StockQuote 생성', () {
      final quote = StockQuote(
        symbol: 'TQQQ',
        currentPrice: 56.04,
        previousClose: 57.06,
        changePercent: -1.79,
        dayHigh: 57.21,
        dayLow: 53.06,
        volume: 120810902,
        timestamp: DateTime.now(),
      );

      expect(quote.symbol, equals('TQQQ'));
      expect(quote.currentPrice, equals(56.04));
      expect(quote.previousClose, equals(57.06));
      expect(quote.isPositive, isFalse);
    });

    test('StockQuote 양수 변동률', () {
      final quote = StockQuote(
        symbol: 'UPRO',
        currentPrice: 121.0,
        previousClose: 120.0,
        changePercent: 0.83,
        dayHigh: 122.0,
        dayLow: 119.0,
        volume: 5000000,
        timestamp: DateTime.now(),
      );

      expect(quote.isPositive, isTrue);
    });

    test('StockQuote 0% 변동률', () {
      final quote = StockQuote(
        symbol: 'TEST',
        currentPrice: 100.0,
        previousClose: 100.0,
        changePercent: 0.0,
        dayHigh: 101.0,
        dayLow: 99.0,
        volume: 1000000,
        timestamp: DateTime.now(),
      );

      expect(quote.isPositive, isTrue); // 0 이상이면 positive
    });

    test('StockQuote toString', () {
      final quote = StockQuote(
        symbol: 'TQQQ',
        currentPrice: 56.04,
        previousClose: 57.06,
        changePercent: -1.79,
        dayHigh: 57.21,
        dayLow: 53.06,
        volume: 120810902,
        timestamp: DateTime.now(),
      );

      expect(quote.toString(), contains('TQQQ'));
      expect(quote.toString(), contains('56.04'));
    });
  });

  group('ExchangeRate 모델 테스트', () {
    test('ExchangeRate 생성', () {
      final rate = ExchangeRate(
        fromCurrency: 'USD',
        toCurrency: 'KRW',
        rate: 1430.83,
        timestamp: DateTime.now(),
      );

      expect(rate.fromCurrency, equals('USD'));
      expect(rate.toCurrency, equals('KRW'));
      expect(rate.rate, equals(1430.83));
    });

    test('ExchangeRate toString', () {
      final rate = ExchangeRate(
        fromCurrency: 'USD',
        toCurrency: 'KRW',
        rate: 1430.83,
        timestamp: DateTime.now(),
      );

      expect(rate.toString(), contains('USD'));
      expect(rate.toString(), contains('KRW'));
      expect(rate.toString(), contains('1430.83'));
    });
  });

  group('ApiException 테스트', () {
    test('NetworkException', () {
      const exception = NetworkException(message: '네트워크 연결 실패');
      expect(exception.message, equals('네트워크 연결 실패'));
      expect(exception.statusCode, isNull);
      expect(exception.toString(), contains('NetworkException'));
    });

    test('ServerException', () {
      const exception = ServerException(
        message: '서버 오류',
        statusCode: 500,
      );
      expect(exception.message, equals('서버 오류'));
      expect(exception.statusCode, equals(500));
      expect(exception.toString(), contains('500'));
    });

    test('ParseException', () {
      const exception = ParseException(message: '데이터 파싱 실패');
      expect(exception.message, equals('데이터 파싱 실패'));
      expect(exception.toString(), contains('ParseException'));
    });

    test('RateLimitException', () {
      const exception = RateLimitException(
        message: 'API 요청 제한 초과',
        retryAfter: Duration(seconds: 60),
      );
      expect(exception.message, equals('API 요청 제한 초과'));
      expect(exception.statusCode, equals(429));
      expect(exception.retryAfter?.inSeconds, equals(60));
    });

    test('UnauthorizedException', () {
      const exception = UnauthorizedException(message: '인증 실패');
      expect(exception.statusCode, equals(401));
    });

    test('NotFoundException', () {
      const exception = NotFoundException(message: '데이터 없음');
      expect(exception.statusCode, equals(404));
    });

    test('TimeoutException', () {
      const exception = TimeoutException(message: '요청 시간 초과');
      expect(exception.statusCode, isNull);
    });
  });

  group('Yahoo Finance 응답 파싱 시뮬레이션', () {
    test('정상 응답 데이터 구조', () {
      // Yahoo Finance API 응답 구조 시뮬레이션
      final mockResponse = {
        'chart': {
          'result': [
            {
              'meta': {
                'symbol': 'TQQQ',
                'regularMarketPrice': 56.04,
                'chartPreviousClose': 57.06,
              },
              'timestamp': [1769697000],
              'indicators': {
                'quote': [
                  {
                    'high': [57.21],
                    'low': [53.06],
                    'volume': [120810902],
                  }
                ]
              }
            }
          ],
          'error': null
        }
      };

      // 데이터 추출 로직 검증
      final chart = mockResponse['chart'] as Map<String, dynamic>;
      final result = (chart['result'] as List)[0] as Map<String, dynamic>;
      final meta = result['meta'] as Map<String, dynamic>;

      expect(meta['symbol'], equals('TQQQ'));
      expect(meta['regularMarketPrice'], equals(56.04));
      expect(meta['chartPreviousClose'], equals(57.06));
    });

    test('빈 결과 처리', () {
      final mockResponse = {
        'chart': {
          'result': [],
          'error': null
        }
      };

      final chart = mockResponse['chart'] as Map<String, dynamic>;
      final result = chart['result'] as List;

      expect(result.isEmpty, isTrue);
    });

    test('에러 응답 처리', () {
      final mockResponse = {
        'chart': {
          'result': null,
          'error': {
            'code': 'Not Found',
            'description': 'No data found for symbol: INVALID'
          }
        }
      };

      final chart = mockResponse['chart'] as Map<String, dynamic>;
      expect(chart['result'], isNull);
      expect(chart['error'], isNotNull);
    });
  });

  group('Exchange Rate 응답 파싱 시뮬레이션', () {
    test('정상 응답 데이터 구조', () {
      final mockResponse = {
        'amount': 1.0,
        'base': 'USD',
        'date': '2026-01-29',
        'rates': {
          'KRW': 1430.83
        }
      };

      expect(mockResponse['base'], equals('USD'));
      expect((mockResponse['rates'] as Map)['KRW'], equals(1430.83));
    });

    test('여러 통화 응답', () {
      final mockResponse = {
        'amount': 1.0,
        'base': 'USD',
        'date': '2026-01-29',
        'rates': {
          'KRW': 1430.83,
          'EUR': 0.92,
          'JPY': 149.50,
        }
      };

      final rates = mockResponse['rates'] as Map<String, dynamic>;
      expect(rates.length, equals(3));
      expect(rates['KRW'], equals(1430.83));
      expect(rates['EUR'], equals(0.92));
      expect(rates['JPY'], equals(149.50));
    });

    test('빈 rates 처리', () {
      final mockResponse = {
        'amount': 1.0,
        'base': 'USD',
        'date': '2026-01-29',
        'rates': {}
      };

      final rates = mockResponse['rates'] as Map;
      expect(rates.isEmpty, isTrue);
    });
  });

  group('데이터 변환 테스트', () {
    test('원화 환산', () {
      // $100 × 1430원 = 143,000원
      final usdAmount = 100.0;
      final exchangeRate = 1430.0;
      final krwAmount = usdAmount * exchangeRate;

      expect(krwAmount, equals(143000.0));
    });

    test('주식 수량 계산', () {
      // 100만원, 환율 1400원, 주가 $50
      // 100만 / 1400 / 50 = 14.29주
      final krwAmount = 1000000.0;
      final exchangeRate = 1400.0;
      final stockPrice = 50.0;
      final shares = krwAmount / exchangeRate / stockPrice;

      expect(shares, closeTo(14.29, 0.01));
    });

    test('변동률 계산', () {
      // 전일 종가 $57.06, 현재가 $56.04
      // 변동률 = (56.04 - 57.06) / 57.06 × 100 = -1.79%
      final previousClose = 57.06;
      final currentPrice = 56.04;
      final changePercent = ((currentPrice - previousClose) / previousClose) * 100;

      expect(changePercent, closeTo(-1.79, 0.01));
    });
  });

  group('날짜/시간 처리 테스트', () {
    test('Unix 타임스탬프 변환', () {
      // Yahoo Finance timestamp (seconds)
      const unixTimestamp = 1769697000;
      final dateTime = DateTime.fromMillisecondsSinceEpoch(unixTimestamp * 1000);

      expect(dateTime.year, greaterThanOrEqualTo(2026));
    });

    test('날짜 문자열 파싱', () {
      // Frankfurter API date format
      const dateStr = '2026-01-29';
      final dateTime = DateTime.tryParse(dateStr);

      expect(dateTime, isNotNull);
      expect(dateTime!.year, equals(2026));
      expect(dateTime.month, equals(1));
      expect(dateTime.day, equals(29));
    });

    test('잘못된 날짜 문자열', () {
      const invalidDateStr = 'invalid-date';
      final dateTime = DateTime.tryParse(invalidDateStr);

      expect(dateTime, isNull);
    });
  });
}
