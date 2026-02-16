import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/api/finnhub_service.dart';
import '../../../routes/app_router.dart';
import '../../providers/api_providers.dart';
import '../../providers/providers.dart';
import '../../widgets/common/date_picker_field.dart';
import '../../widgets/stocks/popular_etf_list.dart';
import '../../widgets/shared/ticker_logo.dart';

/// 나의 주식 등록 화면
///
/// 알파 사이클 없이 단순 보유할 종목을 등록하는 화면입니다.
class HoldingSetupScreen extends ConsumerStatefulWidget {
  final String ticker;
  final PopularEtf? etfInfo;

  const HoldingSetupScreen({
    super.key,
    required this.ticker,
    this.etfInfo,
  });

  @override
  ConsumerState<HoldingSetupScreen> createState() => _HoldingSetupScreenState();
}

class _HoldingSetupScreenState extends ConsumerState<HoldingSetupScreen> {
  final _exchangeRateController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  StockQuote? _tickerQuote;

  double get _exchangeRate => double.tryParse(_exchangeRateController.text) ?? 0;
  double get _price => double.tryParse(_priceController.text) ?? 0;
  int get _quantity => int.tryParse(_quantityController.text) ?? 0;

  String get _tickerName {
    if (widget.etfInfo != null) return widget.etfInfo!.name;

    // 기본 ETF 이름
    final etfNames = {
      'TQQQ': '나스닥 100 3x',
      'SOXL': '반도체 3x',
      'UPRO': 'S&P 500 3x',
      'TECL': '기술 3x',
      'FNGU': 'FANG+ 3x',
      'TNA': '러셀 2000 3x',
      'LABU': '바이오 3x',
      'SPXL': 'S&P 500 3x',
    };
    return etfNames[widget.ticker.toUpperCase()] ?? widget.ticker;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 환율 API 호출
      await ref.read(exchangeRateProvider.notifier).fetchUsdKrwRate();
      final currentRate = ref.read(currentExchangeRateProvider);
      _exchangeRateController.text = currentRate.toStringAsFixed(2);

      // 현재가 조회
      try {
        final quote = await ref.read(finnhubServiceProvider).getQuote(widget.ticker);
        if (mounted) setState(() => _tickerQuote = quote);
      } catch (_) {}

      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _exchangeRateController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalAmountKrw = _price * _quantity * _exchangeRate;
    final isFormValid = _exchangeRate > 0 && _price > 0 && _quantity > 0;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          color: context.appTextPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '나의 주식 등록',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.appTextPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 종목 정보 카드
            _TickerInfoCard(
              ticker: widget.ticker,
              name: _tickerName,
              quote: _tickerQuote,
            ),
            const SizedBox(height: 24),

            // 안내 메시지
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.secondary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '손익분기 매입가와 보유 수량을 입력하면\n손익을 자동으로 계산해드립니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.secondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 입력 필드 섹션
            Text(
              '보유 정보 입력',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // 첫 매수일 선택
            DatePickerField(
              label: '첫 매수일',
              selectedDate: _selectedDate,
              onDateChanged: (date) {
                setState(() {
                  _selectedDate = date;
                });
              },
              helperText: '처음 매수한 날짜를 선택하세요',
            ),
            const SizedBox(height: 16),

            // 매입환율 입력
            _InputField(
              label: '매입환율 (USD/KRW)',
              controller: _exchangeRateController,
              prefix: '\u20a9 ',
              hintText: '예: 1350.00',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              helperText: '매입 시점의 환율을 입력하세요',
            ),
            const SizedBox(height: 16),

            // 손익분기 매입가 입력
            _InputField(
              label: '손익분기 매입가 (USD)',
              controller: _priceController,
              prefix: '\$ ',
              hintText: '예: 50.00',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              helperText: '달러 기준 평균 매입 단가를 입력하세요',
            ),
            const SizedBox(height: 16),

            // 보유 수량 입력 (정수만)
            _InputField(
              label: '보유 수량 (주)',
              controller: _quantityController,
              hintText: '예: 100',
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              helperText: '보유 중인 주식 수량을 입력하세요',
              allowDecimal: false,
            ),
            const SizedBox(height: 16),

            // 예상 투자금액 표시
            if (isFormValid) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: context.isDarkMode
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '예상 투자 금액',
                      style: TextStyle(fontSize: 12, color: context.appTextSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\u20a9${_formatNumber(totalAmountKrw)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '(\$${_price.toStringAsFixed(2)} x $_quantity주 x \u20a9${_exchangeRate.toStringAsFixed(0)})',
                      style: TextStyle(fontSize: 11, color: context.appTextHint),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 메모
            _InputField(
              label: '메모 (선택)',
              controller: _noteController,
              maxLines: 3,
              hintText: '종목에 대한 메모를 입력하세요',
            ),
            const SizedBox(height: 32),

            // 등록 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isFormValid ? _registerHolding : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  disabledBackgroundColor: AppColors.gray300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '주식 등록하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    final intValue = value.round();
    final absValue = intValue.abs();
    final formatted = absValue.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return intValue < 0 ? '-$formatted' : formatted;
  }

  void _registerHolding() async {
    try {
      // 직접 값 설정으로 보유 추가
      await ref.read(holdingListProvider.notifier).addHoldingWithValues(
            ticker: widget.ticker.toUpperCase(),
            name: _tickerName,
            purchasePrice: _price,
            quantity: _quantity,
            purchaseExchangeRate: _exchangeRate,
            notes: _noteController.text.isEmpty ? null : _noteController.text,
            startDate: _selectedDate,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.ticker} 주식이 등록되었습니다'),
            backgroundColor: AppColors.secondary,
          ),
        );
        // My 탭으로 이동
        context.go(AppRouter.stocks);
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

class _TickerInfoCard extends StatelessWidget {
  final String ticker;
  final String name;
  final StockQuote? quote;

  const _TickerInfoCard({
    required this.ticker,
    required this.name,
    this.quote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondary,
            AppColors.secondaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          TickerLogo(
            ticker: ticker,
            size: 56,
            borderRadius: 14,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            textColor: Colors.white,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticker.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          if (quote != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${quote!.currentPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: quote!.isPositive
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.red.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${quote!.isPositive ? '+' : ''}${quote!.changePercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: quote!.isPositive
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFFF87171),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? prefix;
  final String? hintText;
  final String? helperText;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool allowDecimal;

  const _InputField({
    required this.label,
    required this.controller,
    this.prefix,
    this.hintText,
    this.helperText,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
    this.allowDecimal = true,
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
            fontWeight: FontWeight.w600,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          inputFormatters: _getInputFormatters(),
          decoration: InputDecoration(
            prefixText: prefix,
            hintText: hintText,
            hintStyle: const TextStyle(color: AppColors.gray400),
            filled: true,
            fillColor: context.appSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.gray200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.gray200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.secondary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: const TextStyle(fontSize: 11, color: AppColors.gray500),
          ),
        ],
      ],
    );
  }

  List<TextInputFormatter>? _getInputFormatters() {
    if (keyboardType == TextInputType.number) {
      // 정수만 허용
      return [FilteringTextInputFormatter.digitsOnly];
    } else if (keyboardType == const TextInputType.numberWithOptions(decimal: true)) {
      if (allowDecimal) {
        return [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))];
      } else {
        return [FilteringTextInputFormatter.digitsOnly];
      }
    }
    return null;
  }
}
