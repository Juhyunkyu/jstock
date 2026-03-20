import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/image/image_compress_service.dart';

/// 메모 이미지 선택/미리보기 위젯
///
/// 최대 3장의 이미지를 선택하고, 썸네일로 미리보기를 제공합니다.
/// + 버튼으로 이미지를 추가하고, X 버튼으로 개별 삭제할 수 있습니다.
class MemoImagePicker extends StatelessWidget {
  /// 현재 이미지 목록 (base64)
  final List<String> images;

  /// 이미지 추가 콜백
  final ValueChanged<String> onAdd;

  /// 이미지 삭제 콜백 (인덱스)
  final ValueChanged<int> onRemove;

  /// 이미지 탭 콜백 (전체화면 보기용)
  final void Function(int index)? onTap;

  /// 최대 이미지 수
  static const int maxImages = 3;

  const MemoImagePicker({
    super.key,
    required this.images,
    required this.onAdd,
    required this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '이미지 (${images.length}/$maxImages)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // 기존 이미지 썸네일
              ...List.generate(images.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ImageThumbnail(
                    base64String: images[index],
                    onRemove: () => onRemove(index),
                    onTap: onTap != null ? () => onTap!(index) : null,
                  ),
                );
              }),
              // 추가 버튼 (최대 미만일 때만)
              if (images.length < maxImages)
                _AddButton(
                  onTap: () => _pickImage(context),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage(BuildContext context) async {
    final base64 = await ImageCompressService.pickAndCompress();
    if (base64 != null) {
      onAdd(base64);
    }
  }
}

/// 이미지 썸네일 (X 버튼 포함)
class _ImageThumbnail extends StatelessWidget {
  final String base64String;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  const _ImageThumbnail({
    required this.base64String,
    required this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 80,
              height: 80,
              child: Image.memory(
                base64Decode(base64String),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: context.appIconBg,
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 32,
                    color: context.appTextHint,
                  ),
                ),
              ),
            ),
          ),
          // X 삭제 버튼
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 이미지 추가 버튼
class _AddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: context.appIconBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: context.appDivider,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 28,
              color: context.appTextHint,
            ),
            const SizedBox(height: 4),
            Text(
              '추가',
              style: TextStyle(
                fontSize: 11,
                color: context.appTextHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
