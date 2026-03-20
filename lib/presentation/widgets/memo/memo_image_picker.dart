import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/image/image_compress_service.dart';

/// 이미지 선택 버튼
///
/// 이미지를 선택하면 base64로 압축하여 콜백으로 반환합니다.
class MemoImagePickButton extends StatelessWidget {
  /// 이미지 추가 콜백 (base64 반환)
  final ValueChanged<String> onImagePicked;

  const MemoImagePickButton({
    super.key,
    required this.onImagePicked,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pickImage(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.appAccent.withValues(
              alpha: context.isDarkMode ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.appAccent.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 18,
              color: context.appAccent,
            ),
            const SizedBox(width: 6),
            Text(
              '이미지 추가',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.appAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(BuildContext context) async {
    final base64 = await ImageCompressService.pickAndCompress();
    if (base64 != null) {
      onImagePicked(base64);
    }
  }
}
