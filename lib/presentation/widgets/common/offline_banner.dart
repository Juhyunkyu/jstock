import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../../../core/theme/app_colors.dart';

/// 오프라인 상태 배너
///
/// 브라우저의 navigator.onLine API를 사용하여 네트워크 상태를 감지합니다.
/// 오프라인 시 앱 상단에 경고 배너를 표시하고, 온라인 복귀 시 자동으로 숨깁니다.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;

    _isOffline = !web.window.navigator.onLine;

    web.window.addEventListener(
      'online',
      _onOnline.toJS,
    );
    web.window.addEventListener(
      'offline',
      _onOffline.toJS,
    );
  }

  void _onOnline(web.Event event) {
    if (mounted) setState(() => _isOffline = false);
  }

  void _onOffline(web.Event event) {
    if (mounted) setState(() => _isOffline = true);
  }

  @override
  void dispose() {
    if (kIsWeb) {
      web.window.removeEventListener('online', _onOnline.toJS);
      web.window.removeEventListener('offline', _onOffline.toJS);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: context.appCautionColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 16,
            color: context.appTextPrimary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '오프라인 모드 — 캐시된 데이터를 표시합니다',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.appTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
