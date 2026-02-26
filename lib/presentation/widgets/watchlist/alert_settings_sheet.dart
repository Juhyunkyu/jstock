import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/alert_direction.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/watchlist_item.dart';
import '../../../data/services/notification/web_notification_service.dart';
import '../../providers/watchlist_providers.dart';
import 'alert_form_widgets.dart';

/// 알림 설정 Bottom Sheet
class AlertSettingsSheet extends ConsumerStatefulWidget {
  final WatchlistItem item;
  final double? currentPrice;

  const AlertSettingsSheet({
    super.key,
    required this.item,
    this.currentPrice,
  });

  @override
  ConsumerState<AlertSettingsSheet> createState() => _AlertSettingsSheetState();
}

class _AlertSettingsSheetState extends ConsumerState<AlertSettingsSheet> {
  // 현재 보고 있는 탭: 0 = 변동률, 1 = 목표가
  int _selectedTab = 0;
  // 0 = ± 양방향, 1 = ▲ 상승만, 2 = ▼ 하락만
  late int _alertDirection;
  // 0 = 이상(above), 1 = 이하(below)
  late int _targetDirection;
  late TextEditingController _targetPriceController;
  late TextEditingController _basePriceController;
  late TextEditingController _percentController;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    final price = widget.currentPrice ?? 0.0;

    // 기존 설정이 있으면 해당 탭 열기
    if (item.hasTargetAlert && !item.hasPercentAlert) {
      _selectedTab = 1;
    }

    _alertDirection = item.alertDirection ?? 0;
    _targetDirection = item.alertTargetDirection ?? 0;

    // 목표가: 기존 값 or 현재가
    _targetPriceController = TextEditingController(
      text: item.hasTargetAlert
          ? item.alertPrice!.toStringAsFixed(2)
          : price > 0
              ? price.toStringAsFixed(2)
              : '',
    );

    // 변동률 기준가: 기존 값 or 현재가
    _basePriceController = TextEditingController(
      text: item.hasPercentAlert
          ? item.alertBasePrice!.toStringAsFixed(2)
          : price > 0
              ? price.toStringAsFixed(2)
              : '',
    );

    // 변동률 %: 기존 값 or 5.0
    _percentController = TextEditingController(
      text: item.alertPercent?.toStringAsFixed(1) ?? '5.0',
    );
  }

  @override
  void dispose() {
    _targetPriceController.dispose();
    _basePriceController.dispose();
    _percentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.currentPrice;
    final item = widget.item;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.appBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 헤더
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '알림 설정 - ${item.ticker}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // 현재가
          if (price != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '현재가: \$${price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.appTextSecondary,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // 토글 버튼 (활성 알림 표시)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: AlertTabToggle(
                    label: '변동률 알림',
                    isSelected: _selectedTab == 0,
                    hasAlert: item.hasPercentAlert,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AlertTabToggle(
                    label: '목표가 알림',
                    isSelected: _selectedTab == 1,
                    hasAlert: item.hasTargetAlert,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 설정 내용
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _selectedTab == 0
                  ? _buildPercentForm(price)
                  : _buildTargetPriceForm(price),
            ),
          ),

          // 하단 버튼
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                // 현재 탭의 알림이 있으면 해제 버튼
                if ((_selectedTab == 0 && item.hasPercentAlert) ||
                    (_selectedTab == 1 && item.hasTargetAlert)) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _onClearCurrentAlert,
                      child: Text(
                        _selectedTab == 0 ? '변동률 알림 해제' : '목표가 알림 해제',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentForm(double? currentPrice) {
    final basePrice = double.tryParse(_basePriceController.text) ?? 0;
    final percent = double.tryParse(_percentController.text) ?? 0;
    final low = basePrice * (1 - percent / 100);
    final high = basePrice * (1 + percent / 100);

    String previewText = '';
    if (basePrice > 0 && percent > 0) {
      switch (_alertDirection) {
        case 1:
          previewText = '\$${high.toStringAsFixed(2)} 이상이면 알림';
          break;
        case 2:
          previewText = '\$${low.toStringAsFixed(2)} 이하이면 알림';
          break;
        default:
          previewText =
              '\$${low.toStringAsFixed(2)} ~ \$${high.toStringAsFixed(2)} 범위 벗어나면 알림';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AlertFormLabel('알림 방향'),
        const SizedBox(height: 6),
        AlertDirectionSelector(
          children: [
            AlertDirectionChip(
              label: '▼ 하락',
              isActive: _alertDirection == 2,
              activeColor: AppColors.blue500,
              onTap: () => setState(() => _alertDirection = 2),
            ),
            AlertDirectionChip(
              label: '± 양방향',
              isActive: _alertDirection == 0,
              activeColor: AppColors.primary,
              onTap: () => setState(() => _alertDirection = 0),
            ),
            AlertDirectionChip(
              label: '▲ 상승',
              isActive: _alertDirection == 1,
              activeColor: AppColors.red500,
              onTap: () => setState(() => _alertDirection = 1),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const AlertFormLabel('기준 가격'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: AlertFormTextField(
                controller: _basePriceController,
                hint: '기준 가격 입력',
                onChanged: () => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: currentPrice != null
                    ? () {
                        _basePriceController.text =
                            currentPrice.toStringAsFixed(2);
                        setState(() {});
                      }
                    : null,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.gray300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '현재가',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.appTextSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const AlertFormLabel('변동률 (%)'),
        const SizedBox(height: 6),
        AlertFormTextField(
          controller: _percentController,
          hint: '예: 5.0',
          onChanged: () => setState(() {}),
        ),
        if (previewText.isNotEmpty) ...[
          const SizedBox(height: 12),
          AlertPreviewText(previewText),
        ],
      ],
    );
  }

  Widget _buildTargetPriceForm(double? currentPrice) {
    final target = double.tryParse(_targetPriceController.text) ?? 0;
    final diff = currentPrice != null && currentPrice > 0 && target > 0
        ? ((target - currentPrice) / currentPrice * 100)
        : null;
    final dirLabel = AlertDirection.fromTargetInt(_targetDirection).label;
    final previewText = target > 0
        ? '\$${target.toStringAsFixed(2)} $dirLabel 도달 시 알림'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AlertFormLabel('목표 가격'),
        const SizedBox(height: 6),
        AlertFormTextField(
          controller: _targetPriceController,
          hint: '목표 가격 입력',
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 16),
        const AlertFormLabel('알림 조건'),
        const SizedBox(height: 6),
        AlertDirectionSelector(
          children: [
            AlertDirectionChip(
              label: AlertDirection.above.labelWithSymbol,
              isActive: _targetDirection == AlertDirection.above.toTargetInt,
              activeColor: AppColors.red500,
              onTap: () => setState(() => _targetDirection = AlertDirection.above.toTargetInt),
            ),
            AlertDirectionChip(
              label: AlertDirection.below.labelWithSymbol,
              isActive: _targetDirection == AlertDirection.below.toTargetInt,
              activeColor: AppColors.blue500,
              onTap: () => setState(() => _targetDirection = AlertDirection.below.toTargetInt),
            ),
          ],
        ),
        if (diff != null) ...[
          const SizedBox(height: 12),
          AlertPreviewText('현재가 대비 ${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(2)}%'),
        ],
        if (previewText.isNotEmpty) ...[
          const SizedBox(height: 8),
          AlertPreviewText(previewText),
        ],
      ],
    );
  }

  Future<void> _onSave() async {
    final notifier = ref.read(watchlistProvider.notifier);
    if (_selectedTab == 1) {
      // 목표가 저장
      final price = double.tryParse(_targetPriceController.text);
      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('유효한 목표 가격을 입력해주세요')),
        );
        return;
      }
      await notifier.setTargetAlert(
        ticker: widget.item.ticker,
        alertPrice: price,
        alertTargetDirection: _targetDirection,
      );
    } else {
      // 변동률 저장
      final basePrice = double.tryParse(_basePriceController.text);
      final percent = double.tryParse(_percentController.text);
      if (basePrice == null || basePrice <= 0 || percent == null || percent <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('유효한 기준 가격과 변동률을 입력해주세요')),
        );
        return;
      }
      await notifier.setPercentAlert(
        ticker: widget.item.ticker,
        alertBasePrice: basePrice,
        alertPercent: percent,
        alertDirection: _alertDirection,
      );
    }
    // 사용자 인터랙션(버튼 탭) 컨텍스트에서 알림 권한 요청
    // → 모바일 브라우저에서도 권한 팝업이 표시됨
    await WebNotificationService.requestPermission();
    if (mounted) Navigator.pop(context);
  }

  void _onClearCurrentAlert() {
    final notifier = ref.read(watchlistProvider.notifier);
    if (_selectedTab == 0) {
      notifier.clearPercentAlert(widget.item.ticker);
    } else {
      notifier.clearTargetAlert(widget.item.ticker);
    }
    Navigator.pop(context);
  }
}
