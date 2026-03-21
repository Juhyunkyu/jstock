import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/krw_formatter.dart';
import '../../../../data/models/cycle.dart';
import '../../../../data/models/trade.dart';
import '../../../../domain/trading/steady_order_guide.dart';
import '../../../providers/providers.dart';

/// V2.2/V3.0 Steady Cycle 전용 -- 매수+매도 통합 거래 기록 시트
///
/// 하루에 매수 LOC + 매도 LOC + 지정가를 동시에 설정하므로,
/// 체결 결과를 한 화면에서 모두 기록한다.
class SteadyCombinedTradeSheet extends ConsumerStatefulWidget {
  final Cycle cycle;
  final double currentExchangeRate;
  final double? currentPrice;
  final double? changePercent;

  /// 매수 기록 콜백
  final Future<void> Function({
    required TradeSignal signal,
    required double price,
    required double shares,
    required double exchangeRate,
    required DateTime date,
    String? memo,
  }) onRecordBuy;

  /// 매도 기록 콜백
  final Future<void> Function({
    required TradeSignal signal,
    required double price,
    required double shares,
    required double exchangeRate,
    required DateTime date,
    String? memo,
  }) onRecordSell;

  const SteadyCombinedTradeSheet({
    super.key,
    required this.cycle,
    required this.currentExchangeRate,
    this.currentPrice,
    this.changePercent,
    required this.onRecordBuy,
    required this.onRecordSell,
  });

  @override
  ConsumerState<SteadyCombinedTradeSheet> createState() =>
      _SteadyCombinedTradeSheetState();
}

class _SteadyCombinedTradeSheetState
    extends ConsumerState<SteadyCombinedTradeSheet> {
  // Buy A (전반전 LOC A)
  final _buyAPriceCtrl = TextEditingController();
  final _buyASharesCtrl = TextEditingController();

  // Buy B (전반전 LOC B)
  final _buyBPriceCtrl = TextEditingController();
  final _buyBSharesCtrl = TextEditingController();

  // Buy Single (후반전 / 첫 매수 / 쿼터모드)
  final _buySinglePriceCtrl = TextEditingController();
  final _buySingleSharesCtrl = TextEditingController();

  // Sell LOC (1/4 or MOC)
  final _sellLocPriceCtrl = TextEditingController();
  final _sellLocSharesCtrl = TextEditingController();

  // Sell Limit (3/4 지정가)
  final _sellLimitPriceCtrl = TextEditingController();
  final _sellLimitSharesCtrl = TextEditingController();

  late DateTime _selectedDate;
  final _memoController = TextEditingController();
  bool _isSubmitting = false;

  // Parsed values
  double get _buyAPrice => double.tryParse(_buyAPriceCtrl.text) ?? 0;
  double get _buyAShares => double.tryParse(_buyASharesCtrl.text) ?? 0;
  double get _buyBPrice => double.tryParse(_buyBPriceCtrl.text) ?? 0;
  double get _buyBShares => double.tryParse(_buyBSharesCtrl.text) ?? 0;
  double get _buySinglePrice => double.tryParse(_buySinglePriceCtrl.text) ?? 0;
  double get _buySingleShares =>
      double.tryParse(_buySingleSharesCtrl.text) ?? 0;
  double get _sellLocPrice => double.tryParse(_sellLocPriceCtrl.text) ?? 0;
  double get _sellLocShares => double.tryParse(_sellLocSharesCtrl.text) ?? 0;
  double get _sellLimitPrice => double.tryParse(_sellLimitPriceCtrl.text) ?? 0;
  double get _sellLimitShares =>
      double.tryParse(_sellLimitSharesCtrl.text) ?? 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _buyAPriceCtrl.dispose();
    _buyASharesCtrl.dispose();
    _buyBPriceCtrl.dispose();
    _buyBSharesCtrl.dispose();
    _buySinglePriceCtrl.dispose();
    _buySingleSharesCtrl.dispose();
    _sellLocPriceCtrl.dispose();
    _sellLocSharesCtrl.dispose();
    _sellLimitPriceCtrl.dispose();
    _sellLimitSharesCtrl.dispose();
    _memoController.dispose();
    super.dispose();
  }

  bool get _hasAnyOrder {
    return (_buyAPrice > 0 && _buyAShares > 0) ||
        (_buyBPrice > 0 && _buyBShares > 0) ||
        (_buySinglePrice > 0 && _buySingleShares > 0) ||
        (_sellLocPrice > 0 && _sellLocShares > 0) ||
        (_sellLimitPrice > 0 && _sellLimitShares > 0);
  }

  @override
  Widget build(BuildContext context) {
    final guide = ref.watch(steadyOrderGuideProvider(widget.cycle.id));
    final price = widget.currentPrice;
    final changePercent = widget.changePercent;

    return Scaffold(
      backgroundColor: context.appSurface,
      appBar: AppBar(
        backgroundColor: context.appSurface,
        foregroundColor: context.appTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.cycle.ticker} 오늘의 거래 기록',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.appTextPrimary,
              ),
            ),
            if (price != null)
              Row(
                children: [
                  Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appTextSecondary,
                    ),
                  ),
                  if (changePercent != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: changePercent >= 0
                            ? AppColors.red500
                            : AppColors.blue500,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // T값 요약
            if (guide != null) _buildGuideSummary(context, guide),
            const SizedBox(height: 16),

            // === 매수 체결 결과 ===
            _buildSectionHeader(context, '매수 체결 결과', AppColors.blue500),
            const SizedBox(height: 8),
            _buildBuySection(context, guide),
            const SizedBox(height: 20),

            // === 매도 체결 결과 ===
            _buildSectionHeader(context, '매도 체결 결과', AppColors.green500),
            const SizedBox(height: 8),
            _buildSellSection(context, guide),
            const SizedBox(height: 20),

            // === 요약 ===
            _buildSummary(context),
            const SizedBox(height: 20),

            // === 거래일 + 메모 ===
            _buildDateAndMemo(context),
            const SizedBox(height: 24),

            // === 저장 버튼 ===
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _hasAnyOrder && !_isSubmitting ? _onSave : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  disabledBackgroundColor: context.appDivider,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '기록 저장',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // T값 가이드 요약 칩
  // ═══════════════════════════════════════════════════════════════

  Widget _buildGuideSummary(BuildContext context, SteadyOrderGuide guide) {
    final halfLabel = guide.isFirstHalf ? '전반전' : '후반전';
    final halfColor =
        guide.isFirstHalf ? AppColors.blue500 : AppColors.amber500;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.appBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.assignment_outlined, size: 16, color: context.appAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'T: ${guide.tValue.toStringAsFixed(1)}  $halfLabel  오프셋 ${guide.locOffsetPercent >= 0 ? '+' : ''}${guide.locOffsetPercent.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: halfColor,
              ),
            ),
          ),
          if (guide.isQuarterMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:
                    AppColors.amber500.withValues(alpha: context.isDarkMode ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '쿼터모드',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.amber500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 섹션 헤더 (구분선 포함)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSectionHeader(
      BuildContext context, String title, Color color) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 매수 섹션
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBuySection(BuildContext context, SteadyOrderGuide? guide) {
    // 첫 매수 or 쿼터모드 → 단일 입력
    if (guide != null && (guide.isFirstBuy || guide.isQuarterMode)) {
      if (guide.isQuarterMode && !guide.canBuy) {
        return _buildInfoChip(context, '쿼터모드 -- 매수 없음');
      }
      final singleOrder = guide.buySingleOrder;
      return _buildOrderInput(
        context: context,
        label: guide.isFirstBuy ? '첫 매수' : '쿼터 매수',
        labelColor: AppColors.blue500,
        priceCtrl: _buySinglePriceCtrl,
        sharesCtrl: _buySingleSharesCtrl,
        recommendedPrice: singleOrder?.price,
        recommendedShares: singleOrder?.shares,
      );
    }

    // 후반전 → 단일 입력
    if (guide != null && !guide.isFirstHalf) {
      if (!guide.canBuy) {
        return _buildInfoChip(context, '잔여 현금 부족 -- 매수 없음');
      }
      final singleOrder = guide.buySingleOrder;
      return _buildOrderInput(
        context: context,
        label: '후반전 매수',
        labelColor: AppColors.blue500,
        priceCtrl: _buySinglePriceCtrl,
        sharesCtrl: _buySingleSharesCtrl,
        recommendedPrice: singleOrder?.price,
        recommendedShares: singleOrder?.shares,
      );
    }

    // 전반전 → A + B 두 세트
    if (guide != null && !guide.canBuy) {
      return _buildInfoChip(context, '잔여 현금 부족 -- 매수 없음');
    }

    final orderA = guide?.buyOrderA;
    final orderB = guide?.buyOrderB;

    return Column(
      children: [
        _buildOrderInput(
          context: context,
          label: orderA?.label ?? 'LOC A',
          labelColor: AppColors.blue500,
          priceCtrl: _buyAPriceCtrl,
          sharesCtrl: _buyASharesCtrl,
          recommendedPrice: orderA?.price,
          recommendedShares: orderA?.shares,
        ),
        const SizedBox(height: 12),
        _buildOrderInput(
          context: context,
          label: orderB?.label ?? 'LOC B',
          labelColor: AppColors.blue500,
          priceCtrl: _buyBPriceCtrl,
          sharesCtrl: _buyBSharesCtrl,
          recommendedPrice: orderB?.price,
          recommendedShares: orderB?.shares,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 매도 섹션
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSellSection(BuildContext context, SteadyOrderGuide? guide) {
    // 첫 매수이면 아직 매도 없음
    if (guide != null && guide.isFirstBuy) {
      return _buildInfoChip(context, '첫 매수 전 -- 매도 없음');
    }

    final sellLoc = guide?.sellLocOrder;
    final sellLimit = guide?.sellLimitOrder;

    if (sellLoc == null && sellLimit == null) {
      return _buildInfoChip(context, '매도 주문 없음');
    }

    return Column(
      children: [
        if (sellLoc != null)
          _buildOrderInput(
            context: context,
            label: sellLoc.label,
            labelColor: AppColors.green500,
            priceCtrl: _sellLocPriceCtrl,
            sharesCtrl: _sellLocSharesCtrl,
            recommendedPrice: sellLoc.price,
            recommendedShares: sellLoc.shares,
            isSell: true,
          ),
        if (sellLoc != null && sellLimit != null) const SizedBox(height: 12),
        if (sellLimit != null)
          _buildOrderInput(
            context: context,
            label: sellLimit.label,
            labelColor: AppColors.green500,
            priceCtrl: _sellLimitPriceCtrl,
            sharesCtrl: _sellLimitSharesCtrl,
            recommendedPrice: sellLimit.price,
            recommendedShares: sellLimit.shares,
            isSell: true,
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 개별 주문 입력 위젯
  // ═══════════════════════════════════════════════════════════════

  Widget _buildOrderInput({
    required BuildContext context,
    required String label,
    required Color labelColor,
    required TextEditingController priceCtrl,
    required TextEditingController sharesCtrl,
    double? recommendedPrice,
    double? recommendedShares,
    bool isSell = false,
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
                color: labelColor,
              ),
            ),
            if (recommendedPrice != null && intShares != null && intShares > 0) ...[
              const Spacer(),
              GestureDetector(
                onTap: () {
                  priceCtrl.text = recommendedPrice.toStringAsFixed(2);
                  sharesCtrl.text = intShares.toString();
                  setState(() {});
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: labelColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '추천 \$${recommendedPrice.toStringAsFixed(2)} x $intShares주 (${recommendedShares!.toStringAsFixed(1)})',
                    style: TextStyle(fontSize: 10, color: labelColor),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(flex: 3, child: _priceField(context, priceCtrl)),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: _sharesField(context, sharesCtrl, isSell: isSell)),
          ],
        ),
      ],
    );
  }

  Widget _priceField(BuildContext context, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
      ],
      style: TextStyle(fontSize: 14, color: context.appTextPrimary),
      decoration: InputDecoration(
        prefixText: '\$ ',
        prefixStyle: TextStyle(fontSize: 14, color: context.appTextHint),
        hintText: '가격',
        hintStyle: TextStyle(fontSize: 13, color: context.appTextHint),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
        filled: true,
        fillColor: context.appBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.appBorder, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.appBorder, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.appAccent, width: 1),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  /// 매도 시 다른 매도 필드에서 이미 사용 중인 수량을 제외한 최대 매도 가능 수량
  int _maxSellableShares(TextEditingController currentCtrl) {
    final total = widget.cycle.totalShares.floor();
    int otherSellShares = 0;
    // 현재 컨트롤러가 아닌 다른 매도 컨트롤러의 수량 합산
    if (currentCtrl != _sellLocSharesCtrl) {
      otherSellShares += int.tryParse(_sellLocSharesCtrl.text) ?? 0;
    }
    if (currentCtrl != _sellLimitSharesCtrl) {
      otherSellShares += int.tryParse(_sellLimitSharesCtrl.text) ?? 0;
    }
    return (total - otherSellShares).clamp(0, total);
  }

  Widget _sharesField(
    BuildContext context,
    TextEditingController ctrl, {
    bool isSell = false,
  }) {
    void clampIfSell() {
      if (!isSell) return;
      final max = _maxSellableShares(ctrl);
      final current = int.tryParse(ctrl.text) ?? 0;
      if (current > max) {
        ctrl.text = max.toString();
        ctrl.selection = TextSelection.fromPosition(
          TextPosition(offset: ctrl.text.length),
        );
      }
    }

    void stepShares(int delta) {
      final current = int.tryParse(ctrl.text) ?? 0;
      var next = (current + delta).clamp(0, 999999);
      if (isSell) {
        final max = _maxSellableShares(ctrl);
        next = next.clamp(0, max);
      }
      ctrl.text = next == 0 ? '' : next.toString();
      ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: ctrl.text.length),
      );
      setState(() {});
    }

    return Row(
      children: [
        _StepperButton(
          icon: Icons.remove,
          onPressed: () => stepShares(-1),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(fontSize: 14, color: context.appTextPrimary),
            decoration: InputDecoration(
              suffixText: '주',
              suffixStyle:
                  TextStyle(fontSize: 13, color: context.appTextHint),
              hintText: '수량',
              hintStyle:
                  TextStyle(fontSize: 13, color: context.appTextHint),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              isDense: true,
              filled: true,
              fillColor: context.appBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: context.appBorder, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: context.appBorder, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: context.appAccent, width: 1),
              ),
            ),
            onChanged: (_) {
              clampIfSell();
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 4),
        _StepperButton(
          icon: Icons.add,
          onPressed: () => stepShares(1),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 정보 칩 (매수/매도 없음 안내)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildInfoChip(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.appBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 12, color: context.appTextHint),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 요약
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSummary(BuildContext context) {
    final exRate = widget.currentExchangeRate;

    // 매수 합산
    double totalBuyShares = 0;
    double totalBuyKrw = 0;
    if (_buyAPrice > 0 && _buyAShares > 0) {
      totalBuyShares += _buyAShares;
      totalBuyKrw += _buyAShares * _buyAPrice * exRate;
    }
    if (_buyBPrice > 0 && _buyBShares > 0) {
      totalBuyShares += _buyBShares;
      totalBuyKrw += _buyBShares * _buyBPrice * exRate;
    }
    if (_buySinglePrice > 0 && _buySingleShares > 0) {
      totalBuyShares += _buySingleShares;
      totalBuyKrw += _buySingleShares * _buySinglePrice * exRate;
    }

    // 매도 합산
    double totalSellShares = 0;
    double totalSellKrw = 0;
    if (_sellLocPrice > 0 && _sellLocShares > 0) {
      totalSellShares += _sellLocShares;
      totalSellKrw += _sellLocShares * _sellLocPrice * exRate;
    }
    if (_sellLimitPrice > 0 && _sellLimitShares > 0) {
      totalSellShares += _sellLimitShares;
      totalSellKrw += _sellLimitShares * _sellLimitPrice * exRate;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '요약',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '매수',
                style: TextStyle(fontSize: 12, color: AppColors.blue500),
              ),
              const Spacer(),
              Text(
                '${totalBuyShares.toInt()}주 / ${formatKrwWithComma(totalBuyKrw)}원',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '매도',
                style: TextStyle(fontSize: 12, color: AppColors.green500),
              ),
              const Spacer(),
              Text(
                '${totalSellShares.toInt()}주 / ${formatKrwWithComma(totalSellKrw)}원',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 거래일 + 메모
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDateAndMemo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 거래일
        InkWell(
          onTap: () => _showDatePicker(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.appBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.appBorder, width: 0.5),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 16, color: context.appTextHint),
                const SizedBox(width: 8),
                Text(
                  '거래일: ${_formatDate(_selectedDate)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.appTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // 메모
        TextField(
          controller: _memoController,
          style: TextStyle(fontSize: 13, color: context.appTextPrimary),
          decoration: InputDecoration(
            hintText: '메모 (선택)',
            hintStyle: TextStyle(fontSize: 13, color: context.appTextHint),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
            filled: true,
            fillColor: context.appBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.appBorder, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.appBorder, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.appAccent, width: 1),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final dateFormat = DateFormat('yyyy.MM.dd');
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
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              surface: ctx.appSurface,
              onSurface: ctx.appTextPrimary,
            ),
            dialogBackgroundColor: ctx.appSurface,
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
  // 저장
  // ═══════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════
  // 매도 수량 초과 검증 (_onSave 직전)
  // ═══════════════════════════════════════════════════════════════

  bool _validateSellShares(BuildContext context) {
    final totalHeld = widget.cycle.totalShares.floor();
    final sellTotal = (_sellLocShares + _sellLimitShares).toInt();
    if (sellTotal > totalHeld) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('매도 합계 $sellTotal주가 보유 수량 $totalHeld주를 초과합니다'),
          backgroundColor: AppColors.red500,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _onSave() async {
    if (!_validateSellShares(context)) return;
    setState(() => _isSubmitting = true);
    final exchangeRate = widget.currentExchangeRate;
    final date = _selectedDate;
    final memo = _memoController.text.isEmpty ? null : _memoController.text;

    try {
      // Record buys first
      if (_buyAPrice > 0 && _buyAShares > 0) {
        await widget.onRecordBuy(
          signal: TradeSignal.locA,
          price: _buyAPrice,
          shares: _buyAShares,
          exchangeRate: exchangeRate,
          date: date,
          memo: memo,
        );
      }
      if (_buyBPrice > 0 && _buyBShares > 0) {
        await widget.onRecordBuy(
          signal: TradeSignal.locB,
          price: _buyBPrice,
          shares: _buyBShares,
          exchangeRate: exchangeRate,
          date: date,
        );
      }
      if (_buySinglePrice > 0 && _buySingleShares > 0) {
        await widget.onRecordBuy(
          signal: TradeSignal.buySingle,
          price: _buySinglePrice,
          shares: _buySingleShares,
          exchangeRate: exchangeRate,
          date: date,
          memo: memo,
        );
      }

      // Then record sells
      if (_sellLocPrice > 0 && _sellLocShares > 0) {
        await widget.onRecordSell(
          signal: TradeSignal.sellLocQuarter,
          price: _sellLocPrice,
          shares: _sellLocShares,
          exchangeRate: exchangeRate,
          date: date,
        );
      }
      if (_sellLimitPrice > 0 && _sellLimitShares > 0) {
        await widget.onRecordSell(
          signal: TradeSignal.sellLimitThreeQ,
          price: _sellLimitPrice,
          shares: _sellLimitShares,
          exchangeRate: exchangeRate,
          date: date,
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('거래 기록 실패: $e'),
            backgroundColor: AppColors.red500,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// 스텝퍼 버튼 (수량 +/-)
// ═══════════════════════════════════════════════════════════════

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _StepperButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: context.appBackground,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Icon(icon, size: 18, color: context.appTextSecondary),
        ),
      ),
    );
  }
}
