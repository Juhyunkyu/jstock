import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/formula_constants.dart';
import '../../providers/api_providers.dart';
import '../../providers/alpha_cycle_provider.dart';
import '../../widgets/stocks/popular_etf_list.dart';
import '../../widgets/stocks/stock_info_card.dart';
import '../../widgets/stocks/cycle_setup_widgets.dart';

/// 사이클 설정 화면
class CycleSetupScreen extends ConsumerStatefulWidget {
  final String ticker;
  final PopularEtf? etfInfo;

  const CycleSetupScreen({
    super.key,
    required this.ticker,
    this.etfInfo,
  });

  @override
  ConsumerState<CycleSetupScreen> createState() => _CycleSetupScreenState();
}

class _CycleSetupScreenState extends ConsumerState<CycleSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numberFormat = NumberFormat('#,###');

  // 시드 금액 (원 단위)
  double _seedAmountWon = 50000000; // 5천만원

  // 시드 금액 직접 입력 (원 단위)
  final _seedController = TextEditingController(text: '50,000,000');

  // 초기 진입가
  final _priceController = TextEditingController();

  // 매매 조건
  double _buyTrigger = FormulaConstants.buyTriggerPercent;
  double _sellTrigger = FormulaConstants.sellTriggerPercent;
  double _panicTrigger = FormulaConstants.panicTriggerPercent;

  // 환율: 실시간 환율 사용 (currentExchangeRateProvider)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(stockQuoteProvider.notifier).fetchQuote(widget.ticker);
    });
    _priceController.addListener(_onPriceChanged);
  }

  @override
  void dispose() {
    _priceController.removeListener(_onPriceChanged);
    _seedController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _onPriceChanged() {
    setState(() {});
  }

  int? _calculateShares(double exchangeRate) {
    final priceText = _priceController.text;
    if (priceText.isEmpty) return null;

    final priceUsd = double.tryParse(priceText);
    if (priceUsd == null || priceUsd <= 0) return null;

    final shares = _initialEntryAmount / (priceUsd * exchangeRate);
    return shares.floor();
  }

  double? _calculateActualInvestment(int shares, double exchangeRate) {
    final priceText = _priceController.text;
    if (priceText.isEmpty) return null;

    final priceUsd = double.tryParse(priceText);
    if (priceUsd == null || priceUsd <= 0) return null;

    return shares * priceUsd * exchangeRate;
  }

  void _updateSeedFromInput(String value) {
    final won = double.tryParse(value.replaceAll(',', ''));
    if (won != null && won >= 10000000 && won <= 10000000000) {
      setState(() {
        _seedAmountWon = won;
      });
    }
  }

  void _updateInputFromSlider(double billion) {
    final won = (billion * 100000000).round();
    _seedController.text = _numberFormat.format(won);
    setState(() {
      _seedAmountWon = won.toDouble();
    });
  }

  double get _sliderValue => _seedAmountWon / 100000000;
  double get _seedAmount => _seedAmountWon;
  double get _initialEntryAmount => _seedAmount * FormulaConstants.initialEntryRatio;
  double get _remainingCash => _seedAmount * FormulaConstants.remainingCashRatio;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('사이클 설정'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StockInfoCard(ticker: widget.ticker, etfInfo: widget.etfInfo),
            const SizedBox(height: 24),
            _buildSeedAmountSection(),
            const SizedBox(height: 24),
            _buildPriceSection(),
            const SizedBox(height: 24),
            _buildTradingConditions(),
            const SizedBox(height: 32),
            _buildStartButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSeedAmountSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '시드 금액',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.appTextPrimary,
                ),
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text(
                  '*최대 10억',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.red500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _seedController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            inputFormatters: [
              ThousandsSeparatorInputFormatter(),
            ],
            onChanged: _updateSeedFromInput,
            decoration: InputDecoration(
              suffixText: '원',
              suffixStyle: TextStyle(
                fontSize: 14,
                color: context.appTextSecondary,
              ),
              hintText: '50,000,000',
              filled: true,
              fillColor: context.isDarkMode ? AppColors.gray800 : AppColors.gray100,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: context.isDarkMode ? AppColors.gray700 : AppColors.gray200,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _sliderValue.clamp(0.1, 10.0),
              min: 0.1,
              max: 10.0,
              divisions: 99,
              onChanged: (value) {
                _updateInputFromSlider(value);
              },
            ),
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final buttonCount = 7;
              final spacing = 6.0;
              final totalSpacing = spacing * (buttonCount - 1);
              final buttonWidth = (constraints.maxWidth - totalSpacing) / buttonCount;

              return Wrap(
                spacing: spacing,
                runSpacing: 8,
                children: [
                  _buildPresetButton('1천만', 0.1, buttonWidth),
                  _buildPresetButton('5천만', 0.5, buttonWidth),
                  _buildPresetButton('1억', 1.0, buttonWidth),
                  _buildPresetButton('2억', 2.0, buttonWidth),
                  _buildPresetButton('5억', 5.0, buttonWidth),
                  _buildPresetButton('7억', 7.0, buttonWidth),
                  _buildPresetButton('10억', 10.0, buttonWidth),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Divider(color: context.appDivider),
          const SizedBox(height: 12),
          SummaryRow(
            label: '초기 진입금 (20%)',
            value: formatKrw(_initialEntryAmount),
          ),
          SummaryRow(
            label: '잔여 현금 (80%)',
            value: formatKrw(_remainingCash),
          ),
          Divider(height: 20, color: context.appDivider),
          SummaryRow(
            label: '총 시드',
            value: formatKrw(_seedAmount),
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(String label, double billionValue, double width) {
    final isSelected = (_sliderValue - billionValue).abs() < 0.01;
    return GestureDetector(
      onTap: () => _updateInputFromSlider(billionValue),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : (context.isDarkMode ? AppColors.gray800 : AppColors.gray100),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : context.appTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildPriceSection() {
    final exchangeRate = ref.watch(currentExchangeRateProvider);
    final shares = _calculateShares(exchangeRate);
    final actualInvestment = shares != null ? _calculateActualInvestment(shares, exchangeRate) : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '초기 진입가',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '현재 주가 또는 목표 매수가 (USD)',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    hintText: '52.34',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(color: context.isDarkMode ? AppColors.gray600 : AppColors.gray300),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: context.isDarkMode ? AppColors.gray600 : AppColors.gray300),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '입력 필요';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price <= 0) {
                      return '유효하지 않음';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          if (shares != null && shares > 0) ...[
            const SizedBox(height: 16),
            Divider(color: context.appDivider),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '적용 환율',
                  style: TextStyle(fontSize: 13, color: context.appTextSecondary),
                ),
                Text(
                  '₩${_numberFormat.format(exchangeRate.round())}/\$',
                  style: TextStyle(fontSize: 13, color: context.appTextSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '구매 가능 수량',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.appTextPrimary,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '$shares',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      ' 주',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (actualInvestment != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '실제 투자금',
                    style: TextStyle(fontSize: 13, color: context.appTextSecondary),
                  ),
                  Text(
                    formatKrw(actualInvestment),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTradingConditions() {
    return SectionCard(
      title: '매매 조건',
      subtitle: '알파 사이클 기본 설정',
      child: Column(
        children: [
          ConditionRow(label: '매수 시작점', value: _buyTrigger, suffix: '%', color: AppColors.blue500),
          const SizedBox(height: 12),
          ConditionRow(label: '익절 목표', value: _sellTrigger, suffix: '%', color: AppColors.amber500, isPositive: true),
          const SizedBox(height: 12),
          ConditionRow(label: '승부수 발동', value: _panicTrigger, suffix: '%', color: AppColors.red500),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _startCycle,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '사이클 시작하기',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _startCycle() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.parse(_priceController.text);
    final exchangeRate = ref.read(currentExchangeRateProvider);

    final creator = ref.read(cycleCreatorProvider.notifier);
    final cycle = await creator.createCycle(
      ticker: widget.ticker,
      seedAmount: _seedAmount,
      initialEntryPrice: price,
      exchangeRate: exchangeRate,
    );

    if (cycle != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.ticker} 사이클이 시작되었습니다!'),
          backgroundColor: AppColors.green500,
        ),
      );
      context.go('/stocks');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사이클 생성에 실패했습니다.'),
          backgroundColor: AppColors.red500,
        ),
      );
    }
  }
}
