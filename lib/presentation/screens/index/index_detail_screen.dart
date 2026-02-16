import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/ohlc_data.dart';
import '../../../data/services/api/finnhub_service.dart';
import '../../../data/services/technical_indicator_service.dart';
import '../../providers/api_providers.dart';
import '../../widgets/index/detail_chart_section.dart';
import '../../widgets/index/period_returns_section.dart';
import '../../widgets/index/pivot_point_section.dart';
import '../../widgets/index/description_section.dart';
import '../../widgets/index/news_section.dart';
import '../../widgets/shared/return_badge.dart';

/// 지수 상세 페이지
class IndexDetailScreen extends ConsumerStatefulWidget {
  final String symbol;
  final String name;

  const IndexDetailScreen({
    super.key,
    required this.symbol,
    required this.name,
  });

  @override
  ConsumerState<IndexDetailScreen> createState() => _IndexDetailScreenState();
}

class _IndexDetailScreenState extends ConsumerState<IndexDetailScreen> {
  bool _isLoading = true;
  bool _isNewsLoading = true;
  String? _error;

  List<OHLCData> _chartData = [];
  Map<String, double> _periodReturns = {};
  List<NewsItem> _news = [];

  String _selectedPeriod = '일봉';
  bool _showPivotLines = false;

  final _indicatorService = TechnicalIndicatorService();

  String get _chartSymbol {
    switch (widget.symbol) {
      case '^NDX':
        return 'QQQ';
      case '^GSPC':
        return 'SPY';
      default:
        return widget.symbol;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _isNewsLoading = true;
      _error = null;
    });

    try {
      final twelveDataService = ref.read(twelveDataServiceProvider);
      final quoteFuture = ref.read(stockQuoteProvider.notifier).fetchQuote(_chartSymbol);
      final chartFuture = twelveDataService.getChartData(_chartSymbol, interval: '1day', outputsize: 365);
      final results = await Future.wait([quoteFuture, chartFuture]);

      final chartData = results[1] as List<OHLCData>;
      final periodReturns = _calculatePeriodReturns(chartData);

      if (!mounted) return;
      setState(() {
        _chartData = chartData;
        _periodReturns = periodReturns;
        _isLoading = false;
      });

      _loadNews();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, double> _calculatePeriodReturns(List<OHLCData> chartData) {
    final returns = <String, double>{};
    if (chartData.isEmpty) return returns;

    final now = DateTime.now();
    final currentPrice = chartData.last.close;
    if (currentPrice == 0) return returns;

    double? findPriceAtDaysAgo(int daysAgo) {
      final targetDate = now.subtract(Duration(days: daysAgo));
      for (int i = chartData.length - 1; i >= 0; i--) {
        if (chartData[i].date.isBefore(targetDate) ||
            chartData[i].date.isAtSameMomentAs(targetDate)) {
          return chartData[i].close;
        }
      }
      return null;
    }

    double? findYTDPrice() {
      final startOfYear = DateTime(now.year, 1, 1);
      for (int i = 0; i < chartData.length; i++) {
        if (chartData[i].date.isAfter(startOfYear) ||
            chartData[i].date.isAtSameMomentAs(startOfYear)) {
          return chartData[i].close;
        }
      }
      return null;
    }

    final price1d = findPriceAtDaysAgo(1);
    if (price1d != null && price1d > 0) returns['1D'] = ((currentPrice - price1d) / price1d) * 100;

    final price1w = findPriceAtDaysAgo(7);
    if (price1w != null && price1w > 0) returns['1W'] = ((currentPrice - price1w) / price1w) * 100;

    final price1m = findPriceAtDaysAgo(30);
    if (price1m != null && price1m > 0) returns['1M'] = ((currentPrice - price1m) / price1m) * 100;

    final price3m = findPriceAtDaysAgo(90);
    if (price3m != null && price3m > 0) returns['3M'] = ((currentPrice - price3m) / price3m) * 100;

    final priceYtd = findYTDPrice();
    if (priceYtd != null && priceYtd > 0) returns['YTD'] = ((currentPrice - priceYtd) / priceYtd) * 100;

    final price1y = findPriceAtDaysAgo(365);
    if (price1y != null && price1y > 0) returns['1Y'] = ((currentPrice - price1y) / price1y) * 100;

    return returns;
  }

  Future<void> _loadNews() async {
    try {
      final service = ref.read(newsServiceProvider);
      final news = await service.getNews(widget.symbol);
      if (!mounted) return;
      setState(() {
        _news = news;
        _isNewsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isNewsLoading = false;
      });
    }
  }

  Future<void> _loadChartData() async {
    String interval;
    int outputsize;

    switch (_selectedPeriod) {
      case '일봉':
        interval = '1day';
        outputsize = 300;
        break;
      case '주봉':
        interval = '1week';
        outputsize = 240;
        break;
      case '월봉':
        interval = '1month';
        outputsize = 240;
        break;
      default:
        interval = '1day';
        outputsize = 300;
    }

    final service = ref.read(twelveDataServiceProvider);
    final chartData = await service.getChartData(_chartSymbol, interval: interval, outputsize: outputsize);
    if (!mounted) return;
    setState(() {
      _chartData = chartData;
    });
  }

  Map<String, double>? _calculatePivotLevels() {
    if (_chartData.isEmpty) return null;
    final recentData = _chartData.last;
    final high = recentData.high;
    final low = recentData.low;
    final close = recentData.close;
    final pivot = (high + low + close) / 3;
    return {
      'R2': pivot + (high - low),
      'R1': (2 * pivot) - low,
      'P': pivot,
      'S1': (2 * pivot) - high,
      'S2': pivot - (high - low),
    };
  }

  double _getCurrentPrice() {
    if (_chartData.isEmpty) return 0.0;
    return _chartData.last.close;
  }

  @override
  Widget build(BuildContext context) {
    final quoteState = ref.watch(stockQuoteProvider);
    final quote = quoteState.quotes[_chartSymbol];

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appSurface,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: context.appTextPrimary),
          onPressed: () {
            final from = GoRouterState.of(context).uri.queryParameters['from'];
            switch (from) {
              case 'watchlist':
                context.go('/watchlist');
              default:
                context.go('/');
            }
          },
        ),
        title: Text(
          widget.name,
          style: TextStyle(
            color: context.appTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        actions: [
          if (quote != null) _buildAppBarPrice(quote),
          const SizedBox(width: 2),
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.cached_rounded, size: 20, color: context.appTextHint),
              onPressed: _loadData,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('에러: $_error'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMetaInfo(quote),
                        PeriodReturnsSection(periodReturns: _periodReturns),
                        const SizedBox(height: 10),
                        DetailChartSection(
                          chartData: _chartData,
                          selectedPeriod: _selectedPeriod,
                          onPeriodChanged: (period) {
                            setState(() => _selectedPeriod = period);
                            _loadChartData();
                          },
                          showPivotLines: _showPivotLines,
                          pivotLevels: _calculatePivotLevels(),
                          indicatorService: _indicatorService,
                        ),
                        const SizedBox(height: 10),
                        PivotPointSection(
                          pivotLevels: _calculatePivotLevels(),
                          currentPrice: _getCurrentPrice(),
                          showPivotLines: _showPivotLines,
                          onTogglePivotLines: () {
                            setState(() => _showPivotLines = !_showPivotLines);
                          },
                        ),
                        const SizedBox(height: 10),
                        DescriptionSection(symbol: _chartSymbol, name: widget.name),
                        const SizedBox(height: 10),
                        NewsSection(news: _news, isLoading: _isNewsLoading, symbol: _chartSymbol),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildAppBarPrice(StockQuote quote) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatPrice(quote.currentPrice),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 6),
        ReturnBadge(
          value: quote.changePercent,
          size: ReturnBadgeSize.small,
          colorScheme: ReturnBadgeColorScheme.redBlue,
          decimals: 2,
          showIcon: false,
        ),
      ],
    );
  }

  Widget _buildMetaInfo(StockQuote? quote) {
    final timeStr = quote != null
        ? DateFormat('yyyy/MM/dd HH:mm').format(quote.timestamp)
        : '';
    return Container(
      color: context.appSurface,
      padding: const EdgeInsets.only(left: 16, right: 16, top: 6, bottom: 2),
      child: Text(
        '$_chartSymbol · $timeStr',
        style: TextStyle(fontSize: 12, color: context.appTextHint),
      ),
    );
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }
}
