import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/holding.dart';
import '../../../providers/providers.dart';
import '../../../widgets/common/date_picker_field.dart';
import '../../../widgets/shared/return_badge.dart';
import 'holding_input_field.dart';

/// KRW 금액을 천 단위 콤마와 "원" 접미사로 포맷팅
String formatKrwWithComma(double amount) {
  final intAmount = amount.round();
  final absAmount = intAmount.abs();
  final formatted = absAmount.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
  return intAmount < 0 ? '-$formatted' : formatted;
}

/// 거래 기록 바텀시트
class TradeRecordSheet extends ConsumerStatefulWidget {
  final Holding holding;
  final double? currentExchangeRate;
  final double? currentPrice;
  final double? changePercent;

  const TradeRecordSheet({
    super.key,
    required this.holding,
    this.currentExchangeRate,
    this.currentPrice,
    this.changePercent,
  });

  @override
  ConsumerState<TradeRecordSheet> createState() => TradeRecordSheetState();
}

class TradeRecordSheetState extends ConsumerState<TradeRecordSheet> {
  bool _isBuy = true;
  late DateTime _selectedDate;
  final _priceController = TextEditingController();
  final _sharesController = TextEditingController();
  final _noteController = TextEditingController();
  final _exchangeRateController = TextEditingController();
  final _realizedPnlController = TextEditingController();
  bool _isManualPnl = false;

  double get _price => double.tryParse(_priceController.text) ?? 0;
  double get _shares => double.tryParse(_sharesController.text) ?? 0;
  double get _sellExchangeRate => double.tryParse(_exchangeRateController.text) ?? 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    // 기준환율 초기값: 실시간 환율 > 설정 환율 (fallback)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rate = widget.currentExchangeRate ?? ref.read(settingsProvider).exchangeRate;
      _exchangeRateController.text = rate.toStringAsFixed(0);
    });
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
    final exchangeRate = _isBuy
        ? widget.holding.exchangeRate
        : (_sellExchangeRate > 0 ? _sellExchangeRate : widget.holding.exchangeRate);
    final amountKrw = _price * _shares * exchangeRate;

    // 매도 시 실현손익 자동계산 (수동 입력이 아닌 경우)
    if (!_isBuy && !_isManualPnl && _price > 0 && _shares > 0) {
      final autoPnl = (_price - widget.holding.averagePrice) * _shares * exchangeRate;
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
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.holding.ticker} 거래 기록',
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
            // 현재가 + 등락률
            if (widget.currentPrice != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '\$${widget.currentPrice!.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.appTextPrimary,
                    ),
                  ),
                  if (widget.changePercent != null) ...[
                    const SizedBox(width: 8),
                    ReturnBadge(
                      value: widget.changePercent,
                      size: ReturnBadgeSize.small,
                      colorScheme: ReturnBadgeColorScheme.redBlue,
                      decimals: 2,
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 20),

            // 매수/매도 토글
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.isDarkMode ? context.appSurface : AppColors.gray100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isBuy = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isBuy ? AppColors.buyAction : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '매수',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _isBuy ? Colors.white : context.appTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isBuy = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isBuy ? AppColors.sellAction : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '매도',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: !_isBuy ? Colors.white : context.appTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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

            // 가격 입력
            HoldingInputField(
              label: '단가 (USD)',
              controller: _priceController,
              prefix: '\$',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // 수량 입력 (스텝퍼)
            Row(
              children: [
                Text(
                  '수량 (주)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.appTextSecondary,
                  ),
                ),
                if (!_isBuy) ...[
                  const SizedBox(width: 8),
                  Text(
                    '보유: ${widget.holding.quantity.toStringAsFixed(widget.holding.quantity == widget.holding.quantity.roundToDouble() ? 0 : 2)}주',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
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
                    onChanged: (_) {
                      // 매도 시 보유 수량 초과 방지
                      if (!_isBuy) {
                        final entered = double.tryParse(_sharesController.text) ?? 0;
                        if (entered > widget.holding.quantity) {
                          final max = widget.holding.quantity.toDouble();
                          _sharesController.text = max == max.roundToDouble()
                              ? max.toInt().toString()
                              : max.toStringAsFixed(2);
                          _sharesController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _sharesController.text.length),
                          );
                        }
                      }
                      setState(() {});
                    },
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
                    var newVal = current + 1;
                    // 매도 시 보유 수량 초과 방지
                    if (!_isBuy && newVal > widget.holding.quantity) {
                      newVal = widget.holding.quantity.toDouble();
                    }
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
            if (!_isBuy) ...[
              HoldingInputField(
                label: '기준환율 (₩/\$)',
                controller: _exchangeRateController,
                prefix: '₩',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
            ],

            // 금액 표시
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
                    '${formatKrwWithComma(amountKrw)}원',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isBuy
                        ? '(매입환율: \u20a9${exchangeRate.toStringAsFixed(0)}/\$)'
                        : '(기준환율: \u20a9${exchangeRate.toStringAsFixed(0)}/\$)',
                    style: TextStyle(fontSize: 11, color: context.appTextHint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 실현손익 입력 (매도 시에만 표시)
            if (!_isBuy && _price > 0 && _shares > 0) ...[
              HoldingInputField(
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

            // 메모
            HoldingInputField(
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
                onPressed: _price > 0 && _shares > 0 ? _saveTransaction : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isBuy ? AppColors.buyAction : AppColors.sellAction,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isBuy ? '매수 기록 저장' : '매도 기록 저장',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveTransaction() async {
    try {
      if (_isBuy) {
        await ref.read(holdingListProvider.notifier).recordPurchase(
              holdingId: widget.holding.id,
              price: _price,
              shares: _shares,
              date: _selectedDate,
              note: _noteController.text.isEmpty ? null : _noteController.text,
            );
      } else {
        final manualPnl = double.tryParse(_realizedPnlController.text);
        await ref.read(holdingListProvider.notifier).recordSale(
              holdingId: widget.holding.id,
              price: _price,
              shares: _shares,
              date: _selectedDate,
              sellExchangeRate: _sellExchangeRate > 0 ? _sellExchangeRate : null,
              realizedPnlKrw: manualPnl,
              note: _noteController.text.isEmpty ? null : _noteController.text,
            );
      }

      // 거래 내역 리프레시
      refreshTransactions(ref);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isBuy ? '매수 기록이 저장되었습니다' : '매도 기록이 저장되었습니다'),
            backgroundColor: _isBuy ? AppColors.buyAction : AppColors.sellAction,
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
