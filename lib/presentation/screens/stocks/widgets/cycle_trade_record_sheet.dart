import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/krw_formatter.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../data/models/cycle.dart';
import '../../../../data/models/trade.dart';
import '../../../widgets/common/date_picker_field.dart';
import '../../../widgets/cycle/signal_display.dart';
import '../../../widgets/shared/return_badge.dart';
import '../../../widgets/shared/signal_badge_config.dart';
import 'cycle_trade_card.dart';

/// 사이클 거래 기록 풀스크린 시트
///
/// 보유(Holding)의 TradeRecordSheet 패턴을 따르되,
/// 사이클 전용 신호 시스템과 잔여현금/추가자금 로직을 포함합니다.
class CycleTradeRecordSheet extends ConsumerStatefulWidget {
  final Cycle cycle;
  final double currentExchangeRate;
  final double? currentPrice;
  final double? changePercent;
  final TradeSignal currentSignal;
  final double? signalAmount;

  /// 수정 모드: 기존 거래 전달 시 필드를 프리필
  final Trade? editingTrade;

  /// 수정 모드 헤더 타이틀 (예: '매수 기록 수정')
  final String? editTitle;

  /// 저장 콜백
  final void Function({
    required bool isBuy,
    required TradeSignal signal,
    required double price,
    required double shares,
    required double exchangeRate,
    required DateTime date,
    String? memo,
    double extraFundingAmount,
  }) onSubmit;

  const CycleTradeRecordSheet({
    super.key,
    required this.cycle,
    required this.currentExchangeRate,
    this.currentPrice,
    this.changePercent,
    required this.currentSignal,
    this.signalAmount,
    this.editingTrade,
    this.editTitle,
    required this.onSubmit,
  });

  @override
  ConsumerState<CycleTradeRecordSheet> createState() =>
      _CycleTradeRecordSheetState();
}

class _CycleTradeRecordSheetState
    extends ConsumerState<CycleTradeRecordSheet> {
  bool _isBuy = true;
  late DateTime _selectedDate;
  late TradeSignal _selectedSignal;

  final _priceController = TextEditingController();
  final _sharesController = TextEditingController();
  final _memoController = TextEditingController();

  bool _extraFunding = false;
  bool _isSubmitting = false;
  bool _signalExpanded = false;

  double get _price => double.tryParse(_priceController.text) ?? 0;
  double get _shares => double.tryParse(_sharesController.text) ?? 0;

  List<TradeSignal> get _currentSignals => _isBuy
      ? CycleTradeCard.buySignalsFor(widget.cycle.strategyType)
      : CycleTradeCard.sellSignalsFor(widget.cycle.strategyType);

  bool get _isEditing => widget.editingTrade != null;

  @override
  void initState() {
    super.initState();

    final editing = widget.editingTrade;
    if (editing != null) {
      // ── 수정 모드: 기존 거래 값으로 프리필 ──
      _isBuy = editing.action == TradeAction.buy;
      _selectedDate = editing.tradedAt;
      _selectedSignal = editing.signal;
      _priceController.text = editing.price.toStringAsFixed(2);
      final shares = editing.shares;
      _sharesController.text = shares == shares.roundToDouble()
          ? shares.toInt().toString()
          : shares.toStringAsFixed(2);
      _memoController.text = editing.memo ?? '';
    } else {
      // ── 신규 모드 ──
      _selectedDate = DateTime.now();

      // 현재 신호가 매수 관련이면 매수탭 + 해당 신호 프리셀렉트
      final sig = widget.currentSignal;
      if (_isBuySignal(sig)) {
        _isBuy = true;
        _selectedSignal = sig;
      } else if (_isSellSignal(sig)) {
        _isBuy = false;
        _selectedSignal = sig;
      } else {
        _selectedSignal =
            CycleTradeCard.buySignalsFor(widget.cycle.strategyType).first;
      }
    }
  }

  bool _isBuySignal(TradeSignal s) =>
      CycleTradeCard.buySignalsFor(widget.cycle.strategyType).contains(s);

  bool _isSellSignal(TradeSignal s) =>
      CycleTradeCard.sellSignalsFor(widget.cycle.strategyType).contains(s);

  @override
  void dispose() {
    _priceController.dispose();
    _sharesController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exchangeRate = widget.currentExchangeRate;
    final amountKrw = _price * _shares * exchangeRate;

    final exceedsRemaining =
        _isBuy && amountKrw > 0 && amountKrw > widget.cycle.remainingCash && !_extraFunding;

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
            // ═══ 헤더: 티커 + 닫기 ═══
            _buildHeader(context),
            const SizedBox(height: 4),

            // ═══ 현재가 + 등락률 (수정 모드에서는 숨김) ═══
            if (!_isEditing && widget.currentPrice != null) ...[
              _buildCurrentPrice(context),
              const SizedBox(height: 16),
            ] else if (!_isEditing)
              const SizedBox(height: 12),

            // ═══ 신호 가이드 카드 (수정 모드에서는 숨김, hold이 아닐 때만) ═══
            if (!_isEditing && widget.currentSignal != TradeSignal.hold) ...[
              SignalDisplay(
                signal: widget.currentSignal,
                size: SignalDisplaySize.large,
                amount: widget.signalAmount,
              ),
              const SizedBox(height: 16),
            ],

            // ═══ 매수/매도 토글 (수정 모드에서는 비활성) ═══
            _buildToggle(context),
            const SizedBox(height: 20),

            // ═══ 거래일 ═══
            DatePickerField(
              label: '거래일',
              selectedDate: _selectedDate,
              onDateChanged: (date) => setState(() => _selectedDate = date),
            ),
            const SizedBox(height: 16),

            // ═══ 단가 입력 ═══
            _buildLabeledInput(
              context,
              label: '단가 (USD)',
              controller: _priceController,
              prefix: '\$',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
            ),
            const SizedBox(height: 16),

            // ═══ 수량 스텝퍼 ═══
            _buildSharesStepper(context),
            const SizedBox(height: 16),

            // ═══ 신호 선택 (접이식) ═══
            _buildSignalSection(context),
            const SizedBox(height: 16),

            // ═══ 거래 금액 표시 ═══
            _buildAmountDisplay(context, amountKrw, exchangeRate),
            const SizedBox(height: 12),

            // ═══ 매수: 잔여현금 + 추가자금 / 매도: 보유수량 ═══
            if (_isBuy) ...[
              _buildBuyHelpers(context, amountKrw, exceedsRemaining),
            ],

            // ═══ 메모 ═══
            const SizedBox(height: 4),
            _buildLabeledInput(
              context,
              label: '메모 (선택)',
              controller: _memoController,
              keyboardType: TextInputType.text,
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // ═══ 저장 버튼 ═══
            _buildSaveButton(context, exceedsRemaining),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 헤더
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.editTitle ?? '${widget.cycle.ticker} 거래 기록',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.appTextPrimary,
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: context.appTextSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 현재가 + 등락률
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCurrentPrice(BuildContext context) {
    return Row(
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
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 매수/매도 토글 (보유 상세 패턴)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildToggle(BuildContext context) {
    return Opacity(
      opacity: _isEditing ? 0.6 : 1.0,
      child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.isDarkMode ? context.appSurface : AppColors.gray100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _isEditing ? null : () {
                if (!_isBuy) {
                  setState(() {
                    _isBuy = true;
                    // 매수 신호 리스트의 첫 번째로 리셋
                    final buySignals = CycleTradeCard.buySignalsFor(
                        widget.cycle.strategyType);
                    if (!buySignals.contains(_selectedSignal)) {
                      _selectedSignal = buySignals.first;
                    }
                  });
                }
              },
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
                    color:
                        _isBuy ? Colors.white : context.appTextSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _isEditing ? null : () {
                if (_isBuy) {
                  setState(() {
                    _isBuy = false;
                    // 매도 신호 리스트의 첫 번째로 리셋
                    final sellSignals = CycleTradeCard.sellSignalsFor(
                        widget.cycle.strategyType);
                    if (!sellSignals.contains(_selectedSignal)) {
                      _selectedSignal = sellSignals.first;
                    }
                    // 매도 시 보유 수량 초과 방지
                    final entered =
                        double.tryParse(_sharesController.text) ?? 0;
                    if (entered > widget.cycle.totalShares) {
                      final max = widget.cycle.totalShares;
                      _sharesController.text = max == max.roundToDouble()
                          ? max.toInt().toString()
                          : max.toStringAsFixed(2);
                    }
                  });
                }
              },
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
                    color:
                        !_isBuy ? Colors.white : context.appTextSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 수량 스텝퍼
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSharesStepper(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            if (!_isBuy && widget.cycle.totalShares > 0) ...[
              const SizedBox(width: 8),
              Text(
                '보유: ${formatShares(widget.cycle.totalShares)}주',
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
                final current =
                    double.tryParse(_sharesController.text) ?? 0;
                if (current > 0) {
                  final newVal = (current - 1).clamp(0.0, double.infinity);
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
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d*')),
                ],
                onChanged: (_) {
                  // 매도 시 보유 수량 초과 방지
                  if (!_isBuy) {
                    final entered =
                        double.tryParse(_sharesController.text) ?? 0;
                    if (entered > widget.cycle.totalShares) {
                      final max = widget.cycle.totalShares;
                      _sharesController.text =
                          max == max.roundToDouble()
                              ? max.toInt().toString()
                              : max.toStringAsFixed(2);
                      _sharesController.selection =
                          TextSelection.fromPosition(
                        TextPosition(
                            offset: _sharesController.text.length),
                      );
                    }
                  }
                  setState(() {});
                },
                style: TextStyle(color: context.appTextPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.appSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _StepperButton(
              icon: Icons.add,
              onTap: () {
                final current =
                    double.tryParse(_sharesController.text) ?? 0;
                var newVal = current + 1;
                // 매도 시 보유 수량 초과 방지
                if (!_isBuy && newVal > widget.cycle.totalShares) {
                  newVal = widget.cycle.totalShares;
                }
                _sharesController.text = newVal == newVal.roundToDouble()
                    ? newVal.toInt().toString()
                    : newVal.toStringAsFixed(2);
                setState(() {});
              },
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 신호 선택 (접이식)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSignalSection(BuildContext context) {
    final config = SignalBadgeConfig.fromSignal(_selectedSignal);

    if (!_signalExpanded) {
      // ── 접힌 상태: 선택된 신호 배지 + [변경] 버튼 ──
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              '신호:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: config.color.withValues(
                  alpha: context.isDarkMode ? 0.25 : 0.15,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: config.color, width: 1),
              ),
              child: Text(
                config.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: config.color,
                ),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _signalExpanded = true),
              child: Text(
                '변경',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appAccent,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── 펼친 상태: 칩 선택 + [접기] 버튼 ──
    final signals = _currentSignals;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '신호 선택',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appTextSecondary,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _signalExpanded = false),
                child: Text(
                  '접기',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: signals.map((signal) {
              final isSelected = _selectedSignal == signal;
              final chipConfig = SignalBadgeConfig.fromSignal(signal);

              return ChoiceChip(
                label: Text(chipConfig.label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedSignal = signal;
                      _signalExpanded = false;
                    });
                  }
                },
                selectedColor: chipConfig.color.withValues(
                  alpha: context.isDarkMode ? 0.25 : 0.15,
                ),
                backgroundColor: context.appBackground,
                side: BorderSide(
                  color: isSelected ? chipConfig.color : context.appBorder,
                  width: isSelected ? 1.5 : 0.5,
                ),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? chipConfig.color
                      : context.appTextSecondary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 2),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 거래 금액 표시
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAmountDisplay(
      BuildContext context, double amountKrw, double exchangeRate) {
    return Container(
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
            '(환율: ₩${exchangeRate.toStringAsFixed(0)}/\$)',
            style: TextStyle(fontSize: 11, color: context.appTextHint),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 매수 헬퍼 (잔여현금 + 추가자금 토글)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBuyHelpers(BuildContext context, double amountKrw,
      bool exceedsRemaining) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 잔여현금 표시
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            _extraFunding
                ? '시드가 자동으로 증가합니다'
                : '잔여현금: ${formatKrwWithComma(widget.cycle.remainingCash)}원',
            style: TextStyle(
              fontSize: 12,
              color: _extraFunding
                  ? AppColors.amber500
                  : (exceedsRemaining
                      ? AppColors.red500
                      : context.appTextHint),
            ),
          ),
        ),
        if (exceedsRemaining) ...[
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '잔여현금(${formatKrwWithComma(widget.cycle.remainingCash)}원)을 초과합니다',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.red500,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        // 추가 자금 투입 토글
        Row(
          children: [
            SizedBox(
              width: 42,
              height: 28,
              child: FittedBox(
                child: Switch(
                  value: _extraFunding,
                  onChanged: (val) => setState(() => _extraFunding = val),
                  activeColor: AppColors.amber500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '추가 자금 투입',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _extraFunding
                      ? context.appTextPrimary
                      : context.appTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 저장 버튼
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSaveButton(BuildContext context, bool exceedsRemaining) {
    final canSave = _price > 0 && _shares > 0 &&
        !_isSubmitting && !exceedsRemaining;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: canSave ? _onSubmit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isBuy ? AppColors.buyAction : AppColors.sellAction,
          disabledBackgroundColor: context.appBorder,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          _isSubmitting
              ? '처리 중...'
              : _isEditing
                  ? '수정'
                  : (_isBuy ? '매수 기록 저장' : '매도 기록 저장'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 입력 필드 빌더
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLabeledInput(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    String? prefix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
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
          inputFormatters: inputFormatters,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: context.appTextPrimary),
          decoration: InputDecoration(
            prefixText: prefix,
            filled: true,
            fillColor: context.appSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 제출
  // ═══════════════════════════════════════════════════════════════

  void _onSubmit() {
    if (_price <= 0) {
      _showError('단가를 올바르게 입력하세요');
      return;
    }
    if (_shares <= 0) {
      _showError('수량을 올바르게 입력하세요');
      return;
    }

    final exchangeRate = widget.currentExchangeRate;

    if (_isBuy) {
      final amountKrw = _price * _shares * exchangeRate;
      // 추가 자금 미사용 시 잔여현금 초과 차단
      if (!_extraFunding && amountKrw > widget.cycle.remainingCash) {
        _showError(
            '잔여현금(${formatKrwWithComma(widget.cycle.remainingCash)}원)을 초과합니다');
        return;
      }

      double extraAmount = 0;
      if (_extraFunding && amountKrw > widget.cycle.remainingCash) {
        extraAmount = amountKrw - widget.cycle.remainingCash;
      }

      setState(() => _isSubmitting = true);
      widget.onSubmit(
        isBuy: true,
        signal: _selectedSignal,
        price: _price,
        shares: _shares,
        exchangeRate: exchangeRate,
        date: _selectedDate,
        memo: _memoController.text.isEmpty ? null : _memoController.text,
        extraFundingAmount: extraAmount,
      );
    } else {
      // 매도 시 보유 수량 초과 차단
      if (_shares > widget.cycle.totalShares) {
        _showError(
            '보유수량(${formatShares(widget.cycle.totalShares)}주)을 초과합니다');
        return;
      }

      setState(() => _isSubmitting = true);
      widget.onSubmit(
        isBuy: false,
        signal: _selectedSignal,
        price: _price,
        shares: _shares,
        exchangeRate: exchangeRate,
        date: _selectedDate,
        memo: _memoController.text.isEmpty ? null : _memoController.text,
        extraFundingAmount: 0,
      );
    }

    Navigator.of(context).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
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
