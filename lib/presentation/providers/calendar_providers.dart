import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/economic_event.dart';
import '../../data/services/api/calendar_service.dart';
import 'cycle_providers.dart';
import 'watchlist_providers.dart';

// ═══════════════════════════════════════════════════════════════
// 주요 실적 발표 기업 (관심종목 여부와 무관하게 상시 표시)
// ═══════════════════════════════════════════════════════════════

const kMajorEarningsTickers = <String>{
  // Mag 7
  'AAPL', 'MSFT', 'GOOGL', 'AMZN', 'META', 'NVDA', 'TSLA',
  // 반도체 (한국 투자자 선호)
  'AMD', 'AVGO', 'INTC', 'NFLX', 'CRM', 'ADBE', 'ORCL',
  'QCOM', 'MU', 'MRVL', 'ARM',
  // 금융/헬스케어/소비재
  'JPM', 'BAC', 'GS', 'UNH', 'JNJ', 'PG', 'KO',
};

// ═══════════════════════════════════════════════════════════════
// CalendarService Provider
// ═══════════════════════════════════════════════════════════════

/// CalendarService 싱글톤
final calendarServiceProvider = Provider<CalendarService>((ref) {
  return CalendarService();
});

// ═══════════════════════════════════════════════════════════════
// Calendar State
// ═══════════════════════════════════════════════════════════════

/// 캘린더 상태
class CalendarState {
  final List<EconomicEvent> events;
  final bool isLoading;
  final String? error;
  final DateTime selectedDate;

  const CalendarState({
    this.events = const [],
    this.isLoading = false,
    this.error,
    required this.selectedDate,
  });

  CalendarState copyWith({
    List<EconomicEvent>? events,
    bool? isLoading,
    String? error,
    DateTime? selectedDate,
  }) {
    return CalendarState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 선택 날짜의 이벤트
  List<EconomicEvent> get selectedDateEvents {
    final sd = _dateOnly(selectedDate);
    return events.where((e) => _dateOnly(e.date) == sd).toList();
  }

  /// 날짜별 이벤트 맵 (달력 뷰용)
  Map<DateTime, List<EconomicEvent>> get eventsByDate {
    final map = <DateTime, List<EconomicEvent>>{};
    for (final event in events) {
      final key = _dateOnly(event.date);
      (map[key] ??= []).add(event);
    }
    return map;
  }

  /// 다가오는 이벤트 (오늘 이후 14일)
  List<EconomicEvent> get upcomingEvents {
    final today = _dateOnly(DateTime.now());
    final limit = today.add(const Duration(days: 14));
    return events.where((e) {
      final d = _dateOnly(e.date);
      return !d.isBefore(today) && d.isBefore(limit);
    }).toList();
  }

  /// 오늘 이후 모든 이벤트
  List<EconomicEvent> get futureEvents {
    final today = _dateOnly(DateTime.now());
    return events.where((e) => !_dateOnly(e.date).isBefore(today)).toList();
  }

  /// 오늘 이벤트
  List<EconomicEvent> get todayEvents {
    final today = _dateOnly(DateTime.now());
    return events.where((e) => _dateOnly(e.date) == today).toList();
  }
}

// ═══════════════════════════════════════════════════════════════
// CalendarNotifier
// ═══════════════════════════════════════════════════════════════

/// CalendarNotifier — 경제 + 실적 이벤트 병합
class CalendarNotifier extends StateNotifier<CalendarState> {
  final CalendarService _service;
  final List<String> _watchlistTickers;

  CalendarNotifier(this._service, this._watchlistTickers)
      : super(CalendarState(selectedDate: DateTime.now()));

  /// 이벤트 로드 (현재 달 + 다음 달)
  Future<void> loadEvents() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final now = DateTime.now();
      // 현재월 기준 전후 2개월 범위 (전체 연도 불필요 — 서버 부하 감소)
      final from = DateTime(now.year, now.month - 2, 1);
      final to = DateTime(now.year, now.month + 3, 0); // 2개월 뒤 말일

      final fromStr = _dateStr(from);
      final toStr = _dateStr(to);

      // 경제 + 실적 병렬 로드
      final results = await Future.wait([
        _service
            .getEconomicEvents(from: fromStr, to: toStr)
            .catchError((_) => <EconomicEvent>[]),
        _service
            .getEarningsEvents(from: fromStr, to: toStr)
            .catchError((_) => <EconomicEvent>[]),
      ]);

      final economic = results[0];
      var earnings = results[1];

      // 실적: 서버가 주요 기업(MAJOR_EARNINGS_SYMBOLS)을 이미 포함
      // 클라이언트는 관심종목 추가 필터만 적용 (서버에 없는 watchlist 종목 표시용)
      if (_watchlistTickers.isNotEmpty) {
        final relevantTickers = {..._watchlistTickers, ...kMajorEarningsTickers};
        earnings = earnings
            .where(
                (e) => e.ticker != null && relevantTickers.contains(e.ticker))
            .toList();
      }

      final allEvents = [...economic, ...earnings]
        ..sort((a, b) => a.date.compareTo(b.date));

      state = state.copyWith(events: allEvents, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '일정 로드 실패');
    }
  }

  /// 날짜 선택 (달력 뷰)
  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ═══════════════════════════════════════════════════════════════
// Providers
// ═══════════════════════════════════════════════════════════════

/// Calendar Provider
final calendarProvider =
    StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  final service = ref.watch(calendarServiceProvider);

  // 관심종목 + 활성 사이클 종목 합산
  final watchlistTickers =
      ref.watch(watchlistProvider.select((s) => s.tickers));
  final cycleTickers = ref
      .watch(activeCyclesProvider)
      .map((c) => c.ticker)
      .toList();

  final allTickers = <String>{...watchlistTickers, ...cycleTickers}.toList();

  return CalendarNotifier(service, allTickers);
});

/// 다가오는 이벤트 (7일)
final upcomingEventsProvider = Provider<List<EconomicEvent>>((ref) {
  return ref.watch(calendarProvider).upcomingEvents;
});

/// 오늘 이벤트
final todayEventsProvider = Provider<List<EconomicEvent>>((ref) {
  return ref.watch(calendarProvider).todayEvents;
});
