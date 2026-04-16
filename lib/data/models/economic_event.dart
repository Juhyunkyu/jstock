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
  holiday,
  other;

  /// Worker 응답 문자열 → enum 변환
  static EventCategory fromString(String value) =>
      EventCategory.values.firstWhere(
        (e) => e.name == value.toLowerCase(),
        orElse: () => EventCategory.other,
      );

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
      case EventCategory.holiday:
        return AppColors.calendarHoliday;
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
      case EventCategory.holiday:
        return '휴장';
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
      case EventCategory.holiday:
        return Icons.event_busy;
      case EventCategory.other:
        return Icons.event;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// 경제 캘린더 이벤트 모델
// ═══════════════════════════════════════════════════════════════

/// 경제 캘린더 이벤트 (경제지표 + 실적)
///
/// 인플레이션 지표(CPI/PPI/PCE)는 YoY(기본)와 MoM(보조) 두 단위를 모두 가짐:
///   - forecast/actual/previous = YoY (전년동월대비, 뉴스 보도 기준)
///   - forecastMom/actualMom/previousMom = MoM (전월대비)
/// 기타 지표는 forecast/actual/previous만 사용 (단일 단위).
class EconomicEvent {
  final String id;
  final String title;
  final String titleEn;
  final DateTime date;
  final EventCategory category;
  final double? forecast;
  final double? previous;
  final double? actual;
  final double? forecastMom;
  final double? previousMom;
  final double? actualMom;
  final String? unit;
  final int importance;
  final String? ticker;
  final String? hour;
  final double? revenueEstimate;
  final double? revenueActual;
  final String? description;

  const EconomicEvent({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.date,
    required this.category,
    this.forecast,
    this.previous,
    this.actual,
    this.forecastMom,
    this.previousMom,
    this.actualMom,
    this.unit,
    this.importance = 2,
    this.ticker,
    this.hour,
    this.revenueEstimate,
    this.revenueActual,
    this.description,
  });

  /// MoM 데이터가 하나라도 있는지 (dual-unit 이벤트 판정용)
  bool get hasMomData =>
      forecastMom != null || actualMom != null || previousMom != null;

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
      forecastMom: (json['forecastMom'] as num?)?.toDouble(),
      previousMom: (json['previousMom'] as num?)?.toDouble(),
      actualMom: (json['actualMom'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      importance: json['importance'] as int? ?? 2,
      ticker: json['ticker'] as String?,
      hour: json['hour'] as String?,
      revenueEstimate: (json['revenueEstimate'] as num?)?.toDouble(),
      revenueActual: (json['revenueActual'] as num?)?.toDouble(),
      description: json['description'] as String?,
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
      if (forecastMom != null) 'forecastMom': forecastMom,
      if (previousMom != null) 'previousMom': previousMom,
      if (actualMom != null) 'actualMom': actualMom,
      'unit': unit,
      'importance': importance,
      'ticker': ticker,
      'hour': hour,
      'revenueEstimate': revenueEstimate,
      'revenueActual': revenueActual,
      if (description != null) 'description': description,
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

  /// 한국어 표시용 타이틀 (FRED 서버에서 한국어 title 설정)
  String get displayTitle => title;

  /// 실적 이벤트 여부
  bool get isEarnings => category == EventCategory.earnings;

  /// 네 마녀의 날 여부
  bool get isWitching => id.startsWith('witching-');

  /// 서프라이즈 여부 (actual 발표 후)
  String? get surprise {
    if (actual == null || forecast == null) return null;
    if (actual! > forecast!) return 'beat';
    if (actual! < forecast!) return 'miss';
    return 'inline';
  }
}
