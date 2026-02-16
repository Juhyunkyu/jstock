import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/holding.dart';
import '../../../providers/providers.dart';
import '../../../widgets/common/date_picker_field.dart';

/// KRW 금액을 천 단위 콤마로 포맷팅 (내부용)
String _formatKrwWithComma(double amount) {
  final intAmount = amount.round();
  final absAmount = intAmount.abs();
  final formatted = absAmount.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
  return intAmount < 0 ? '-$formatted' : formatted;
}

/// 보유 정보 수정 바텀시트
class EditHoldingSheet extends ConsumerStatefulWidget {
  final Holding holding;

  const EditHoldingSheet({super.key, required this.holding});

  @override
  ConsumerState<EditHoldingSheet> createState() => EditHoldingSheetState();
}

class EditHoldingSheetState extends ConsumerState<EditHoldingSheet> {
  late DateTime _selectedStartDate;
  late TextEditingController _exchangeRateController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;

  double get _exchangeRate => double.tryParse(_exchangeRateController.text) ?? 0;
  double get _price => double.tryParse(_priceController.text) ?? 0;
  int get _quantity => int.tryParse(_quantityController.text) ?? 0;

  @override
  void initState() {
    super.initState();
    _selectedStartDate = widget.holding.startDate;
    _exchangeRateController = TextEditingController(
      text: widget.holding.purchaseExchangeRate.toStringAsFixed(2),
    );
    _priceController = TextEditingController(
      text: widget.holding.averagePrice.toStringAsFixed(2),
    );
    _quantityController = TextEditingController(
      text: widget.holding.quantity.toString(),
    );
  }

  @override
  void dispose() {
    _exchangeRateController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalAmountKrw = _price * _quantity * _exchangeRate;
    final isFormValid = _exchangeRate > 0 && _price > 0 && _quantity > 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.holding.ticker} 정보 수정',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 첫 매수일 선택
            DatePickerField(
              label: '첫 매수일',
              selectedDate: _selectedStartDate,
              onDateChanged: (date) {
                setState(() {
                  _selectedStartDate = date;
                });
              },
            ),
            const SizedBox(height: 16),

            // 매입환율 입력
            _InputField(
              label: '매입환율 (USD/KRW)',
              controller: _exchangeRateController,
              prefix: '\u20a9',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // 매입가 입력
            _InputField(
              label: '손익분기 매입가 (USD)',
              controller: _priceController,
              prefix: '\$',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // 수량 입력
            _InputField(
              label: '보유 수량 (주)',
              controller: _quantityController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // 예상 투자금액 표시
            if (isFormValid)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '예상 투자 금액',
                      style: TextStyle(fontSize: 12, color: context.appTextSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\u20a9${_formatNumber(totalAmountKrw)}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // 저장 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isFormValid ? _saveChanges : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  disabledBackgroundColor: context.isDarkMode ? const Color(0xFF2D333B) : AppColors.gray300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '변경사항 저장',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
    );
  }

  String _formatNumber(double value) {
    return _formatKrwWithComma(value.toDouble());
  }

  void _saveChanges() async {
    try {
      await ref.read(holdingListProvider.notifier).updateHoldingValues(
            holdingId: widget.holding.id,
            purchasePrice: _price,
            quantity: _quantity,
            purchaseExchangeRate: _exchangeRate,
            startDate: _selectedStartDate,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('정보가 수정되었습니다'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류: ${e.toString()}'),
            backgroundColor: AppColors.red500,
          ),
        );
      }
    }
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? prefix;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _InputField({
    required this.label,
    required this.controller,
    this.prefix,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          inputFormatters: keyboardType == const TextInputType.numberWithOptions(decimal: true)
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
              : keyboardType == TextInputType.number
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
          decoration: InputDecoration(
            prefixText: prefix,
            filled: true,
            fillColor: context.appSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
