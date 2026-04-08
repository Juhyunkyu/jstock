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
  'CPI 전월비': (
    desc: '소비자가 구매하는 상품과 서비스의 가격 변동을 측정하는 물가 지표. 연준의 금리 결정에 핵심적인 역할.',
    higher: '물가 상승 → 금리 인상 압력 → 주식시장 부정적',
    lower: '물가 안정 → 금리 인하 기대 → 주식시장 긍정적',
  ),
  'CPI 전년비': (
    desc: '소비자가 구매하는 상품과 서비스의 가격 변동을 측정하는 물가 지표. 연준의 금리 결정에 핵심적인 역할.',
    higher: '물가 상승 → 금리 인상 압력 → 주식시장 부정적',
    lower: '물가 안정 → 금리 인하 기대 → 주식시장 긍정적',
  ),
  '근원 CPI 전월비': (
    desc: '식품과 에너지를 제외한 소비자물가 변동. 기초적인 물가 추세를 더 정확히 반영.',
    higher: '물가 상승 → 금리 인상 압력 → 주식시장 부정적',
    lower: '물가 안정 → 금리 인하 기대 → 주식시장 긍정적',
  ),
  '근원 CPI 전년비': (
    desc: '식품과 에너지를 제외한 소비자물가 변동. 기초적인 물가 추세를 더 정확히 반영.',
    higher: '물가 상승 → 금리 인상 압력 → 주식시장 부정적',
    lower: '물가 안정 → 금리 인하 기대 → 주식시장 긍정적',
  ),
  'PPI 생산자물가지수': (
    desc: '생산자가 받는 가격의 변동을 측정. CPI의 선행지표로, 향후 소비자물가를 예측하는 데 활용.',
    higher: '생산비용 상승 → 소비자물가 상승 예고 → 긴축 우려',
    lower: '생산비용 안정 → 인플레이션 완화 신호',
  ),
  'PPI 전월비': (
    desc: '생산자가 받는 가격의 변동을 측정. CPI의 선행지표로, 향후 소비자물가를 예측하는 데 활용.',
    higher: '생산비용 상승 → 소비자물가 상승 예고 → 긴축 우려',
    lower: '생산비용 안정 → 인플레이션 완화 신호',
  ),
  'PPI 전년비': (
    desc: '생산자가 받는 가격의 변동을 측정. CPI의 선행지표로, 향후 소비자물가를 예측하는 데 활용.',
    higher: '생산비용 상승 → 소비자물가 상승 예고 → 긴축 우려',
    lower: '생산비용 안정 → 인플레이션 완화 신호',
  ),
  'PCE 개인소비지출': (
    desc: '연준이 가장 선호하는 물가지표. 소비자 지출 패턴 변화를 반영하여 CPI보다 정확.',
    higher: '소비 과열 → 금리 인상 근거 → 시장 경계',
    lower: '소비 둔화 → 금리 인하 근거 → 시장 안도',
  ),
  '근원 PCE 물가지수 전월비': (
    desc: '연준이 가장 선호하는 물가지표. 소비자 지출 패턴 변화를 반영하여 CPI보다 정확.',
    higher: '소비 과열 → 금리 인상 근거 → 시장 경계',
    lower: '소비 둔화 → 금리 인하 근거 → 시장 안도',
  ),
  '근원 PCE 물가지수 전년비': (
    desc: '연준이 가장 선호하는 물가지표. 소비자 지출 패턴 변화를 반영하여 CPI보다 정확.',
    higher: '소비 과열 → 금리 인상 근거 → 시장 경계',
    lower: '소비 둔화 → 금리 인하 근거 → 시장 안도',
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
  '비농업 고용자수': (
    desc: '비농업 고용자수(NFP)와 실업률을 포함. 노동시장 건강도를 보여주는 핵심 지표.',
    higher: '고용 증가 → 경제 활력 but 임금 인플레 압력 → 금리 인상 가능',
    lower: '고용 둔화 → 경기 둔화 신호 but 금리 인하 기대 → 혼합 신호',
  ),
  '실업률': (
    desc: '경제 활동 인구 중 실업자 비율. 노동시장 건강도의 핵심 지표.',
    higher: '실업 증가 → 경기 둔화 → 금리 인하 기대',
    lower: '실업 감소 → 경제 활력 → but 임금 인플레 압력',
  ),
  'FOMC 금리 결정': (
    desc: '미국 연방준비제도의 기준금리 결정. 모든 자산 가격에 직접적인 영향을 미치는 최중요 이벤트.',
    higher: '금리 인상 → 대출비용 증가 → 주식/부동산 하락 압력',
    lower: '금리 인하 → 유동성 증가 → 주식/부동산 상승 기대',
  ),
  'FOMC 금리결정': (
    desc: '미국 연방준비제도의 기준금리 결정. 모든 자산 가격에 직접적인 영향을 미치는 최중요 이벤트.',
    higher: '금리 인상 → 대출비용 증가 → 주식/부동산 하락 압력',
    lower: '금리 인하 → 유동성 증가 → 주식/부동산 상승 기대',
  ),
  '연준 금리결정': (
    desc: '미국 연방준비제도의 기준금리 결정. 모든 자산 가격에 직접적인 영향을 미치는 최중요 이벤트.',
    higher: '금리 인상 → 대출비용 증가 → 주식/부동산 하락 압력',
    lower: '금리 인하 → 유동성 증가 → 주식/부동산 상승 기대',
  ),
  'FOMC 의사록': (
    desc: 'FOMC 회의 내용을 상세히 기록한 문서. 연준 위원들의 의견 분포와 향후 정책 방향 힌트.',
    higher: '매파적 톤 → 긴축 지속 우려 → 시장 하락 압력',
    lower: '비둘기파적 톤 → 완화 기대 → 시장 상승 기대',
  ),
  '소매판매': (
    desc: '소비자 지출의 규모를 측정. 미국 GDP의 약 70%가 소비로 구성되어 경기 판단의 핵심.',
    higher: '소비 활발 → 경제 건강 → 기업 매출 증가 기대',
    lower: '소비 위축 → 경기 둔화 우려 → 방어주 선호',
  ),
  '소매판매 전월비': (
    desc: '소비자 지출의 규모를 측정. 미국 GDP의 약 70%가 소비로 구성되어 경기 판단의 핵심.',
    higher: '소비 활발 → 경제 건강 → 기업 매출 증가 기대',
    lower: '소비 위축 → 경기 둔화 우려 → 방어주 선호',
  ),
  'ADP 주간 고용변동': (
    desc: 'ADP사가 발표하는 민간 고용 변동. 공식 고용보고서의 선행지표로 활용.',
    higher: '민간 고용 증가 → NFP 호조 예상 → 경기 활력',
    lower: '민간 고용 감소 → NFP 부진 예상 → 경기 둔화',
  ),
  'ADP 비농업 고용변동': (
    desc: 'ADP사가 발표하는 민간 고용 변동. 공식 고용보고서의 선행지표로 활용.',
    higher: '민간 고용 증가 → NFP 호조 예상 → 경기 활력',
    lower: '민간 고용 감소 → NFP 부진 예상 → 경기 둔화',
  ),
  '내구재주문 전월비': (
    desc: '3년 이상 사용 가능한 제조품(자동차, 가전 등)의 신규 주문량. 기업 투자심리 반영.',
    higher: '기업 투자 확대 → 경기 확장 신호 → 제조업 활황',
    lower: '기업 투자 위축 → 경기 둔화 신호 → 제조업 부진',
  ),
  '내구재주문(운송제외) 전월비': (
    desc: '변동성 큰 운송장비를 제외한 내구재주문. 핵심 사업 투자 트렌드를 더 정확하게 반영.',
    higher: '핵심 투자 증가 → 지속적 경기 확장 신호',
    lower: '핵심 투자 감소 → 구조적 둔화 우려',
  ),
  '물류관리자지수(LMI)': (
    desc: '물류 산업의 건강도를 측정하는 지수. 50 이상이면 확장, 이하면 수축.',
    higher: '물류 활발 → 경제 활동 증가 → 공급망 정상화',
    lower: '물류 둔화 → 경제 활동 위축 → 수요 감소',
  ),
  '비국방자본재주문(항공제외)': (
    desc: '항공과 국방을 제외한 자본재 주문. 기업의 순수 설비투자 의향을 가장 잘 반영.',
    higher: '설비투자 확대 → 장기 성장 기대 → 기업 자신감',
    lower: '설비투자 위축 → 성장 둔화 전망 → 기업 불확실성',
  ),
  '소비자신용 변동': (
    desc: '소비자 대출(신용카드, 자동차 등) 잔액의 월간 변동. 소비 여력과 부채 수준 파악.',
    higher: '대출 증가 → 소비 활발 but 부채 위험 증가',
    lower: '대출 감소 → 소비 위축 or 건전한 가계 관리',
  ),
  'RCM/TIPP 경기낙관지수': (
    desc: '소비자의 경제 전망 심리를 측정하는 지수. 50 이상이면 낙관, 이하면 비관.',
    higher: '소비자 낙관 → 소비 증가 기대 → 경기 상승',
    lower: '소비자 비관 → 소비 감소 우려 → 경기 하강',
  ),
  '소비자 인플레이션 기대': (
    desc: '소비자가 예상하는 향후 인플레이션율. 실제 물가에 자기실현적 영향.',
    higher: '기대 인플레 상승 → 연준 긴축 압력 → 시장 불안',
    lower: '기대 인플레 하락 → 물가 안정 기대 → 시장 안도',
  ),
  'API 원유재고 변동': (
    desc: 'API(미국석유협회) 발표 주간 원유재고 변동. EIA 공식 데이터의 선행지표.',
    higher: '재고 증가 → 수요 둔화 → 유가 하락 압력',
    lower: '재고 감소 → 수요 강세 → 유가 상승 압력',
  ),
  '레드북 소매판매 전년비': (
    desc: '대형 소매업체의 매출 성장률. 소비자 지출 트렌드를 주간 단위로 추적.',
    higher: '소매 매출 성장 → 소비 건강 → 경기 활력',
    lower: '소매 매출 둔화 → 소비 위축 → 경기 우려',
  ),
  '3년물 국채 입찰': (
    desc: '미국 재무부 3년물 국채 입찰. 입찰 수요(응찰배수)가 금리 방향성의 단서.',
    higher: '수익률 상승 → 채권 수요 약세 → 금리 상승 압력',
    lower: '수익률 하락 → 채권 수요 강세 → 금리 하락 압력',
  ),
  '10년물 국채 입찰': (
    desc: '미국 재무부 10년물 국채 입찰. 장기 금리 방향성의 핵심 단서.',
    higher: '수익률 상승 → 채권 수요 약세 → 금리 상승 압력',
    lower: '수익률 하락 → 채권 수요 강세 → 금리 하락 압력',
  ),
  '30년물 국채 입찰': (
    desc: '미국 재무부 30년물 국채 입찰. 초장기 금리 전망을 반영.',
    higher: '수익률 상승 → 채권 수요 약세 → 금리 상승 압력',
    lower: '수익률 하락 → 채권 수요 강세 → 금리 하락 압력',
  ),
  'NY연준 단기국채 매입(1~4개월)': (
    desc: 'NY연준의 단기 국채 매입 규모. 단기 유동성 공급 규모를 나타냄.',
    higher: '매입 확대 → 유동성 증가 → 시장 안정',
    lower: '매입 축소 → 유동성 감소 → 긴축 신호',
  ),
  '신규 실업수당 청구건수': (
    desc: '매주 새로 실업수당을 신청한 건수. 고용시장의 실시간 건강 상태를 반영.',
    higher: '실업 증가 → 경기 둔화 신호 → 금리 인하 기대',
    lower: '실업 감소 → 고용시장 건강 → 경기 활력',
  ),
  '계속 실업수당 청구건수': (
    desc: '실업수당을 계속 받고 있는 총 건수. 장기 실업 추세를 파악.',
    higher: '장기 실업 증가 → 노동시장 약화 → 경기 우려',
    lower: '장기 실업 감소 → 재취업 활발 → 경기 회복',
  ),
  'ISM 제조업 PMI': (
    desc: '제조업 구매관리자지수. 50 이상이면 확장, 이하면 수축을 의미.',
    higher: '제조업 확장 → 경기 활력 → 시장 긍정적',
    lower: '제조업 수축 → 경기 둔화 → 시장 부정적',
  ),
  'ISM 서비스업 PMI': (
    desc: '서비스업 구매관리자지수. 미국 GDP의 약 80%를 차지하는 서비스 부문 건강도.',
    higher: '서비스업 확장 → 경기 활력 → 시장 긍정적',
    lower: '서비스업 수축 → 경기 둔화 → 시장 부정적',
  ),
  '미시간 소비자심리지수': (
    desc: '미시간대학이 발표하는 소비자 심리 조사. 향후 소비 지출 예측에 활용.',
    higher: '소비자 심리 개선 → 소비 증가 기대 → 경기 활력',
    lower: '소비자 심리 악화 → 소비 위축 우려 → 경기 둔화',
  ),
  '산업생산 전월비': (
    desc: '광업, 제조업, 유틸리티의 생산량 변동. 경기순환과 밀접한 관련.',
    higher: '생산 증가 → 경기 확장 → 기업 실적 기대',
    lower: '생산 감소 → 경기 둔화 → 수요 약화',
  ),
  'JOLTs 구인건수': (
    desc: '미국 내 미충원 일자리 수. 노동시장의 수요 측면을 측정.',
    higher: '구인 증가 → 노동 수요 강세 → 임금 인플레 압력',
    lower: '구인 감소 → 노동 수요 약화 → 경기 둔화 신호',
  ),
  '연준 기자회견': (
    desc: 'FOMC 결정 후 연준 의장의 기자회견. 향후 통화정책 방향에 대한 핵심 힌트 제공.',
    higher: '매파적 발언 → 긴축 지속 → 시장 하락 압력',
    lower: '비둘기파적 발언 → 완화 기대 → 시장 상승 기대',
  ),
  // ─── 에너지 (EIA 주간) ───
  'EIA 원유재고 변동': (
    desc: 'EIA(미국에너지정보청) 주간 원유재고 변동. 유가에 직접적인 영향.',
    higher: '재고 증가 → 수요 둔화 → 유가 하락 압력',
    lower: '재고 감소 → 수요 강세 → 유가 상승 압력',
  ),
  'EIA 원유수입 변동': (
    desc: '미국의 주간 원유 수입량 변동. 공급 측면의 유가 영향 요인.',
    higher: '수입 증가 → 공급 확대 → 유가 하락 압력',
    lower: '수입 감소 → 공급 축소 → 유가 상승 압력',
  ),
  'EIA 쿠싱 원유재고 변동': (
    desc: '오클라호마 쿠싱 저장기지 원유재고. WTI 선물 인도 기준점으로 유가에 민감.',
    higher: '재고 증가 → WTI 하락 압력',
    lower: '재고 감소 → WTI 상승 압력',
  ),
  'EIA 가솔린 재고 변동': (
    desc: '주간 가솔린 재고 변동. 드라이빙 시즌 등 소비 패턴과 연계.',
    higher: '재고 증가 → 수요 둔화 → 가솔린 가격 하락',
    lower: '재고 감소 → 수요 강세 → 가솔린 가격 상승',
  ),
  'EIA 가솔린 생산 변동': (
    desc: '주간 가솔린 생산량 변동. 정유소 가동률과 연계.',
    higher: '생산 증가 → 공급 확대 → 가격 안정',
    lower: '생산 감소 → 공급 축소 → 가격 상승 압력',
  ),
  'EIA 증류유 재고 변동': (
    desc: '디젤, 난방유 등 증류유 재고 변동. 산업/운송 수요 반영.',
    higher: '재고 증가 → 수요 둔화',
    lower: '재고 감소 → 수요 강세',
  ),
  'EIA 증류유 생산 변동': (
    desc: '주간 증류유 생산량 변동. 정유소 생산 활동 수준을 반영.',
    higher: '생산 증가 → 공급 확대',
    lower: '생산 감소 → 공급 축소',
  ),
  'EIA 난방유 재고 변동': (
    desc: '주간 난방유 재고 변동. 겨울철 수요와 밀접.',
    higher: '재고 증가 → 가격 안정',
    lower: '재고 감소 → 가격 상승 압력',
  ),
  'EIA 정유소 가동 변동': (
    desc: '정유소의 원유 처리량 변동. 정제 능력과 석유제품 공급량을 반영.',
    higher: '가동 증가 → 석유제품 공급 확대',
    lower: '가동 감소 → 공급 축소 → 제품 가격 상승',
  ),
  // ─── 주택 / 모기지 (MBA 주간) ───
  'MBA 모기지 신청건수': (
    desc: '주간 모기지 신청건수 변동. 주택시장 수요의 선행지표.',
    higher: '신청 증가 → 주택 수요 강세 → 경기 활력',
    lower: '신청 감소 → 주택 수요 약화 → 경기 둔화',
  ),
  'MBA 모기지 시장지수': (
    desc: '모기지 시장 전체 활동을 측정하는 종합지수.',
    higher: '활동 증가 → 주택시장 활성화',
    lower: '활동 감소 → 주택시장 둔화',
  ),
  'MBA 모기지 리파이낸싱지수': (
    desc: '기존 모기지 재융자 활동. 금리 변동에 매우 민감.',
    higher: '재융자 증가 → 금리 하락 반영 → 소비 여력 확대',
    lower: '재융자 감소 → 금리 상승 반영 → 소비 여력 축소',
  ),
  'MBA 주택구매지수': (
    desc: '신규 주택 구매 목적의 모기지 신청. 실수요를 반영.',
    higher: '구매 증가 → 주택 실수요 강세',
    lower: '구매 감소 → 주택 실수요 약화',
  ),
  'MBA 30년 모기지 금리': (
    desc: '30년 고정금리 모기지 평균 금리. 주택시장의 핵심 비용 지표.',
    higher: '금리 상승 → 주택 구매 비용 증가 → 수요 억제',
    lower: '금리 하락 → 주택 구매 비용 감소 → 수요 촉진',
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
              onTap: _scrollToToday,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 6 * fs, vertical: 3 * fs),
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

    // 각 날짜 그룹의 높이를 대략적으로 계산
    // 날짜 헤더 ~26px + 이벤트 행 ~22px * 개수 + 간격 ~4px
    double offset = 0;
    for (int i = 0; i < targetIdx; i++) {
      final dateEvents = grouped[sortedKeys[i]]!;
      offset += 26 + (dateEvents.length * 22) + 4;
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

  /// 이벤트 행 (서프라이즈 표시 포함, 탭 → 설명 바텀시트)
  Widget _buildEventRow(
      BuildContext context, EconomicEvent event, double fs, DateTime today) {
    final isPast = _isPastDate(event.date, today);
    final hasActual = event.actual != null;

    // 부제를 한 번만 생성
    final subtitle = (!isPast || !hasActual) ? _buildSubtitle(event) : '';

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
                  if (isPast && hasActual)
                    _buildActualRow(context, event, fs)
                  else if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
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

  // ─── 이벤트 설명 바텀시트 ───

  void _showEventExplanation(
      BuildContext context, EconomicEvent event, double fs) {
    final title = event.displayTitle;
    final info = _eventDescriptions[title];
    final hasDesc = info != null;
    final unit = event.unit ?? '';

    showModalBottomSheet(
      context: context,
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
                // 드래그 핸들
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

                // 제목 + 카테고리 배지
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

                // 설명
                Text(
                  hasDesc
                      ? info.desc
                      : '이 지표에 대한 설명이 아직 준비되지 않았습니다.',
                  style: TextStyle(
                    fontSize: 12 * fs,
                    height: 1.5,
                    color: context.appTextSecondary,
                  ),
                ),

                if (hasDesc) ...[
                  SizedBox(height: 16 * fs),

                  // 예상보다 높으면
                  _buildImpactSection(
                    context,
                    fs: fs,
                    icon: Icons.trending_up_rounded,
                    iconColor: AppColors.red500,
                    label: '예상보다 높으면',
                    text: info.higher,
                  ),
                  SizedBox(height: 10 * fs),

                  // 예상보다 낮으면
                  _buildImpactSection(
                    context,
                    fs: fs,
                    icon: Icons.trending_down_rounded,
                    iconColor: AppColors.blue500,
                    label: '예상보다 낮으면',
                    text: info.lower,
                  ),
                ],

                // 최근 결과 (actual이 있을 때만)
                if (event.actual != null) ...[
                  SizedBox(height: 16 * fs),
                  Divider(height: 1, color: context.appDivider),
                  SizedBox(height: 12 * fs),
                  Center(
                    child: Text(
                      '최근 결과',
                      style: TextStyle(
                        fontSize: 10 * fs,
                        fontWeight: FontWeight.w600,
                        color: context.appTextHint,
                      ),
                    ),
                  ),
                  SizedBox(height: 8 * fs),
                  _buildActualComparisonRow(context, event, fs, unit),
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

  Widget _buildActualComparisonRow(
      BuildContext context, EconomicEvent event, double fs, String unit) {
    final actual = event.actual!;
    final forecast = event.forecast;

    if (forecast == null) {
      return Center(
        child: Text(
          '실제 ${_fmtVal(actual)}$unit',
          style: TextStyle(
            fontSize: 13 * fs,
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
      );
    }

    final diff = actual - forecast;
    final sign = diff >= 0 ? '+' : '';
    final isBeat = diff > 0;
    final isMiss = diff < 0;
    final surpriseColor = isBeat
        ? AppColors.red500
        : isMiss
            ? AppColors.blue500
            : context.appTextSecondary;
    final surpriseLabel = isBeat
        ? 'beat'
        : isMiss
            ? 'miss'
            : 'inline';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '예상 ${_fmtVal(forecast)}$unit',
              style: TextStyle(
                  fontSize: 12 * fs, color: context.appTextSecondary),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8 * fs),
              child: Icon(Icons.arrow_forward_rounded,
                  size: 14 * fs, color: context.appTextHint),
            ),
            Text(
              '실제 ${_fmtVal(actual)}$unit',
              style: TextStyle(
                fontSize: 12 * fs,
                fontWeight: FontWeight.w700,
                color: surpriseColor,
              ),
            ),
          ],
        ),
        SizedBox(height: 4 * fs),
        Text(
          '${isBeat ? "▲" : isMiss ? "▼" : "─"} 서프라이즈 $sign${_fmtVal(diff)}$unit ($surpriseLabel)',
          style: TextStyle(
            fontSize: 10 * fs,
            fontWeight: FontWeight.w600,
            color: surpriseColor,
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
    final hash = events.length; // 간단한 변경 감지
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
    EventCategory.earnings: 4,
    EventCategory.other: 5,
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
            onTap: () => _showAllEventsSheet(context, sorted, fs),
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
  void _showAllEventsSheet(
      BuildContext context, List<EconomicEvent> sortedEvents, double fs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = sortedEvents.first.date;
    final dateLabel = '${date.month}/${date.day}';

    showModalBottomSheet(
      context: context,
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
