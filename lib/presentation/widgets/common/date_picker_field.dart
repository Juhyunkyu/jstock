import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';

/// 재사용 가능한 날짜 선택 필드 위젯
///
/// 캘린더 UI를 통해 날짜를 선택할 수 있으며,
/// 한국어 날짜 포맷(yyyy.MM.dd (요일))으로 표시됩니다.
class DatePickerField extends StatelessWidget {
  /// 필드 라벨 텍스트
  final String label;

  /// 현재 선택된 날짜
  final DateTime selectedDate;

  /// 날짜 변경 시 호출되는 콜백
  final ValueChanged<DateTime> onDateChanged;

  /// 도움말 텍스트 (선택)
  final String? helperText;

  /// 선택 가능한 최소 날짜 (기본: 2000년 1월 1일)
  final DateTime? firstDate;

  /// 선택 가능한 최대 날짜 (기본: 오늘)
  final DateTime? lastDate;

  const DatePickerField({
    super.key,
    required this.label,
    required this.selectedDate,
    required this.onDateChanged,
    this.helperText,
    this.firstDate,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(height: 8),

        // 날짜 선택 필드
        InkWell(
          onTap: () => _showDatePicker(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.appDivider,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // 달력 아이콘
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.appAccent.withValues(alpha: context.isDarkMode ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    size: 20,
                    color: context.appAccent,
                  ),
                ),
                const SizedBox(width: 14),

                // 선택된 날짜 텍스트
                Expanded(
                  child: Text(
                    _formatDate(selectedDate),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: context.appTextPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),

                // 화살표 아이콘
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 24,
                  color: context.appTextHint,
                ),
              ],
            ),
          ),
        ),

        // 도움말 텍스트
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              helperText!,
              style: TextStyle(
                fontSize: 12,
                color: context.appTextHint,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 날짜를 한국어 포맷으로 변환
  /// 예: 2024.01.15 (월)
  String _formatDate(DateTime date) {
    final dateFormat = DateFormat('yyyy.MM.dd');
    final weekdayFormat = DateFormat('E', 'ko_KR');

    try {
      final weekday = weekdayFormat.format(date);
      return '${dateFormat.format(date)} ($weekday)';
    } catch (e) {
      // 한국어 로케일이 없는 경우 대체
      final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
      final weekday = weekdays[date.weekday - 1];
      return '${dateFormat.format(date)} ($weekday)';
    }
  }

  /// 날짜 선택 다이얼로그 표시
  Future<void> _showDatePicker(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: firstDate ?? DateTime(2000, 1, 1),
      lastDate: lastDate ?? today,
      locale: const Locale('ko', 'KR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: context.appTextPrimary,
              surface: context.appSurface,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: context.appSurface,
              headerBackgroundColor: AppColors.primary,
              headerForegroundColor: Colors.white,
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary;
                }
                return null;
              }),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                if (states.contains(WidgetState.disabled)) {
                  return context.appTextHint;
                }
                return context.appTextPrimary;
              }),
              todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary;
                }
                return Colors.transparent;
              }),
              todayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return AppColors.primary;
              }),
              todayBorder: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
              yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary;
                }
                return null;
              }),
              yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return context.appTextPrimary;
              }),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && pickedDate != selectedDate) {
      onDateChanged(pickedDate);
    }
  }
}
