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
  'Crude Oil Inventories': '원유재고',

  // 물류 / 기타
  'LMI Logistics Managers Index': '물류관리자지수(LMI)',
  'Redbook YoY': '레드북 소매판매 전년비',

  // 금리 / 국채
  '3-Year Note Auction': '3년물 국채 입찰',
  '10-Year Note Auction': '10년물 국채 입찰',
  '30-Year Bond Auction': '30년물 국채 입찰',
  '2-Year Note Auction': '2년물 국채 입찰',
  '5-Year Note Auction': '5년물 국채 입찰',
  '7-Year Note Auction': '7년물 국채 입찰',
  'NY Fed Bill Purchases 1 to 4 months': 'NY연준 단기국채 매입(1~4개월)',

  // FOMC
  'FOMC Meeting Minutes': 'FOMC 의사록',
  'FOMC Rate Decision': 'FOMC 금리결정',
  'Fed Interest Rate Decision': '연준 금리결정',
  'Fed Press Conference': '연준 기자회견',
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
