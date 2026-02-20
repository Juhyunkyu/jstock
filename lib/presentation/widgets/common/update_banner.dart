import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/pwa/pwa_update_service.dart';

/// PWA 업데이트 알림 배너
///
/// 새 버전이 감지되면 화면 상단에 표시됩니다.
/// 탭하면 페이지를 새로고침하여 업데이트를 적용합니다.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appAccent,
      child: InkWell(
        onTap: PWAUpdateService.applyUpdate,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.system_update, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '새 버전이 있습니다. 탭하여 업데이트하세요.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '업데이트',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
