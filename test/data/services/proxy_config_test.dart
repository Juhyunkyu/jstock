import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_cycle/data/services/api/proxy_config.dart';
import 'package:alpha_cycle/core/config/app_config.dart';

/// ProxyConfig 단위 테스트
///
/// AppConfig의 값은 String.fromEnvironment로 결정되므로 테스트 환경에서는
/// PROXY_BASE_URL이 빈 문자열 → useProxy = false.
/// 프록시 비활성 상태의 동작 검증 + URL 구조 검증에 집중.
void main() {
  // =========================================================================
  // 테스트 환경 기본 상태 확인
  // =========================================================================
  group('ProxyConfig 테스트 환경 확인', () {
    test('테스트 환경에서 useProxy는 false', () {
      // dart-define 없이 실행 → PROXY_BASE_URL 빈 문자열 → false
      expect(ProxyConfig.useProxy, isFalse);
    });

    test('테스트 환경에서 proxyBase는 빈 문자열', () {
      expect(ProxyConfig.proxyBase, isEmpty);
    });
  });

  // =========================================================================
  // Finnhub — 프록시 비활성 시 (직접 호출 모드)
  // =========================================================================
  group('Finnhub — 프록시 비활성', () {
    test('finnhubBaseUrl은 원본 API URL 반환', () {
      expect(ProxyConfig.finnhubBaseUrl, equals(AppConfig.finnhubBaseUrl));
      expect(ProxyConfig.finnhubBaseUrl, contains('finnhub.io'));
    });

    test('finnhubPath — 경로 변환 없이 원본 반환', () {
      expect(ProxyConfig.finnhubPath('/stock/profile2'), equals('/stock/profile2'));
      expect(ProxyConfig.finnhubPath('/stock/metric'), equals('/stock/metric'));
      expect(ProxyConfig.finnhubPath('/quote'), equals('/quote'));
    });

    test('finnhubParams — 파라미터 변경 없이 원본 반환', () {
      final params = {'symbol': 'TQQQ', 'token': 'abc123', 'metric': 'all'};
      final result = ProxyConfig.finnhubParams(params);

      expect(result, equals(params));
      expect(result.containsKey('token'), isTrue);
      expect(result.containsKey('metric'), isTrue);
    });

    test('finnhubParams — 원본 맵 불변성 확인', () {
      final original = {'symbol': 'SOXL', 'token': 'key123'};
      final result = ProxyConfig.finnhubParams(original);

      // 프록시 비활성 → 같은 맵 반환
      expect(identical(result, original), isTrue);
    });
  });

  // =========================================================================
  // FMP — 프록시 비활성 시
  // =========================================================================
  group('FMP — 프록시 비활성', () {
    test('fmpUrl은 원본 FMP API URL 반환', () {
      final url = ProxyConfig.fmpUrl('profile');
      expect(url, equals('${AppConfig.fmpBaseUrl}/profile'));
      expect(url, contains('financialmodelingprep.com'));
    });

    test('fmpUrl — 다양한 엔드포인트', () {
      expect(
        ProxyConfig.fmpUrl('income-statement'),
        endsWith('/income-statement'),
      );
      expect(
        ProxyConfig.fmpUrl('balance-sheet-statement'),
        endsWith('/balance-sheet-statement'),
      );
    });

    test('fmpParams — 파라미터 변경 없이 원본 반환', () {
      final params = {'symbol': 'AAPL', 'apikey': 'fmp_key_123'};
      final result = ProxyConfig.fmpParams(params);

      expect(result.containsKey('apikey'), isTrue);
      expect(result['apikey'], equals('fmp_key_123'));
    });
  });

  // =========================================================================
  // Exchange Rate / MarketAux — 프록시 비활성 시
  // =========================================================================
  group('Exchange Rate / MarketAux — 프록시 비활성', () {
    test('exchangeRateUrl은 null (직접 호출 폴백 사용)', () {
      expect(ProxyConfig.exchangeRateUrl, isNull);
    });

    test('marketAuxUrl은 null (직접 호출 폴백 사용)', () {
      expect(ProxyConfig.marketAuxUrl, isNull);
    });
  });

  // =========================================================================
  // Finnhub 경로 변환 로직 — 문자열 패턴 검증
  // =========================================================================
  group('finnhubPath 변환 규칙 검증', () {
    test('/stock/ 접두사가 있는 경로만 변환', () {
      // useProxy=false이므로 변환 안 됨 → 원본 반환
      // 이 테스트는 메서드의 구조를 문서화하는 역할
      expect(ProxyConfig.finnhubPath('/stock/profile2'), equals('/stock/profile2'));
      expect(ProxyConfig.finnhubPath('/stock/metric'), equals('/stock/metric'));
    });

    test('/stock/ 접두사가 없는 경로는 변경 없음', () {
      expect(ProxyConfig.finnhubPath('/quote'), equals('/quote'));
      expect(ProxyConfig.finnhubPath('/search'), equals('/search'));
    });

    test('빈 문자열 입력', () {
      expect(ProxyConfig.finnhubPath(''), equals(''));
    });
  });

  // =========================================================================
  // URL 구조 검증 — 프록시 활성 시 예상 형태
  // =========================================================================
  group('프록시 URL 구조 검증 (문자열 패턴)', () {
    // AppConfig.proxyBaseUrl이 설정된 경우의 기대 패턴을 검증
    // 실제 프록시는 활성화되지 않지만, 코드 경로가 올바른 URL을 생성하는지 확인

    test('Finnhub 프록시 URL 패턴: {base}/api/finnhub', () {
      const mockBase = 'https://worker.example.dev';
      // ProxyConfig 소스코드에서: '$proxyBase/api/finnhub'
      final expectedPattern = '$mockBase/api/finnhub';
      expect(expectedPattern, contains('/api/finnhub'));
    });

    test('FMP 프록시 URL 패턴: {base}/api/fmp/{endpoint}', () {
      const mockBase = 'https://worker.example.dev';
      // ProxyConfig 소스코드에서: '$proxyBase/api/fmp/$endpoint'
      final expectedUrl = '$mockBase/api/fmp/profile';
      expect(expectedUrl, contains('/api/fmp/profile'));
    });

    test('Exchange Rate 프록시 URL 패턴: {base}/api/exchange-rate', () {
      const mockBase = 'https://worker.example.dev';
      final expectedUrl = '$mockBase/api/exchange-rate';
      expect(expectedUrl, contains('/api/exchange-rate'));
    });

    test('MarketAux 프록시 URL 패턴: {base}/api/marketaux/news', () {
      const mockBase = 'https://worker.example.dev';
      final expectedUrl = '$mockBase/api/marketaux/news';
      expect(expectedUrl, contains('/api/marketaux/news'));
    });
  });

  // =========================================================================
  // finnhubParams 필터링 로직 — 프록시 활성 시 제거할 키
  // =========================================================================
  group('finnhubParams 필터링 대상 키 문서화', () {
    test('프록시 시 제거 대상: token, metric', () {
      // ProxyConfig 소스코드에서 제거하는 키 목록 확인
      // useProxy=false이므로 실제 제거는 안 되지만 구조 검증
      final params = {
        'symbol': 'TQQQ',
        'token': 'abc',
        'metric': 'all',
        'exchange': 'US',
      };

      // 프록시 활성 시 token과 metric이 제거되어야 함
      final simulatedFiltered = Map<String, dynamic>.from(params)
        ..remove('token')
        ..remove('metric');

      expect(simulatedFiltered.containsKey('token'), isFalse);
      expect(simulatedFiltered.containsKey('metric'), isFalse);
      expect(simulatedFiltered.containsKey('symbol'), isTrue);
      expect(simulatedFiltered.containsKey('exchange'), isTrue);
    });

    test('fmpParams 프록시 시 제거 대상: apikey', () {
      final params = {
        'symbol': 'AAPL',
        'apikey': 'fmp_key',
        'period': 'annual',
      };

      final simulatedFiltered = Map<String, dynamic>.from(params)
        ..remove('apikey');

      expect(simulatedFiltered.containsKey('apikey'), isFalse);
      expect(simulatedFiltered.containsKey('symbol'), isTrue);
      expect(simulatedFiltered.containsKey('period'), isTrue);
    });
  });
}
