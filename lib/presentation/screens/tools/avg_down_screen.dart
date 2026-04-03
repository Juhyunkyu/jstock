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

/// 3필드 연동: 마지막 입력 필드 추적
enum _EditedField { shares, amount, targetReturn }

/// 물타기 계산기 메인 화면
class AvgDownScreen extends ConsumerStatefulWidget {
  const AvgDownScreen({super.key});

  @override
  ConsumerState<AvgDownScreen> createState() => _AvgDownScreenState();
}

class _AvgDownScreenState extends ConsumerState<AvgDownScreen> {
  // === static InputFormatters (avoid per-build RegExp allocation) ===
  static final _decimalFilter = FilteringTextInputFormatter.allow(RegExp(r'[\d.]'));
  static final _commaDigitFilter = FilteringTextInputFormatter.allow(RegExp(r'[\d,]'));
  static final _signedDecimalFilter = FilteringTextInputFormatter.allow(RegExp(r'[-\d.]'));
  // === 현재 보유 ===
  final _tickerNameController = TextEditingController();
  final _holdingSharesController = TextEditingController();
  final _avgPriceController = TextEditingController();
  final _currentPriceController = TextEditingController();
  final _exchangeRateController = TextEditingController();

  // === 추가 매수 (3필드 상호 연동) ===
  final _addPriceController = TextEditingController();
  final _addAmountController = TextEditingController();
  final _addSharesController = TextEditingController();
  final _targetReturnController = TextEditingController();

  // === 목표가 ===
  final _targetPriceController = TextEditingController();

  // === 통화 모드 ===
  bool _isKrwMode = false; // false=USD, true=KRW

  // === 접이식 ===
  bool _showExchangeRate = false;
  bool _showScenario = false;

  // === 3필드 연동: 마지막 입력 필드 추적 ===
  _EditedField _lastEditedField = _EditedField.shares;

  // 프로그래밍적 텍스트 업데이트 중 순환 방지
  bool _isAutoUpdating = false;

  // === 계산 결과 ===
  AvgDownResult? _result;

  @override
  void initState() {
    super.initState();
    _targetReturnController.text = '-';
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

  bool get _hasValidInput =>
      _holdingShares > 0 && _avgPrice > 0 && _currentPrice > 0;

  /// 통화 prefix + 가격 포맷 (쉼표 포함)
  String _fmtPrice(double value) {
    if (_isKrwMode) return '₩${formatKrwWithComma(value)}';
    // USD: 정수부 쉼표 + 소수점 2자리
    final intPart = formatKrwWithComma(value.truncate().toDouble());
    final decimal = (value - value.truncate()).toStringAsFixed(2).substring(1); // .XX
    return '\$$intPart$decimal';
  }

  /// KRW 금액 포맷 (쉼표 + 부호)
  String _fmtKrw(double value) {
    final sign = value >= 0 ? '+' : '';
    return '$sign₩${formatKrwWithComma(value)}';
  }

  bool get _hasAdditionalBuy => _addPrice > 0 && _addShares > 0;

  // ════════════════════════════════════════════
  // 3필드 상호 연동 로직
  // ════════════════════════════════════════════

  /// 수량 필드 수정 → 금액, 목표손익률 자동계산
  void _onSharesChanged(String _) {
    if (_isAutoUpdating) return;
    _lastEditedField = _EditedField.shares;
    _syncFromShares();
    _recalculate();
  }

  /// 금액 필드 수정 → 수량, 목표손익률 자동계산
  void _onAmountChanged(String _) {
    if (_isAutoUpdating) return;
    _lastEditedField = _EditedField.amount;
    _syncFromAmount();
    _recalculate();
  }

  /// 목표손익률 필드 수정 → 수량, 금액 자동계산 (역산)
  void _onTargetReturnChanged(String _) {
    if (_isAutoUpdating) return;
    _lastEditedField = _EditedField.targetReturn;
    _syncFromTargetReturn();
    _recalculate();
  }

  /// 매수가 변경 → 현재 마스터 필드 기준으로 나머지 재계산
  void _onAddPriceChanged(String _) {
    if (_isAutoUpdating) return;
    _syncDependentFields();
    _recalculate();
  }

  /// MDD 계산 후 목표손익률 필드 업데이트 (공통 헬퍼)
  void _updateTargetReturnFromMdd(double shares, double price) {
    if (_holdingShares > 0 && _avgPrice > 0 && _currentPrice > 0) {
      final newAvg = AverageDownCalculator.newAveragePrice(
        holdingShares: _holdingShares,
        averagePrice: _avgPrice,
        additionalShares: shares,
        additionalPrice: price,
      );
      final newMddVal = AverageDownCalculator.mdd(
        currentPrice: _currentPrice,
        averagePrice: newAvg,
      );
      _targetReturnController.text = newMddVal.toStringAsFixed(2);
    }
  }

  /// KRW 쉼표 자동 포맷 (공통 헬퍼)
  void _autoFormatComma(TextEditingController controller, String value, ValueChanged<String> onChanged) {
    final raw = value.replaceAll(',', '');
    if (raw.isEmpty) {
      onChanged(value);
      return;
    }
    final num = int.tryParse(raw);
    if (num != null) {
      final formatted = formatKrwWithComma(num.toDouble());
      if (formatted != value) {
        controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }
    onChanged(raw);
  }

  /// 수량 기준 → 금액, 목표손익률 계산
  void _syncFromShares() {
    _isAutoUpdating = true;
    final price = _addPrice;
    final shares = _addShares;
    final exRate = _exchangeRate > 0 ? _exchangeRate : 1400.0;

    if (price > 0 && shares > 0) {
      final amount = shares * price * exRate;
      _addAmountController.text = formatKrwWithComma(amount);
      _updateTargetReturnFromMdd(shares, price);
    }
    _isAutoUpdating = false;
  }

  /// 금액 기준 → 수량, 목표손익률 계산
  void _syncFromAmount() {
    _isAutoUpdating = true;
    final price = _addPrice;
    final amount = _addAmount;
    final exRate = _exchangeRate > 0 ? _exchangeRate : 1400.0;

    if (price > 0 && amount > 0 && exRate > 0) {
      final shares = amount / (price * exRate);
      _addSharesController.text = shares.toStringAsFixed(4);
      _updateTargetReturnFromMdd(shares, price);
    }
    _isAutoUpdating = false;
  }

  /// 목표손익률 기준 → 수량, 금액 역산
  void _syncFromTargetReturn() {
    _isAutoUpdating = true;
    final price = _addPrice;
    final targetRet = _targetReturn;
    final exRate = _exchangeRate > 0 ? _exchangeRate : 1400.0;

    if (price > 0 && _holdingShares > 0 && _avgPrice > 0 && _currentPrice > 0) {
      final reverseResult = AverageDownCalculator.reverseCalc(
        holdingShares: _holdingShares,
        averagePrice: _avgPrice,
        currentPrice: _currentPrice,
        additionalPrice: price,
        exchangeRate: exRate,
        targetReturnRate: targetRet,
      );

      if (reverseResult.isFeasible && reverseResult.requiredShares > 0) {
        _addSharesController.text = reverseResult.requiredShares.toStringAsFixed(4);
        _addAmountController.text = formatKrwWithComma(reverseResult.requiredAmountKrw);
      } else {
        _addSharesController.text = '';
        _addAmountController.text = '';
      }
    }
    _isAutoUpdating = false;
  }

  /// 매수가 변경 시 현재 마스터 필드 기준으로 재계산
  void _syncDependentFields() {
    switch (_lastEditedField) {
      case _EditedField.shares:
        _syncFromShares();
      case _EditedField.amount:
        _syncFromAmount();
      case _EditedField.targetReturn:
        _syncFromTargetReturn();
    }
  }

  // ════════════════════════════════════════════
  // 계산
  // ════════════════════════════════════════════

  void _recalculate() {
    if (!_hasValidInput) {
      setState(() => _result = null);
      return;
    }

    final addPrice = _addPrice;
    final addShares = _addShares;
    final exRate = _exchangeRate > 0 ? _exchangeRate : 1400.0;

    final result = AverageDownCalculator.calculateAll(
      holdingShares: _holdingShares,
      averagePrice: _avgPrice,
      currentPrice: _currentPrice,
      exchangeRate: exRate,
      additionalRounds: addPrice > 0 && addShares > 0
          ? [(price: addPrice, shares: addShares)]
          : [],
      targetPrice: _targetPrice > 0 ? _targetPrice : null,
    );

    setState(() => _result = result);
  }

  void _onBasicInputChanged([String? _]) => _recalculate();

  // ════════════════════════════════════════════
  // 초기화
  // ════════════════════════════════════════════

  void _resetHolding() {
    _tickerNameController.clear();
    _holdingSharesController.clear();
    _avgPriceController.clear();
    _currentPriceController.clear();

    final rate = ref.read(currentExchangeRateProvider);
    _exchangeRateController.text = rate.toStringAsFixed(0);

    _recalculate();
  }

  void _resetAdditional() {
    _addPriceController.clear();
    _addAmountController.clear();
    _addSharesController.clear();
    _targetReturnController.text = '-';
    _lastEditedField = _EditedField.shares;
    _recalculate();
  }

  void _resetAll() {
    _resetHolding();
    _resetAdditional();
    _targetPriceController.clear();
  }

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
                final seedText = formatKoreanAmountShort(cycle.seedAmount);
                // Ladder: buyTicker 사용, 나머지: ticker
                final displayTicker = cycle.buyTicker.isNotEmpty
                    ? cycle.buyTicker
                    : cycle.ticker;

                return ListTile(
                  title: Text(
                    cycle.nickname.isNotEmpty
                        ? '$displayTicker (${cycle.nickname})'
                        : displayTicker,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '$strategyLabel · 시드 $seedText\n'
                    '${cycle.totalShares.toStringAsFixed(1)}주 · 평단 ${_fmtPrice(cycle.averagePrice)}',
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
    // Ladder: 실제 투입 티커 사용
    final displayTicker = cycle.buyTicker.isNotEmpty
        ? cycle.buyTicker
        : cycle.ticker;
    _tickerNameController.text = displayTicker;

    _holdingSharesController.text = cycle.totalShares > 0
        ? cycle.totalShares.toStringAsFixed(2)
        : '';
    _avgPriceController.text = cycle.averagePrice > 0
        ? cycle.averagePrice.toStringAsFixed(2)
        : '';

    // 현재가: stockQuoteProvider에서 가져오기
    final quoteState = ref.read(stockQuoteProvider);
    final quote = quoteState.quotes[displayTicker];
    if (quote != null && quote.currentPrice > 0) {
      _currentPriceController.text = quote.currentPrice.toStringAsFixed(2);
      _addPriceController.text = quote.currentPrice.toStringAsFixed(2);
    }

    // 환율: 사이클의 exchangeRateAtEntry 자동 채움
    if (cycle.exchangeRateAtEntry > 0) {
      _exchangeRateController.text = cycle.exchangeRateAtEntry.toStringAsFixed(0);
    } else {
      final rate = ref.read(currentExchangeRateProvider);
      _exchangeRateController.text = rate.toStringAsFixed(0);
    }

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
            _buildTargetPriceSection(),
            const SizedBox(height: 32),
          ],
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
            child: _buildInputSection(),
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
  // Section A: 현재 보유
  // ════════════════════════════════════════════

  Widget _buildInputSection() {
    return Column(
      children: [
        _buildCard(
          title: '현재 보유',
          titleTrailing: _buildCurrencyToggle(),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildResetButton(_resetHolding),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _showCyclePicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.appAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.appAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_outlined, size: 14, color: context.appAccent),
                      const SizedBox(width: 4),
                      Text('불러오기', style: TextStyle(fontSize: 11, color: context.appAccent)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildTextField(
                label: '종목명',
                controller: _tickerNameController,
                hint: 'TQQQ',
                onChanged: _onBasicInputChanged,
              ),
              const SizedBox(height: 12),
              _buildPriceInput(
                label: '평균단가',
                controller: _avgPriceController,
                onChanged: _onBasicInputChanged,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                label: '보유수량',
                controller: _holdingSharesController,
                hint: '0',
                suffix: '주',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_decimalFilter],
                onChanged: _onBasicInputChanged,
              ),
              const SizedBox(height: 12),
              _buildPriceInput(
                label: '현재가',
                controller: _currentPriceController,
                onChanged: _onBasicInputChanged,
              ),
              if (!_isKrwMode) ...[
              const SizedBox(height: 8),
              // 환율 접이식 (USD 모드에서만)
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
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: _onBasicInputChanged,
                ),
              ],
              ], // if (!_isKrwMode) 닫기
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Section B: 추가 매수 (3필드 상호 연동)
        _buildCard(
          title: '추가 매수',
          trailing: _buildResetButton(_resetAdditional),
          child: Column(
            children: [
              _buildPriceInput(
                label: '매수가',
                controller: _addPriceController,
                onChanged: _onAddPriceChanged,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                label: '매수수량',
                controller: _addSharesController,
                hint: '0',
                suffix: '주',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_decimalFilter],
                onChanged: _onSharesChanged,
                highlighted: _lastEditedField == _EditedField.shares,
              ),
              const SizedBox(height: 12),
              _buildAmountField(),
              const SizedBox(height: 12),
              _buildTargetReturnField(),
              if (_lastEditedField == _EditedField.targetReturn && _targetReturnController.text.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildReverseCalcInfo(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 가격 입력 필드 — KRW 모드에서 쉼표 자동 포맷
  Widget _buildPriceInput({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    if (_isKrwMode) {
      // KRW: 정수 + 쉼표 자동 포맷
      return _buildTextField(
        label: label,
        controller: controller,
        hint: '0',
        prefix: '₩',
        keyboardType: const TextInputType.numberWithOptions(decimal: false),
        inputFormatters: [_commaDigitFilter],
        onChanged: (value) => _autoFormatComma(controller, value, onChanged),
      );
    }
    // USD: 소수점 허용, 쉼표 없음
    return _buildTextField(
      label: label,
      controller: controller,
      hint: '0.00',
      prefix: '\$',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [_decimalFilter],
      onChanged: onChanged,
    );
  }

  /// 매수금액 필드 — 쉼표 포맷 + suffix에 한글 축약
  Widget _buildAmountField() {
    final highlighted = _lastEditedField == _EditedField.amount;
    final rawText = _addAmountController.text.replaceAll(',', '');
    final amount = double.tryParse(rawText) ?? 0;
    final koreanSuffix = amount >= 10000 ? '약 ${formatCashShort(amount)}' : '';

    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            '매수금액',
            style: TextStyle(
              fontSize: 13,
              color: highlighted ? context.appAccent : context.appTextSecondary,
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: _addAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [_commaDigitFilter],
            onChanged: (value) => _autoFormatComma(_addAmountController, value, _onAmountChanged),
            style: TextStyle(fontSize: 14, color: context.appTextPrimary),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(color: context.appTextHint),
              prefixText: '₩',
              prefixStyle: TextStyle(fontSize: 14, color: context.appTextSecondary),
              suffixText: koreanSuffix.isNotEmpty ? koreanSuffix : null,
              suffixStyle: TextStyle(fontSize: 11, color: context.appTextHint),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: context.appSurface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: highlighted ? context.appAccent.withValues(alpha: 0.4) : context.appBorder,
                ),
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

  /// 통화 토글 (USD/KRW)
  Widget _buildCurrencyToggle() {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: context.appIconBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCurrencyChip('USD', !_isKrwMode),
          _buildCurrencyChip('KRW', _isKrwMode),
        ],
      ),
    );
  }

  Widget _buildCurrencyChip(String label, bool selected) {
    return GestureDetector(
      onTap: () {
        final newMode = label == 'KRW';
        if (newMode == _isKrwMode) return;
        setState(() {
          _isKrwMode = newMode;
          if (_isKrwMode) {
            // KRW 모드: 환율을 1로 설정
            _exchangeRateController.text = '1';
            _showExchangeRate = false;
          } else {
            // USD 모드: 실시간 환율 복원
            final rate = ref.read(currentExchangeRateProvider);
            _exchangeRateController.text = rate.toStringAsFixed(0);
          }
          // 입력값 초기화 (통화 전환 시 값이 의미 없어짐)
          _avgPriceController.clear();
          _currentPriceController.clear();
          _addPriceController.clear();
          _targetPriceController.clear();
          _recalculate();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? context.appAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : context.appTextHint,
          ),
        ),
      ),
    );
  }

  /// 목표손익률 필드 — +/- 부호 버튼 포함
  Widget _buildTargetReturnField() {
    final highlighted = _lastEditedField == _EditedField.targetReturn;
    // 물타기 계산기이므로 기본 마이너스(손실)
    final isNegative = _targetReturnController.text.isEmpty || _targetReturnController.text.startsWith('-');

    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            '목표손익률',
            style: TextStyle(
              fontSize: 13,
              color: highlighted ? context.appAccent : context.appTextSecondary,
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        // +/- 토글 버튼
        GestureDetector(
          onTap: () {
            final text = _targetReturnController.text;
            if (text.isEmpty) {
              _targetReturnController.text = '-';
              return;
            }
            if (text.startsWith('-')) {
              _targetReturnController.text = text.substring(1);
            } else {
              _targetReturnController.text = '-$text';
            }
            _onTargetReturnChanged(_targetReturnController.text);
          },
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: isNegative ? AppColors.blue500.withValues(alpha: 0.15) : AppColors.red500.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isNegative ? AppColors.blue500.withValues(alpha: 0.4) : AppColors.red500.withValues(alpha: 0.4),
              ),
            ),
            child: Center(
              child: Text(
                isNegative ? '−' : '+',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isNegative ? AppColors.blue500 : AppColors.red500,
                ),
              ),
            ),
          ),
        ),
        // 숫자 입력 필드
        Expanded(
          child: TextField(
            controller: _targetReturnController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            inputFormatters: [_signedDecimalFilter],
            onChanged: _onTargetReturnChanged,
            style: TextStyle(fontSize: 14, color: context.appTextPrimary),
            decoration: InputDecoration(
              hintText: '-5.0',
              hintStyle: TextStyle(color: context.appTextHint),
              suffixText: '%',
              suffixStyle: TextStyle(fontSize: 13, color: context.appTextSecondary),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: context.appSurface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: highlighted ? context.appAccent.withValues(alpha: 0.4) : context.appBorder,
                ),
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

  /// 역산 결과 안내 (목표손익률 입력 시 인라인 표시)
  Widget _buildReverseCalcInfo() {
    final price = _addPrice;
    final shares = _addShares;
    if (price <= 0 || shares <= 0) {
      // 역산 실패 케이스 — 계산기 엔진 결과 확인
      if (_holdingShares > 0 && _avgPrice > 0 && _currentPrice > 0 && price > 0) {
        final exRate = _exchangeRate > 0 ? _exchangeRate : 1400.0;
        final reverseResult = AverageDownCalculator.reverseCalc(
          holdingShares: _holdingShares,
          averagePrice: _avgPrice,
          currentPrice: _currentPrice,
          additionalPrice: price,
          exchangeRate: exRate,
          targetReturnRate: _targetReturn,
        );
        if (!reverseResult.isFeasible) {
          return Padding(
            padding: const EdgeInsets.only(left: 72),
            child: Text(
              reverseResult.infeasibleReason ?? '달성 불가능',
              style: TextStyle(fontSize: 11, color: context.appTextHint),
            ),
          );
        }
      }
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 72),
      child: Text(
        '수량은 소수점 포함 참고용입니다',
        style: TextStyle(fontSize: 11, color: context.appTextHint),
      ),
    );
  }

  /// 섹션 초기화 작은 버튼
  Widget _buildResetButton(VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.appIconBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: context.appBorder),
        ),
        child: Text(
          '초기화',
          style: TextStyle(fontSize: 11, color: context.appTextSecondary),
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
                  _fmtPrice(result.currentAvgPrice),
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
                  _fmtPrice(result.newAvgPrice),
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
      trailing: GestureDetector(
        onTap: () => setState(() => _showScenario = !_showScenario),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _showScenario ? '접기' : '펼치기',
              style: TextStyle(fontSize: 12, color: context.appTextHint),
            ),
            Icon(
              _showScenario ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: context.appTextHint,
            ),
          ],
        ),
      ),
      child: !_showScenario
          ? const SizedBox.shrink()
          : Column(
        children: [
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
                      _fmtPrice(row.projectedPrice),
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
  // Section E: 목표가 수익
  // ════════════════════════════════════════════

  Widget _buildTargetPriceSection() {
    final result = _result;

    return _buildCard(
      title: '목표가 수익',
      child: Column(
        children: [
          _buildPriceInput(
            label: '목표가',
            controller: _targetPriceController,
            onChanged: _onBasicInputChanged,
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
  // 공통 위젯
  // ════════════════════════════════════════════

  Widget _buildCard({
    required String title,
    required Widget child,
    Widget? trailing,
    Widget? titleTrailing,
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
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.appTextPrimary,
                ),
              ),
              if (titleTrailing != null) ...[
                const SizedBox(width: 8),
                titleTrailing,
              ],
              const Spacer(),
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
    bool highlighted = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: highlighted ? context.appAccent : context.appTextSecondary,
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
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
                borderSide: BorderSide(
                  color: highlighted ? context.appAccent.withValues(alpha: 0.4) : context.appBorder,
                ),
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
