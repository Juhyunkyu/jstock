import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/economic_event.dart';
import '../../providers/calendar_providers.dart';

// ═══════════════════════════════════════════════════════════════
// 경제 캘린더 카드 — 목록(Timeline) / 달력(Mini Calendar) 토글
// ═══════════════════════════════════════════════════════════════

class EconomicCalendarCard extends ConsumerStatefulWidget {
  /// 외부 마진 사용 여부 (standalone 배치 시 true)
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
  bool _isCalendarView = false; // false=목록, true=달력

  @override
  void initState() {
    super.initState();
    // 최초 이벤트 로드
    Future.microtask(() {
      ref.read(calendarProvider.notifier).loadEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarProvider);

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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            const SizedBox(height: 8),
            if (state.isLoading)
              _buildLoading()
            else if (state.error != null)
              _buildError(context, state.error!)
            else if (_isCalendarView)
              _buildCalendarView(context, state)
            else
              _buildTimelineView(context, state),
          ],
        ),
      ),
    );
  }

  // ─── 헤더: 제목 + [목록|달력] 토글 ───

  Widget _buildHeader(BuildContext context) {
    final title = _isCalendarView
        ? '${DateTime.now().month}월'
        : '주요 일정';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 16,
              color: context.appTextSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
          ],
        ),
        _buildViewToggle(context),
      ],
    );
  }

  Widget _buildViewToggle(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _toggleButton(context, label: '목록', isActive: !_isCalendarView,
            onTap: () {
          setState(() => _isCalendarView = false);
        }),
        const SizedBox(width: 2),
        _toggleButton(context, label: '달력', isActive: _isCalendarView,
            onTap: () {
          setState(() => _isCalendarView = true);
        }),
      ],
    );
  }

  Widget _toggleButton(
    BuildContext context, {
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.calendarEarnings // #58A6FF
              : context.appIconBg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive
                ? const Color(0xFF0D1117) // 다크 텍스트 (활성 상태)
                : context.appTextSecondary,
          ),
        ),
      ),
    );
  }

  // ─── 로딩 / 에러 ───

  Widget _buildLoading() {
    return const SizedBox(
      height: 120,
      child: Center(child: CircularProgressIndicator.adaptive()),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, style: TextStyle(
              fontSize: 11,
              color: context.appTextHint,
            )),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => ref.read(calendarProvider.notifier).loadEvents(),
              child: Text('다시 시도',
                  style: TextStyle(fontSize: 11, color: context.appAccent)),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 목록 뷰 (Timeline)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTimelineView(BuildContext context, CalendarState state) {
    final events = state.upcomingEvents;

    if (events.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            '이번 주 예정된 일정이 없습니다',
            style: TextStyle(fontSize: 11, color: context.appTextHint),
          ),
        ),
      );
    }

    // 최대 6개 표시
    final displayEvents = events.length > 6 ? events.sublist(0, 6) : events;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < displayEvents.length; i++) ...[
          _buildTimelineItem(context, displayEvents[i]),
          if (i < displayEvents.length - 1)
            Divider(height: 1, color: context.appDivider),
        ],
      ],
    );
  }

  Widget _buildTimelineItem(BuildContext context, EconomicEvent event) {
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[event.date.weekday - 1];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜 컬럼 (일 + 요일)
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Text(
                  '${event.date.day}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                ),
                Text(
                  weekday,
                  style: TextStyle(
                    fontSize: 8,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          // 도트 컬럼
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: SizedBox(
              width: 10,
              child: Center(
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: event.category.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // 이벤트 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  _buildSubtitle(event),
                  style: TextStyle(
                    fontSize: 9,
                    color: context.appTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // D-day 배지
          _buildDdayBadge(context, event),
        ],
      ),
    );
  }

  /// 타임라인 부제 텍스트 생성
  String _buildSubtitle(EconomicEvent event) {
    final parts = <String>[];

    if (event.isEarnings) {
      // 실적 이벤트
      if (event.forecast != null) {
        parts.add('EPS \$${event.forecast!.toStringAsFixed(2)}');
      }
      // bmo/amc 변환
      final hourText = _earningsHourText(event.hour);
      if (hourText != null) parts.add(hourText);
    } else {
      // 경제 지표
      if (event.forecast != null && event.previous != null) {
        final unit = event.unit ?? '';
        parts.add(
            '예상 ${_formatValue(event.forecast!)}$unit (전월 ${_formatValue(event.previous!)}$unit)');
      }
      if (event.hour != null && event.hour!.isNotEmpty) {
        parts.add(event.hour!);
      }
    }

    if (parts.isEmpty) {
      // 시간만이라도 표시
      if (event.hour != null && event.hour!.isNotEmpty) {
        return '${event.hour} KST';
      }
      return '';
    }

    return parts.join(' · ');
  }

  /// 실적 시간 텍스트
  String? _earningsHourText(String? hour) {
    if (hour == null) return null;
    final h = hour.toLowerCase();
    if (h == 'bmo' || h.contains('before')) return '장 개장 전';
    if (h == 'amc' || h.contains('after')) return '장 마감 후';
    return hour;
  }

  /// 숫자 포맷 (소수점 불필요 시 제거)
  String _formatValue(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  /// D-day 배지 위젯
  Widget _buildDdayBadge(BuildContext context, EconomicEvent event) {
    final text = event.ddayText;
    final dday = _parseDday(text);

    // D-DAY ~ D-3: 빨간 계열 / D-4+: 기본 회색
    final isUrgent = dday != null && dday >= 0 && dday <= 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: isUrgent
            ? AppColors.calendarFomc.withValues(alpha: 0.15)
            : context.appIconBg,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: isUrgent ? AppColors.calendarFomc : context.appTextSecondary,
        ),
      ),
    );
  }

  /// D-day 텍스트에서 숫자 추출 (D-DAY→0, D-3→3, D+2→-2)
  int? _parseDday(String text) {
    if (text == 'D-DAY') return 0;
    final match = RegExp(r'D-(\d+)').firstMatch(text);
    if (match != null) return int.tryParse(match.group(1)!);
    final matchPlus = RegExp(r'D\+(\d+)').firstMatch(text);
    if (matchPlus != null) return -(int.tryParse(matchPlus.group(1)!) ?? 0);
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  // 달력 뷰 (Mini Calendar)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCalendarView(BuildContext context, CalendarState state) {
    final now = DateTime.now();
    final selectedDate = state.selectedDate;
    final eventsByDate = state.eventsByDate;

    // 현재 달 기준 그리드 계산
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final lastOfMonth = DateTime(now.year, now.month + 1, 0);
    // 일요일=0 시작 (DateTime.weekday: 월=1 ~ 일=7)
    final startWeekday = firstOfMonth.weekday % 7; // 일=0, 월=1 ... 토=6
    final daysInMonth = lastOfMonth.day;

    // 이전 달 마지막 날
    final prevMonthLast = DateTime(now.year, now.month, 0);
    final prevMonthDays = prevMonthLast.day;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 요일 헤더
        _buildWeekHeader(context),
        const SizedBox(height: 2),
        // 날짜 그리드
        _buildDayGrid(
          context,
          firstOfMonth: firstOfMonth,
          daysInMonth: daysInMonth,
          startWeekday: startWeekday,
          prevMonthDays: prevMonthDays,
          selectedDate: selectedDate,
          eventsByDate: eventsByDate,
          now: now,
        ),
        // 선택 날짜 이벤트 목록
        const SizedBox(height: 4),
        Divider(height: 1, color: context.appDivider),
        const SizedBox(height: 4),
        _buildSelectedDateEvents(context, state),
        // 범례
        const SizedBox(height: 6),
        _buildLegend(context),
      ],
    );
  }

  Widget _buildWeekHeader(BuildContext context) {
    const days = ['일', '월', '화', '수', '목', '금', '토'];
    return Row(
      children: days
          .map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 8,
                      color: context.appTextHint,
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildDayGrid(
    BuildContext context, {
    required DateTime firstOfMonth,
    required int daysInMonth,
    required int startWeekday,
    required int prevMonthDays,
    required DateTime selectedDate,
    required Map<DateTime, List<EconomicEvent>> eventsByDate,
    required DateTime now,
  }) {
    final rows = <Widget>[];
    int dayCounter = 1;
    int nextMonthDay = 1;

    // 최대 6주
    for (int week = 0; week < 6; week++) {
      if (dayCounter > daysInMonth && week > 0) break;

      final cells = <Widget>[];
      for (int col = 0; col < 7; col++) {
        final cellIndex = week * 7 + col;

        if (cellIndex < startWeekday) {
          // 이전 달
          final day = prevMonthDays - startWeekday + cellIndex + 1;
          cells.add(_buildDayCell(
            context,
            day: day,
            isDim: true,
            isToday: false,
            isSelected: false,
            dots: [],
            onTap: null,
          ));
        } else if (dayCounter <= daysInMonth) {
          final day = dayCounter;
          final date = DateTime(firstOfMonth.year, firstOfMonth.month, day);
          final isToday =
              day == now.day && firstOfMonth.month == now.month && firstOfMonth.year == now.year;
          final isSelected = day == selectedDate.day &&
              firstOfMonth.month == selectedDate.month &&
              firstOfMonth.year == selectedDate.year;
          final dayEvents = eventsByDate[date] ?? [];
          // 카테고리 컬러 도트 (최대 3개)
          final dots = dayEvents
              .map((e) => e.category.color)
              .toSet()
              .take(3)
              .toList();

          cells.add(_buildDayCell(
            context,
            day: day,
            isDim: false,
            isToday: isToday,
            isSelected: isSelected,
            dots: dots,
            onTap: () {
              ref.read(calendarProvider.notifier).selectDate(date);
            },
          ));
          dayCounter++;
        } else {
          // 다음 달
          cells.add(_buildDayCell(
            context,
            day: nextMonthDay++,
            isDim: true,
            isToday: false,
            isSelected: false,
            dots: [],
            onTap: null,
          ));
        }
      }
      rows.add(Row(children: cells));
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _buildDayCell(
    BuildContext context, {
    required int day,
    required bool isDim,
    required bool isToday,
    required bool isSelected,
    required List<Color> dots,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 2),
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
                  fontSize: 9,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                  color: isDim
                      ? context.appTextHint.withValues(alpha: 0.3)
                      : isSelected
                          ? context.appAccent
                          : context.appTextSecondary,
                ),
              ),
              if (dots.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: dots
                      .map((c) => Container(
                            width: 3,
                            height: 3,
                            margin: const EdgeInsets.only(left: 0.5, right: 0.5),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                            ),
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 선택 날짜 이벤트 목록
  Widget _buildSelectedDateEvents(BuildContext context, CalendarState state) {
    final events = state.selectedDateEvents;

    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Text(
            '이 날짜에 예정된 일정이 없습니다',
            style: TextStyle(fontSize: 9, color: context.appTextHint),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: events.map((event) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              // 컬러 도트
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: event.category.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              // 이벤트명
              Expanded(
                child: Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 10,
                    color: context.appTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 시간 (우측)
              if (event.hour != null && event.hour!.isNotEmpty)
                Text(
                  event.isEarnings
                      ? (_earningsHourText(event.hour) ?? event.hour!)
                      : event.hour!,
                  style: TextStyle(
                    fontSize: 9,
                    color: context.appTextSecondary,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 범례 (FOMC, 물가, 고용, 실적, GDP)
  Widget _buildLegend(BuildContext context) {
    const categories = [
      EventCategory.fomc,
      EventCategory.inflation,
      EventCategory.employment,
      EventCategory.earnings,
      EventCategory.gdp,
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 2,
      children: categories.map((cat) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: cat.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              cat.labelKo,
              style: TextStyle(
                fontSize: 7,
                color: context.appTextSecondary,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
