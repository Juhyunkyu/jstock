import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// JS interop: window._pwaUpdateAvailable 플래그 읽기
@JS('_pwaUpdateAvailable')
external JSBoolean? get _jsPwaUpdateAvailable;

/// PWA 업데이트 감지 서비스
///
/// Service Worker가 새 버전을 설치했을 때 이를 감지하고
/// 사용자에게 업데이트를 안내합니다.
class PWAUpdateService {
  /// 새 버전 업데이트가 가능한지 확인
  ///
  /// `web/index.html`의 JS 코드가 `window._pwaUpdateAvailable`을
  /// true로 설정하면 이 메서드가 true를 반환합니다.
  static bool checkForUpdate() {
    if (!kIsWeb) return false;
    try {
      final flag = _jsPwaUpdateAvailable;
      return flag?.toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 업데이트 적용 (페이지 새로고침)
  ///
  /// sessionStorage에 플래그를 설정하여 리로드 후
  /// SW 전환 이벤트로 배너가 다시 뜨는 것을 방지합니다.
  static void applyUpdate() {
    if (!kIsWeb) return;
    web.window.sessionStorage.setItem('_pwaJustUpdated', 'true');
    web.window.location.reload();
  }
}
