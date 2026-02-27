import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'drawing_toolbar.dart';

/// 드로잉 모드 안내 바
///
/// 드로잉 모드 중 차트 상단에 반투명 바로 안내 텍스트를 표시합니다.
class DrawingGuideBar extends StatelessWidget {
  final DrawingMode drawingMode;
  final bool waitingSecondPoint;
  final VoidCallback onCancel;

  const DrawingGuideBar({
    super.key,
    required this.drawingMode,
    required this.waitingSecondPoint,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (drawingMode == DrawingMode.none) return const SizedBox.shrink();

    final message = _getMessage();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.appAccent.withAlpha(200),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            child: const Icon(Icons.close, size: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }

  String _getMessage() {
    switch (drawingMode) {
      case DrawingMode.horizontalLine:
        return '차트를 탭하거나 드래그하여 수평선을 배치하세요';
      case DrawingMode.trendLine:
        if (waitingSecondPoint) {
          return '추세선의 끝점을 탭하세요';
        }
        return '추세선의 시작점을 탭하세요';
      case DrawingMode.none:
        return '';
    }
  }
}
