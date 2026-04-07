import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/economic_event.dart';
import '../../providers/calendar_providers.dart';

// ═══════════════════════════════════════════════════════════════
// 경제 캘린더 카드 — 목록(Timeline) / 달력(Mini Calendar) 토글
// v3.0: 날짜 그룹 헤더 + 과거 actual 서프라이즈 + 과거 월 네비게이션
// ═══════════════════════════════════════════════════════════════

class EconomicCalendarCard extends ConsumerStatefulWidget {
  final bool useOuterMargin;

  const EconomicCalendarCard({
    super.key,
    this.useOuterMargin = true,
  });

  @override
  ConsumerState<EconomicCalendarCard> createState() =>
      _EconomicCalendarCardState();
}

class _EconomicCalendarCardState extends ConsumerState<EconomicCalendarCard> {
  bool _isCalendarView = false;
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month, 1);
    Future.microtask(() {
      ref.read(calendarProvider.notifier).loadEvents();
    });
  }

  double _fontScale(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1024) return 1.16;
    if (w >= 600) return 1.08;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarProvider);
    final fs = _fontScale(context);

    return Container(
      margin: widget.useOuterMargin
          ? const EdgeInsets.symmetric(horizontal: 16)
          : EdgeInsets.zero,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Padding(
        padding: EdgeInsets.all(12 * fs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, fs),
            SizedBox(height: 8 * fs),
            if (state.isLoading)
              _buildLoading()
            else if (state.error != null)
              _buildError(context, state.error!, fs)
            else if (_isCalendarView)
              _buildCalendarView(context, state, fs)
            else
              _buildTimelineView(context, state, fs),
          ],
        ),
      ),
    );
  }

  // ─── 헤더 ───

  Widget _buildHeader(BuildContext context, double fs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_outlined,
                size: 16 * fs, color: context.appTextSecondary),
            SizedBox(width: 5 * fs),
            Text(
              _isCalendarView ? '경제 캘린더' : '주요 일정',
              style: TextStyle(
                fontSize: 13 * fs,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
          ],
        ),
        _buildViewToggle(context, fs),
      ],
    );
  }

  Widget _buildViewToggle(BuildContext context, double fs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _toggleBtn(context, fs: fs, label: '목록', isActive: !_isCalendarView,
            onTap: () => setState(() => _isCalendarView = false)),
        SizedBox(width: 2 * fs),
        _toggleBtn(context, fs: fs, label: '달력', isActive: _isCalendarView,
            onTap: () => setState(() => _isCalendarView = true)),
      ],
    );
  }

  Widget _toggleBtn(BuildContext context,
      {required double fs,
      required String label,
      required bool isActive,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6 * fs, vertical: 3 * fs),
        decoration: BoxDecoration(
          color: isActive ? AppColors.calendarEarnings : context.appIconBg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10 * fs,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive
                ? const Color(0xFF0D1117)
                : context.appTextSecondary,
          ),
        ),
      ),
    );
  }

  // ─── 로딩 / 에러 ───

  Widget _buildLoading() {
    return const SizedBox(
        height: 120, child: Center(child: CircularProgressIndicator.adaptive()));
  }

  Widget _buildError(BuildContext context, String error, double fs) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error,
                style: TextStyle(fontSize: 11 * fs, color: context.appTextHint)),
            SizedBox(height: 8 * fs),
            GestureDetector(
              onTap: () => ref.read(calendarProvider.notifier).loadEvents(),
              child: Text('다시 시도',
                  style: TextStyle(fontSize: 11 * fs, color: context.appAccent)),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 목록 뷰 — 날짜 그룹 헤더 + 서프라이즈 표시
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTimelineView(
      BuildContext context, CalendarState state, double fs) {
    final events = state.futureEvents;

    if (events.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text('예정된 일정이 없습니다',
              style: TextStyle(fontSize: 11 * fs, color: context.appTextHint)),
        ),
      );
    }

    // 날짜별 그룹화 (같은 날짜 묶기)
    final grouped = <String, List<EconomicEvent>>{};
    for (final e in events) {
      final key =
          '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
      (grouped[key] ??= []).add(e);
    }
    final sortedDateKeys = grouped.keys.toList()..sort();

    // 월 경계 추적용
    int? lastMonth;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: sortedDateKeys.length,
        itemBuilder: (context, idx) {
          final dateKey = sortedDateKeys[idx];
          final dateEvents = grouped[dateKey]!;
          final date = dateEvents.first.date;
          final month = date.month;
          final showMonthHeader = month != lastMonth;
          lastMonth = month;

          final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
          final weekday = weekdays[date.weekday - 1];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 월 헤더 (월이 바뀔 때만)
              if (showMonthHeader) ...[
                if (idx > 0) SizedBox(height: 10 * fs),
                _buildMonthDivider(context, month, fs),
                SizedBox(height: 6 * fs),
              ],
              // 날짜 헤더
              _buildDateHeader(context, date, weekday, dateEvents.length, fs),
              // 해당 날짜 이벤트들
              for (final event in dateEvents)
                _buildEventRow(context, event, fs),
              SizedBox(height: 4 * fs),
            ],
          );
        },
      ),
    );
  }

  /// 월 구분선
  Widget _buildMonthDivider(BuildContext context, int month, double fs) {
    return Row(
      children: [
        Expanded(child: Divider(height: 1, color: context.appDivider)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8 * fs),
          child: Text(
            '$month월',
            style: TextStyle(
              fontSize: 10 * fs,
              fontWeight: FontWeight.w700,
              color: context.appAccent,
            ),
          ),
        ),
        Expanded(child: Divider(height: 1, color: context.appDivider)),
      ],
    );
  }

  /// 날짜 헤더: "4/7 (화) ━━━━ 5건 ━━━━ D-DAY"
  Widget _buildDateHeader(BuildContext context, DateTime date, String weekday,
      int eventCount, double fs) {
    final dday = _ddayFromDate(date);

    return Padding(
      padding: EdgeInsets.only(top: 2 * fs, bottom: 2 * fs),
      child: Row(
        children: [
          // 날짜 + 요일
          Text(
            '${date.month}/${date.day} ($weekday)',
            style: TextStyle(
              fontSize: 11 * fs,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          ),
          SizedBox(width: 6 * fs),
          // 구분선
          Expanded(
            child: Container(
              height: 1,
              color: context.appDivider,
            ),
          ),
          SizedBox(width: 6 * fs),
          // 건수
          Text(
            '$eventCount건',
            style: TextStyle(
              fontSize: 9 * fs,
              color: context.appTextHint,
            ),
          ),
          SizedBox(width: 6 * fs),
          // D-day 배지
          _buildDdayChip(context, dday, fs),
        ],
      ),
    );
  }

  /// 이벤트 행 (서프라이즈 표시 포함)
  Widget _buildEventRow(BuildContext context, EconomicEvent event, double fs) {
    final isPast = _isPastEvent(event);
    final hasActual = event.actual != null;

    return Padding(
      padding: EdgeInsets.only(left: 8 * fs, top: 2 * fs, bottom: 2 * fs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카테고리 도트
          Padding(
            padding: EdgeInsets.only(top: 4 * fs),
            child: Container(
              width: 5 * fs,
              height: 5 * fs,
              decoration: BoxDecoration(
                color: event.category.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: 6 * fs),
          // 이벤트 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.displayTitle,
                  style: TextStyle(
                    fontSize: 11 * fs,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // 부제: 미래=예상/전월, 과거=actual 서프라이즈
                if (isPast && hasActual)
                  _buildActualRow(context, event, fs)
                else if (_hasSubtitle(event))
                  Text(
                    _buildSubtitle(event),
                    style: TextStyle(
                        fontSize: 9 * fs, color: context.appTextSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 과거 이벤트: actual 서프라이즈 행
  Widget _buildActualRow(
      BuildContext context, EconomicEvent event, double fs) {
    final actual = event.actual!;
    final forecast = event.forecast;
    final unit = event.unit ?? '';

    // 서프라이즈 계산
    String surpriseText = '';
    Color surpriseColor = context.appTextSecondary;

    if (forecast != null && forecast != 0) {
      final diff = actual - forecast;
      final sign = diff >= 0 ? '+' : '';
      surpriseText = ' ($sign${_fmtVal(diff)}$unit)';

      if (diff > 0) {
        surpriseColor = AppColors.red500; // beat = 상승 = 빨간 (한국 관례)
      } else if (diff < 0) {
        surpriseColor = AppColors.blue500; // miss = 하락 = 파란
      }
    }

    return Row(
      children: [
        if (forecast != null) ...[
          Text(
            '예상 ${_fmtVal(forecast)}$unit → ',
            style: TextStyle(fontSize: 9 * fs, color: context.appTextHint),
          ),
        ],
        Text(
          '실제 ${_fmtVal(actual)}$unit',
          style: TextStyle(
            fontSize: 9 * fs,
            fontWeight: FontWeight.w600,
            color: surpriseColor,
          ),
        ),
        if (surpriseText.isNotEmpty)
          Text(
            surpriseText,
            style: TextStyle(fontSize: 9 * fs, color: surpriseColor),
          ),
      ],
    );
  }

  // ─── 헬퍼 ───

  bool _isPastEvent(EconomicEvent event) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
    return eventDate.isBefore(today);
  }

  bool _hasSubtitle(EconomicEvent event) {
    return _buildSubtitle(event).isNotEmpty;
  }

  String _buildSubtitle(EconomicEvent event) {
    final parts = <String>[];
    if (event.isEarnings) {
      if (event.forecast != null) {
        parts.add('EPS \$${event.forecast!.toStringAsFixed(2)}');
      }
      final hourText = _earningsHourText(event.hour);
      if (hourText != null) parts.add(hourText);
    } else {
      if (event.forecast != null && event.previous != null) {
        final unit = event.unit ?? '';
        parts.add(
            '예상 ${_fmtVal(event.forecast!)}$unit (전월 ${_fmtVal(event.previous!)}$unit)');
      }
    }
    return parts.join(' · ');
  }

  String? _earningsHourText(String? hour) {
    if (hour == null) return null;
    final h = hour.toLowerCase();
    if (h == 'bmo' || h.contains('before')) return '장 개장 전';
    if (h == 'amc' || h.contains('after')) return '장 마감 후';
    return hour;
  }

  String _fmtVal(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  String _ddayFromDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(date.year, date.month, date.day);
    final diff = eventDate.difference(today).inDays;
    if (diff == 0) return 'D-DAY';
    if (diff > 0) return 'D-$diff';
    return 'D+${diff.abs()}';
  }

  Widget _buildDdayChip(BuildContext context, String text, double fs) {
    final isToday = text == 'D-DAY';
    final isPast = text.startsWith('D+');
    final dday = _parseDday(text);
    final isUrgent = dday != null && dday >= 0 && dday <= 3;

    Color bgColor;
    Color textColor;
    if (isToday) {
      bgColor = AppColors.calendarFomc.withValues(alpha: 0.2);
      textColor = AppColors.calendarFomc;
    } else if (isPast) {
      bgColor = context.appIconBg;
      textColor = context.appTextHint;
    } else if (isUrgent) {
      bgColor = AppColors.calendarFomc.withValues(alpha: 0.15);
      textColor = AppColors.calendarFomc;
    } else {
      bgColor = context.appIconBg;
      textColor = context.appTextSecondary;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4 * fs, vertical: 1 * fs),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 8 * fs, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }

  int? _parseDday(String text) {
    if (text == 'D-DAY') return 0;
    final match = RegExp(r'D-(\d+)').firstMatch(text);
    if (match != null) return int.tryParse(match.group(1)!);
    final matchPlus = RegExp(r'D\+(\d+)').firstMatch(text);
    if (matchPlus != null) return -(int.tryParse(matchPlus.group(1)!) ?? 0);
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  // 달력 뷰 — 과거 월 네비게이션 (1월~12월)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCalendarView(
      BuildContext context, CalendarState state, double fs) {
    final now = DateTime.now();
    final selectedDate = state.selectedDate;
    final eventsByDate = state.eventsByDate;

    final firstOfMonth =
        DateTime(_displayMonth.year, _displayMonth.month, 1);
    final lastOfMonth =
        DateTime(_displayMonth.year, _displayMonth.month + 1, 0);
    final startWeekday = firstOfMonth.weekday % 7;
    final daysInMonth = lastOfMonth.day;
    final prevMonthLast =
        DateTime(_displayMonth.year, _displayMonth.month, 0);
    final prevMonthDays = prevMonthLast.day;

    // 1월~12월 전체 이동 가능
    final firstMonth = DateTime(now.year, 1, 1);
    final lastMonth = DateTime(now.year, 12, 1);
    final canGoPrev = _displayMonth.isAfter(firstMonth);
    final canGoNext = _displayMonth.isBefore(lastMonth);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMonthNav(context, fs,
            canGoPrev: canGoPrev, canGoNext: canGoNext),
        SizedBox(height: 4 * fs),
        _buildWeekHeader(context, fs),
        SizedBox(height: 2 * fs),
        _buildDayGrid(context,
            fs: fs,
            firstOfMonth: firstOfMonth,
            daysInMonth: daysInMonth,
            startWeekday: startWeekday,
            prevMonthDays: prevMonthDays,
            selectedDate: selectedDate,
            eventsByDate: eventsByDate,
            now: now),
        SizedBox(height: 4 * fs),
        Divider(height: 1, color: context.appDivider),
        SizedBox(height: 4 * fs),
        _buildSelectedDateEvents(context, state, fs),
        SizedBox(height: 6 * fs),
        _buildLegend(context, fs),
      ],
    );
  }

  Widget _buildMonthNav(BuildContext context, double fs,
      {required bool canGoPrev, required bool canGoNext}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: canGoPrev
              ? () => setState(() => _displayMonth =
                  DateTime(_displayMonth.year, _displayMonth.month - 1, 1))
              : null,
          child: Padding(
            padding: EdgeInsets.all(4 * fs),
            child: Icon(Icons.chevron_left_rounded,
                size: 18 * fs,
                color: canGoPrev
                    ? context.appTextSecondary
                    : context.appTextHint.withValues(alpha: 0.3)),
          ),
        ),
        SizedBox(width: 8 * fs),
        Text(
          '${_displayMonth.year}년 ${_displayMonth.month}월',
          style: TextStyle(
            fontSize: 13 * fs,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
        SizedBox(width: 8 * fs),
        GestureDetector(
          onTap: canGoNext
              ? () => setState(() => _displayMonth =
                  DateTime(_displayMonth.year, _displayMonth.month + 1, 1))
              : null,
          child: Padding(
            padding: EdgeInsets.all(4 * fs),
            child: Icon(Icons.chevron_right_rounded,
                size: 18 * fs,
                color: canGoNext
                    ? context.appTextSecondary
                    : context.appTextHint.withValues(alpha: 0.3)),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekHeader(BuildContext context, double fs) {
    const days = ['일', '월', '화', '수', '목', '금', '토'];
    return Row(
      children: days
          .map((d) => Expanded(
                child: Center(
                  child: Text(d,
                      style: TextStyle(
                          fontSize: 10 * fs, color: context.appTextHint)),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildDayGrid(BuildContext context,
      {required double fs,
      required DateTime firstOfMonth,
      required int daysInMonth,
      required int startWeekday,
      required int prevMonthDays,
      required DateTime selectedDate,
      required Map<DateTime, List<EconomicEvent>> eventsByDate,
      required DateTime now}) {
    final rows = <Widget>[];
    int dayCounter = 1;
    int nextMonthDay = 1;

    for (int week = 0; week < 6; week++) {
      if (dayCounter > daysInMonth && week > 0) break;
      final cells = <Widget>[];
      for (int col = 0; col < 7; col++) {
        final cellIndex = week * 7 + col;
        if (cellIndex < startWeekday) {
          final day = prevMonthDays - startWeekday + cellIndex + 1;
          cells.add(_buildDayCell(context,
              fs: fs,
              day: day,
              isDim: true,
              isToday: false,
              isSelected: false,
              dots: [],
              onTap: null));
        } else if (dayCounter <= daysInMonth) {
          final day = dayCounter;
          final date =
              DateTime(firstOfMonth.year, firstOfMonth.month, day);
          final isToday = day == now.day &&
              firstOfMonth.month == now.month &&
              firstOfMonth.year == now.year;
          final isSelected = day == selectedDate.day &&
              firstOfMonth.month == selectedDate.month &&
              firstOfMonth.year == selectedDate.year;
          final dayEvents = eventsByDate[date] ?? [];
          final dots =
              dayEvents.map((e) => e.category.color).toSet().take(3).toList();
          cells.add(_buildDayCell(context,
              fs: fs,
              day: day,
              isDim: false,
              isToday: isToday,
              isSelected: isSelected,
              dots: dots,
              onTap: () =>
                  ref.read(calendarProvider.notifier).selectDate(date)));
          dayCounter++;
        } else {
          cells.add(_buildDayCell(context,
              fs: fs,
              day: nextMonthDay++,
              isDim: true,
              isToday: false,
              isSelected: false,
              dots: [],
              onTap: null));
        }
      }
      rows.add(Row(children: cells));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _buildDayCell(BuildContext context,
      {required double fs,
      required int day,
      required bool isDim,
      required bool isToday,
      required bool isSelected,
      required List<Color> dots,
      VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 2 * fs),
          decoration: BoxDecoration(
            color: isSelected
                ? context.appAccent.withValues(alpha: 0.15)
                : isToday
                    ? context.appIconBg
                    : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 12 * fs,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                  color: isDim
                      ? context.appTextHint.withValues(alpha: 0.3)
                      : isSelected
                          ? context.appAccent
                          : context.appTextSecondary,
                ),
              ),
              if (dots.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 1 * fs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: dots
                        .map((c) => Container(
                              width: 5 * fs,
                              height: 5 * fs,
                              margin: EdgeInsets.symmetric(horizontal: 1 * fs),
                              decoration: BoxDecoration(
                                  color: c, shape: BoxShape.circle),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 선택 날짜 이벤트 목록 (달력 뷰) — 서프라이즈 표시 포함
  Widget _buildSelectedDateEvents(
      BuildContext context, CalendarState state, double fs) {
    final events = state.selectedDateEvents;

    if (events.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 4 * fs),
        child: Center(
          child: Text('이 날짜에 예정된 일정이 없습니다',
              style: TextStyle(fontSize: 11 * fs, color: context.appTextHint)),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: events.map((event) {
        final isPast = _isPastEvent(event);
        final hasActual = event.actual != null;

        return Padding(
          padding: EdgeInsets.symmetric(vertical: 2 * fs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 5 * fs,
                    height: 5 * fs,
                    decoration: BoxDecoration(
                        color: event.category.color, shape: BoxShape.circle),
                  ),
                  SizedBox(width: 4 * fs),
                  Expanded(
                    child: Text(
                      event.displayTitle,
                      style: TextStyle(
                          fontSize: 11 * fs, color: context.appTextPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // 과거 actual 서프라이즈 or 미래 예상값
              if (isPast && hasActual)
                Padding(
                  padding: EdgeInsets.only(left: 9 * fs),
                  child: _buildActualRow(context, event, fs),
                )
              else if (_hasSubtitle(event))
                Padding(
                  padding: EdgeInsets.only(left: 9 * fs),
                  child: Text(
                    _buildSubtitle(event),
                    style: TextStyle(
                        fontSize: 9 * fs, color: context.appTextSecondary),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLegend(BuildContext context, double fs) {
    const categories = [
      EventCategory.fomc,
      EventCategory.inflation,
      EventCategory.employment,
      EventCategory.earnings,
      EventCategory.gdp,
    ];
    return Wrap(
      spacing: 8 * fs,
      runSpacing: 2 * fs,
      children: categories.map((cat) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5 * fs,
              height: 5 * fs,
              decoration:
                  BoxDecoration(color: cat.color, shape: BoxShape.circle),
            ),
            SizedBox(width: 3 * fs),
            Text(cat.labelKo,
                style: TextStyle(
                    fontSize: 9 * fs, color: context.appTextSecondary)),
          ],
        );
      }).toList(),
    );
  }
}
