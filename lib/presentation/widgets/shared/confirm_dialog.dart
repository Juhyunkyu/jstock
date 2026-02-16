import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 확인 다이얼로그 위젯
///
/// 사용자에게 위험한 작업을 확인받을 때 사용합니다.
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String cancelText;
  final String confirmText;
  final Color? confirmColor;
  final VoidCallback? onConfirm;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.cancelText = '취소',
    this.confirmText = '확인',
    this.confirmColor,
    this.onConfirm,
  });

  /// 확인 다이얼로그를 표시하고 결과를 반환합니다.
  ///
  /// [context] 빌드 컨텍스트
  /// [title] 다이얼로그 제목
  /// [message] 다이얼로그 메시지
  /// [cancelText] 취소 버튼 텍스트 (기본값: '취소')
  /// [confirmText] 확인 버튼 텍스트 (기본값: '확인')
  /// [confirmColor] 확인 버튼 색상 (기본값: AppColors.red500)
  /// [isDanger] 위험한 작업 여부 (true인 경우 확인 버튼이 빨간색)
  ///
  /// 사용자가 확인을 누르면 true, 취소를 누르면 false를 반환합니다.
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String cancelText = '취소',
    String confirmText = '확인',
    bool isDanger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (buildContext) => AlertDialog(
        backgroundColor: buildContext.appCardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: buildContext.appTextPrimary,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: buildContext.appTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(buildContext).pop(false),
            child: Text(
              cancelText,
              style: TextStyle(
                color: buildContext.appTextSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(buildContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: isDanger ? AppColors.red500 : AppColors.primary,
            ),
            child: Text(
              confirmText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDanger ? AppColors.red500 : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.appCardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: context.appTextPrimary,
        ),
      ),
      content: Text(
        message,
        style: TextStyle(
          fontSize: 14,
          color: context.appTextSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            cancelText,
            style: TextStyle(
              color: context.appTextSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(true);
            onConfirm?.call();
          },
          child: Text(
            confirmText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: confirmColor ?? AppColors.red500,
            ),
          ),
        ),
      ],
    );
  }
}
