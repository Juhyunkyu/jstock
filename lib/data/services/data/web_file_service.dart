import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// 웹 브라우저 파일 다운로드/업로드 서비스
class WebFileService {
  /// JSON 파일 다운로드
  static void downloadJson(Map<String, dynamic> data, String filename) {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    _downloadString(jsonStr, filename, 'application/json');
  }

  /// CSV 파일 다운로드
  static void downloadCsv(String csvContent, String filename) {
    _downloadString(csvContent, filename, 'text/csv');
  }

  /// 파일 선택 → JSON Map 읽기
  static Future<Map<String, dynamic>?> pickAndReadJsonFile() async {
    final completer = Completer<Map<String, dynamic>?>();

    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = '.json';

    input.addEventListener(
      'change',
      ((web.Event event) {
        final files = input.files;
        if (files == null || files.length == 0) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        final file = files.item(0);
        if (file == null) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        final reader = web.FileReader();

        reader.addEventListener(
          'load',
          ((web.Event e) {
            try {
              final content = (reader.result as JSString).toDart;
              final json = jsonDecode(content) as Map<String, dynamic>;
              if (!completer.isCompleted) completer.complete(json);
            } catch (e) {
              if (!completer.isCompleted) {
                completer.completeError(FormatException('JSON 파일 형식이 올바르지 않습니다: $e'));
              }
            }
          }).toJS,
        );

        reader.addEventListener(
          'error',
          ((web.Event e) {
            if (!completer.isCompleted) {
              completer.completeError(Exception('파일 읽기 실패'));
            }
          }).toJS,
        );

        reader.readAsText(file);
      }).toJS,
    );

    // 취소 감지: focus 복귀 시 파일 미선택이면 null
    web.window.addEventListener(
      'focus',
      ((web.Event event) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        });
      }).toJS,
    );

    input.click();
    return completer.future;
  }

  /// 문자열을 파일로 다운로드
  static void _downloadString(String content, String filename, String mimeType) {
    final bytes = utf8.encode(content);
    final jsArray = bytes.toJS;
    final blob = web.Blob(
      [jsArray].toJS,
      web.BlobPropertyBag(type: mimeType),
    );

    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = filename;
    anchor.style.display = 'none';

    web.document.body?.appendChild(anchor);
    anchor.click();

    // 클린업
    Future.delayed(const Duration(milliseconds: 100), () {
      web.document.body?.removeChild(anchor);
      web.URL.revokeObjectURL(url);
    });
  }

  /// 백업 파일명 생성
  static String backupFilename() {
    final now = DateTime.now();
    final date = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'alpha_cycle_backup_$date.json';
  }

  /// CSV 파일명 생성
  static String csvFilename() {
    final now = DateTime.now();
    final date = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'alpha_cycle_trades_$date.csv';
  }
}
