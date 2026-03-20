import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 메모 화면 (빈 화면 — 추후 구현)
class MemoScreen extends StatelessWidget {
  const MemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appSurface,
        elevation: 0,
        toolbarHeight: 64,
        title: const Text('메모'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note_rounded, size: 64, color: context.appTextHint),
            const SizedBox(height: 16),
            Text(
              '주식 공부 메모',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '곧 추가됩니다',
              style: TextStyle(fontSize: 14, color: context.appTextHint),
            ),
          ],
        ),
      ),
    );
  }
}
