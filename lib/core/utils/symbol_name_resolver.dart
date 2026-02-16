import 'package:hive/hive.dart';
import '../../data/models/watchlist_item.dart';
import '../../data/models/holding.dart';
import '../../presentation/widgets/stocks/popular_etf_list.dart';

/// 심볼 → 표시명 조회 유틸리티
///
/// 우선순위:
/// 1. 정적 매핑 (주요 지수/종목)
/// 2. Hive WatchlistItem 조회
/// 3. Hive Holding 조회
/// 4. PopularEtf.leveraged3x 목록
/// 5. Fallback: 심볼 자체 반환
class SymbolNameResolver {
  SymbolNameResolver._();

  /// 잘 알려진 심볼의 정적 매핑
  static const Map<String, String> _staticMap = {
    '^NDX': 'NASDAQ 100',
    '^GSPC': 'S&P 500',
    '^DJI': 'Dow Jones',
    '^RUT': 'Russell 2000',
    '^VIX': 'VIX',
    'QQQ': 'Invesco QQQ Trust',
    'SPY': 'SPDR S&P 500 ETF',
    'AAPL': 'Apple Inc.',
    'MSFT': 'Microsoft Corp.',
    'GOOGL': 'Alphabet Inc.',
    'AMZN': 'Amazon.com Inc.',
    'NVDA': 'NVIDIA Corp.',
    'META': 'Meta Platforms Inc.',
    'TSLA': 'Tesla Inc.',
  };

  /// 심볼에 대한 표시명을 조회합니다.
  static String resolve(String symbol) {
    // 1. 정적 매핑
    final staticName = _staticMap[symbol];
    if (staticName != null) return staticName;

    // 2. Hive WatchlistItem 조회
    try {
      if (Hive.isBoxOpen('watchlist')) {
        final box = Hive.box<WatchlistItem>('watchlist');
        for (final item in box.values) {
          if (item.ticker == symbol) return item.name;
        }
      }
    } catch (_) {}

    // 3. Hive Holding 조회
    try {
      if (Hive.isBoxOpen('holdings')) {
        final box = Hive.box<Holding>('holdings');
        for (final item in box.values) {
          if (item.ticker == symbol) return item.name;
        }
      }
    } catch (_) {}

    // 4. PopularEtf.leveraged3x 목록
    for (final etf in PopularEtf.leveraged3x) {
      if (etf.ticker == symbol) return etf.name;
    }

    // 5. Fallback
    return symbol;
  }
}
