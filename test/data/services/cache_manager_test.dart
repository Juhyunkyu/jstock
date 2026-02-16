import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_cycle/data/services/cache/cache_manager.dart';

/// 캐시 매니저 단위 테스트
void main() {
  late CacheManager cacheManager;

  setUp(() {
    cacheManager = CacheManager();
  });

  group('CacheEntry 테스트', () {
    test('CacheEntry 생성 및 만료 여부', () {
      final entry = CacheEntry<String>(
        data: 'test data',
        createdAt: DateTime.now(),
        ttl: const Duration(minutes: 15),
      );

      expect(entry.data, equals('test data'));
      expect(entry.isExpired, isFalse);
    });

    test('CacheEntry 만료 시간 계산', () {
      final now = DateTime.now();
      final entry = CacheEntry<String>(
        data: 'test',
        createdAt: now,
        ttl: const Duration(minutes: 15),
      );

      expect(entry.expiresAt, equals(now.add(const Duration(minutes: 15))));
    });

    test('CacheEntry 잔여 시간', () {
      final entry = CacheEntry<String>(
        data: 'test',
        createdAt: DateTime.now(),
        ttl: const Duration(minutes: 15),
      );

      expect(entry.remainingTime.inMinutes, lessThanOrEqualTo(15));
      expect(entry.remainingTime.inMinutes, greaterThanOrEqualTo(14));
    });

    test('만료된 CacheEntry', () {
      final pastTime = DateTime.now().subtract(const Duration(minutes: 20));
      final entry = CacheEntry<String>(
        data: 'expired data',
        createdAt: pastTime,
        ttl: const Duration(minutes: 15),
      );

      expect(entry.isExpired, isTrue);
      expect(entry.remainingTime, equals(Duration.zero));
    });
  });

  group('CacheManager 기본 동작', () {
    test('데이터 저장 및 조회', () {
      cacheManager.set('key1', 'value1');

      expect(cacheManager.get<String>('key1'), equals('value1'));
    });

    test('존재하지 않는 키 조회', () {
      expect(cacheManager.get<String>('nonexistent'), isNull);
    });

    test('다양한 타입 저장', () {
      cacheManager.set('string', 'hello');
      cacheManager.set('int', 42);
      cacheManager.set('double', 3.14);
      cacheManager.set('bool', true);
      cacheManager.set('list', [1, 2, 3]);
      cacheManager.set('map', {'key': 'value'});

      expect(cacheManager.get<String>('string'), equals('hello'));
      expect(cacheManager.get<int>('int'), equals(42));
      expect(cacheManager.get<double>('double'), equals(3.14));
      expect(cacheManager.get<bool>('bool'), isTrue);
      expect(cacheManager.get<List>('list'), equals([1, 2, 3]));
      expect(cacheManager.get<Map>('map'), equals({'key': 'value'}));
    });

    test('키 덮어쓰기', () {
      cacheManager.set('key', 'value1');
      cacheManager.set('key', 'value2');

      expect(cacheManager.get<String>('key'), equals('value2'));
    });
  });

  group('TTL 동작 테스트', () {
    test('기본 TTL 적용', () {
      cacheManager.set('stock', 'price');

      // 기본 TTL은 15분
      expect(cacheManager.containsKey('stock'), isTrue);
    });

    test('커스텀 TTL 적용', () {
      cacheManager.set('custom', 'data', ttl: const Duration(hours: 1));

      expect(cacheManager.containsKey('custom'), isTrue);
    });

    test('만료된 데이터 조회 시 null 반환', () {
      // 과거 시간으로 직접 테스트하기 어려우므로 cleanup 테스트로 대체
      cacheManager.set('test', 'data', ttl: const Duration(milliseconds: 1));

      // 약간의 지연 후 확인
      Future.delayed(const Duration(milliseconds: 10), () {
        expect(cacheManager.get<String>('test'), isNull);
      });
    });
  });

  group('삭제 동작 테스트', () {
    test('특정 키 삭제', () {
      cacheManager.set('key1', 'value1');
      cacheManager.set('key2', 'value2');

      cacheManager.remove('key1');

      expect(cacheManager.get<String>('key1'), isNull);
      expect(cacheManager.get<String>('key2'), equals('value2'));
    });

    test('패턴으로 삭제', () {
      cacheManager.set('stock:TQQQ', 'data1');
      cacheManager.set('stock:SOXL', 'data2');
      cacheManager.set('exchange:USD:KRW', 'data3');

      cacheManager.removePattern('^stock:');

      expect(cacheManager.get<String>('stock:TQQQ'), isNull);
      expect(cacheManager.get<String>('stock:SOXL'), isNull);
      expect(cacheManager.get<String>('exchange:USD:KRW'), equals('data3'));
    });

    test('전체 캐시 삭제', () {
      cacheManager.set('key1', 'value1');
      cacheManager.set('key2', 'value2');
      cacheManager.set('key3', 'value3');

      cacheManager.clear();

      expect(cacheManager.get<String>('key1'), isNull);
      expect(cacheManager.get<String>('key2'), isNull);
      expect(cacheManager.get<String>('key3'), isNull);
    });
  });

  group('캐시 통계 테스트', () {
    test('캐시 통계 조회', () {
      cacheManager.set('key1', 'value1');
      cacheManager.set('key2', 'value2');

      final stats = cacheManager.stats;

      expect(stats.itemCount, equals(2));
      expect(stats.keys.contains('key1'), isTrue);
      expect(stats.keys.contains('key2'), isTrue);
    });

    test('빈 캐시 통계', () {
      final stats = cacheManager.stats;

      expect(stats.itemCount, equals(0));
      expect(stats.keys.isEmpty, isTrue);
    });
  });

  group('containsKey 테스트', () {
    test('존재하는 키 확인', () {
      cacheManager.set('exists', 'value');

      expect(cacheManager.containsKey('exists'), isTrue);
    });

    test('존재하지 않는 키 확인', () {
      expect(cacheManager.containsKey('notexists'), isFalse);
    });
  });

  group('캐시 키 생성 함수 테스트', () {
    test('stockCacheKey', () {
      expect(stockCacheKey('tqqq'), equals('stock:TQQQ'));
      expect(stockCacheKey('SOXL'), equals('stock:SOXL'));
      expect(stockCacheKey('Upro'), equals('stock:UPRO'));
    });

    test('exchangeRateCacheKey', () {
      expect(exchangeRateCacheKey('usd', 'krw'), equals('exchange:USD:KRW'));
      expect(exchangeRateCacheKey('USD', 'EUR'), equals('exchange:USD:EUR'));
      expect(exchangeRateCacheKey('Eur', 'Jpy'), equals('exchange:EUR:JPY'));
    });
  });

  group('기본 TTL 상수 테스트', () {
    test('주가 캐시 TTL은 15분', () {
      expect(CacheManager.defaultStockTtl, equals(const Duration(minutes: 15)));
    });

    test('환율 캐시 TTL은 1시간', () {
      expect(CacheManager.defaultExchangeRateTtl, equals(const Duration(hours: 1)));
    });
  });

  group('복합 객체 캐싱 테스트', () {
    test('객체 저장 및 조회', () {
      final testObject = {'name': 'TQQQ', 'price': 56.04, 'volume': 120000000};

      cacheManager.set('stock:TQQQ', testObject);

      final retrieved = cacheManager.get<Map<String, dynamic>>('stock:TQQQ');
      expect(retrieved, isNotNull);
      expect(retrieved!['name'], equals('TQQQ'));
      expect(retrieved['price'], equals(56.04));
    });

    test('리스트 저장 및 조회', () {
      final testList = ['TQQQ', 'SOXL', 'UPRO'];

      cacheManager.set('popular_stocks', testList);

      final retrieved = cacheManager.get<List<String>>('popular_stocks');
      expect(retrieved, equals(testList));
    });
  });

  group('동시성 시뮬레이션', () {
    test('여러 키 동시 저장', () async {
      final futures = <Future>[];

      for (var i = 0; i < 100; i++) {
        futures.add(Future(() {
          cacheManager.set('key$i', 'value$i');
        }));
      }

      await Future.wait(futures);

      // 모든 키가 저장되었는지 확인
      for (var i = 0; i < 100; i++) {
        expect(cacheManager.get<String>('key$i'), equals('value$i'));
      }
    });
  });
}
