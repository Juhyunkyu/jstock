import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/economic_event.dart';
import '../../providers/calendar_providers.dart';

// ═══════════════════════════════════════════════════════════════
// 경제 캘린더 카드 — 목록(Timeline) / 달력(Mini Calendar) 토글
// v4.0: 월 구분선 제거, 오늘 자동스크롤, 이벤트 설명 바텀시트
// ═══════════════════════════════════════════════════════════════

// ─── 이벤트 설명 데이터 (초보자용) ───

const _eventDescriptions = <String, ({String desc, String higher, String lower})>{
  'CPI 소비자물가지수': (
    desc: '소비자가 구매하는 상품과 서비스의 가격 변동을 측정하는 물가 지표. 연준의 금리 결정에 핵심적인 역할.',
    higher: '물가 상승 → 금리 인상 압력 → 주식시장 부정적',
    lower: '물가 안정 → 금리 인하 기대 → 주식시장 긍정적',
  ),
  'PPI 생산자물가지수': (
    desc: '생산자가 받는 가격의 변동을 측정. CPI의 선행지표로, 향후 소비자물가를 예측하는 데 활용.',
    higher: '생산비용 상승 → 소비자물가 상승 예고 → 긴축 우려',
    lower: '생산비용 안정 → 인플레이션 완화 신호',
  ),
  'GDP 성장률': (
    desc: '국내총생산의 분기별 성장률. 경제 전체의 건강 상태를 보여주는 가장 포괄적인 지표.',
    higher: '경제 성장 → 기업 실적 개선 기대 → 주식시장 긍정적',
    lower: '경제 둔화 → 경기침체 우려 → 방어적 포지션 고려',
  ),
  '고용보고서': (
    desc: '비농업 고용자수(NFP)와 실업률을 포함. 노동시장 건강도를 보여주는 핵심 지표.',
    higher: '고용 증가 → 경제 활력 but 임금 인플레 압력 → 금리 인상 가능',
    lower: '고용 둔화 → 경기 둔화 신호 but 금리 인하 기대 → 혼합 신호',
  ),
  '소매판매': (
    desc: '소비자 지출의 규모를 측정. 미국 GDP의 약 70%가 소비로 구성되어 경기 판단의 핵심.',
    higher: '소비 활발 → 경제 건강 → 기업 매출 증가 기대',
    lower: '소비 위축 → 경기 둔화 우려 → 방어주 선호',
  ),
  'PCE 개인소비지출': (
    desc: '연준이 가장 선호하는 물가지표. 소비자 지출 패턴 변화를 반영하여 CPI보다 정확.',
    higher: '소비 과열 → 금리 인상 근거 → 시장 경계',
    lower: '소비 둔화 → 금리 인하 근거 → 시장 안도',
  ),
  'ISM 제조업 PMI': (
    desc: '제조업 구매관리자지수. 50 이상이면 확장, 이하면 수축. 경기 선행지표로 시장에 즉각 반영.',
    higher: '제조업 확장 → 경기 활력 → 시장 긍정적',
    lower: '제조업 수축 → 경기 둔화 → 시장 부정적',
  ),
  'ISM 서비스업 PMI': (
    desc: '서비스업 구매관리자지수. 미국 GDP의 약 70%를 차지하는 서비스 부문 건강도.',
    higher: '서비스업 확장 → 경기 활력 → 시장 긍정적',
    lower: '서비스업 수축 → 경기 둔화 → 시장 부정적',
  ),
  '미시간 소비자심리지수': (
    desc: '미시간대학이 발표하는 소비자 심리 조사. 향후 소비 지출 예측에 활용.',
    higher: '소비자 심리 개선 → 소비 증가 기대 → 경기 활력',
    lower: '소비자 심리 악화 → 소비 위축 우려 → 경기 둔화',
  ),
  '내구재 주문': (
    desc: '3년 이상 사용 가능한 제조품(자동차, 가전 등)의 신규 주문량. 기업 투자심리 반영.',
    higher: '기업 투자 확대 → 경기 확장 신호 → 제조업 활황',
    lower: '기업 투자 위축 → 경기 둔화 신호 → 제조업 부진',
  ),
  'FOMC 금리결정': (
    desc: '미국 연방준비제도의 기준금리 결정. 모든 자산 가격에 직접적인 영향을 미치는 최중요 이벤트.',
    higher: '금리 인상 → 대출비용 증가 → 주식/부동산 하락 압력',
    lower: '금리 인하 → 유동성 증가 → 주식/부동산 상승 기대',
  ),
  '네 마녀의 날': (
    desc: '주가지수 선물/옵션, 개별 주식 선물/옵션 4종의 만기가 동시에 겹치는 날. 분기별 셋째 금요일에 발생.',
    higher: '변동성 확대 → 대량 포지션 청산 → 급격한 가격 변동 가능',
    lower: '변동성 확대 → 대량 포지션 청산 → 급격한 가격 변동 가능',
  ),
};

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
  bool _isCalendarView = true;
  late DateTime _displayMonth;
  final ScrollController _timelineScrollController = ScrollController();
  bool _initialScrollDone = false;
  DateTime? _scrollTarget; // 목록 전환 시 스크롤할 날짜

  // 날짜별 그룹화 캐시 (타임라인 뷰 + 스크롤 공유)
  Map<String, List<EconomicEvent>> _cachedGrouped = {};
  List<String> _cachedSortedKeys = [];
  int _cachedEventsHash = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month, 1);
    Future.microtask(() {
      ref.read(calendarProvider.notifier).loadEvents();
    });
  }

  @override
  void dispose() {
    _timelineScrollController.dispose();
    super.dispose();
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
          children: [
            _buildHeader(context, fs),
            SizedBox(height: 8 * fs),
            if (state.isLoading)
              _buildLoading()
            else if (state.error != null)
              _buildError(context, state.error!, fs)
            else if (_isCalendarView)
              Expanded(child: _buildCalendarView(context, state, fs))
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "오늘" 버튼
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _scrollToToday,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 8 * fs, vertical: 6 * fs),
                decoration: BoxDecoration(
                  color: AppColors.calendarFomc.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '오늘',
                  style: TextStyle(
                    fontSize: 10 * fs,
                    fontWeight: FontWeight.w600,
                    color: AppColors.calendarFomc,
                  ),
                ),
              ),
            ),
            SizedBox(width: 6 * fs),
            _buildViewToggle(context, fs),
          ],
        ),
      ],
    );
  }

  void _scrollToToday() {
    if (_isCalendarView) {
      // 달력 뷰: 이번 달로 이동 + 오늘 날짜 선택
      final now = DateTime.now();
      setState(() {
        _displayMonth = DateTime(now.year, now.month, 1);
      });
      ref
          .read(calendarProvider.notifier)
          .selectDate(DateTime(now.year, now.month, now.day));
    } else {
      // 타임라인 뷰: 오늘로 스크롤
      _doScrollToDate();
    }
  }

  void _doScrollToDate([DateTime? target]) {
    final state = ref.read(calendarProvider);
    final events = state.events;
    if (events.isEmpty) return;

    final (:grouped, :sortedKeys) = _groupEventsByDate(events);
    final targetKey = _dateKey(target ?? DateTime.now());

    // 타겟 또는 이후 가장 가까운 날짜의 인덱스 찾기
    int targetIdx = sortedKeys.length - 1;
    for (int i = 0; i < sortedKeys.length; i++) {
      if (sortedKeys[i].compareTo(targetKey) >= 0) {
        targetIdx = i;
        break;
      }
    }

    // fs 기반 높이 계산
    final fs = _fontScale(context);
    final headerH = 20 * fs;
    final eventH = 20 * fs;
    final gapH = 4 * fs;

    double offset = 0;
    for (int i = 0; i < targetIdx; i++) {
      final dateEvents = grouped[sortedKeys[i]]!;
      offset += headerH + (dateEvents.length * eventH) + gapH;
    }

    if (_timelineScrollController.hasClients) {
      final maxScroll = _timelineScrollController.position.maxScrollExtent;
      _timelineScrollController.jumpTo(offset.clamp(0, maxScroll));
    }
  }

  Widget _buildViewToggle(BuildContext context, double fs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _toggleBtn(context, fs: fs, label: '목록', isActive: !_isCalendarView,
            onTap: () {
              // 달력에서 선택한 날짜를 목록 스크롤 타겟으로 저장
              _scrollTarget = ref.read(calendarProvider).selectedDate;
              setState(() {
                _isCalendarView = false;
                _initialScrollDone = false;
              });
            }),
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
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8 * fs, vertical: 6 * fs),
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
  // 목록 뷰 — 날짜 그룹 헤더 + 서프라이즈 표시 (월 구분선 제거)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTimelineView(
      BuildContext context, CalendarState state, double fs) {
    final events = state.events;

    if (events.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text('예정된 일정이 없습니다',
              style: TextStyle(fontSize: 11 * fs, color: context.appTextHint)),
        ),
      );
    }

    final (:grouped, :sortedKeys) = _groupEventsByDate(events);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 첫 빌드 후 타겟 날짜로 자동 스크롤 (달력 선택 날짜 또는 오늘)
    if (!_initialScrollDone) {
      _initialScrollDone = true;
      final target = _scrollTarget;
      _scrollTarget = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _doScrollToDate(target);
      });
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        controller: _timelineScrollController,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: sortedKeys.length,
        itemBuilder: (context, idx) {
          final dateKey = sortedKeys[idx];
          final dateEvents = grouped[dateKey]!;
          final date = dateEvents.first.date;

          final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
          final weekday = weekdays[date.weekday - 1];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDateHeader(
                  context, date, weekday, dateEvents.length,
                  dateEvents.first.ddayText, fs),
              // 해당 날짜 이벤트들
              for (final event in dateEvents)
                _buildEventRow(context, event, fs, today),
              SizedBox(height: 4 * fs),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateHeader(BuildContext context, DateTime date, String weekday,
      int eventCount, String dday, double fs) {

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

  /// 이벤트 행 (3-value 표시, 탭 → 설명 바텀시트)
  Widget _buildEventRow(
      BuildContext context, EconomicEvent event, double fs, DateTime today) {
    // 어닝스 이벤트는 별도 부제 로직
    final earningsSubtitle = event.isEarnings ? _buildEarningsSubtitle(event) : null;

    return GestureDetector(
      onTap: () => _showEventExplanation(context, event, fs),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(left: 8 * fs, top: 2 * fs, bottom: 2 * fs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  if (event.category == EventCategory.holiday)
                    Text(
                      '\u{1F534} 뉴욕증시 휴장',
                      style: TextStyle(
                          fontSize: 9 * fs, color: AppColors.calendarHoliday),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else if (event.isEarnings && earningsSubtitle != null && earningsSubtitle.isNotEmpty)
                    Text(
                      earningsSubtitle,
                      style: TextStyle(
                          fontSize: 9 * fs, color: context.appTextSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else if (!event.isEarnings)
                    _buildThreeValueRow(context, event, fs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 경제지표 3-value 행: 예상 | 전월 | 실제
  Widget _buildThreeValueRow(
      BuildContext context, EconomicEvent event, double fs) {
    final unit = event.unit ?? '';
    final forecastStr = event.forecast != null ? _fmtVal(event.forecast!) + unit : '--';
    final previousStr = event.previous != null ? _fmtVal(event.previous!) + unit : '--';
    final actualStr = event.actual != null ? _fmtVal(event.actual!) + unit : '--';

    // actual 색상: actual vs forecast 비교
    Color actualColor = context.appTextSecondary;
    FontWeight actualWeight = FontWeight.normal;
    if (event.actual != null && event.forecast != null) {
      if (event.actual! > event.forecast!) {
        actualColor = AppColors.red500;
      } else if (event.actual! < event.forecast!) {
        actualColor = AppColors.blue500;
      }
      actualWeight = FontWeight.w600;
    } else if (event.actual != null) {
      actualWeight = FontWeight.w600;
    }

    return Row(
      children: [
        Text(
          '예상 $forecastStr',
          style: TextStyle(fontSize: 9 * fs, color: context.appTextSecondary),
        ),
        Text(
          '  |  ',
          style: TextStyle(fontSize: 9 * fs, color: context.appTextHint),
        ),
        Text(
          '전월 $previousStr',
          style: TextStyle(fontSize: 9 * fs, color: context.appTextSecondary),
        ),
        Text(
          '  |  ',
          style: TextStyle(fontSize: 9 * fs, color: context.appTextHint),
        ),
        Text(
          '실제 $actualStr',
          style: TextStyle(
            fontSize: 9 * fs,
            fontWeight: actualWeight,
            color: actualColor,
          ),
        ),
      ],
    );
  }

  // ─── 이벤트 설명 바텀시트 ───

  void _showEventExplanation(
      BuildContext context, EconomicEvent event, double fs) {
    final title = event.displayTitle;
    final info = _eventDescriptions[title];
    final hasDesc = info != null;
    final unit = event.unit ?? '';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.appCardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20 * fs, 16 * fs, 20 * fs, 24 * fs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.appDivider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 16 * fs),

                Row(
                  children: [
                    Container(
                      width: 10 * fs,
                      height: 10 * fs,
                      decoration: BoxDecoration(
                        color: event.category.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8 * fs),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15 * fs,
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 6 * fs, vertical: 2 * fs),
                      decoration: BoxDecoration(
                        color: event.category.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        event.category.labelKo,
                        style: TextStyle(
                          fontSize: 10 * fs,
                          fontWeight: FontWeight.w600,
                          color: event.category.color,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12 * fs),

                Text(
                  event.category == EventCategory.holiday
                      ? (event.description ?? '뉴욕증시 휴장일')
                      : hasDesc
                          ? info.desc
                          : '이 지표에 대한 설명이 아직 준비되지 않았습니다.',
                  style: TextStyle(
                    fontSize: 12 * fs,
                    height: 1.5,
                    color: context.appTextSecondary,
                  ),
                ),

                if (hasDesc && event.category != EventCategory.holiday) ...[
                  SizedBox(height: 16 * fs),

                  _buildImpactSection(
                    context,
                    fs: fs,
                    icon: Icons.trending_up_rounded,
                    iconColor: AppColors.red500,
                    label: '예상보다 높으면',
                    text: info.higher,
                  ),
                  SizedBox(height: 10 * fs),

                  _buildImpactSection(
                    context,
                    fs: fs,
                    icon: Icons.trending_down_rounded,
                    iconColor: AppColors.blue500,
                    label: '예상보다 낮으면',
                    text: info.lower,
                  ),
                ],

                if (!event.isEarnings && event.category != EventCategory.holiday) ...[
                  SizedBox(height: 16 * fs),
                  Divider(height: 1, color: context.appDivider),
                  SizedBox(height: 12 * fs),
                  Center(
                    child: Text(
                      '발표 수치',
                      style: TextStyle(
                        fontSize: 10 * fs,
                        fontWeight: FontWeight.w600,
                        color: context.appTextHint,
                      ),
                    ),
                  ),
                  SizedBox(height: 8 * fs),
                  _buildDetailThreeValueRow(context, event, fs, unit),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImpactSection(
    BuildContext context, {
    required double fs,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16 * fs, color: iconColor),
        SizedBox(width: 6 * fs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11 * fs,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
              ),
              SizedBox(height: 2 * fs),
              Text(
                text,
                style: TextStyle(
                  fontSize: 11 * fs,
                  height: 1.4,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 디테일 팝업용 3-value 표시: 예상 | 전월 | 실제 (+ 서프라이즈)
  Widget _buildDetailThreeValueRow(
      BuildContext context, EconomicEvent event, double fs, String unit) {
    final forecastStr = event.forecast != null ? _fmtVal(event.forecast!) + unit : '--';
    final previousStr = event.previous != null ? _fmtVal(event.previous!) + unit : '--';
    final actualStr = event.actual != null ? _fmtVal(event.actual!) + unit : '--';

    // actual 색상
    Color actualColor = context.appTextPrimary;
    if (event.actual != null && event.forecast != null) {
      if (event.actual! > event.forecast!) {
        actualColor = AppColors.red500;
      } else if (event.actual! < event.forecast!) {
        actualColor = AppColors.blue500;
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDetailValueColumn(
                context, fs, '예상', forecastStr, context.appTextSecondary,
              ),
            ),
            Container(
              width: 1,
              height: 28 * fs,
              color: context.appDivider,
            ),
            Expanded(
              child: _buildDetailValueColumn(
                context, fs, '전월', previousStr, context.appTextSecondary,
              ),
            ),
            Container(
              width: 1,
              height: 28 * fs,
              color: context.appDivider,
            ),
            Expanded(
              child: _buildDetailValueColumn(
                context, fs, '실제', actualStr, actualColor,
                bold: event.actual != null,
              ),
            ),
          ],
        ),
        // 서프라이즈 행 (actual과 forecast 둘 다 있을 때만)
        if (event.actual != null && event.forecast != null) ...[
          SizedBox(height: 6 * fs),
          Builder(builder: (_) {
            final diff = event.actual! - event.forecast!;
            final sign = diff >= 0 ? '+' : '';
            final isBeat = diff > 0;
            final isMiss = diff < 0;
            final surpriseColor = isBeat
                ? AppColors.red500
                : isMiss
                    ? AppColors.blue500
                    : context.appTextSecondary;
            final surpriseLabel = isBeat ? 'beat' : isMiss ? 'miss' : 'inline';
            return Text(
              '${isBeat ? "▲" : isMiss ? "▼" : "─"} 서프라이즈 $sign${_fmtVal(diff)}$unit ($surpriseLabel)',
              style: TextStyle(
                fontSize: 10 * fs,
                fontWeight: FontWeight.w600,
                color: surpriseColor,
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildDetailValueColumn(
    BuildContext context,
    double fs,
    String label,
    String value,
    Color valueColor, {
    bool bold = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10 * fs,
            color: context.appTextHint,
          ),
        ),
        SizedBox(height: 2 * fs),
        Text(
          value,
          style: TextStyle(
            fontSize: 13 * fs,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ─── 헬퍼 ───

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// 날짜별 그룹화 (타임라인 뷰 + 스크롤 공유, 이벤트 변경 시만 재계산)
  ({Map<String, List<EconomicEvent>> grouped, List<String> sortedKeys})
      _groupEventsByDate(List<EconomicEvent> events) {
    // 길이 + 첫/마지막 이벤트 날짜로 변경 감지
    final hash = events.length ^
        (events.isNotEmpty ? events.first.date.hashCode ^ events.last.date.hashCode : 0);
    if (hash == _cachedEventsHash && _cachedGrouped.isNotEmpty) {
      return (grouped: _cachedGrouped, sortedKeys: _cachedSortedKeys);
    }
    final grouped = <String, List<EconomicEvent>>{};
    for (final e in events) {
      (grouped[_dateKey(e.date)] ??= []).add(e);
    }
    final sortedKeys = grouped.keys.toList()..sort();
    _cachedGrouped = grouped;
    _cachedSortedKeys = sortedKeys;
    _cachedEventsHash = hash;
    return (grouped: grouped, sortedKeys: sortedKeys);
  }

  bool _isPastDate(DateTime date, DateTime today) =>
      DateTime(date.year, date.month, date.day).isBefore(today);

  String _buildEarningsSubtitle(EconomicEvent event) {
    final parts = <String>[];
    if (event.forecast != null) {
      parts.add('EPS \$${event.forecast!.toStringAsFixed(2)}');
    }
    final hourText = _earningsHourText(event.hour);
    if (hourText != null) parts.add(hourText);
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
        _buildMonthNavWithLegend(context, fs,
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
      ],
    );
  }

  Widget _buildMonthNavWithLegend(BuildContext context, double fs,
      {required bool canGoPrev, required bool canGoNext}) {
    return Row(
      children: [
        // 월 네비게이션 (왼쪽)
        _buildMonthNav(context, fs,
            canGoPrev: canGoPrev, canGoNext: canGoNext),
        const Spacer(),
        // 범례 (오른쪽)
        _buildLegend(context, fs),
      ],
    );
  }

  Widget _buildMonthNav(BuildContext context, double fs,
      {required bool canGoPrev, required bool canGoNext}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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

  /// 카테고리별 정렬 우선순위 (낮을수록 먼저)
  static const _categoryPriority = <EventCategory, int>{
    EventCategory.fomc: 0,
    EventCategory.inflation: 1,
    EventCategory.employment: 2,
    EventCategory.gdp: 3,
    EventCategory.holiday: 4,
    EventCategory.earnings: 5,
    EventCategory.other: 6,
  };

  /// 이벤트를 카테고리 우선순위 → importance 내림차순으로 정렬
  List<EconomicEvent> _sortEvents(List<EconomicEvent> events) {
    final sorted = List<EconomicEvent>.from(events);
    sorted.sort((a, b) {
      final catCmp = (_categoryPriority[a.category] ?? 5)
          .compareTo(_categoryPriority[b.category] ?? 5);
      if (catCmp != 0) return catCmp;
      return b.importance.compareTo(a.importance);
    });
    return sorted;
  }

  /// 선택 날짜 이벤트 목록 (달력 뷰) — 상위 2건 + 더보기
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

    final sorted = _sortEvents(events);
    final visible = sorted.take(2).toList();
    final remainCount = sorted.length - visible.length;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...visible.map((event) => _buildEventRow(context, event, fs, today)),
        if (remainCount > 0)
          GestureDetector(
            onTap: () => _showAllEventsSheet(context, sorted, fs, today),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.only(top: 4 * fs),
              child: Center(
                child: Text(
                  '더보기 ($remainCount건)',
                  style: TextStyle(
                    fontSize: 11 * fs,
                    color: context.appAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 전체 이벤트 바텀시트
  void _showAllEventsSheet(BuildContext context,
      List<EconomicEvent> sortedEvents, double fs, DateTime today) {
    final date = sortedEvents.first.date;
    final dateLabel = '${date.month}/${date.day}';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.appCardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding:
                  EdgeInsets.fromLTRB(20 * fs, 16 * fs, 20 * fs, 24 * fs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.appDivider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 12 * fs),
                  Text(
                    '$dateLabel 경제 일정 (${sortedEvents.length}건)',
                    style: TextStyle(
                      fontSize: 14 * fs,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                  SizedBox(height: 8 * fs),
                  ...sortedEvents.map(
                      (event) => _buildEventRow(context, event, fs, today)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegend(BuildContext context, double fs) {
    const categories = [
      EventCategory.fomc,
      EventCategory.inflation,
      EventCategory.employment,
      EventCategory.earnings,
      EventCategory.gdp,
      EventCategory.holiday,
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
