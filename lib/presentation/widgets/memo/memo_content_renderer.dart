import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'html_text_block.dart';
import 'memo_image_viewer.dart';

/// 메모 본문 인라인 렌더러
///
/// content 문자열의 [IMG:N] 마커를 파싱하여
/// 텍스트(HtmlTextBlock)와 이미지를 교차 배치하는 Column 위젯.
///
/// 텍스트 블록은 HtmlElementView 기반 네이티브 HTML로 렌더링되어
/// 모바일 웹에서도 long-press → 부분 선택 → 복사가 100% 동작.
class MemoContentRenderer extends StatelessWidget {
  final String content;
  final List<String> imageBase64List;

  /// 텍스트 스타일 (null이면 기본값 사용)
  final TextStyle? textStyle;

  /// 이미지 최대 높이
  final double maxImageHeight;

  /// 링크 색상 (null이면 context.appAccent)
  final Color? linkColor;

  /// 메모 ID (HtmlTextBlock viewId 고유성을 위해)
  final String? memoId;

  static final _markerPattern = RegExp(r'\[IMG:(\d+)\]');

  const MemoContentRenderer({
    super.key,
    required this.content,
    required this.imageBase64List,
    this.textStyle,
    this.maxImageHeight = 300,
    this.linkColor,
    this.memoId,
  });

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) return const SizedBox.shrink();

    final widgets = <Widget>[];
    final matches = _markerPattern.allMatches(content).toList();
    int textBlockIndex = 0;

    if (matches.isEmpty) {
      // 마커 없으면 텍스트만
      widgets.add(_buildText(context, content, textBlockIndex));
    } else {
      int lastEnd = 0;
      for (final match in matches) {
        // 마커 앞 텍스트
        if (match.start > lastEnd) {
          final text = content.substring(lastEnd, match.start).trim();
          if (text.isNotEmpty) {
            widgets.add(_buildText(context, text, textBlockIndex++));
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
          widgets.add(_buildText(context, text, textBlockIndex));
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

  Widget _buildText(BuildContext context, String text, int blockIndex) {
    final style = textStyle ??
        TextStyle(
          fontSize: 15,
          color: context.appTextPrimary,
          height: 1.6,
        );

    final effectiveLinkColor = linkColor ?? context.appAccent;
    final id = memoId ?? content.hashCode.toString();

    return HtmlTextBlock(
      text: text,
      textColor: style.color ?? context.appTextPrimary,
      linkColor: effectiveLinkColor,
      fontSize: style.fontSize ?? 15,
      lineHeight: style.height ?? 1.6,
      viewId: '$id-$blockIndex',
    );
  }

  Widget _buildImage(BuildContext context, int index) {
    final base64 = imageBase64List[index];
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    // 반응형 이미지 최대폭: 모바일 70%, 태블릿 50%, 데스크톱 고정 500px
    final maxImageWidth = isMobile
        ? screenWidth * 0.7
        : isTablet
            ? screenWidth * 0.5
            : 500.0;

    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => MemoImageViewer.show(context, imageBase64List, index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: maxImageWidth,
            child: Image.memory(
              base64Decode(base64),
              width: maxImageWidth,
              fit: BoxFit.fitWidth,
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
