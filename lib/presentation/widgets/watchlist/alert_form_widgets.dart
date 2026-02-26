import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

/// 알림 탭 토글 버튼 (변동률 / 목표가)
class AlertTabToggle extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool hasAlert;
  final VoidCallback onTap;

  const AlertTabToggle({
    super.key,
    required this.label,
    required this.isSelected,
    required this.hasAlert,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : context.appIconBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasAlert) ...[
              Icon(
                Icons.check_circle,
                size: 14,
                color: isSelected ? Colors.white : AppColors.amber600,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : context.appTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 방향 선택기 컨테이너 (변동률/목표가 공통)
class AlertDirectionSelector extends StatelessWidget {
  final List<Widget> children;

  const AlertDirectionSelector({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appIconBg,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(children: children),
    );
  }
}

/// 방향 선택 칩 (변동률 방향 + 목표가 방향 통합)
class AlertDirectionChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const AlertDirectionChip({
    super.key,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? Colors.white : context.appTextHint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 폼 섹션 라벨
class AlertFormLabel extends StatelessWidget {
  final String text;

  const AlertFormLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.appTextSecondary,
      ),
    );
  }
}

/// 숫자 입력 텍스트 필드 (소수점 2자리 제한)
class AlertFormTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback? onChanged;

  const AlertFormTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        TextInputFormatter.withFunction((oldValue, newValue) {
          if (newValue.text.isEmpty) return newValue;
          if (RegExp(r'^\d*\.?\d{0,2}$').hasMatch(newValue.text)) {
            return newValue;
          }
          return oldValue;
        }),
      ],
      onChanged: (_) => onChanged?.call(),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: context.appIconBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

/// 미리보기 텍스트 (알림 조건 요약)
class AlertPreviewText extends StatelessWidget {
  final String text;

  const AlertPreviewText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontStyle: FontStyle.italic,
        color: context.appTextHint,
      ),
    );
  }
}
