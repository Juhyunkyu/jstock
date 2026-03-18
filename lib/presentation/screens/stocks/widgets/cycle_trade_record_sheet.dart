import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/korean_number_formatter.dart';
import '../../../../core/utils/krw_formatter.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../data/models/cycle.dart';
import '../../../../data/models/trade.dart';
import '../../../../domain/trading/alpha_cycle_service.dart';
import '../../../../domain/trading/steady_order_guide.dart';
import '../../../../domain/trading/trading_math.dart';
import '../../../providers/providers.dart';
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

  /// 매수/매도 탭 전환 시 이전 신호를 기억
  TradeSignal? _lastBuySignal;
  TradeSignal? _lastSellSignal;

  final _priceController = TextEditingController();
  final _sharesController = TextEditingController();
  final _memoController = TextEditingController();

  // V2.2/V3.0 전반전 A/B 분리 입력
  final _priceAController = TextEditingController();
  final _sharesAController = TextEditingController();
  final _priceBController = TextEditingController();
  final _sharesBController = TextEditingController();

  bool _extraFunding = false;
  bool _isSubmitting = false;
  bool _signalExpanded = false;

  double get _price => double.tryParse(_priceController.text) ?? 0;
  double get _shares => double.tryParse(_sharesController.text) ?? 0;

  double get _priceA => double.tryParse(_priceAController.text) ?? 0;
  double get _sharesA => double.tryParse(_sharesAController.text) ?? 0;
  double get _priceB => double.tryParse(_priceBController.text) ?? 0;
  double get _sharesB => double.tryParse(_sharesBController.text) ?? 0;

  /// V2.2/V3.0 전반전 LOC A+B → 분리 입력 모드 여부
  bool get _isSplitMode =>
      _isBuy &&
      _selectedSignal == TradeSignal.locAB &&
      widget.cycle.strategyType == StrategyType.infiniteBuy &&
      widget.cycle.steadyVersion != SteadyVersion.v1;

  List<TradeSignal> get _currentSignals => _isBuy
      ? CycleTradeCard.buySignalsFor(widget.cycle.strategyType, steadyVersion: widget.cycle.steadyVersion)
      : CycleTradeCard.sellSignalsFor(widget.cycle.strategyType, steadyVersion: widget.cycle.steadyVersion);

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
            CycleTradeCard.buySignalsFor(widget.cycle.strategyType, steadyVersion: widget.cycle.steadyVersion).first;
      }
    }
  }

  bool _isBuySignal(TradeSignal s) =>
      CycleTradeCard.buySignalsFor(widget.cycle.strategyType, steadyVersion: widget.cycle.steadyVersion).contains(s);

  bool _isSellSignal(TradeSignal s) =>
      CycleTradeCard.sellSignalsFor(widget.cycle.strategyType, steadyVersion: widget.cycle.steadyVersion).contains(s);

  @override
  void dispose() {
    _priceController.dispose();
    _sharesController.dispose();
    _memoController.dispose();
    _priceAController.dispose();
    _sharesAController.dispose();
    _priceBController.dispose();
    _sharesBController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exchangeRate = widget.currentExchangeRate;
    // Combined amount calculation
    final double amountKrw;
    if (_isSplitMode) {
      amountKrw = (_priceA * _sharesA + _priceB * _sharesB) * exchangeRate;
    } else {
      amountKrw = _price * _shares * exchangeRate;
    }

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
            // ═══ 1. 헤더: 티커 + 닫기 ═══
            _buildHeader(context),
            const SizedBox(height: 4),

            // ═══ 2. 현재가 + 등락률 (수정 모드에서는 숨김) ═══
            if (!_isEditing && widget.currentPrice != null) ...[
              _buildCurrentPrice(context),
              const SizedBox(height: 12),
            ] else if (!_isEditing)
              const SizedBox(height: 8),

            // ═══ 2.5. 주문 가이드 요약 (V2.2/V3.0 Steady만) ═══
            if (widget.cycle.strategyType == StrategyType.infiniteBuy &&
                widget.cycle.steadyVersion != SteadyVersion.v1) ...[
              _buildGuideSummary(context, ref),
              const SizedBox(height: 12),
            ],

            // ═══ 3. 거래일 (한 줄 Row) ═══
            _buildInlineDatePicker(context),
            const SizedBox(height: 12),

            // ═══ 4. 매수/매도 토글 (수정 모드에서는 비활성) ═══
            _buildToggle(context),
            const SizedBox(height: 12),

            // ═══ 5. 신호 선택 (토글 바로 아래) ═══
            _buildSignalSection(context),
            const SizedBox(height: 12),

            // ═══ 6. 매수 추천 가이드 (Smart Cycle only) ═══
            if (_showBuyGuide)
              _buildBuyGuide(context, exchangeRate),

            // ═══ 7-8. 단가/수량 입력 (V2.2/V3.0 A/B 분리 또는 기존 단일) ═══
            if (_isSplitMode)
              _buildSplitInputs(context)
            else ...[
              _buildInlinePriceInput(context),
              const SizedBox(height: 12),
              _buildInlineSharesStepper(context),
            ],
            const SizedBox(height: 12),

            // ═══ 9. 거래 금액 + 잔여현금/추가자금 통합 ═══
            _buildAmountSection(context, amountKrw, exchangeRate, exceedsRemaining),
            const SizedBox(height: 12),

            // ═══ 10. 메모 ═══
            _buildLabeledInput(
              context,
              label: '메모 (선택)',
              controller: _memoController,
              keyboardType: TextInputType.text,
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // ═══ 11. 저장 버튼 ═══
            _buildSaveButton(context, exceedsRemaining),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 매수 신호별 추천 가이드 (Smart Cycle)
  // ═══════════════════════════════════════════════════════════════

  /// Smart Cycle + 매수탭 + 신규모드 + 가이드 대상 신호일 때 표시
  bool get _showBuyGuide {
    if (_isEditing || !_isBuy) return false;
    if (widget.cycle.strategyType != StrategyType.alphaCycleV3) return false;

    switch (_selectedSignal) {
      case TradeSignal.initial:
        return true;
      case TradeSignal.weightedBuy:
      case TradeSignal.panicBuy:
        // entryPrice가 없으면 가중매수/승부수 가이드 불가
        final ep = widget.cycle.entryPrice;
        return ep != null && ep > 0;
      default:
        return false;
    }
  }

  /// 신호별 추천 금액(KRW)과 설명 라벨 계산
  ({double amount, String label, String title}) _buyGuideInfo() {
    final cycle = widget.cycle;
    final currentPrice = widget.currentPrice ?? 0;
    final exchangeRate = widget.currentExchangeRate;

    switch (_selectedSignal) {
      case TradeSignal.initial:
        final amount = cycle.seedAmount * cycle.initialEntryRatio;
        final ratioPercent =
            (cycle.initialEntryRatio * 100).toStringAsFixed(0);
        return (
          amount: amount,
          label: '시드의 $ratioPercent%',
          title: '초기 진입 추천',
        );

      case TradeSignal.weightedBuy:
        final loss = AlphaCycleService.lossRate(currentPrice, cycle.entryPrice);
        final perPercent = cycle.effectiveWeightedBuyPerPercent;
        final amount = AlphaCycleService.weightedBuyAmount(
          lossRate: loss,
          weightedBuyPerPercent: perPercent,
        );
        final lossStr = loss.abs().toStringAsFixed(1);
        return (
          amount: amount,
          label: '손실률 $lossStr% × ${formatKoreanAmountShort(perPercent)}/1%',
          title: '가중 매수 추천',
        );

      case TradeSignal.panicBuy:
        final evalAmount = TradingMath.evaluatedAmount(
          cycle.totalShares,
          currentPrice,
          exchangeRate,
        );
        final panicAmount = AlphaCycleService.panicBuyAmount(
          evaluatedAmount: evalAmount,
          panicBuyMultiplier: cycle.panicBuyMultiplier,
        );
        // 가중매수 금액도 합산
        final loss = AlphaCycleService.lossRate(currentPrice, cycle.entryPrice);
        final wbAmount = AlphaCycleService.weightedBuyAmount(
          lossRate: loss,
          weightedBuyPerPercent: cycle.effectiveWeightedBuyPerPercent,
        );
        final totalAmount = panicAmount + wbAmount;
        final multPercent =
            (cycle.panicBuyMultiplier * 100).toStringAsFixed(0);
        return (
          amount: totalAmount,
          label: '평가금의 $multPercent% + 가중매수',
          title: '승부수 추천',
        );

      default:
        return (amount: 0.0, label: '', title: '');
    }
  }

  Widget _buildBuyGuide(BuildContext context, double exchangeRate) {
    final info = _buyGuideInfo();
    final recommendedKrw = info.amount;

    // 단가 입력 시 추천 수량 계산
    final priceUsd = _price;
    final canCalcShares = priceUsd > 0 && exchangeRate > 0;
    final recommendedShares = canCalcShares
        ? (recommendedKrw / (priceUsd * exchangeRate)).floor()
        : 0;
    final actualKrw = recommendedShares * priceUsd * exchangeRate;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.appAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: context.appAccent.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 제목 (중앙정렬)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lightbulb_outline,
                    size: 16, color: context.appAccent),
                const SizedBox(width: 6),
                Text(
                  info.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 매수금액 (중앙)
            Text(
              '매수금액: ${formatKoreanAmountShort(recommendedKrw)}',
              style: TextStyle(
                fontSize: 13,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 2),
            // 설명 라벨 (중앙)
            Text(
              '(${info.label})',
              style: TextStyle(
                fontSize: 12,
                color: context.appTextSecondary,
              ),
            ),
            // 단가 입력 시 추천 수량
            if (canCalcShares && recommendedShares > 0) ...[
              const SizedBox(height: 6),
              Divider(height: 1, color: context.appAccent.withValues(alpha: 0.15)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '추천 수량: $recommendedShares주',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '≈ ${formatKoreanAmountShort(actualKrw)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // [적용] 버튼 (우측)
                  GestureDetector(
                    onTap: () {
                      _sharesController.text = recommendedShares.toString();
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.appAccent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '적용',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // _formatGuideAmount → korean_number_formatter.dart의 formatKoreanAmountShort() 사용

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
  // 주문 가이드 요약 (V2.2/V3.0 Steady)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildGuideSummary(BuildContext context, WidgetRef ref) {
    final guide = ref.watch(steadyOrderGuideProvider(widget.cycle.id));
    if (guide == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.appBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: context.appAccent),
              const SizedBox(width: 6),
              Text(
                'T: ${guide.tValue.toStringAsFixed(1)}  ${guide.isFirstHalf ? "전반전" : "후반전"}  오프셋 ${guide.locOffsetPercent >= 0 ? "+" : ""}${guide.locOffsetPercent.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appAccent),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 2-column layout
          Row(
            children: [
              // Left column: 매수
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (guide.buyOrderA != null)
                      _guideItem(context, '매수A', guide.buyOrderA!),
                    if (guide.buyOrderB != null)
                      _guideItem(context, '매수B', guide.buyOrderB!),
                    if (guide.buySingleOrder != null)
                      _guideItem(context, '매수', guide.buySingleOrder!),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right column: 매도
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (guide.sellLocOrder != null)
                      _guideItem(context, '매도¼', guide.sellLocOrder!),
                    if (guide.sellLimitOrder != null)
                      _guideItem(context, '매도¾', guide.sellLimitOrder!),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _guideItem(BuildContext context, String label, OrderItem order) {
    final intShares = order.shares.floor();
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '$label \$${order.price.toStringAsFixed(2)} × ${intShares}주 (${order.shares.toStringAsFixed(1)})',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.appTextPrimary),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 거래일 (한 줄 인라인)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildInlineDatePicker(BuildContext context) {
    return Row(
      children: [
        Text(
          '거래일',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.appTextSecondary,
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: () => _showDatePicker(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.appDivider, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: context.appAccent,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(_selectedDate),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: context.appTextHint,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final dateFormat = DateFormat('yyyy.MM.dd');
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[date.weekday - 1];
    return '${dateFormat.format(date)} ($weekday)';
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: today,
      locale: const Locale('ko', 'KR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: context.appTextPrimary,
              surface: context.appSurface,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: context.appSurface,
              headerBackgroundColor: AppColors.primary,
              headerForegroundColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() => _selectedDate = pickedDate);
    }
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
                    _lastSellSignal = _selectedSignal;
                    _isBuy = true;
                    final buySignals = CycleTradeCard.buySignalsFor(
                        widget.cycle.strategyType, steadyVersion: widget.cycle.steadyVersion);
                    _selectedSignal = (_lastBuySignal != null && buySignals.contains(_lastBuySignal!))
                        ? _lastBuySignal!
                        : buySignals.first;
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
                    _lastBuySignal = _selectedSignal;
                    _isBuy = false;
                    final sellSignals = CycleTradeCard.sellSignalsFor(
                        widget.cycle.strategyType, steadyVersion: widget.cycle.steadyVersion);
                    _selectedSignal = (_lastSellSignal != null && sellSignals.contains(_lastSellSignal!))
                        ? _lastSellSignal!
                        : sellSignals.first;
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
  // 단가 입력 (한 줄 인라인)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildInlinePriceInput(BuildContext context) {
    return Row(
      children: [
        Text(
          '단가 (USD)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _priceController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: context.appTextPrimary),
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              prefixText: '\$',
              filled: true,
              fillColor: context.appSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 수량 스텝퍼 (한 줄 인라인)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildInlineSharesStepper(BuildContext context) {
    return Row(
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
        const Spacer(),
        // 스텝퍼 ([-] [input] [+])
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
        const SizedBox(width: 6),
        SizedBox(
          width: 80,
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
                  horizontal: 8, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 6),
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
  // V2.2/V3.0 전반전 A/B 분리 입력
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSplitInputs(BuildContext context) {
    final guide = ref.watch(steadyOrderGuideProvider(widget.cycle.id));
    final exchangeRate = widget.currentExchangeRate;
    final isV3 = widget.cycle.steadyVersion == SteadyVersion.v3_0;

    // Labels
    final labelA = isV3 ? 'LOC A (오프셋)' : 'LOC A (평단)';
    final labelB = isV3 ? 'LOC B (평단)' : 'LOC B (오프셋)';

    final amountA = _priceA * _sharesA * exchangeRate;
    final amountB = _priceB * _sharesB * exchangeRate;
    final totalShares = _sharesA + _sharesB;
    final totalAmount = amountA + amountB;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LOC A
        _buildSplitRow(
          context,
          label: labelA,
          priceController: _priceAController,
          sharesController: _sharesAController,
          recommendedPrice: guide?.buyOrderA?.price,
          recommendedShares: guide?.buyOrderA?.shares,
        ),
        const SizedBox(height: 10),
        // LOC B
        _buildSplitRow(
          context,
          label: labelB,
          priceController: _priceBController,
          sharesController: _sharesBController,
          recommendedPrice: guide?.buyOrderB?.price,
          recommendedShares: guide?.buyOrderB?.shares,
        ),
        const SizedBox(height: 10),
        // Combined total
        if (totalShares > 0 || totalAmount > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.appAccent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '합계: ${totalShares.toStringAsFixed(totalShares == totalShares.roundToDouble() ? 0 : 2)}주',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                Text(
                  '${formatKrwWithComma(totalAmount)}원',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSplitRow(
    BuildContext context, {
    required String label,
    required TextEditingController priceController,
    required TextEditingController sharesController,
    double? recommendedPrice,
    double? recommendedShares,
  }) {
    final intShares = recommendedShares?.floor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.appAccent,
              ),
            ),
            if (recommendedPrice != null && recommendedShares != null) ...[
              const Spacer(),
              GestureDetector(
                onTap: () {
                  priceController.text = recommendedPrice.toStringAsFixed(2);
                  sharesController.text = intShares.toString();
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.appAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '추천 적용 $intShares주 (${recommendedShares.toStringAsFixed(1)})',
                    style: TextStyle(fontSize: 10, color: context.appAccent),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            // Price input
            Expanded(
              flex: 3,
              child: TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(
                    fontSize: 14,
                    color: context.appTextHint,
                  ),
                  hintText: '단가',
                  hintStyle: TextStyle(color: context.appTextHint, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  isDense: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: context.appBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: context.appAccent),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            // Shares input
            Expanded(
              flex: 2,
              child: TextField(
                controller: sharesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
                decoration: InputDecoration(
                  suffixText: '주',
                  suffixStyle: TextStyle(
                    fontSize: 14,
                    color: context.appTextHint,
                  ),
                  hintText: '수량',
                  hintStyle: TextStyle(color: context.appTextHint, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  isDense: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: context.appBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: context.appAccent),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 거래 금액 + 잔여현금/추가자금 통합 섹션
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAmountSection(BuildContext context, double amountKrw,
      double exchangeRate, bool exceedsRemaining) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 거래 금액
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

          // 매수일 때만: 잔여현금 + 추가자금 토글
          if (_isBuy) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: context.appDivider),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _extraFunding
                        ? '시드가 자동으로 증가합니다'
                        : exceedsRemaining
                            ? '잔여현금 초과!'
                            : '잔여현금: ${formatKrwWithComma(widget.cycle.remainingCash)}원',
                    style: TextStyle(
                      fontSize: 12,
                      color: _extraFunding
                          ? AppColors.amber500
                          : exceedsRemaining
                              ? AppColors.red500
                              : context.appTextHint,
                    ),
                  ),
                ),
                // 추가자금 토글 (컴팩트)
                Text(
                  '추가자금',
                  style: TextStyle(
                    fontSize: 12,
                    color: _extraFunding
                        ? context.appTextPrimary
                        : context.appTextSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 36,
                  height: 22,
                  child: FittedBox(
                    child: Switch(
                      value: _extraFunding,
                      onChanged: (val) =>
                          setState(() => _extraFunding = val),
                      activeColor: AppColors.amber500,
                    ),
                  ),
                ),
              ],
            ),
            if (exceedsRemaining) ...[
              const SizedBox(height: 4),
              Text(
                '잔여현금(${formatKrwWithComma(widget.cycle.remainingCash)}원)을 초과합니다',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.red500,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 저장 버튼
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSaveButton(BuildContext context, bool exceedsRemaining) {
    final bool canSave;
    if (_isSplitMode) {
      canSave = !_isSubmitting && !exceedsRemaining &&
          ((_priceA > 0 && _sharesA > 0) || (_priceB > 0 && _sharesB > 0));
    } else {
      canSave = _price > 0 && _shares > 0 && !_isSubmitting && !exceedsRemaining;
    }

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
  // 입력 필드 빌더 (메모 등에 사용)
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
    final exchangeRate = widget.currentExchangeRate;

    // V2.2/V3.0 전반전 A/B 분리 모드
    if (_isSplitMode) {
      final hasA = _priceA > 0 && _sharesA > 0;
      final hasB = _priceB > 0 && _sharesB > 0;

      if (!hasA && !hasB) {
        _showError('LOC A 또는 LOC B 중 하나 이상 입력하세요');
        return;
      }

      // VWAP 계산: (priceA*sharesA + priceB*sharesB) / (sharesA + sharesB)
      final totalShares = _sharesA + _sharesB;
      final weightedPrice = totalShares > 0
          ? (_priceA * _sharesA + _priceB * _sharesB) / totalShares
          : 0.0;
      final totalAmountKrw = (_priceA * _sharesA + _priceB * _sharesB) * exchangeRate;

      if (!_extraFunding && totalAmountKrw > widget.cycle.remainingCash) {
        _showError('잔여현금(${formatKrwWithComma(widget.cycle.remainingCash)}원)을 초과합니다');
        return;
      }

      double extraAmount = 0;
      if (_extraFunding && totalAmountKrw > widget.cycle.remainingCash) {
        extraAmount = totalAmountKrw - widget.cycle.remainingCash;
      }

      // Determine signal: both filled → locAB, only one → locA or locB
      TradeSignal signal;
      if (hasA && hasB) {
        signal = TradeSignal.locAB;
      } else if (hasA) {
        signal = TradeSignal.locA;
      } else {
        signal = TradeSignal.locB;
      }

      setState(() => _isSubmitting = true);
      widget.onSubmit(
        isBuy: true,
        signal: signal,
        price: weightedPrice,
        shares: totalShares,
        exchangeRate: exchangeRate,
        date: _selectedDate,
        memo: _memoController.text.isEmpty ? null : _memoController.text,
        extraFundingAmount: extraAmount,
      );
      Navigator.of(context).pop();
      return;
    }

    // === Existing single-input logic below ===
    if (_price <= 0) {
      _showError('단가를 올바르게 입력하세요');
      return;
    }
    if (_shares <= 0) {
      _showError('수량을 올바르게 입력하세요');
      return;
    }

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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: context.appTextPrimary),
      ),
    );
  }
}
