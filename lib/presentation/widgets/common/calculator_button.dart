import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

/// 앱바용 계산기 아이콘 버튼 — 물타기 계산기 진입점
class CalculatorButton extends StatelessWidget {
  const CalculatorButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.calculate_outlined,
        color: context.appTextPrimary,
      ),
      tooltip: '물타기 계산기',
      onPressed: () => context.push('/tools/avg-down'),
    );
  }
}
