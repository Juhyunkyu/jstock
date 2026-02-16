import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

class HoldingInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? prefix;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  const HoldingInputField({
    super.key,
    required this.label,
    required this.controller,
    this.prefix,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          inputFormatters: inputFormatters ?? (keyboardType == const TextInputType.numberWithOptions(decimal: true)
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
              : keyboardType == TextInputType.number
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null),
          decoration: InputDecoration(
            prefixText: prefix,
            filled: true,
            fillColor: context.appSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
