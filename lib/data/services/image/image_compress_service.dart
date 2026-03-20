import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Web 이미지 압축 서비스
///
/// HTML Canvas를 이용한 리사이즈 + JPEG 압축 → base64 반환.
/// APK 전환 시 조건부 import로 모바일 구현체로 교체.
class ImageCompressService {
  /// 최대 해상도 (긴 변 기준)
  static const int maxDimension = 800;

  /// JPEG 압축 품질 (0.0~1.0)
  static const double jpegQuality = 0.7;

  /// 파일 선택 + 리사이즈 + 압축 + base64 반환
  static Future<String?> pickAndCompress() async {
    final completer = Completer<String?>();

    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = 'image/*';

    input.addEventListener(
      'change',
      ((web.Event event) async {
        try {
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

          final base64 = await _compressFile(file);
          if (!completer.isCompleted) completer.complete(base64);
        } catch (e) {
          if (!completer.isCompleted) completer.complete(null);
        }
      }).toJS,
    );

    // 취소 감지 (focus 복귀 시 파일 미선택)
    web.window.addEventListener(
      'focus',
      ((web.Event e) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!completer.isCompleted) completer.complete(null);
        });
      }).toJS,
    );

    input.click();
    return completer.future;
  }

  /// 파일 → Canvas 리사이즈 → JPEG 압축 → base64
  static Future<String?> _compressFile(web.File file) async {
    final completer = Completer<String?>();

    // 1. FileReader로 이미지 data URL 읽기
    final reader = web.FileReader();

    reader.addEventListener(
      'load',
      ((web.Event e) {
        try {
          final dataUrl = (reader.result as JSString).toDart;

          // 2. Image 요소에 로드
          final img = web.document.createElement('img') as web.HTMLImageElement;

          img.addEventListener(
            'load',
            ((web.Event imgEvent) {
              try {
                final result = _resizeAndCompress(img);
                if (!completer.isCompleted) completer.complete(result);
              } catch (e) {
                if (!completer.isCompleted) completer.complete(null);
              }
            }).toJS,
          );

          img.addEventListener(
            'error',
            ((web.Event errEvent) {
              if (!completer.isCompleted) completer.complete(null);
            }).toJS,
          );

          img.src = dataUrl;
        } catch (e) {
          if (!completer.isCompleted) completer.complete(null);
        }
      }).toJS,
    );

    reader.addEventListener(
      'error',
      ((web.Event e) {
        if (!completer.isCompleted) completer.complete(null);
      }).toJS,
    );

    reader.readAsDataURL(file);
    return completer.future;
  }

  /// Canvas 리사이즈 + JPEG 압축 → base64 문자열 (data:image prefix 제거)
  static String? _resizeAndCompress(web.HTMLImageElement img) {
    final origW = img.naturalWidth;
    final origH = img.naturalHeight;
    if (origW == 0 || origH == 0) return null;

    // 비율 유지 축소
    int newW = origW;
    int newH = origH;
    if (origW > maxDimension || origH > maxDimension) {
      if (origW > origH) {
        newW = maxDimension;
        newH = (origH * maxDimension / origW).round();
      } else {
        newH = maxDimension;
        newW = (origW * maxDimension / origH).round();
      }
    }

    // Canvas에 그리기
    final canvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    canvas.width = newW;
    canvas.height = newH;

    final ctx = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
    ctx.drawImage(img, 0, 0, newW.toDouble(), newH.toDouble());

    // JPEG로 변환 (toDataURL 사용)
    final dataUrl = canvas.toDataURL('image/jpeg', jpegQuality.toJS);

    // "data:image/jpeg;base64," prefix 제거
    const prefix = 'data:image/jpeg;base64,';
    if (dataUrl.startsWith(prefix)) {
      return dataUrl.substring(prefix.length);
    }
    return dataUrl;
  }

  /// base64 문자열에서 Image 위젯 생성
  static Widget imageFromBase64(String base64String) {
    final bytes = base64Decode(base64String);
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
    );
  }
}
