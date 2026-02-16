import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/logo_provider.dart';

/// 티커 로고 위젯
///
/// 로고 URL이 캐시되어 있으면 이미지를 표시하고,
/// 없으면 티커의 첫 글자를 fallback으로 표시합니다.
class TickerLogo extends ConsumerStatefulWidget {
  final String ticker;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;
  final double borderRadius;

  const TickerLogo({
    super.key,
    required this.ticker,
    this.size = 40,
    this.backgroundColor,
    this.textColor,
    this.borderRadius = 10,
  });

  @override
  ConsumerState<TickerLogo> createState() => _TickerLogoState();
}

class _TickerLogoState extends ConsumerState<TickerLogo> {
  @override
  void initState() {
    super.initState();
    // 로고 URL 비동기 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tickerLogoProvider.notifier).fetchLogo(widget.ticker);
    });
  }

  @override
  Widget build(BuildContext context) {
    final logos = ref.watch(tickerLogoProvider);
    final logoUrl = logos[widget.ticker.toUpperCase()];

    final bgColor = widget.backgroundColor ??
        context.appTextSecondary.withValues(alpha: 0.1);
    final txtColor = widget.textColor ?? context.appTextSecondary;

    // CORS 우회: wsrv.nl 프록시를 통해 이미지 로드
    final proxiedUrl = logoUrl != null && logoUrl.isNotEmpty
        ? 'https://wsrv.nl/?url=${Uri.encodeComponent(logoUrl)}&w=${(widget.size * 2).toInt()}&h=${(widget.size * 2).toInt()}&fit=contain'
        : null;

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: proxiedUrl != null
          ? Image.network(
              proxiedUrl,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _FallbackLetter(
                ticker: widget.ticker,
                size: widget.size,
                color: txtColor,
              ),
            )
          : _FallbackLetter(
              ticker: widget.ticker,
              size: widget.size,
              color: txtColor,
            ),
    );
  }
}

/// 로고가 없을 때 첫 글자를 표시하는 fallback 위젯
class _FallbackLetter extends StatelessWidget {
  final String ticker;
  final double size;
  final Color color;

  const _FallbackLetter({
    required this.ticker,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        ticker.isNotEmpty ? ticker.substring(0, 1).toUpperCase() : '?',
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
