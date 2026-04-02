import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../core/constants/web_constants.dart';

/// 네이티브 HTML <div>로 텍스트를 렌더링하는 위젯.
///
/// Flutter Web CanvasKit은 canvas 위 픽셀로 텍스트를 그려서
/// 모바일 브라우저의 long-press → 복사 메뉴가 동작하지 않음.
/// HtmlElementView를 사용하면 브라우저가 DOM 텍스트를 인식하여
/// 네이티브 텍스트 선택+복사가 100% 동작.
class HtmlTextBlock extends StatefulWidget {
  final String text;
  final Color textColor;
  final Color linkColor;
  final double fontSize;
  final double lineHeight;
  final String viewId;

  const HtmlTextBlock({
    super.key,
    required this.text,
    required this.textColor,
    required this.linkColor,
    required this.fontSize,
    required this.lineHeight,
    required this.viewId,
  });

  @override
  State<HtmlTextBlock> createState() => _HtmlTextBlockState();

  /// 사전 처리된 HTML로 렌더링 높이를 측정.
  static Future<double> measureHeight({
    required String processedHtml,
    required double fontSize,
    required double lineHeight,
    required double maxWidth,
  }) async {
    await web.document.fonts.ready.toDart;

    final div = web.document.createElement('div') as web.HTMLDivElement;
    div.style.cssText =
        'position:absolute;visibility:hidden;pointer-events:none;'
        'font-family:$kWebFontFamily;'
        'font-size:${fontSize}px;'
        'line-height:$lineHeight;'
        'width:${maxWidth}px;'
        'word-break:keep-all;'
        'overflow-wrap:break-word;';
    div.innerHTML = processedHtml.toJS;
    web.document.body!.appendChild(div);

    await Future<void>.delayed(Duration.zero);
    final height = div.offsetHeight.toDouble();
    web.document.body!.removeChild(div);

    return height > 0 ? height : fontSize * lineHeight;
  }

  static final _urlPattern = RegExp(
    r'https?://[^\s<>\[\](){}「」『』【】\u3000]+',
    caseSensitive: false,
  );

  /// 텍스트를 HTML로 변환 (XSS 이스케이프 + URL → <a> 태그)
  static String processText(String text, Color linkColor) {
    var html = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');

    html = html.replaceAllMapped(_urlPattern, (match) {
      final url = match.group(0)!;
      final cssColor = _colorToCss(linkColor);
      return '<a href="$url" target="_blank" rel="noopener noreferrer" '
          'style="color:$cssColor;text-decoration:underline;'
          'text-underline-offset:2px;overflow-wrap:anywhere;">'
          '$url</a>';
    });

    // 연속 줄바꿈 → min-height 블록 (모바일에서 빈 줄 터치 영역 확보)
    html = html.replaceAll(
        '\n\n', '</p><p style="min-height:1.2em;margin:0;padding:0;">');
    html = html.replaceAll('\n', '<br>');
    return '<p style="margin:0;padding:0;">$html</p>';
  }

  static String _colorToCss(Color c) {
    final r = (c.r * 255).round();
    final g = (c.g * 255).round();
    final b = (c.b * 255).round();
    final a = c.a;
    return 'rgba($r,$g,$b,$a)';
  }
}

class _HtmlTextBlockState extends State<HtmlTextBlock> {
  /// platformViewRegistry는 deregister를 지원하지 않아 세션 동안 누적됨
  static final _registered = <String>{};

  double _measuredHeight = 0;
  bool _ready = false;
  bool _measuring = false;
  String _cachedHtml = '';

  String get _viewType =>
      'memo-text-${widget.viewId}-'
      '${widget.textColor.value.toRadixString(16)}-'
      '${widget.text.hashCode}';

  @override
  void initState() {
    super.initState();
    _cachedHtml =
        HtmlTextBlock.processText(widget.text, widget.linkColor);
    _register();
    _measure();
  }

  @override
  void didUpdateWidget(HtmlTextBlock old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text ||
        old.textColor != widget.textColor ||
        old.linkColor != widget.linkColor ||
        old.fontSize != widget.fontSize) {
      _cachedHtml =
          HtmlTextBlock.processText(widget.text, widget.linkColor);
      _register();
      _measure();
      setState(() => _ready = false);
    }
  }

  void _register() {
    final viewType = _viewType;
    if (_registered.contains(viewType)) return;
    _registered.add(viewType);

    ui_web.platformViewRegistry.registerViewFactory(viewType, (int id) {
      return _createElement();
    });
  }

  web.HTMLDivElement _createElement() {
    final div = web.document.createElement('div') as web.HTMLDivElement;
    div.style.cssText = _buildCss();
    div.innerHTML = _cachedHtml.toJS;
    return div;
  }

  String _buildCss() {
    final textCss = HtmlTextBlock._colorToCss(widget.textColor);
    return 'margin:0;padding:0;'
        'font-family:$kWebFontFamily;'
        'font-size:${widget.fontSize}px;'
        'line-height:${widget.lineHeight};'
        'color:$textCss;'
        'word-break:keep-all;'
        'overflow-wrap:break-word;'
        '-webkit-user-select:text;'
        'user-select:text;'
        'cursor:text;'
        'touch-action:pan-y;'
        'overflow:visible;'
        'width:100%;'
        'box-sizing:border-box;';
  }

  Future<void> _measure() async {
    if (!mounted || _measuring) return;
    _measuring = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _measuring = false;
        return;
      }

      final screenWidth = MediaQuery.sizeOf(context).width;
      final isDesktop = screenWidth >= 768;
      final isWideDesktop = screenWidth >= 1024;
      final maxContentWidth = isWideDesktop ? 800.0 : 600.0;
      final padding = isDesktop ? 48.0 : 32.0;
      final maxWidth =
          (screenWidth < maxContentWidth + padding
              ? screenWidth - padding
              : maxContentWidth) -
          2;

      final height = await HtmlTextBlock.measureHeight(
        processedHtml: _cachedHtml,
        fontSize: widget.fontSize,
        lineHeight: widget.lineHeight,
        maxWidth: maxWidth,
      );
      _measuring = false;
      if (mounted) {
        setState(() {
          _measuredHeight = height;
          _ready = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Text(
        widget.text,
        style: TextStyle(
          fontSize: widget.fontSize,
          color: widget.textColor,
          height: widget.lineHeight,
          fontFamily: 'Pretendard Variable',
        ),
      );
    }

    return SizedBox(
      height: _measuredHeight,
      width: double.infinity,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
