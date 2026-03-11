import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

/// 평균 매입환율 수정 다이얼로그 (공용)
///
/// 저장 시 새 환율(double)을 반환, 취소 시 null 반환.
Future<double?> showExchangeRateEditDialog(
  BuildContext context, {
  required double currentRate,
}) {
  final controller = TextEditingController(
    text: currentRate.toStringAsFixed(2),
  );

  return showDialog<double>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: context.appCardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        '평균 매입환율 수정',
        style: TextStyle(color: context.appTextPrimary),
      ),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        style: TextStyle(color: context.appTextPrimary),
        autofocus: true,
        decoration: InputDecoration(
          prefixText: '₩',
          prefixStyle: TextStyle(color: context.appTextPrimary),
          suffixText: '/ \$1',
          suffixStyle: TextStyle(color: context.appTextSecondary),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.appBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.appAccent),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(
            '취소',
            style: TextStyle(color: context.appTextSecondary),
          ),
        ),
        TextButton(
          onPressed: () {
            final newRate = double.tryParse(controller.text);
            if (newRate != null && newRate > 0) {
              Navigator.pop(dialogContext, newRate);
            }
          },
          child: Text('저장', style: TextStyle(color: context.appAccent)),
        ),
      ],
    ),
  );
}
