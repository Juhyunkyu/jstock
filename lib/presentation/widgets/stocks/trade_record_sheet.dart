import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../data/models/trade.dart';

// ═══════════════════════════════════════════════════════════════
// 신호 배지 설정 (공유 유틸)
// ═══════════════════════════════════════════════════════════════

class SignalBadgeConfig {
  final String label;
  final Color color;

  const SignalBadgeConfig({required this.label, required this.color});

  /// 전체 신호에 대한 배지 설정 반환
  static SignalBadgeConfig fromSignal(TradeSignal signal) {
    switch (signal) {
      case TradeSignal.initial:
        return SignalBadgeConfig(label: '초기진입', color: AppColors.green600);
      case TradeSignal.weightedBuy:
        return SignalBadgeConfig(label: '가중매수', color: AppColors.blue500);
      case TradeSignal.panicBuy:
        return SignalBadgeConfig(label: '승부수', color: AppColors.red500);
      case TradeSignal.cashSecure:
        return SignalBadgeConfig(label: '현금확보', color: AppColors.amber500);
      case TradeSignal.takeProfit:
        return SignalBadgeConfig(label: '익절', color: AppColors.green500);
      case TradeSignal.locAB:
        return SignalBadgeConfig(label: 'LOC A+B', color: AppColors.blue500);
      case TradeSignal.locA:
        return SignalBadgeConfig(label: 'LOC A', color: AppColors.blue500);
      case TradeSignal.locB:
        return SignalBadgeConfig(label: 'LOC B', color: AppColors.blue400);
      case TradeSignal.manual:
        return SignalBadgeConfig(label: '수동', color: AppColors.gray500);
      case TradeSignal.hold:
        return SignalBadgeConfig(label: '대기', color: AppColors.gray400);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// 매수/매도 기록 BottomSheet
// ═══════════════════════════════════════════════════════════════

class TradeRecordSheet extends StatefulWidget {
  final String title;
  final TradeAction action;
  final String cycleId;
  final List<TradeSignal> signals;
  final double exchangeRate;
  final double? maxCash;
  final double? maxShares;

  /// 신호 버튼에서 진입 시 미리 선택된 신호
  final TradeSignal? preSelectedSignal;

  /// 신호 버튼에서 진입 시 미리 채워질 금액 (KRW)
  final double? preFilledAmount;

  /// 편집 모드: 기존 거래 데이터 (null이면 신규 기록)
  final Trade? editingTrade;

  /// 매수/매도 기록 콜백
  /// [extraFundingAmount] > 0 이면 시드 증가 필요 (추가 자금 투입)
  final void Function(
    TradeSignal signal,
    double price,
    double? amountKrw,
    double? shares,
    double exchangeRate,
    String? memo, {
    double extraFundingAmount,
  }) onSubmit;

  const TradeRecordSheet({
    super.key,
    required this.title,
    required this.action,
    required this.cycleId,
    required this.signals,
    required this.exchangeRate,
    this.maxCash,
    this.maxShares,
    this.preSelectedSignal,
    this.preFilledAmount,
    this.editingTrade,
    required this.onSubmit,
  });

  @override
  State<TradeRecordSheet> createState() => TradeRecordSheetState();
}

class TradeRecordSheetState extends State<TradeRecordSheet> {
  late TradeSignal _selectedSignal;
  final _priceController = TextEditingController();
  final _amountController = TextEditingController();
  final _sharesController = TextEditingController();
  final _exchangeRateController = TextEditingController();
  final _memoController = TextEditingController();
  bool _isSubmitting = false;
  bool _extraFunding = false;

  /// 신호가 미리 선택되어 변경 불가 여부
  bool get _isSignalLocked => widget.preSelectedSignal != null;

  bool get _isBuy => widget.action == TradeAction.buy;

  bool get _isEditing => widget.editingTrade != null;

  @override
  void initState() {
    super.initState();

    final editing = widget.editingTrade;
    if (editing != null) {
      // 편집 모드: 기존 거래 데이터로 필드 채우기
      _selectedSignal = editing.signal;
      _priceController.text = editing.price.toStringAsFixed(2);
      _exchangeRateController.text = editing.exchangeRate.toStringAsFixed(2);
      _memoController.text = editing.memo ?? '';
      if (editing.action == TradeAction.buy) {
        _amountController.text = editing.amountKrw.round().toString();
      } else {
        _sharesController.text = editing.shares % 1 == 0
            ? editing.shares.round().toString()
            : editing.shares.toStringAsFixed(2);
      }
    } else {
      // 신규 기록 모드
      _selectedSignal = widget.preSelectedSignal ?? widget.signals.first;
      _exchangeRateController.text = widget.exchangeRate.toStringAsFixed(2);

      // 미리 채워진 금액이 있으면 설정
      if (widget.preFilledAmount != null && widget.preFilledAmount! > 0) {
        _amountController.text = widget.preFilledAmount!.round().toString();
      }
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _amountController.dispose();
    _sharesController.dispose();
    _exchangeRateController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 핸들바
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appDivider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 타이틀
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // 신호 선택
              Text(
                '신호',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _buildSignalSelector(context),
              const SizedBox(height: 16),

              // 체결가
              _buildTextField(
                context,
                label: '체결가 (USD)',
                controller: _priceController,
                prefix: '\$',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
              ),
              const SizedBox(height: 12),

              // 매수: 금액 / 매도: 수량
              if (_isBuy)
                _buildBuyAmountSection(context)
              else
                _buildTextField(
                  context,
                  label: '수량 (주)',
                  controller: _sharesController,
                  suffix: '주',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  helperText: widget.maxShares != null
                      ? '보유수량: ${formatShares(widget.maxShares!)}주'
                      : null,
                ),
              const SizedBox(height: 12),

              // 환율
              _buildTextField(
                context,
                label: '환율 (USD/KRW)',
                controller: _exchangeRateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
              ),
              const SizedBox(height: 12),

              // 메모
              _buildTextField(
                context,
                label: '메모 (선택)',
                controller: _memoController,
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 24),

              // 기록 버튼
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _isBuy ? AppColors.red500 : AppColors.blue500,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isSubmitting ? '처리 중...' : (_isEditing ? '수정' : '기록'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 매수 금액 섹션 (잔여현금 제한 + 추가 자금 토글)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBuyAmountSection(BuildContext context) {
    final enteredAmount = double.tryParse(_amountController.text) ?? 0;
    final hasMaxCash = widget.maxCash != null;
    final exceedsRemaining =
        hasMaxCash && enteredAmount > widget.maxCash! && !_extraFunding;

    // 헬퍼 텍스트 결정
    String? helperText;
    Color? helperColor;
    if (hasMaxCash) {
      if (_extraFunding) {
        helperText = '시드가 자동으로 증가합니다';
        helperColor = AppColors.amber500;
      } else {
        helperText =
            '잔여현금: ${formatKrwWithComma(widget.maxCash!)}\u2009원';
        helperColor = exceedsRemaining
            ? AppColors.red500
            : context.appTextHint;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          context,
          label: '금액 (KRW)',
          controller: _amountController,
          suffix: '원',
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          helperText: helperText,
          helperColor: helperColor,
          errorText: exceedsRemaining
              ? '잔여현금(${formatKrwWithComma(widget.maxCash!)}\u2009원)을 초과합니다'
              : null,
          onChanged: (_) => setState(() {}),
        ),
        // 추가 자금 투입 토글 (잔여현금 제한이 있을 때만 표시)
        if (hasMaxCash) ...[
          const SizedBox(height: 8),
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
      ],
    );
  }

  Widget _buildSignalSelector(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.signals.map((signal) {
        final isSelected = _selectedSignal == signal;
        final config = SignalBadgeConfig.fromSignal(signal);

        return ChoiceChip(
          label: Text(config.label),
          selected: isSelected,
          onSelected: _isSignalLocked
              ? null
              : (selected) {
                  if (selected) setState(() => _selectedSignal = signal);
                },
          selectedColor: config.color.withValues(
            alpha: context.isDarkMode ? 0.25 : 0.15,
          ),
          backgroundColor: context.appBackground,
          side: BorderSide(
            color: isSelected
                ? config.color
                : context.appBorder,
            width: isSelected ? 1.5 : 0.5,
          ),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? config.color : context.appTextSecondary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        );
      }).toList(),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    String? prefix,
    String? suffix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? helperText,
    Color? helperColor,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 16,
            color: context.appTextPrimary,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              fontSize: 14,
              color: context.appTextHint,
            ),
            prefixText: prefix,
            prefixStyle: TextStyle(
              fontSize: 16,
              color: context.appTextPrimary,
            ),
            suffixText: suffix,
            suffixStyle: TextStyle(
              fontSize: 14,
              color: context.appTextHint,
            ),
            filled: true,
            fillColor: context.appBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.appBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError ? AppColors.red500 : context.appBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError ? AppColors.red500 : context.appAccent,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              errorText,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.red500,
              ),
            ),
          ),
        ] else if (helperText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              helperText,
              style: TextStyle(
                fontSize: 12,
                color: helperColor ?? context.appTextHint,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _onSubmit() {
    final price = double.tryParse(_priceController.text);
    final exchangeRate = double.tryParse(_exchangeRateController.text);

    if (price == null || price <= 0) {
      _showError('체결가를 올바르게 입력하세요');
      return;
    }

    if (exchangeRate == null || exchangeRate <= 0) {
      _showError('환율을 올바르게 입력하세요');
      return;
    }

    if (_isBuy) {
      final amount = double.tryParse(_amountController.text);
      if (amount == null || amount <= 0) {
        _showError('금액을 올바르게 입력하세요');
        return;
      }
      // 추가 자금 미사용 시 잔여현금 초과 차단
      if (!_extraFunding &&
          widget.maxCash != null &&
          amount > widget.maxCash!) {
        _showError(
            '잔여현금(${formatKrwWithComma(widget.maxCash!)}\u2009원)을 초과합니다');
        return;
      }

      // 추가 자금 투입 금액 계산
      double extraAmount = 0;
      if (_extraFunding && widget.maxCash != null && amount > widget.maxCash!) {
        extraAmount = amount - widget.maxCash!;
      }

      setState(() => _isSubmitting = true);
      widget.onSubmit(
        _selectedSignal,
        price,
        amount,
        null,
        exchangeRate,
        _memoController.text.isEmpty ? null : _memoController.text,
        extraFundingAmount: extraAmount,
      );
    } else {
      final shares = double.tryParse(_sharesController.text);
      if (shares == null || shares <= 0) {
        _showError('수량을 올바르게 입력하세요');
        return;
      }
      if (widget.maxShares != null && shares > widget.maxShares!) {
        _showError(
            '보유수량(${formatShares(widget.maxShares!)}주)을 초과합니다');
        return;
      }

      setState(() => _isSubmitting = true);
      widget.onSubmit(
        _selectedSignal,
        price,
        null,
        shares,
        exchangeRate,
        _memoController.text.isEmpty ? null : _memoController.text,
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
