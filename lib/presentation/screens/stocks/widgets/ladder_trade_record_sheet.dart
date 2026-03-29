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
import '../../../../domain/trading/ladder_cycle_service.dart';
import '../../../providers/providers.dart';
import '../../../widgets/common/top_toast.dart';
import '../../../widgets/shared/return_badge.dart';
import '../../../widgets/shared/signal_badge_config.dart';

/// Ladder Cycle 전용 거래 기록 풀스크린 시트
///
/// 기존 CycleTradeRecordSheet 패턴을 따르되, Ladder 전용:
/// - 종목 선택 (안정형만: QQQ/QLD/TQQQ)
/// - 신호: ladderStep1~6 + manual
/// - 매도 시 보유 종목만 뱃지 표시
/// - 단계별 매수 추천 가이드
class LadderTradeRecordSheet extends ConsumerStatefulWidget {
  final Cycle cycle;
  final double currentExchangeRate;
  final double? currentPrice;
  final double? changePercent;

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
    String? ticker,
  }) onSubmit;

  const LadderTradeRecordSheet({
    super.key,
    required this.cycle,
    required this.currentExchangeRate,
    this.currentPrice,
    this.changePercent,
    this.editingTrade,
    this.editTitle,
    required this.onSubmit,
  });

  @override
  ConsumerState<LadderTradeRecordSheet> createState() =>
      _LadderTradeRecordSheetState();
}

class _LadderTradeRecordSheetState
    extends ConsumerState<LadderTradeRecordSheet> {
  bool _isBuy = true;
  late DateTime _selectedDate;
  late TradeSignal _selectedSignal;

  /// 매수/매도 탭 전환 시 이전 신호를 기억
  TradeSignal? _lastBuySignal;
  TradeSignal? _lastSellSignal;

  final _priceController = TextEditingController();
  final _sharesController = TextEditingController();
  final _memoController = TextEditingController();

  bool _extraFunding = false;
  bool _isSubmitting = false;
  bool _signalExpanded = false;

  /// 안정형에서 선택된 티커 (null이면 추천 첫 번째)
  String? _selectedTicker;

  double get _price => double.tryParse(_priceController.text) ?? 0;
  double get _shares => double.tryParse(_sharesController.text) ?? 0;

  bool get _isEditing => widget.editingTrade != null;
  bool get _isConservative => widget.cycle.ladderMode == 0;

  /// 현재 단계의 다음 단계 (기본 선택용)
  int get _nextStep => (widget.cycle.currentStep + 1)
      .clamp(1, widget.cycle.ladderSteps);

  /// Ladder 매수 신호 목록 (단계 수에 따라 동적)
  List<TradeSignal> get _buySignals {
    final steps = widget.cycle.ladderSteps;
    final signals = <TradeSignal>[];
    for (int i = 1; i <= steps; i++) {
      signals.add(_stepToSignal(i));
    }
    signals.add(TradeSignal.manual);
    return signals;
  }

  /// Ladder 매도 신호: 수동만
  List<TradeSignal> get _sellSignals => [TradeSignal.manual];

  List<TradeSignal> get _currentSignals => _isBuy ? _buySignals : _sellSignals;

  /// step 번호 → TradeSignal 변환
  TradeSignal _stepToSignal(int step) {
    return switch (step) {
      1 => TradeSignal.ladderStep1,
      2 => TradeSignal.ladderStep2,
      3 => TradeSignal.ladderStep3,
      4 => TradeSignal.ladderStep4,
      5 => TradeSignal.ladderStep5,
      6 => TradeSignal.ladderStep6,
      _ => TradeSignal.manual,
    };
  }

  /// TradeSignal → step 번호 (0이면 비단계)
  int _signalToStep(TradeSignal signal) {
    return switch (signal) {
      TradeSignal.ladderStep1 => 1,
      TradeSignal.ladderStep2 => 2,
      TradeSignal.ladderStep3 => 3,
      TradeSignal.ladderStep4 => 4,
      TradeSignal.ladderStep5 => 5,
      TradeSignal.ladderStep6 => 6,
      _ => 0,
    };
  }

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
      _selectedTicker = editing.ticker;
    } else {
      // ── 신규 모드 ──
      _selectedDate = DateTime.now();
      // 기본 신호: 다음 단계
      _selectedSignal = _stepToSignal(_nextStep);
      // 안정형: 추천 티커의 첫 번째를 기본 선택
      if (_isConservative) {
        final tickers = recommendedTickers(
          widget.cycle.ladderMode,
          _nextStep,
        );
        _selectedTicker = tickers.isNotEmpty ? tickers.first : null;
      }
    }
  }

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
            // ═══ 1. 헤더: 티커 + 닫기 ═══
            _buildHeader(context),
            const SizedBox(height: 4),

            // ═══ 2. 현재가 + 등락률 (수정 모드에서는 숨김) ═══
            if (!_isEditing && widget.currentPrice != null) ...[
              _buildCurrentPrice(context),
              const SizedBox(height: 12),
            ] else if (!_isEditing)
              const SizedBox(height: 8),

            // ═══ 3. 거래일 (한 줄 Row) ═══
            _buildInlineDatePicker(context),
            const SizedBox(height: 12),

            // ═══ 4. 매수/매도 토글 (수정 모드에서는 비활성) ═══
            _buildToggle(context),
            const SizedBox(height: 12),

            // ═══ 5. 신호 선택 (접이식) ═══
            _buildSignalSection(context),
            const SizedBox(height: 12),

            // ═══ 6. 종목 선택 (안정형만) ═══
            if (_isConservative) ...[
              _buildTickerSelection(context),
              const SizedBox(height: 12),
            ],

            // ═══ 7. 매수 추천 가이드 ═══
            if (_showBuyGuide)
              _buildBuyGuide(context, exchangeRate),

            // ═══ 8. 단가/수량 입력 ═══
            _buildInlinePriceInput(context),
            const SizedBox(height: 12),
            _buildInlineSharesStepper(context),
            const SizedBox(height: 12),

            // ═══ 9. 거래 금액 + 잔여현금 ═══
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
  // 매수 추천 가이드 표시 조건
  // ═══════════════════════════════════════════════════════════════

  bool get _showBuyGuide {
    if (_isEditing || !_isBuy) return false;
    final step = _signalToStep(_selectedSignal);
    return step > 0; // 단계 신호일 때만 (수동은 0)
  }

  // ═══════════════════════════════════════════════════════════════
  // 헤더
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context) {
    final displayTicker = _isConservative && _selectedTicker != null
        ? _selectedTicker!
        : widget.cycle.ticker;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.editTitle ?? '$displayTicker 거래 기록',
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
  // 매수/매도 토글
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
                      _selectedSignal = (_lastBuySignal != null && _buySignals.contains(_lastBuySignal!))
                          ? _lastBuySignal!
                          : _stepToSignal(_nextStep);
                      // 안정형: 매수 시 추천 티커 초기화
                      if (_isConservative) {
                        final step = _signalToStep(_selectedSignal);
                        final tickers = recommendedTickers(
                          widget.cycle.ladderMode,
                          step > 0 ? step : _nextStep,
                        );
                        _selectedTicker = tickers.isNotEmpty ? tickers.first : null;
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
                      color: _isBuy ? Colors.white : context.appTextSecondary,
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
                      _selectedSignal = (_lastSellSignal != null && _sellSignals.contains(_lastSellSignal!))
                          ? _lastSellSignal!
                          : TradeSignal.manual;
                      // 안정형 매도: 보유 종목에서 첫 번째 선택
                      if (_isConservative) {
                        _selectedTicker = null; // 빌드 시 보유 종목에서 결정
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
                      color: !_isBuy ? Colors.white : context.appTextSecondary,
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
                      // 안정형: 신호 변경 시 추천 티커 업데이트
                      if (_isConservative && _isBuy) {
                        final step = _signalToStep(signal);
                        if (step > 0) {
                          final tickers = recommendedTickers(
                            widget.cycle.ladderMode,
                            step,
                          );
                          _selectedTicker = tickers.isNotEmpty ? tickers.first : null;
                        }
                      }
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
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? chipConfig.color
                      : context.appTextSecondary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 종목 선택 (안정형만)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTickerSelection(BuildContext context) {
    final trades = ref.watch(tradeListProvider(widget.cycle.id));
    final prices = ref.watch(closingPricesProvider);

    if (_isBuy) {
      return _buildBuyTickerSelection(context, prices);
    } else {
      return _buildSellTickerSelection(context, trades, prices);
    }
  }

  /// 매수 시: 추천 티커 3개 뱃지 (현재가 표시)
  Widget _buildBuyTickerSelection(
    BuildContext context,
    Map<String, double> prices,
  ) {
    final step = _signalToStep(_selectedSignal);
    final tickers = recommendedTickers(
      widget.cycle.ladderMode,
      step > 0 ? step : _nextStep,
    );

    // 선택된 티커가 추천 목록에 없으면 첫 번째로 리셋
    if (_selectedTicker != null && !tickers.contains(_selectedTicker)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedTicker = tickers.isNotEmpty ? tickers.first : null;
          });
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '종목 선택',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tickers.map((ticker) {
            final isSelected = _selectedTicker == ticker;
            final tickerPrice = prices[ticker];
            final priceLabel = tickerPrice != null
                ? ' \$${tickerPrice.toStringAsFixed(2)}'
                : '';

            return GestureDetector(
              onTap: () => setState(() => _selectedTicker = ticker),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.amber500.withValues(alpha: context.isDarkMode ? 0.25 : 0.15)
                      : context.appSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.amber500 : context.appBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  isSelected ? '$ticker$priceLabel \u2713' : '$ticker$priceLabel',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? AppColors.amber500
                        : context.appTextPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 매도 시: 보유 종목만 뱃지 (보유 수량 표시)
  Widget _buildSellTickerSelection(
    BuildContext context,
    List<Trade> trades,
    Map<String, double> prices,
  ) {
    final holdings = buildTickerHoldings(
      trades,
      widget.cycle.ticker,
      prices,
      widget.currentExchangeRate,
    );

    // 보유 수량 > 0인 종목만 필터
    final holdingTickers = holdings.where((h) => h.shares > 0).toList();

    // 선택된 티커가 보유 목록에 없으면 첫 번째로 리셋
    if (holdingTickers.isNotEmpty) {
      final tickerNames = holdingTickers.map((h) => h.ticker).toList();
      if (_selectedTicker == null || !tickerNames.contains(_selectedTicker)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedTicker = holdingTickers.first.ticker;
            });
          }
        });
      }
    }

    if (holdingTickers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '매도 가능한 보유 종목이 없습니다',
          style: TextStyle(fontSize: 13, color: context.appTextHint),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '종목 선택',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: holdingTickers.map((holding) {
            final isSelected = _selectedTicker == holding.ticker;
            final sharesLabel = '${formatShares(holding.shares)}주';

            return GestureDetector(
              onTap: () => setState(() => _selectedTicker = holding.ticker),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.amber500.withValues(alpha: context.isDarkMode ? 0.25 : 0.15)
                      : context.appSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.amber500 : context.appBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  isSelected
                      ? '${holding.ticker} $sharesLabel \u2713'
                      : '${holding.ticker} $sharesLabel',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? AppColors.amber500
                        : context.appTextPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 매수 추천 가이드
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBuyGuide(BuildContext context, double exchangeRate) {
    final step = _signalToStep(_selectedSignal);
    if (step == 0) return const SizedBox.shrink();

    final recommendedKrw = stepAmount(
      widget.cycle.seedAmount,
      step,
      widget.cycle,
    );

    // 단가 입력 시 추천 수량 계산
    final priceUsd = _price;
    final canCalcShares = priceUsd > 0 && exchangeRate > 0;
    final recommendedShares = canCalcShares
        ? (recommendedKrw / (priceUsd * exchangeRate)).floor()
        : 0;
    final exactShares = canCalcShares
        ? recommendedKrw / (priceUsd * exchangeRate)
        : 0.0;
    final actualKrw = recommendedShares * priceUsd * exchangeRate;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.amber500.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.amber500.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 제목
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lightbulb_outline,
                    size: 16, color: AppColors.amber500),
                const SizedBox(width: 6),
                Text(
                  '$step단계 매수 추천',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.amber500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 매수금액
            Text(
              '매수금액: ${formatKoreanAmountShort(recommendedKrw)}',
              style: TextStyle(
                fontSize: 13,
                color: context.appTextPrimary,
              ),
            ),
            // 단가 입력 시 추천 수량
            if (canCalcShares && recommendedShares > 0) ...[
              const SizedBox(height: 6),
              Divider(height: 1, color: AppColors.amber500.withValues(alpha: 0.15)),
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
                          '≈ ${formatKoreanAmountShort(actualKrw)} (${exactShares.toStringAsFixed(1)})',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // [적용] 버튼
                  GestureDetector(
                    onTap: () {
                      _sharesController.text = recommendedShares.toString();
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.amber500,
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    // 매도 시 선택된 티커의 보유 수량 표시
    double? maxSellShares;
    if (!_isBuy && _isConservative && _selectedTicker != null) {
      final trades = ref.watch(tradeListProvider(widget.cycle.id));
      final prices = ref.watch(closingPricesProvider);
      final holdings = buildTickerHoldings(
        trades,
        widget.cycle.ticker,
        prices,
        widget.currentExchangeRate,
      );
      final holding = holdings.where((h) => h.ticker == _selectedTicker).firstOrNull;
      maxSellShares = holding?.shares ?? 0;
    } else if (!_isBuy) {
      maxSellShares = widget.cycle.totalShares;
    }

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
        if (!_isBuy && maxSellShares != null && maxSellShares > 0) ...[
          const SizedBox(width: 8),
          Text(
            '보유: ${formatShares(maxSellShares)}주',
            style: TextStyle(
              fontSize: 12,
              color: context.appAccent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const Spacer(),
        // 스텝퍼 ([-] [input] [+])
        _LadderStepperButton(
          icon: Icons.remove,
          onTap: () {
            final current = double.tryParse(_sharesController.text) ?? 0;
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            onChanged: (_) {
              // 매도 시 보유 수량 초과 방지
              if (!_isBuy && maxSellShares != null) {
                final entered = double.tryParse(_sharesController.text) ?? 0;
                if (entered > maxSellShares) {
                  _sharesController.text = maxSellShares == maxSellShares.roundToDouble()
                      ? maxSellShares.toInt().toString()
                      : maxSellShares.toStringAsFixed(2);
                  _sharesController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _sharesController.text.length),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 6),
        _LadderStepperButton(
          icon: Icons.add,
          onTap: () {
            final current = double.tryParse(_sharesController.text) ?? 0;
            var newVal = current + 1;
            // 매도 시 보유 수량 초과 방지
            if (!_isBuy && maxSellShares != null && newVal > maxSellShares) {
              newVal = maxSellShares;
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
            '(환율: \u20a9${exchangeRate.toStringAsFixed(0)}/\$)',
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
                      onChanged: (val) => setState(() => _extraFunding = val),
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
    final canSave = _price > 0 && _shares > 0 && !_isSubmitting && !exceedsRemaining;

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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      _showError('단가를 입력해주세요');
      return;
    }
    if (_shares <= 0) {
      _showError('수량을 입력해주세요');
      return;
    }

    setState(() => _isSubmitting = true);

    final exchangeRate = widget.currentExchangeRate;

    widget.onSubmit(
      isBuy: _isBuy,
      signal: _selectedSignal,
      price: _price,
      shares: _shares,
      exchangeRate: exchangeRate,
      date: _selectedDate,
      memo: _memoController.text.isEmpty ? null : _memoController.text,
      ticker: _isConservative ? _selectedTicker : null,
    );

    Navigator.of(context).pop();
  }

  void _showError(String message) {
    showErrorToast(context, message);
  }
}

/// 수량 스텝퍼 버튼
class _LadderStepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _LadderStepperButton({required this.icon, required this.onTap});

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
