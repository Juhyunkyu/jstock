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

  /// 텍스트의 렌더링 높이를 사전 측정.
  /// 폰트 로딩 완료 후 임시 div를 body에 부착 → offsetHeight 읽기 → 제거.
  static Future<double> measureHeight({
    required String text,
    required double fontSize,
    required double lineHeight,
    required double maxWidth,
  }) async {
    // 폰트 로딩 완료 대기
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
    div.innerHTML = _processText(text, const Color(0xFF000000)).toJS;
    web.document.body!.appendChild(div);

    // 한 프레임 대기 후 높이 읽기
    await Future<void>.delayed(Duration.zero);
    final height = div.offsetHeight.toDouble();
    web.document.body!.removeChild(div);

    // 최소 높이 보장 (빈 줄 등)
    return height > 0 ? height : fontSize * lineHeight;
  }

  /// URL 패턴: http/https 링크 감지
  static final _urlPattern = RegExp(
    r'https?://[^\s<>\[\](){}「」『』【】\u3000]+',
    caseSensitive: false,
  );

  /// 텍스트를 HTML로 변환 (XSS 이스케이프 + URL → <a> 태그)
  static String _processText(String text, Color linkColor) {
    // 1. HTML 이스케이프 (XSS 방지)
    var html = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');

    // 2. URL → <a> 태그 변환
    html = html.replaceAllMapped(_urlPattern, (match) {
      final url = match.group(0)!;
      final cssColor = _colorToCss(linkColor);
      return '<a href="$url" target="_blank" rel="noopener noreferrer" '
          'style="color:$cssColor;text-decoration:underline;'
          'text-underline-offset:2px;overflow-wrap:anywhere;">'
          '$url</a>';
    });

    // 3. 줄바꿈 → <br>
    return html.replaceAll('\n', '<br>');
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
  /// 등록된 viewType 목록 (중복 방지)
  static final _registered = <String>{};

  double _measuredHeight = 0;
  bool _ready = false;

  String get _viewType =>
      'memo-text-${widget.viewId}-${widget.textColor.value.toRadixString(16)}';

  @override
  void initState() {
    super.initState();
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
      _register();
      _measure();
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
    div.innerHTML =
        HtmlTextBlock._processText(widget.text, widget.linkColor).toJS;
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
    if (!mounted) return;
    // LayoutBuilder에서 maxWidth를 가져올 수 없으므로
    // 빌드 후 한 프레임 기다려 context.size를 읽는다
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // 부모의 폭 추정: ConstrainedBox maxWidth - padding
      final screenWidth = MediaQuery.sizeOf(context).width;
      final isDesktop = screenWidth >= 768;
      final isWideDesktop = screenWidth >= 1024;
      final maxContentWidth = isWideDesktop ? 800.0 : 600.0;
      final padding = isDesktop ? 48.0 : 32.0; // symmetric 24 or 16 × 2
      final maxWidth =
          (screenWidth < maxContentWidth + padding
              ? screenWidth - padding
              : maxContentWidth) -
          2; // 여유 2px

      final height = await HtmlTextBlock.measureHeight(
        text: widget.text,
        fontSize: widget.fontSize,
        lineHeight: widget.lineHeight,
        maxWidth: maxWidth,
      );
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
      // 측정 완료 전: Flutter Text로 폴백 (깜박임 최소화)
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
