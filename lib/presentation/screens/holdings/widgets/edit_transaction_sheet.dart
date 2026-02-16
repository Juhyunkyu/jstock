import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/holding.dart';
import '../../../../data/models/holding_transaction.dart';
import '../../../providers/providers.dart';
import '../../../widgets/common/date_picker_field.dart';

/// KRW 금액을 천 단위 콤마로 포맷팅 (내부용)
String formatKrwWithComma(double amount) {
  final intAmount = amount.round();
  final absAmount = intAmount.abs();
  final formatted = absAmount.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
  return intAmount < 0 ? '-$formatted' : formatted;
}

/// 거래 내역 수정 바텀시트
class EditTransactionSheet extends ConsumerStatefulWidget {
  final HoldingTransaction transaction;
  final Holding? holding;

  const EditTransactionSheet({super.key, required this.transaction, this.holding});

  @override
  ConsumerState<EditTransactionSheet> createState() => EditTransactionSheetState();
}

class EditTransactionSheetState extends ConsumerState<EditTransactionSheet> {
  late DateTime _selectedDate;
  late TextEditingController _priceController;
  late TextEditingController _sharesController;
  late TextEditingController _noteController;
  late TextEditingController _exchangeRateController;
  late TextEditingController _realizedPnlController;
  bool _isManualPnl = false;

  double get _price => double.tryParse(_priceController.text) ?? 0;
  double get _shares => double.tryParse(_sharesController.text) ?? 0;
  double get _editExchangeRate => double.tryParse(_exchangeRateController.text) ?? 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.transaction.date;
    _priceController = TextEditingController(
      text: widget.transaction.price.toStringAsFixed(2),
    );
    _sharesController = TextEditingController(
      text: widget.transaction.shares.toStringAsFixed(
        widget.transaction.shares == widget.transaction.shares.roundToDouble() ? 0 : 2,
      ),
    );
    _noteController = TextEditingController(text: widget.transaction.note ?? '');
    _exchangeRateController = TextEditingController(
      text: widget.transaction.exchangeRate.toStringAsFixed(0),
    );
    _realizedPnlController = TextEditingController(
      text: widget.transaction.realizedPnlKrw?.round().toString() ?? '',
    );
    // 기존 값이 있으면 수동 입력 상태로 시작 (기존값 유지)
    _isManualPnl = widget.transaction.realizedPnlKrw != null;
  }

  @override
  void dispose() {
    _priceController.dispose();
    _sharesController.dispose();
    _noteController.dispose();
    _exchangeRateController.dispose();
    _realizedPnlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBuy = widget.transaction.isBuy;
    final typeColor = isBuy ? AppColors.buyAction : AppColors.sellAction;
    final typeText = isBuy ? '매수' : '매도';
    final isFormValid = _price > 0 && _shares > 0;
    // 매도: 사용자 입력 환율, 매수: holding 환율
    final holding = widget.holding ?? ref.watch(holdingByIdProvider(widget.transaction.holdingId));
    final exchangeRate = !isBuy && _editExchangeRate > 0
        ? _editExchangeRate
        : (holding?.exchangeRate ?? widget.transaction.exchangeRate);

    // 매도 시 실현손익 자동계산 (수동 입력이 아닌 경우)
    if (!isBuy && !_isManualPnl && _price > 0 && _shares > 0 && holding != null) {
      final autoPnl = (_price - holding.averagePrice) * _shares * exchangeRate;
      final autoPnlStr = autoPnl.round().toString();
      if (_realizedPnlController.text != autoPnlStr) {
        _realizedPnlController.text = autoPnlStr;
      }
    }

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
              Row(
                children: [
                  Text(
                    '거래 내역 수정',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        typeText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 거래일 선택
            DatePickerField(
              label: '거래일',
              selectedDate: _selectedDate,
              onDateChanged: (date) {
                setState(() {
                  _selectedDate = date;
                });
              },
            ),
            const SizedBox(height: 16),

            // 단가 입력
            _InputField(
              label: '단가 (USD)',
              controller: _priceController,
              prefix: '\$',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // 수량 입력 (스텝퍼)
            Text(
              '수량 (주)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StepperButton(
                  icon: Icons.remove,
                  onTap: () {
                    final current = double.tryParse(_sharesController.text) ?? 0;
                    if (current > 0) {
                      final newVal = (current - 1).clamp(0, double.infinity);
                      _sharesController.text = newVal == newVal.roundToDouble()
                          ? newVal.toInt().toString()
                          : newVal.toStringAsFixed(2);
                      setState(() {});
                    }
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _sharesController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: context.appSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StepperButton(
                  icon: Icons.add,
                  onTap: () {
                    final current = double.tryParse(_sharesController.text) ?? 0;
                    final newVal = current + 1;
                    _sharesController.text = newVal == newVal.roundToDouble()
                        ? newVal.toInt().toString()
                        : newVal.toStringAsFixed(2);
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 기준환율 입력 (매도 시에만 표시)
            if (!isBuy) ...[
              _InputField(
                label: '기준환율 (₩/\$)',
                controller: _exchangeRateController,
                prefix: '₩',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
            ],

            // 거래 금액 미리보기
            if (_price > 0 && _shares > 0)
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
                      '거래 금액',
                      style: TextStyle(fontSize: 12, color: context.appTextSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatKrwWithComma(_price * _shares * exchangeRate)}원',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isBuy
                          ? '(매입환율: \u20a9${exchangeRate.toStringAsFixed(0)}/\$)'
                          : '(기준환율: \u20a9${exchangeRate.toStringAsFixed(0)}/\$)',
                      style: TextStyle(fontSize: 11, color: context.appTextHint),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // 실현손익 입력 (매도 시에만 표시)
            if (!isBuy && _price > 0 && _shares > 0) ...[
              _InputField(
                label: '실현손익 (원)',
                controller: _realizedPnlController,
                prefix: '₩',
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))],
                onChanged: (_) {
                  _isManualPnl = true;
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
            ],

            // 메모 입력
            _InputField(
              label: '메모 (선택)',
              controller: _noteController,
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // 저장 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isFormValid ? _saveChanges : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: typeColor,
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

  void _saveChanges() async {
    try {
      final manualPnl = widget.transaction.isSell ? double.tryParse(_realizedPnlController.text) : null;
      await ref.read(holdingListProvider.notifier).updateTransaction(
            widget.transaction.id,
            date: _selectedDate,
            price: _price,
            shares: _shares,
            exchangeRate: widget.transaction.isSell && _editExchangeRate > 0 ? _editExchangeRate : null,
            realizedPnlKrw: manualPnl,
            note: _noteController.text.isEmpty ? null : _noteController.text,
          );

      // 거래 내역 리프레시
      refreshTransactions(ref);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('거래 내역이 수정되었습니다'),
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
  final List<TextInputFormatter>? inputFormatters;

  const _InputField({
    required this.label,
    required this.controller,
    this.prefix,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
    this.inputFormatters,
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
          inputFormatters: inputFormatters ?? (keyboardType == const TextInputType.numberWithOptions(decimal: true)
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
              : keyboardType == TextInputType.number
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null),
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

/// 수량 스텝퍼 버튼
class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: context.appTextPrimary),
      ),
    );
  }
}
