import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../../core/utils/korean_number_formatter.dart';
import '../../../data/models/cycle.dart';
import '../../../domain/trading/average_down_calculator.dart';
import '../../providers/providers.dart';
import '../../widgets/shared/info_row.dart';

/// 물타기 계산기 메인 화면
class AvgDownScreen extends ConsumerStatefulWidget {
  const AvgDownScreen({super.key});

  @override
  ConsumerState<AvgDownScreen> createState() => _AvgDownScreenState();
}

class _AvgDownScreenState extends ConsumerState<AvgDownScreen> {
  // === 현재 보유 ===
  final _tickerNameController = TextEditingController();
  final _holdingSharesController = TextEditingController();
  final _avgPriceController = TextEditingController();
  final _currentPriceController = TextEditingController();
  final _exchangeRateController = TextEditingController();

  // === 추가 매수 ===
  final _addPriceController = TextEditingController();
  final _addAmountController = TextEditingController();
  final _addSharesController = TextEditingController();
  bool _inputByAmount = true; // true=금액입력, false=수량입력

  // === 수익률 역산 ===
  final _targetReturnController = TextEditingController(text: '-5.0');

  // === 목표가 ===
  final _targetPriceController = TextEditingController();

  // === 환율 접이식 ===
  bool _showExchangeRate = false;

  // === 사이클 연동 ===
  String? _loadedCycleId;

  // === 계산 결과 ===
  AvgDownResult? _result;

  @override
  void initState() {
    super.initState();
    // 기본 환율 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rate = ref.read(currentExchangeRateProvider);
      _exchangeRateController.text = rate.toStringAsFixed(0);
      _recalculate();
    });
  }

  @override
  void dispose() {
    _tickerNameController.dispose();
    _holdingSharesController.dispose();
    _avgPriceController.dispose();
    _currentPriceController.dispose();
    _exchangeRateController.dispose();
    _addPriceController.dispose();
    _addAmountController.dispose();
    _addSharesController.dispose();
    _targetReturnController.dispose();
    _targetPriceController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════
  // 파싱 헬퍼
  // ════════════════════════════════════════════

  double _parseDouble(TextEditingController c) {
    final text = c.text.replaceAll(',', '').replaceAll('₩', '').replaceAll('\$', '');
    return double.tryParse(text) ?? 0.0;
  }

  double get _holdingShares => _parseDouble(_holdingSharesController);
  double get _avgPrice => _parseDouble(_avgPriceController);
  double get _currentPrice => _parseDouble(_currentPriceController);
  double get _exchangeRate => _parseDouble(_exchangeRateController);
  double get _addPrice => _parseDouble(_addPriceController);
  double get _addAmount => _parseDouble(_addAmountController);
  double get _addShares => _parseDouble(_addSharesController);
  double get _targetReturn => _parseDouble(_targetReturnController);
  double get _targetPrice => _parseDouble(_targetPriceController);

  /// 추가매수 수량 계산 (금액 입력 모드일 때)
  double get _effectiveAddShares {
    if (_inputByAmount) {
      return AverageDownCalculator.sharesToBuy(
        amountKrw: _addAmount,
        price: _addPrice > 0 ? _addPrice : _currentPrice,
        exchangeRate: _exchangeRate,
      );
    }
    return _addShares;
  }

  /// 추가매수 단가 (미입력 시 현재가)
  double get _effectiveAddPrice => _addPrice > 0 ? _addPrice : _currentPrice;

  bool get _hasValidInput =>
      _holdingShares > 0 && _avgPrice > 0 && _currentPrice > 0;

  bool get _hasAdditionalBuy => _effectiveAddShares > 0;

  // ════════════════════════════════════════════
  // 계산
  // ════════════════════════════════════════════

  void _recalculate() {
    if (!_hasValidInput) {
      setState(() => _result = null);
      return;
    }

    final addShares = _effectiveAddShares;
    final addPrice = _effectiveAddPrice;
    final exRate = _exchangeRate > 0 ? _exchangeRate : 1400.0;

    final result = AverageDownCalculator.calculateAll(
      holdingShares: _holdingShares,
      averagePrice: _avgPrice,
      currentPrice: _currentPrice,
      exchangeRate: exRate,
      additionalRounds: addShares > 0
          ? [(price: addPrice, shares: addShares)]
          : [],
      targetReturnRate: _targetReturn != 0 ? _targetReturn : null,
      targetPrice: _targetPrice > 0 ? _targetPrice : null,
    );

    setState(() => _result = result);
  }

  void _onInputChanged([String? _]) => _recalculate();

  // ════════════════════════════════════════════
  // 사이클 불러오기
  // ════════════════════════════════════════════

  void _showCyclePicker() {
    final cycles = ref.read(cycleListProvider);
    final activeCycles = cycles.where((c) => c.status == CycleStatus.active).toList();

    if (activeCycles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('활성 사이클이 없습니다', style: TextStyle(color: context.appTextPrimary)),
          backgroundColor: context.appSurface,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _buildCyclePickerSheet(ctx, activeCycles),
    );
  }

  Widget _buildCyclePickerSheet(BuildContext ctx, List<Cycle> cycles) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.appTextHint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '활성 사이클에서 불러오기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.appTextPrimary,
              ),
            ),
          ),
          Divider(height: 1, color: context.appDivider),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: cycles.length,
              itemBuilder: (ctx, i) {
                final cycle = cycles[i];
                final strategyLabel = switch (cycle.strategyType) {
                  StrategyType.alphaCycleV3 => 'Smart Cycle',
                  StrategyType.infiniteBuy => 'Steady Cycle',
                  StrategyType.ladderCycle => 'Ladder Cycle',
                };
                final mdd = cycle.totalShares > 0 && cycle.averagePrice > 0
                    ? AverageDownCalculator.mdd(
                        currentPrice: cycle.averagePrice, // placeholder
                        averagePrice: cycle.averagePrice,
                      )
                    : 0.0;
                final seedText = formatKoreanAmountShort(cycle.seedAmount);

                return ListTile(
                  title: Text(
                    cycle.nickname.isNotEmpty ? '${cycle.ticker} (${cycle.nickname})' : cycle.ticker,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '$strategyLabel · 시드 $seedText\n'
                    '${cycle.totalShares.toStringAsFixed(1)}주 · 평단 \$${cycle.averagePrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                  isThreeLine: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    _loadFromCycle(cycle);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _resetAll();
              },
              child: Text(
                '직접 입력으로 전환',
                style: TextStyle(color: context.appAccent),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _loadFromCycle(Cycle cycle) {
    _tickerNameController.text = cycle.ticker;
    _holdingSharesController.text = cycle.totalShares > 0
        ? cycle.totalShares.toStringAsFixed(2)
        : '';
    _avgPriceController.text = cycle.averagePrice > 0
        ? cycle.averagePrice.toStringAsFixed(2)
        : '';

    // 현재가: stockQuoteProvider에서 가져오기
    final quoteState = ref.read(stockQuoteProvider);
    final quote = quoteState.quotes[cycle.ticker];
    if (quote != null && quote.currentPrice > 0) {
      _currentPriceController.text = quote.currentPrice.toStringAsFixed(2);
      // 추가매수가 기본값 = 현재가
      _addPriceController.text = quote.currentPrice.toStringAsFixed(2);
    }

    // 환율
    final rate = ref.read(currentExchangeRateProvider);
    _exchangeRateController.text = rate.toStringAsFixed(0);

    _loadedCycleId = cycle.id;
    _recalculate();
  }

  void _resetAll() {
    _tickerNameController.clear();
    _holdingSharesController.clear();
    _avgPriceController.clear();
    _currentPriceController.clear();
    _addPriceController.clear();
    _addAmountController.clear();
    _addSharesController.clear();
    _targetReturnController.text = '-5.0';
    _targetPriceController.clear();
    _loadedCycleId = null;

    final rate = ref.read(currentExchangeRateProvider);
    _exchangeRateController.text = rate.toStringAsFixed(0);

    _recalculate();
  }

  // ════════════════════════════════════════════
  // 빌드
  // ════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 900;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.appTextPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '물타기 계산기',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.appTextPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _buildInputSection(),
          const SizedBox(height: 16),
          if (_hasValidInput) ...[
            _buildResultCard(),
            const SizedBox(height: 16),
            _buildScenarioTable(),
            const SizedBox(height: 16),
            _buildReverseCalcSection(),
            const SizedBox(height: 16),
            _buildTargetPriceSection(),
            const SizedBox(height: 24),
          ],
          _buildResetButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 좌측: 입력 패널 (고정 폭)
        SizedBox(
          width: 380,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInputSection(),
                const SizedBox(height: 24),
                _buildResetButton(),
              ],
            ),
          ),
        ),
        VerticalDivider(width: 1, color: context.appDivider),
        // 우측: 결과 패널 (스크롤)
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_hasValidInput) ...[
                  _buildResultCard(),
                  const SizedBox(height: 16),
                  _buildScenarioTable(),
                  const SizedBox(height: 16),
                  _buildReverseCalcSection(),
                  const SizedBox(height: 16),
                  _buildTargetPriceSection(),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text(
                        '보유 정보를 입력하면 결과가 표시됩니다',
                        style: TextStyle(
                          color: context.appTextHint,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════
  // Section A+B: 입력 영역
  // ════════════════════════════════════════════

  Widget _buildInputSection() {
    return Column(
      children: [
        // Section A: 현재 보유
        _buildCard(
          title: '현재 보유',
          trailing: TextButton.icon(
            icon: Icon(Icons.download_outlined, size: 16, color: context.appAccent),
            label: Text(
              '사이클에서 불러오기',
              style: TextStyle(fontSize: 12, color: context.appAccent),
            ),
            onPressed: _showCyclePicker,
          ),
          child: Column(
            children: [
              _buildTextField(
                label: '종목명',
                controller: _tickerNameController,
                hint: 'TQQQ',
                onChanged: _onInputChanged,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                label: '보유수량',
                controller: _holdingSharesController,
                hint: '0',
                suffix: '주',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: _onInputChanged,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                label: '평균단가',
                controller: _avgPriceController,
                hint: '0.00',
                prefix: '\$',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: _onInputChanged,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                label: '현재가',
                controller: _currentPriceController,
                hint: '0.00',
                prefix: '\$',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: _onInputChanged,
              ),
              const SizedBox(height: 8),
              // 환율 접이식
              InkWell(
                onTap: () => setState(() => _showExchangeRate = !_showExchangeRate),
                child: Row(
                  children: [
                    Icon(
                      _showExchangeRate ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: context.appTextHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '환율 설정',
                      style: TextStyle(fontSize: 12, color: context.appTextHint),
                    ),
                    const Spacer(),
                    Text(
                      '₩${_exchangeRateController.text}',
                      style: TextStyle(fontSize: 12, color: context.appTextSecondary),
                    ),
                  ],
                ),
              ),
              if (_showExchangeRate) ...[
                const SizedBox(height: 8),
                _buildTextField(
                  label: '환율',
                  controller: _exchangeRateController,
                  hint: '1400',
                  prefix: '₩',
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  onChanged: _onInputChanged,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Section B: 추가 매수
        _buildCard(
          title: '추가 매수',
          trailing: _buildAmountSharesToggle(),
          child: Column(
            children: [
              _buildTextField(
                label: '매수가',
                controller: _addPriceController,
                hint: _currentPrice > 0 ? _currentPrice.toStringAsFixed(2) : '0.00',
                prefix: '\$',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: _onInputChanged,
              ),
              const SizedBox(height: 12),
              if (_inputByAmount) ...[
                _buildTextField(
                  label: '매수금액',
                  controller: _addAmountController,
                  hint: '0',
                  prefix: '₩',
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  onChanged: _onInputChanged,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                if (_effectiveAddShares > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 14, color: context.appTextHint),
                        const SizedBox(width: 4),
                        Text(
                          '예상수량  ${_effectiveAddShares.toStringAsFixed(2)}주',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ] else
                _buildTextField(
                  label: '매수수량',
                  controller: _addSharesController,
                  hint: '0',
                  suffix: '주',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: _onInputChanged,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountSharesToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildToggleChip('금액', _inputByAmount, () {
          setState(() => _inputByAmount = true);
          _recalculate();
        }),
        const SizedBox(width: 4),
        _buildToggleChip('수량', !_inputByAmount, () {
          setState(() => _inputByAmount = false);
          _recalculate();
        }),
      ],
    );
  }

  Widget _buildToggleChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? context.appAccent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? context.appAccent : context.appBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? context.appAccent : context.appTextHint,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // Section C: 핵심 결과
  // ════════════════════════════════════════════

  Widget _buildResultCard() {
    final result = _result;
    if (result == null) return const SizedBox.shrink();

    final currentMdd = result.currentMdd;
    final newMdd = result.newMdd;
    final improvement = result.mddImprovement;
    final isLoss = newMdd < 0;

    return _buildCard(
      title: '결과',
      child: Column(
        children: [
          // 평단 변화
          if (_hasAdditionalBuy) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('현재 평단', style: TextStyle(fontSize: 13, color: context.appTextSecondary)),
                Text(
                  '\$${result.currentAvgPrice.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 13, color: context.appTextPrimary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.arrow_forward, size: 14, color: context.appAccent),
                    const SizedBox(width: 4),
                    Text('새 평단', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.appTextPrimary)),
                  ],
                ),
                Text(
                  '\$${result.newAvgPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: context.appAccent,
                  ),
                ),
              ],
            ),
            if (result.avgPriceReduction != 0)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${result.avgPriceReduction > 0 ? '+' : ''}${result.avgPriceReduction.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: result.avgPriceReduction < 0
                        ? context.appStockChangePlusFg // 평단 하락 = 긍정
                        : context.appStockChangeMinusFg, // 평단 상승 = 부정
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],

          // MDD 카드
          _buildMddCard(currentMdd, newMdd, improvement, isLoss),

          const SizedBox(height: 16),

          // 포지션 요약
          InfoRow(
            label: '총 투자금',
            value: '₩${formatKrwWithComma(result.totalInvestedKrw)}',
          ),
          const SizedBox(height: 6),
          InfoRow(
            label: '총 수량',
            value: '${result.totalShares.toStringAsFixed(2)}주',
          ),
          const SizedBox(height: 6),
          InfoRow(
            label: '평가금액',
            value: '₩${formatKrwWithComma(result.evaluatedAmountKrw)}',
          ),
          const SizedBox(height: 6),
          InfoRow(
            label: '평가손익',
            value: '${result.profitLossKrw >= 0 ? '+' : ''}₩${formatKrwWithComma(result.profitLossKrw)}',
            valueColor: result.profitLossKrw >= 0
                ? AppColors.red500
                : AppColors.blue500,
          ),
          const SizedBox(height: 6),
          InfoRow(
            label: '손익률',
            value: '${result.returnRate >= 0 ? '+' : ''}${result.returnRate.toStringAsFixed(1)}%',
            valueColor: result.returnRate >= 0
                ? AppColors.red500
                : AppColors.blue500,
          ),
        ],
      ),
    );
  }

  Widget _buildMddCard(double currentMdd, double newMdd, double improvement, bool isLoss) {
    final bgColor = isLoss ? context.appStockChangeMinusBg : context.appStockChangePlusBg;
    final mddColor = isLoss ? context.appStockChangeMinusFg : context.appStockChangePlusFg;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          // 현재 MDD
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('현재 MDD', style: TextStyle(fontSize: 13, color: context.appTextSecondary)),
              Text(
                '${currentMdd >= 0 ? '+' : ''}${currentMdd.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: currentMdd >= 0 ? AppColors.red500 : AppColors.blue500,
                ),
              ),
            ],
          ),
          if (_hasAdditionalBuy) ...[
            const SizedBox(height: 8),
            // 물타기 후 MDD
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.arrow_downward, size: 16, color: mddColor),
                    const SizedBox(width: 4),
                    Text('물타기 후', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.appTextPrimary)),
                  ],
                ),
                Text(
                  '${newMdd >= 0 ? '+' : ''}${newMdd.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: newMdd >= 0 ? AppColors.red500 : AppColors.blue500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 개선폭
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('개선폭', style: TextStyle(fontSize: 13, color: context.appTextSecondary)),
                Text(
                  '${improvement >= 0 ? '+' : ''}${improvement.toStringAsFixed(1)}%p',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: improvement >= 0
                        ? AppColors.red500 // MDD 상승 = 개선
                        : AppColors.blue500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // Section D: 하락 시나리오 테이블
  // ════════════════════════════════════════════

  Widget _buildScenarioTable() {
    final result = _result;
    if (result == null || result.scenarios.isEmpty) return const SizedBox.shrink();

    return _buildCard(
      title: '하락 시나리오',
      child: Column(
        children: [
          // 헤더
          Row(
            children: [
              Expanded(flex: 2, child: Text('추가하락', style: _headerStyle)),
              Expanded(flex: 2, child: Text('예상가', style: _headerStyle, textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text('MDD', style: _headerStyle, textAlign: TextAlign.right)),
              Expanded(flex: 3, child: Text('손실금액', style: _headerStyle, textAlign: TextAlign.right)),
            ],
          ),
          Divider(height: 16, color: context.appDivider),
          // 행
          ...result.scenarios.map((row) {
            final opacity = (row.dropPercent.abs() / 100).clamp(0.05, 0.5);
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: context.appStockChangeMinusFg.withValues(alpha: opacity),
                borderRadius: BorderRadius.circular(6),
              ),
              margin: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${row.dropPercent.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appTextPrimary),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '\$${row.projectedPrice.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 13, color: context.appTextPrimary),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${row.mdd.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.blue500,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${row.lossAmountKrw >= 0 ? '+' : '-'}₩${formatCashShort(row.lossAmountKrw.abs())}',
                      style: TextStyle(
                        fontSize: 13,
                        color: row.lossAmountKrw >= 0 ? AppColors.red500 : AppColors.blue500,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  TextStyle get _headerStyle => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: context.appTextHint,
      );

  // ════════════════════════════════════════════
  // Section E: 수익률 역산
  // ════════════════════════════════════════════

  Widget _buildReverseCalcSection() {
    final result = _result;

    return _buildCard(
      title: '수익률 역산',
      child: Column(
        children: [
          _buildTextField(
            label: '목표 손익률',
            controller: _targetReturnController,
            hint: '-5.0',
            suffix: '%',
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            onChanged: _onInputChanged,
          ),
          if (result?.reverseCalc != null) ...[
            const SizedBox(height: 16),
            if (result!.reverseCalc!.isFeasible) ...[
              InfoRow(
                label: '필요 금액',
                value: '₩${formatKrwWithComma(result.reverseCalc!.requiredAmountKrw)}',
                valueColor: context.appAccent,
              ),
              const SizedBox(height: 6),
              InfoRow(
                label: '필요 수량',
                value: '${result.reverseCalc!.requiredShares.toStringAsFixed(2)}주',
              ),
              const SizedBox(height: 6),
              InfoRow(
                label: '새 평단',
                value: '\$${result.reverseCalc!.newAvgPrice.toStringAsFixed(2)}',
              ),
              // 대규모 자금 경고
              if (result.reverseCalc!.requiredAmountKrw > 1000000000)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, size: 14, color: context.appCautionColor),
                      const SizedBox(width: 4),
                      Text(
                        '대규모 자금 필요',
                        style: TextStyle(fontSize: 12, color: context.appCautionColor),
                      ),
                    ],
                  ),
                ),
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.appStockChangeMinusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result.reverseCalc!.infeasibleReason ?? '달성 불가능',
                  style: TextStyle(fontSize: 13, color: context.appTextSecondary),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // Section F: 목표가 수익
  // ════════════════════════════════════════════

  Widget _buildTargetPriceSection() {
    final result = _result;

    return _buildCard(
      title: '목표가 수익',
      child: Column(
        children: [
          _buildTextField(
            label: '목표가',
            controller: _targetPriceController,
            hint: '0.00',
            prefix: '\$',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: _onInputChanged,
          ),
          if (result?.targetPriceResult != null) ...[
            const SizedBox(height: 16),
            InfoRow(
              label: '현재 기준 수익',
              value: '${result!.targetPriceResult!.currentProfit >= 0 ? '+' : ''}₩${formatKrwWithComma(result.targetPriceResult!.currentProfit)}',
              valueColor: result.targetPriceResult!.currentProfit >= 0
                  ? AppColors.red500
                  : AppColors.blue500,
            ),
            const SizedBox(height: 6),
            if (_hasAdditionalBuy) ...[
              InfoRow(
                label: '물타기 후 수익',
                value: '${result.targetPriceResult!.newProfit >= 0 ? '+' : ''}₩${formatKrwWithComma(result.targetPriceResult!.newProfit)}',
                valueColor: result.targetPriceResult!.newProfit >= 0
                    ? AppColors.red500
                    : AppColors.blue500,
              ),
              const SizedBox(height: 6),
              InfoRow(
                label: '수익률 비교',
                value: '${result.targetPriceResult!.currentReturnRate >= 0 ? '+' : ''}${result.targetPriceResult!.currentReturnRate.toStringAsFixed(1)}%'
                    ' → ${result.targetPriceResult!.newReturnRate >= 0 ? '+' : ''}${result.targetPriceResult!.newReturnRate.toStringAsFixed(1)}%',
                valueColor: result.targetPriceResult!.newReturnRate > result.targetPriceResult!.currentReturnRate
                    ? AppColors.red500
                    : AppColors.blue500,
                flexible: true,
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // 초기화 버튼
  // ════════════════════════════════════════════

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(Icons.refresh, size: 18, color: context.appTextSecondary),
        label: Text(
          '초기화',
          style: TextStyle(color: context.appTextSecondary),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: context.appBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: _resetAll,
      ),
    );
  }

  // ════════════════════════════════════════════
  // 공통 위젯
  // ════════════════════════════════════════════

  Widget _buildCard({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder.withValues(alpha: 0.5)),
        boxShadow: context.appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.appTextPrimary,
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? prefix,
    String? suffix,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: context.appTextSecondary,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            style: TextStyle(
              fontSize: 14,
              color: context.appTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: context.appTextHint),
              prefixText: prefix,
              prefixStyle: TextStyle(
                fontSize: 14,
                color: context.appTextSecondary,
              ),
              suffixText: suffix,
              suffixStyle: TextStyle(
                fontSize: 13,
                color: context.appTextSecondary,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: context.appSurface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.appBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.appAccent, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
