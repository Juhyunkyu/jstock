import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/notification/web_notification_service.dart';
import '../../providers/settings_providers.dart';

/// Zone color constants for Fear & Greed Index
const _kExtremeFearColor = Color(0xFFDC2626);
const _kFearColor = Color(0xFFF97316);
const _kNeutralColor = Color(0xFFEAB308);
const _kGreedColor = Color(0xFF84CC16);
const _kExtremeGreedColor = Color(0xFF22C55E);

/// Get Korean zone name from value
String _getZoneName(int value) {
  if (value <= 24) return '극도의 공포';
  if (value <= 43) return '공포';
  if (value <= 55) return '중립';
  if (value <= 74) return '탐욕';
  return '극도의 탐욕';
}

/// Get zone color from value
Color _getZoneColor(int value) {
  if (value <= 24) return _kExtremeFearColor;
  if (value <= 43) return _kFearColor;
  if (value <= 55) return _kNeutralColor;
  if (value <= 74) return _kGreedColor;
  return _kExtremeGreedColor;
}

/// Get zone name from an alert threshold value and direction
String _getAlertZoneDescription(int value, int direction) {
  final zoneName = _getZoneName(value);
  final directionText = direction == 0 ? '이하' : '이상';
  return '지수 $value $directionText($zoneName 구간) 진입 시 알림을 받습니다';
}

/// BottomSheet for configuring Fear & Greed Index alerts
class FearGreedAlertSheet extends ConsumerStatefulWidget {
  final int currentValue;

  const FearGreedAlertSheet({
    super.key,
    required this.currentValue,
  });

  @override
  ConsumerState<FearGreedAlertSheet> createState() =>
      _FearGreedAlertSheetState();
}

class _FearGreedAlertSheetState extends ConsumerState<FearGreedAlertSheet> {
  late bool _enabled;
  late int _alertValue;
  late int _direction;
  late TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _enabled = settings.fearGreedAlertEnabled;
    _alertValue = settings.fearGreedAlertValue;
    _direction = settings.fearGreedAlertDirection;
    _valueController = TextEditingController(text: _alertValue.toString());
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _onValueChanged(String text) {
    if (text.isEmpty) return;
    final parsed = int.tryParse(text);
    if (parsed == null) return;
    final clamped = parsed.clamp(0, 100);
    setState(() {
      _alertValue = clamped;
    });
    // If user typed something out of range, correct the field
    if (clamped != parsed) {
      _valueController.text = clamped.toString();
      _valueController.selection = TextSelection.fromPosition(
        TextPosition(offset: _valueController.text.length),
      );
    }
  }

  Future<void> _onSave() async {
    ref.read(settingsProvider.notifier).updateFearGreedAlert(
          enabled: _enabled,
          value: _alertValue,
          direction: _direction,
        );
    // 사용자 인터랙션(버튼 탭) 컨텍스트에서 알림 권한 요청
    // → 모바일 브라우저에서도 권한 팝업이 표시됨
    await WebNotificationService.requestPermission();
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('공포탐욕지수 알림이 저장되었습니다'),
        backgroundColor: AppColors.green500,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zoneColor = _getZoneColor(widget.currentValue);
    final zoneName = _getZoneName(widget.currentValue);
    final accent = context.appAccent;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              '공포탐욕지수 알림 설정',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Current value chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: zoneColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '현재: ${widget.currentValue} ($zoneName)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: zoneColor,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Settings container
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.appBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '알림 조건',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                      ),
                      Switch.adaptive(
                        value: _enabled,
                        activeColor: accent,
                        onChanged: (value) {
                          setState(() {
                            _enabled = value;
                          });
                        },
                      ),
                    ],
                  ),

                  // Condition row (animated)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: _enabled
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _buildConditionRow(context, accent),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Hint text
            if (_enabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _getAlertZoneDescription(_alertValue, _direction),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextHint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: context.isDarkMode
                      ? AppColors.darkBackground
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '저장',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionRow(BuildContext context, Color accent) {
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '지수가',
          style: TextStyle(
            fontSize: 14,
            color: context.appTextSecondary,
          ),
        ),

        // Number input
        SizedBox(
          width: 60,
          height: 40,
          child: TextField(
            controller: _valueController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onChanged: _onValueChanged,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.appBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: accent, width: 1.5),
              ),
              filled: true,
              fillColor: context.appCardBackground,
            ),
          ),
        ),

        // Direction selector
        SegmentedButton<int>(
          segments: const [
            ButtonSegment<int>(value: 0, label: Text('이하')),
            ButtonSegment<int>(value: 1, label: Text('이상')),
          ],
          selected: {_direction},
          onSelectionChanged: (selected) {
            setState(() {
              _direction = selected.first;
            });
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return accent.withValues(alpha: 0.15);
              }
              return context.appCardBackground;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return accent;
              }
              return context.appTextSecondary;
            }),
            side: WidgetStateProperty.all(
              BorderSide(color: context.appBorder),
            ),
            textStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),

        Text(
          '도달 시',
          style: TextStyle(
            fontSize: 14,
            color: context.appTextSecondary,
          ),
        ),
      ],
    );
  }
}
