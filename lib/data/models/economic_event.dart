import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// ═══════════════════════════════════════════════════════════════
// 경제 캘린더 이벤트 카테고리
// ═══════════════════════════════════════════════════════════════

enum EventCategory {
  fomc,
  inflation,
  employment,
  earnings,
  gdp,
  other;

  /// Worker 응답 문자열 → enum 변환
  static EventCategory fromString(String value) {
    switch (value.toLowerCase()) {
      case 'fomc':
        return EventCategory.fomc;
      case 'inflation':
        return EventCategory.inflation;
      case 'employment':
        return EventCategory.employment;
      case 'earnings':
        return EventCategory.earnings;
      case 'gdp':
        return EventCategory.gdp;
      default:
        return EventCategory.other;
    }
  }

  /// 카테고리별 컬러 (app_colors.dart에 정의)
  Color get color {
    switch (this) {
      case EventCategory.fomc:
        return AppColors.calendarFomc;
      case EventCategory.inflation:
        return AppColors.calendarInflation;
      case EventCategory.employment:
        return AppColors.calendarEmployment;
      case EventCategory.earnings:
        return AppColors.calendarEarnings;
      case EventCategory.gdp:
        return AppColors.calendarGdp;
      case EventCategory.other:
        return AppColors.calendarOther;
    }
  }

  /// 카테고리 한국어명
  String get labelKo {
    switch (this) {
      case EventCategory.fomc:
        return 'FOMC';
      case EventCategory.inflation:
        return '물가';
      case EventCategory.employment:
        return '고용';
      case EventCategory.earnings:
        return '실적';
      case EventCategory.gdp:
        return 'GDP';
      case EventCategory.other:
        return '기타';
    }
  }

  /// 카테고리 아이콘
  IconData get icon {
    switch (this) {
      case EventCategory.fomc:
        return Icons.account_balance;
      case EventCategory.inflation:
        return Icons.trending_up;
      case EventCategory.employment:
        return Icons.people;
      case EventCategory.earnings:
        return Icons.bar_chart;
      case EventCategory.gdp:
        return Icons.show_chart;
      case EventCategory.other:
        return Icons.event;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// 영→한 타이틀 매핑 (TradingView 이벤트용, API 호출 없음)
// ═══════════════════════════════════════════════════════════════

const _titleKoMap = <String, String>{
  // 고용
  'ADP Employment Change Weekly': 'ADP 주간 고용변동',
  'ADP Nonfarm Employment Change': 'ADP 비농업 고용변동',
  'Initial Jobless Claims': '신규 실업수당 청구건수',
  'Continuing Jobless Claims': '계속 실업수당 청구건수',
  'Nonfarm Payrolls': '비농업 고용자수',
  'Unemployment Rate': '실업률',
  'JOLTs Job Openings': 'JOLTs 구인건수',

  // GDP / 경기
  'Durable Goods Orders MoM': '내구재주문 전월비',
  'Durable Goods Orders Ex Transp MoM': '내구재주문(운송제외) 전월비',
  'Durable Goods Orders ex Defense MoM': '내구재주문(국방제외) 전월비',
  'Non Defense Goods Orders Ex Air': '비국방자본재주문(항공제외)',
  'Consumer Credit Change': '소비자신용 변동',
  'Consumer Inflation Expectations': '소비자 인플레이션 기대',
  'RCM/TIPP Economic Optimism Index': 'RCM/TIPP 경기낙관지수',
  'Retail Sales MoM': '소매판매 전월비',
  'Retail Sales Ex Autos MoM': '소매판매(자동차제외) 전월비',
  'Industrial Production MoM': '산업생산 전월비',
  'ISM Manufacturing PMI': 'ISM 제조업 PMI',
  'ISM Services PMI': 'ISM 서비스업 PMI',
  'Michigan Consumer Sentiment': '미시간 소비자심리지수',

  // 물가
  'CPI MoM': 'CPI 전월비',
  'CPI YoY': 'CPI 전년비',
  'Core CPI MoM': '근원 CPI 전월비',
  'Core CPI YoY': '근원 CPI 전년비',
  'Core PCE Price Index MoM': '근원 PCE 물가지수 전월비',
  'Core PCE Price Index YoY': '근원 PCE 물가지수 전년비',
  'PPI MoM': 'PPI 전월비',
  'PPI YoY': 'PPI 전년비',

  // 에너지 / 원자재
  'API Crude Oil Stock Change': 'API 원유재고 변동',
  'EIA Crude Oil Stocks Change': 'EIA 원유재고 변동',
  'EIA Crude Oil Imports Change': 'EIA 원유수입 변동',
  'EIA Cushing Crude Oil Stocks Change': 'EIA 쿠싱 원유재고 변동',
  'EIA Distillate Stocks Change': 'EIA 증류유 재고 변동',
  'EIA Distillate Fuel Production Change': 'EIA 증류유 생산 변동',
  'EIA Gasoline Stocks Change': 'EIA 가솔린 재고 변동',
  'EIA Gasoline Production Change': 'EIA 가솔린 생산 변동',
  'EIA Heating Oil Stocks Change': 'EIA 난방유 재고 변동',
  'EIA Refinery Crude Runs Change': 'EIA 정유소 가동 변동',
  'EIA Natural Gas Stocks Change': 'EIA 천연가스 재고 변동',
  'Crude Oil Inventories': '원유재고',

  // 주택 / 모기지
  'MBA Mortgage Applications': 'MBA 모기지 신청건수',
  'MBA Mortgage Market Index': 'MBA 모기지 시장지수',
  'MBA Mortgage Refinance Index': 'MBA 모기지 리파이낸싱지수',
  'MBA Purchase Index': 'MBA 주택구매지수',
  'MBA 30-Year Mortgage Rate': 'MBA 30년 모기지 금리',
  'Existing Home Sales': '기존주택 판매',
  'Existing Home Sales MoM': '기존주택 판매 전월비',
  'New Home Sales': '신규주택 판매',
  'Building Permits': '건축허가건수',
  'Housing Starts': '주택착공건수',

  // 물류 / 기타
  'LMI Logistics Managers Index': '물류관리자지수(LMI)',
  'Redbook YoY': '레드북 소매판매 전년비',
  'Factory Orders MoM': '공장주문 전월비',
  'Chicago PMI': '시카고 PMI',
  'Dallas Fed Manufacturing Index': '달라스 연준 제조업지수',
  'Philadelphia Fed Manufacturing Index': '필라델피아 연준 제조업지수',
  'Richmond Fed Manufacturing Index': '리치먼드 연준 제조업지수',
  'NY Empire State Manufacturing Index': 'NY 엠파이어 제조업지수',
  'S&P Global Manufacturing PMI': 'S&P 글로벌 제조업 PMI',
  'S&P Global Services PMI': 'S&P 글로벌 서비스업 PMI',
  'S&P Global Composite PMI': 'S&P 글로벌 종합 PMI',
  'CB Consumer Confidence': 'CB 소비자신뢰지수',
  'Trade Balance': '무역수지',
  'Current Account': '경상수지',
  'Wholesale Inventories MoM': '도매재고 전월비',
  'Business Inventories MoM': '기업재고 전월비',
  'Personal Income MoM': '개인소득 전월비',
  'Personal Spending MoM': '개인지출 전월비',
  'Import Prices MoM': '수입물가 전월비',
  'Export Prices MoM': '수출물가 전월비',
  'Real Personal Spending MoM': '실질 개인지출 전월비',
  'Real Consumer Spending QoQ Final': '실질 소비지출 전분기비(최종)',
  'Corporate Profits QoQ': '기업이익 전분기비',
  'Jobless Claims 4-week Average': '실업수당 4주 이동평균',

  // 금리 / 국채
  '15-Year Mortgage Rate': '15년 모기지 금리',
  '30-Year Mortgage Rate': '30년 모기지 금리',
  '2-Year Note Auction': '2년물 국채 입찰',
  '3-Year Note Auction': '3년물 국채 입찰',
  '5-Year Note Auction': '5년물 국채 입찰',
  '7-Year Note Auction': '7년물 국채 입찰',
  '10-Year Note Auction': '10년물 국채 입찰',
  '20-Year Bond Auction': '20년물 국채 입찰',
  '30-Year Bond Auction': '30년물 국채 입찰',
  '4-Week Bill Auction': '4주물 국채 입찰',
  '8-Week Bill Auction': '8주물 국채 입찰',
  '13-Week Bill Auction': '13주물 국채 입찰',
  '17-Week Bill Auction': '17주물 국채 입찰',
  '26-Week Bill Auction': '26주물 국채 입찰',
  '52-Week Bill Auction': '52주물 국채 입찰',
  'NY Fed Bill Purchases 1 to 4 months': 'NY연준 단기국채 매입(1~4개월)',

  // FOMC / 연준
  'FOMC Meeting Minutes': 'FOMC 의사록',
  'FOMC Minutes': 'FOMC 의사록',
  'FOMC Rate Decision': 'FOMC 금리결정',
  'Fed Interest Rate Decision': '연준 금리결정',
  'Fed Press Conference': '연준 기자회견',
  'Fed Balance Sheet': '연준 대차대조표',
  'Fed Waller Speech': '연준 월러 연설',
  'Fed Daly Speech': '연준 데일리 연설',
  'Fed Williams Speech': '연준 윌리엄스 연설',
  'Fed Barkin Speech': '연준 바킨 연설',
  'Fed Bostic Speech': '연준 보스틱 연설',
  'Fed Bowman Speech': '연준 보우먼 연설',
  'Fed Collins Speech': '연준 콜린스 연설',
  'Fed Cook Speech': '연준 쿡 연설',
  'Fed Goolsbee Speech': '연준 굴스비 연설',
  'Fed Harker Speech': '연준 하커 연설',
  'Fed Jefferson Speech': '연준 제퍼슨 연설',
  'Fed Kashkari Speech': '연준 카시카리 연설',
  'Fed Kugler Speech': '연준 쿠글러 연설',
  'Fed Logan Speech': '연준 로건 연설',
  'Fed Musalem Speech': '연준 무살렘 연설',
  'Fed Powell Speech': '연준 파월 연설',
  'Fed Schmid Speech': '연준 슈미드 연설',
};

// ═══════════════════════════════════════════════════════════════
// 경제 캘린더 이벤트 모델
// ═══════════════════════════════════════════════════════════════

/// 경제 캘린더 이벤트 (경제지표 + 실적)
class EconomicEvent {
  final String id;
  final String title;
  final String titleEn;
  final DateTime date;
  final EventCategory category;
  final double? forecast;
  final double? previous;
  final double? actual;
  final String? unit;
  final int importance;
  final String? ticker;
  final String? hour;
  final double? revenueEstimate;

  const EconomicEvent({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.date,
    required this.category,
    this.forecast,
    this.previous,
    this.actual,
    this.unit,
    this.importance = 2,
    this.ticker,
    this.hour,
    this.revenueEstimate,
  });

  /// JSON 역직렬화
  factory EconomicEvent.fromJson(Map<String, dynamic> json) {
    return EconomicEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      titleEn: json['titleEn'] as String? ?? json['title'] as String,
      date: DateTime.parse(json['date'] as String),
      category: EventCategory.fromString(json['category'] as String),
      forecast: (json['forecast'] as num?)?.toDouble(),
      previous: (json['previous'] as num?)?.toDouble(),
      actual: (json['actual'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      importance: json['importance'] as int? ?? 2,
      ticker: json['ticker'] as String?,
      hour: json['hour'] as String?,
      revenueEstimate: (json['revenueEstimate'] as num?)?.toDouble(),
    );
  }

  /// JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'titleEn': titleEn,
      'date': date.toIso8601String(),
      'category': category.name,
      'forecast': forecast,
      'previous': previous,
      'actual': actual,
      'unit': unit,
      'importance': importance,
      'ticker': ticker,
      'hour': hour,
      'revenueEstimate': revenueEstimate,
    };
  }

  /// D-day 텍스트
  String get ddayText {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final eventDate = DateTime(date.year, date.month, date.day);
    final diff = eventDate.difference(todayDate).inDays;
    if (diff == 0) return 'D-DAY';
    if (diff > 0) return 'D-$diff';
    return 'D+${diff.abs()}';
  }

  /// 한국어 표시용 타이틀 (매핑 있으면 한국어, 없으면 원본)
  String get displayTitle => _titleKoMap[titleEn] ?? _titleKoMap[title] ?? title;

  /// 실적 이벤트 여부
  bool get isEarnings => category == EventCategory.earnings;

  /// 서프라이즈 여부 (actual 발표 후)
  String? get surprise {
    if (actual == null || forecast == null) return null;
    if (actual! > forecast!) return 'beat';
    if (actual! < forecast!) return 'miss';
    return 'inline';
  }
}
