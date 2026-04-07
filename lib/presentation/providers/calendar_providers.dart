import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/economic_event.dart';
import '../../data/services/api/calendar_service.dart';
import 'cycle_providers.dart';
import 'watchlist_providers.dart';

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

  /// 선택 날짜의 이벤트
  List<EconomicEvent> get selectedDateEvents {
    return events
        .where((e) =>
            e.date.year == selectedDate.year &&
            e.date.month == selectedDate.month &&
            e.date.day == selectedDate.day)
        .toList();
  }

  /// 날짜별 이벤트 맵 (달력 뷰용)
  Map<DateTime, List<EconomicEvent>> get eventsByDate {
    final map = <DateTime, List<EconomicEvent>>{};
    for (final event in events) {
      final key = DateTime(event.date.year, event.date.month, event.date.day);
      (map[key] ??= []).add(event);
    }
    return map;
  }

  /// 다가오는 이벤트 (오늘 이후 14일)
  List<EconomicEvent> get upcomingEvents {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekLater = today.add(const Duration(days: 14));
    return events
        .where((e) {
          final d = DateTime(e.date.year, e.date.month, e.date.day);
          return !d.isBefore(today) && d.isBefore(weekLater);
        })
        .toList();
  }

  /// 오늘 이후 모든 이벤트 (월별 그룹 뷰용)
  List<EconomicEvent> get futureEvents {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return events
        .where((e) {
          final d = DateTime(e.date.year, e.date.month, e.date.day);
          return !d.isBefore(today);
        })
        .toList();
  }

  /// 오늘 이벤트
  List<EconomicEvent> get todayEvents {
    final now = DateTime.now();
    return events
        .where((e) =>
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.date.day == now.day)
        .toList();
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
      final from = DateTime(now.year, 1, 1); // 연초부터 (과거 결과 확인용)
      final to = DateTime(now.year, 12, 31); // 연말까지

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

      // 실적: 관심종목/사이클 종목만 필터
      if (_watchlistTickers.isNotEmpty) {
        earnings = earnings
            .where(
                (e) => e.ticker != null && _watchlistTickers.contains(e.ticker))
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
