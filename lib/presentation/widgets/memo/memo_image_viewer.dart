import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 메모 이미지 전체화면 뷰어
///
/// 이미지를 탭하면 전체화면으로 확대하여 보여줍니다.
/// PageView로 여러 이미지 간 스와이프 가능.
class MemoImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const MemoImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  /// 전체화면 뷰어를 표시합니다.
  static void show(BuildContext context, List<String> images, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: MemoImageViewer(
              images: images,
              initialIndex: initialIndex,
            ),
          );
        },
      ),
    );
  }

  @override
  State<MemoImageViewer> createState() => _MemoImageViewerState();
}

class _MemoImageViewerState extends State<MemoImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // 이미지 PageView
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return Center(
                  child: InteractiveViewer(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Image.memory(
                        base64Decode(widget.images[index]),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.broken_image_outlined,
                          size: 64,
                          color: context.appTextHint,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // 닫기 버튼
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

            // 페이지 인디케이터 (2장 이상일 때)
            if (widget.images.length > 1)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.images.length, (index) {
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentIndex
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
