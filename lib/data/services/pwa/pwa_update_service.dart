import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// JS interop: window._pwaUpdateAvailable 플래그 읽기
@JS('_pwaUpdateAvailable')
external JSBoolean? get _jsPwaUpdateAvailable;

/// JS interop: eval() 함수 직접 호출
@JS('eval')
external void _jsEval(JSString code);

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

  /// 업데이트 적용 (SW 캐시 삭제 → 페이지 새로고침)
  ///
  /// 1. JavaScript로 모든 Service Worker 캐시 삭제
  /// 2. sessionStorage 플래그 설정 (배너 재표시 방지)
  /// 3. 페이지 새로고침 → 서버에서 최신 코드 로드
  static void applyUpdate() {
    if (!kIsWeb) return;
    // JS로 캐시 삭제 + 리로드 (Dart JS interop 제약 우회)
    _evalJs('''
      caches.keys().then(function(names) {
        return Promise.all(names.map(function(name) {
          return caches.delete(name);
        }));
      }).then(function() {
        sessionStorage.setItem('_pwaJustUpdated', 'true');
        location.reload();
      });
    ''');
  }

  /// JavaScript 코드 실행 헬퍼
  static void _evalJs(String code) {
    _jsEval(code.toJS);
  }
}
