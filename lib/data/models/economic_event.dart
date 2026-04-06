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
