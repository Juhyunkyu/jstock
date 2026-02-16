import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/watchlist_item.dart';
import '../../providers/watchlist_providers.dart';

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
                  child: _buildToggle(
                    label: '변동률 알림',
                    isSelected: _selectedTab == 0,
                    hasAlert: item.hasPercentAlert,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildToggle(
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

  Widget _buildToggle({
    required String label,
    required bool isSelected,
    required bool hasAlert,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : context.appIconBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasAlert) ...[
              Icon(
                Icons.check_circle,
                size: 14,
                color: isSelected ? Colors.white : AppColors.amber600,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : context.appTextSecondary,
              ),
            ),
          ],
        ),
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
        _buildLabel('알림 방향'),
        const SizedBox(height: 6),
        _buildDirectionSelector(),
        const SizedBox(height: 16),
        _buildLabel('기준 가격'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _basePriceController,
                hint: '기준 가격 입력',
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
        _buildLabel('변동률 (%)'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _percentController,
          hint: '예: 5.0',
        ),
        if (previewText.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            previewText,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: context.appTextHint,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDirectionSelector() {
    return Container(
      decoration: BoxDecoration(
        color: context.appIconBg,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _buildDirectionChip(
            label: '▼ 하락',
            value: 2,
            color: AppColors.blue500,
          ),
          _buildDirectionChip(
            label: '± 양방향',
            value: 0,
            color: AppColors.primary,
          ),
          _buildDirectionChip(
            label: '▲ 상승',
            value: 1,
            color: AppColors.red500,
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionChip({
    required String label,
    required int value,
    required Color color,
  }) {
    final isActive = _alertDirection == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _alertDirection = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? Colors.white : context.appTextHint,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTargetPriceForm(double? currentPrice) {
    final target = double.tryParse(_targetPriceController.text) ?? 0;
    final diff = currentPrice != null && currentPrice > 0 && target > 0
        ? ((target - currentPrice) / currentPrice * 100)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('목표 가격'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _targetPriceController,
          hint: '목표 가격 입력',
        ),
        if (diff != null) ...[
          const SizedBox(height: 12),
          Text(
            '현재가 대비 ${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(2)}%',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: context.appTextHint,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.appTextSecondary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
      ],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: context.appIconBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  void _onSave() {
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
      notifier.setTargetAlert(
        ticker: widget.item.ticker,
        alertPrice: price,
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
      notifier.setPercentAlert(
        ticker: widget.item.ticker,
        alertBasePrice: basePrice,
        alertPercent: percent,
        alertDirection: _alertDirection,
      );
    }
    Navigator.pop(context);
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
