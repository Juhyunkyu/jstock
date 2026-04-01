import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'memo_image_viewer.dart';

/// 메모 본문 인라인 렌더러
///
/// content 문자열의 [IMG:N] 마커를 파싱하여
/// 텍스트와 이미지를 교차 배치하는 Column 위젯.
class MemoContentRenderer extends StatelessWidget {
  final String content;
  final List<String> imageBase64List;

  /// 텍스트 스타일 (null이면 기본값 사용)
  final TextStyle? textStyle;

  /// 이미지 최대 높이
  final double maxImageHeight;

  static final _markerPattern = RegExp(r'\[IMG:(\d+)\]');

  const MemoContentRenderer({
    super.key,
    required this.content,
    required this.imageBase64List,
    this.textStyle,
    this.maxImageHeight = 300,
  });

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) return const SizedBox.shrink();

    final widgets = <Widget>[];
    final matches = _markerPattern.allMatches(content).toList();

    if (matches.isEmpty) {
      // 마커 없으면 텍스트만
      widgets.add(_buildText(context, content));
    } else {
      int lastEnd = 0;
      for (final match in matches) {
        // 마커 앞 텍스트
        if (match.start > lastEnd) {
          final text = content.substring(lastEnd, match.start).trim();
          if (text.isNotEmpty) {
            widgets.add(_buildText(context, text));
            widgets.add(const SizedBox(height: 12));
          }
        }

        // 이미지
        final imgIndex = int.tryParse(match.group(1) ?? '');
        if (imgIndex != null &&
            imgIndex >= 0 &&
            imgIndex < imageBase64List.length) {
          widgets.add(_buildImage(context, imgIndex));
          widgets.add(const SizedBox(height: 12));
        }

        lastEnd = match.end;
      }

      // 마지막 마커 뒤 텍스트
      if (lastEnd < content.length) {
        final text = content.substring(lastEnd).trim();
        if (text.isNotEmpty) {
          widgets.add(_buildText(context, text));
        }
      }
    }

    // 끝에 불필요한 SizedBox 제거
    while (widgets.isNotEmpty && widgets.last is SizedBox) {
      widgets.removeLast();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildText(BuildContext context, String text) {
    final style = textStyle ??
        TextStyle(
          fontSize: 15,
          color: context.appTextPrimary,
          height: 1.6,
        );
    return Text(text, style: style);
  }

  Widget _buildImage(BuildContext context, int index) {
    final base64 = imageBase64List[index];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => MemoImageViewer.show(context, imageBase64List, index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxImageHeight),
            child: Image.memory(
              base64Decode(base64),
              fit: BoxFit.contain,
              width: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                height: 120,
                decoration: BoxDecoration(
                  color: context.appIconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 40,
                    color: context.appTextHint,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
