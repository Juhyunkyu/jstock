import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/krw_formatter.dart';
import '../../../../data/models/cycle.dart';

/// 시드 수정 다이얼로그
///
/// 투자금 이상의 새 시드 금액을 입력받아 반환.
/// null 반환 시 취소 처리.
class CycleSeedEditDialog {
  CycleSeedEditDialog._();

  /// 다이얼로그를 표시하고 새 시드 금액을 반환 (취소 시 null)
  static Future<double?> show(BuildContext context, Cycle cycle) {
    final investedAmount = cycle.seedAmount - cycle.remainingCash;
    final controller = TextEditingController(
      text: cycle.seedAmount.round().toString(),
    );

    return showDialog<double>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.appCardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                '시드 수정',
                style: TextStyle(color: context.appTextPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '현재 투자금: ${formatKrwWithComma(investedAmount)}원',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '새 시드는 투자금 이상이어야 합니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: TextStyle(color: context.appTextPrimary),
                    decoration: InputDecoration(
                      labelText: '시드 금액 (원)',
                      labelStyle: TextStyle(color: context.appTextSecondary),
                      errorText: errorText,
                      suffixText: '원',
                      suffixStyle: TextStyle(color: context.appTextSecondary),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.appBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.appAccent),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.red500),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.red500),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    '취소',
                    style: TextStyle(color: context.appTextSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.appAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    final value = double.tryParse(controller.text);
                    if (value == null || value <= 0) {
                      setDialogState(() {
                        errorText = '유효한 금액을 입력하세요';
                      });
                      return;
                    }
                    if (value < investedAmount) {
                      setDialogState(() {
                        errorText =
                            '투자금(${formatKrwWithComma(investedAmount)}원) 이상이어야 합니다';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(value);
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
