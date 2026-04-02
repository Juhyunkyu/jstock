import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  /// URL 패턴: http/https 링크 자동 감지
  static final _urlPattern = RegExp(
    r'https?://[^\s<>\[\](){}「」『』【】\u3000]+',
    caseSensitive: false,
  );

  Widget _buildText(BuildContext context, String text) {
    final style = textStyle ??
        TextStyle(
          fontSize: 15,
          color: context.appTextPrimary,
          height: 1.6,
        );

    final matches = _urlPattern.allMatches(text).toList();
    if (matches.isEmpty) {
      // SelectableText: 모바일 웹에서 롱프레스 → 선택 → 복사 툴바 정상 표시
      return SelectableText(text, style: style);
    }

    // URL이 포함된 텍스트 → SelectableText.rich로 분리
    // (SelectionArea + Text.rich 조합은 모바일 웹에서 컨텍스트 메뉴 미표시 이슈)
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // URL 앞 일반 텍스트
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: style,
        ));
      }

      // URL 링크 (파란색 + 밑줄 + 탭 가능)
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: style.copyWith(
          color: context.appAccent,
          decoration: TextDecoration.underline,
          decorationColor: context.appAccent,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _launchUrl(url),
      ));

      lastEnd = match.end;
    }

    // URL 뒤 남은 텍스트
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: style,
      ));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      // 모바일 웹에서 롱프레스 시 복사/붙여넣기 툴바 표시
      contextMenuBuilder: (context, editableTextState) {
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editableTextState.contextMenuAnchors,
          buttonItems: editableTextState.contextMenuButtonItems,
        );
      },
    );
  }

  static Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

    // 반응형 이미지 최대높이: 모바일 300, 태블릿/데스크톱 450
    final effectiveMaxHeight = isMobile ? maxImageHeight : 450.0;

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
