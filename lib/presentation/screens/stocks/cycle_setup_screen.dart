import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../../data/models/cycle.dart';
import '../../providers/providers.dart';
import '../../widgets/stocks/popular_etf_list.dart';
import '../../widgets/shared/ticker_logo.dart';

/// 새 사이클 생성 화면
class CycleSetupScreen extends ConsumerStatefulWidget {
  const CycleSetupScreen({
    super.key,
    this.initialStrategy = StrategyType.alphaCycleV3,
  });

  final StrategyType initialStrategy;

  @override
  ConsumerState<CycleSetupScreen> createState() => _CycleSetupScreenState();
}

class _CycleSetupScreenState extends ConsumerState<CycleSetupScreen> {
  // === 기본 설정 ===
  late StrategyType _selectedStrategy = widget.initialStrategy;
  String? _selectedTicker;
  String? _selectedName;
  final _seedController = TextEditingController();
  bool _isCreating = false;

  // === Strategy A: Alpha Cycle V3 파라미터 ===
  double _initialEntryRatio = 0.20;
  double _weightedBuyThreshold = -20.0;
  double _weightedBuyDivisor = 1000.0;
  double _panicBuyThreshold = -50.0;
  double _panicBuyMultiplier = 0.50;
  double _firstProfitTarget = 30.0;
  double _profitTargetStep = 5.0;
  double _minProfitTarget = 10.0;
  double _cashSecureRatio = 0.3333;

  // === Strategy B: 순정 무한매수법 파라미터 ===
  double _takeProfitPercent = 10.0;
  int _totalRounds = 40;

  // === 고급 설정 ===
  bool _showAdvanced = false;

  final _seedFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _seedFocusNode.addListener(_onSeedFocusChanged);
  }

  @override
  void dispose() {
    _seedFocusNode.removeListener(_onSeedFocusChanged);
    _seedFocusNode.dispose();
    _seedController.dispose();
    super.dispose();
  }

  void _onSeedFocusChanged() {
    if (!_seedFocusNode.hasFocus) {
      // 포커스 아웃 시 콤마 포맷팅 적용
      final text = _seedController.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (text.isNotEmpty) {
        final trimmed = text.replaceFirst(RegExp(r'^0+'), '');
        final effective = trimmed.isEmpty ? '0' : trimmed;
        _seedController.text = _addCommas(effective);
      }
    } else {
      // 포커스 인 시 콤마 제거 → 순수 숫자만
      final digits = _seedController.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty && digits != _seedController.text) {
        _seedController.text = digits;
        _seedController.selection = TextSelection.collapsed(offset: digits.length);
      }
    }
    setState(() {});
  }

  static String _addCommas(String digits) {
    final buffer = StringBuffer();
    final length = digits.length;
    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  double get _seedAmount {
    final text = _seedController.text.replaceAll(',', '');
    return double.tryParse(text) ?? 0;
  }

  bool get _canCreate =>
      _selectedTicker != null && _seedAmount >= 10000 && !_isCreating;

  @override
  Widget build(BuildContext context) {
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
          '새 사이클',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.appTextPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // 1. 전략 선택
            _buildSectionLabel('전략 선택'),
            const SizedBox(height: 8),
            _buildStrategySelector(),
            const SizedBox(height: 12),
            _buildStrategyDescription(),

            const SizedBox(height: 24),

            // 2. 종목 선택
            _buildSectionLabel('종목 선택'),
            const SizedBox(height: 8),
            _buildTickerSelector(),

            const SizedBox(height: 24),

            // 3. 시드 금액
            _buildSectionLabel('시드 금액'),
            const SizedBox(height: 8),
            _buildSeedInput(),
            if (_seedAmount > 0) ...[
              const SizedBox(height: 12),
              _buildCalculationPreview(),
            ],

            const SizedBox(height: 24),

            // 4. 고급 설정
            _buildAdvancedSettings(),

            const SizedBox(height: 32),

            // 5. 시작 버튼
            _buildStartButton(),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 섹션 라벨
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: context.appTextPrimary,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 1. 전략 선택
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStrategySelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<StrategyType>(
        segments: [
          ButtonSegment<StrategyType>(
            value: StrategyType.alphaCycleV3,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: _selectedStrategy == StrategyType.alphaCycleV3
                      ? Colors.white
                      : context.appTextSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Smart Cycle',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _selectedStrategy == StrategyType.alphaCycleV3
                        ? Colors.white
                        : context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          ButtonSegment<StrategyType>(
            value: StrategyType.infiniteBuy,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.all_inclusive,
                  size: 16,
                  color: _selectedStrategy == StrategyType.infiniteBuy
                      ? Colors.white
                      : context.appTextSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Steady Cycle',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _selectedStrategy == StrategyType.infiniteBuy
                        ? Colors.white
                        : context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
        selected: {_selectedStrategy},
        onSelectionChanged: (selected) {
          setState(() {
            _selectedStrategy = selected.first;
          });
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return context.appAccent;
            }
            return context.appSurface;
          }),
          side: WidgetStateProperty.all(
            BorderSide(color: context.appBorder, width: 0.5),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStrategyDescription() {
    final isAlpha = _selectedStrategy == StrategyType.alphaCycleV3;
    final color = isAlpha ? AppColors.blue500 : AppColors.green500;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDarkMode ? 0.10 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: context.isDarkMode ? 0.20 : 0.12),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isAlpha ? Icons.shield_outlined : Icons.all_inclusive,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAlpha ? '스마트 방어형' : '꾸준한 분할매수형',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAlpha
                      ? '하락장에서도 현금을 보존하며\n가중매수와 승부수로 저점 매수 기회를 포착합니다.\n연속 익절 시 목표가 자동 조절됩니다.'
                      : '40회 분할 매수로\n기계적으로 평균단가를 낮추며\n+10% 익절 시 복리 효과를 극대화합니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showStrategyHelp(isAlpha),
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.help_outline,
                size: 18,
                color: context.appTextHint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStrategyHelp(bool isAlpha) {
    final title = isAlpha ? 'Smart Cycle' : 'Steady Cycle';
    final description = isAlpha
        ? '📌 한 줄 요약\n'
          '시장 하락 시 가중매수로 저점을 잡고, 연속 익절하면 목표가를 높이는 적응형 전략입니다.\n\n'
          '🔍 어떻게 작동하나요?\n\n'
          '1️⃣ 시드의 20%로 첫 매수\n'
          '나머지 80%는 현금으로 보존합니다.\n\n'
          '2️⃣ 가격이 떨어지면 자동으로 더 매수\n'
          '하락폭이 클수록 매수 금액이 커지는 가중매수 방식입니다.\n'
          '평균 단가 대비 -20% 이하일 때 가중매수가 시작됩니다.\n\n'
          '3️⃣ 급락 시 승부수 (패닉바이)\n'
          '평균 단가 대비 -50% 이하의 급락이면\n'
          '잔여 현금의 50%를 과감하게 투입합니다.\n\n'
          '4️⃣ 익절 목표 자동 조절\n'
          '첫 익절 목표는 +30%입니다.\n'
          '연속 익절에 성공하면 목표가 5%씩 낮아져\n'
          '최소 +10%까지 내려갑니다.\n'
          '손실 사이클이 발생하면 다시 +30%로 리셋됩니다.\n\n'
          '5️⃣ 익절 시 현금 확보\n'
          '수익의 1/3은 현금으로 확보하여\n'
          '다음 하락에 대비합니다.\n\n'
          '✅ 이런 분에게 추천\n'
          '• 하락장에서도 안정적으로 운용하고 싶은 분\n'
          '• 감정적 매매를 줄이고 규칙 기반으로 투자하고 싶은 분\n'
          '• 한 종목에 장기 집중 투자하는 분'
        : '📌 한 줄 요약\n'
          '시드를 40회로 나눠 매회 동일 금액을 매수하고, +10% 수익 시 전량 익절하는 기계적 전략입니다.\n\n'
          '🔍 어떻게 작동하나요?\n\n'
          '1️⃣ 시드를 40등분\n'
          '예: 시드 1,000만원 → 1회당 25만원씩 매수합니다.\n\n'
          '2️⃣ 매수 타이밍\n'
          '• 현재가 ≤ 평균단가: 1회분 전액 매수 (LOC A+B)\n'
          '• 현재가 > 평균단가: 1회분의 절반만 매수 (LOC B)\n'
          '이미 수익 중이면 절반만 사서 리스크를 줄입니다.\n\n'
          '3️⃣ 익절 조건\n'
          '평가 수익률이 +10%에 도달하면\n'
          '보유 주식 전량을 매도합니다.\n\n'
          '4️⃣ 사이클 반복\n'
          '익절 후 수익금 포함하여 다시 1회차부터 시작합니다.\n'
          '복리 효과로 시드가 점점 커집니다.\n\n'
          '5️⃣ 40회 소진 시\n'
          '40회차를 모두 매수했으면\n'
          '목표 수익률에 도달할 때까지 보유합니다.\n\n'
          '✅ 이런 분에게 추천\n'
          '• 복잡한 판단 없이 기계적으로 투자하고 싶은 분\n'
          '• 변동성이 큰 레버리지 ETF (TQQQ, SOXL 등)에 투자하는 분\n'
          '• 꾸준한 복리 수익을 원하는 분';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: context.appTextSecondary,
              height: 1.6,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 2. 종목 선택
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTickerSelector() {
    if (_selectedTicker != null) {
      return _buildSelectedTicker();
    }
    return _buildTickerPickerButton();
  }

  Widget _buildSelectedTicker() {
    final quoteState = ref.watch(stockQuoteProvider);
    final quote = quoteState.quotes[_selectedTicker!];
    final currentPrice = quote?.currentPrice ?? 0.0;
    final changePercent = quote?.changePercent ?? 0.0;
    final isUp = changePercent >= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appAccent, width: 1),
      ),
      child: Row(
        children: [
          TickerLogo(
            ticker: _selectedTicker!,
            size: 36,
            borderRadius: 8,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text(
                      _selectedTicker!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.appTickerColor,
                      ),
                    ),
                    if (currentPrice > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: context.appBackground,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '\$${currentPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.appTextPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${isUp ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: changePercent == 0
                                    ? context.appTextSecondary
                                    : isUp
                                        ? AppColors.red500
                                        : AppColors.blue500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (_selectedName != null)
                  Text(
                    _selectedName!,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: context.appTextHint, size: 20),
            onPressed: () {
              setState(() {
                _selectedTicker = null;
                _selectedName = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTickerPickerButton() {
    return GestureDetector(
      onTap: _showTickerPicker,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: context.appTextHint,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '종목을 선택하세요 (예: TQQQ, SOXL)',
                style: TextStyle(
                  fontSize: 14,
                  color: context.appTextHint,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.appTextHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showTickerPicker() {
    // 이미 활성 사이클이 있는 티커 목록
    final activeCycles = ref.read(activeCyclesProvider);
    final activeTickers = activeCycles.map((c) => c.ticker).toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // 핸들
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appDivider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Text(
                    '종목 선택',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),

                // 직접 입력 필드
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: _ManualTickerInput(
                    onSubmitted: (ticker, name) {
                      Navigator.pop(context);
                      final t = ticker.toUpperCase();
                      setState(() {
                        _selectedTicker = t;
                        _selectedName = name;
                      });
                      ref.read(stockQuoteProvider.notifier).fetchQuote(t);
                    },
                  ),
                ),

                Divider(color: context.appDivider),

                // 인기 ETF 목록
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: PopularEtfList(
                      onEtfSelected: (etf) {
                        Navigator.pop(context);
                        setState(() {
                          _selectedTicker = etf.ticker;
                          _selectedName = etf.name;
                        });
                        ref.read(stockQuoteProvider.notifier).fetchQuote(etf.ticker);
                      },
                      disabledTickers: activeTickers,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 3. 시드 금액
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSeedInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _seedController,
                  focusNode: _seedFocusNode,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.appTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '10,000,000',
                    hintStyle: TextStyle(
                      color: context.appTextHint,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Text(
                '원',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
        ),
        // 한글 금액 표시 (입력 숫자와 수직 정렬)
        if (_seedAmount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 4),
            child: Text(
              _formatKoreanAmount(_seedAmount),
              style: TextStyle(
                fontSize: 13,
                color: context.appTextSecondary,
              ),
            ),
          ),
      ],
    );
  }

  static String _formatKoreanAmount(double amount) {
    final value = amount.toInt();
    if (value <= 0) return '';

    final buffer = StringBuffer();

    final eok = value ~/ 100000000;
    final man = (value % 100000000) ~/ 10000;
    final rest = value % 10000;

    if (eok > 0) {
      final eokStr = _toKoreanUnit(eok);
      buffer.write('${eokStr.isEmpty ? '일' : eokStr}억');
      if (man > 0 || rest > 0) buffer.write(' ');
    }
    if (man > 0) {
      buffer.write('${_toKoreanUnit(man)}만');
      if (rest > 0) buffer.write(' ');
    }
    if (rest > 0) {
      buffer.write(_toKoreanUnit(rest));
    }

    if (buffer.isEmpty) return '0원';
    return '${buffer}원';
  }

  static const _koreanDigits = ['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];

  /// 1~9999를 순수 한글로 변환
  /// 1000 → 천, 5000 → 오천, 100 → 백, 1500 → 천오백
  static String _toKoreanUnit(int n) {
    if (n <= 0) return '';
    final buffer = StringBuffer();
    final cheon = n ~/ 1000;
    final baek = (n % 1000) ~/ 100;
    final sip = (n % 100) ~/ 10;
    final il = n % 10;

    if (cheon > 0) {
      if (cheon > 1) buffer.write(_koreanDigits[cheon]);
      buffer.write('천');
    }
    if (baek > 0) {
      if (baek > 1) buffer.write(_koreanDigits[baek]);
      buffer.write('백');
    }
    if (sip > 0) {
      if (sip > 1) buffer.write(_koreanDigits[sip]);
      buffer.write('십');
    }
    if (il > 0) {
      buffer.write(_koreanDigits[il]);
    }
    return buffer.toString();
  }

  Widget _buildCalculationPreview() {
    final seed = _seedAmount;
    if (seed <= 0) return const SizedBox.shrink();

    final isAlpha = _selectedStrategy == StrategyType.alphaCycleV3;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '자동 계산',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (isAlpha) ...[
            _CalcRow(
              label: '초기 진입금',
              value: '${formatKrwWithComma(seed * _initialEntryRatio)}\u2009원',
              subLabel: '(${(_initialEntryRatio * 100).toStringAsFixed(0)}%)',
            ),
            const SizedBox(height: 6),
            _CalcRow(
              label: '잔여 현금',
              value:
                  '${formatKrwWithComma(seed * (1 - _initialEntryRatio))}\u2009원',
              subLabel: '(${((1 - _initialEntryRatio) * 100).toStringAsFixed(0)}%)',
            ),
            const SizedBox(height: 6),
            _CalcRow(
              label: '익절 목표',
              value: '+${_firstProfitTarget.toStringAsFixed(0)}%',
            ),
          ] else ...[
            _buildInfiniteBuyCalcRows(seed),
          ],
        ],
      ),
    );
  }

  Widget _buildInfiniteBuyCalcRows(double seed) {
    final perRound = seed / _totalRounds;
    final exchangeRate = ref.watch(currentExchangeRateProvider);
    final quoteState = ref.watch(stockQuoteProvider);
    final quote = _selectedTicker != null
        ? quoteState.quotes[_selectedTicker!]
        : null;
    final currentPrice = quote?.currentPrice ?? 0.0;

    // 달러 환산
    final perRoundUsd =
        exchangeRate > 0 ? perRound / exchangeRate : 0.0;

    // 매수 주수 (현재가 기준)
    final shares =
        currentPrice > 0 ? (perRoundUsd / currentPrice).floor() : 0;

    return Column(
      children: [
        _CalcRow(
          label: '1회 매수금액',
          value: '${formatKrwWithComma(perRound)}\u2009원',
          subLabel: perRoundUsd > 0
              ? '(약 \$${perRoundUsd.toStringAsFixed(1)})'
              : null,
        ),
        if (currentPrice > 0 && shares > 0) ...[
          const SizedBox(height: 6),
          _CalcRow(
            label: '매수 주수 (현재가 기준)',
            value: '약 $shares주',
            subLabel: '(\$${currentPrice.toStringAsFixed(2)})',
          ),
        ],
        const SizedBox(height: 6),
        _CalcRow(
          label: '총 회차',
          value: '$_totalRounds회',
        ),
        const SizedBox(height: 6),
        _CalcRow(
          label: '익절 목표',
          value: '+${_takeProfitPercent.toStringAsFixed(0)}%',
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 4. 고급 설정
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAdvancedSettings() {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _showAdvanced,
          onExpansionChanged: (expanded) {
            setState(() => _showAdvanced = expanded);
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Icon(
            Icons.tune,
            size: 20,
            color: context.appTextSecondary,
          ),
          title: Text(
            '고급 설정',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
          children: [
            if (_selectedStrategy == StrategyType.alphaCycleV3)
              _buildAlphaAdvanced()
            else
              _buildInfiniteBuyAdvanced(),
          ],
        ),
      ),
    );
  }

  Widget _buildAlphaAdvanced() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildParamSlider(
          label: '초기 진입 비율',
          value: _initialEntryRatio,
          min: 0.05,
          max: 0.50,
          divisions: 9,
          format: (v) => '${(v * 100).toStringAsFixed(0)}%',
          onChanged: (v) => setState(() => _initialEntryRatio = v),
        ),
        _buildParamSlider(
          label: '가중매수 발동 기준',
          value: _weightedBuyThreshold,
          min: -50.0,
          max: -5.0,
          divisions: 9,
          format: (v) => '${v.toStringAsFixed(0)}%',
          onChanged: (v) => setState(() => _weightedBuyThreshold = v),
        ),
        _buildParamSlider(
          label: '가중매수 금액 제수',
          value: _weightedBuyDivisor,
          min: 500.0,
          max: 2000.0,
          divisions: 6,
          format: (v) => v.toStringAsFixed(0),
          onChanged: (v) => setState(() => _weightedBuyDivisor = v),
        ),
        _buildParamSlider(
          label: '승부수 발동 기준',
          value: _panicBuyThreshold,
          min: -80.0,
          max: -30.0,
          divisions: 10,
          format: (v) => '${v.toStringAsFixed(0)}%',
          onChanged: (v) => setState(() => _panicBuyThreshold = v),
        ),
        _buildParamSlider(
          label: '승부수 투입 배율',
          value: _panicBuyMultiplier,
          min: 0.20,
          max: 1.00,
          divisions: 8,
          format: (v) => '${(v * 100).toStringAsFixed(0)}%',
          onChanged: (v) => setState(() => _panicBuyMultiplier = v),
        ),
        _buildParamSlider(
          label: '첫 익절 목표',
          value: _firstProfitTarget,
          min: 10.0,
          max: 50.0,
          divisions: 8,
          format: (v) => '+${v.toStringAsFixed(0)}%',
          onChanged: (v) => setState(() => _firstProfitTarget = v),
        ),
        _buildParamSlider(
          label: '연속 익절 감소폭',
          value: _profitTargetStep,
          min: 1.0,
          max: 10.0,
          divisions: 9,
          format: (v) => '${v.toStringAsFixed(0)}%p',
          onChanged: (v) => setState(() => _profitTargetStep = v),
        ),
        _buildParamSlider(
          label: '최소 익절 목표',
          value: _minProfitTarget,
          min: 5.0,
          max: 20.0,
          divisions: 3,
          format: (v) => '+${v.toStringAsFixed(0)}%',
          onChanged: (v) => setState(() => _minProfitTarget = v),
        ),
        _buildParamSlider(
          label: '현금 확보 비율',
          value: _cashSecureRatio,
          min: 0.10,
          max: 0.50,
          divisions: 8,
          format: (v) => '${(v * 100).toStringAsFixed(1)}%',
          onChanged: (v) => setState(() => _cashSecureRatio = v),
        ),
      ],
    );
  }

  Widget _buildInfiniteBuyAdvanced() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildParamSlider(
          label: '익절 목표',
          value: _takeProfitPercent,
          min: 5.0,
          max: 30.0,
          divisions: 5,
          format: (v) => '+${v.toStringAsFixed(0)}%',
          onChanged: (v) => setState(() => _takeProfitPercent = v),
        ),
        _buildParamSlider(
          label: '총 분할 회차',
          value: _totalRounds.toDouble(),
          min: 20.0,
          max: 80.0,
          divisions: 12,
          format: (v) => '${v.toInt()}회',
          onChanged: (v) => setState(() => _totalRounds = v.toInt()),
        ),
      ],
    );
  }

  Widget _buildParamSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTextSecondary,
                ),
              ),
              Text(
                format(value),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appAccent,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: context.appAccent,
              inactiveTrackColor: context.appDivider,
              thumbColor: context.appAccent,
              overlayColor: context.appAccent.withValues(alpha: 0.12),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 5. 시작 버튼
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _canCreate ? _createCycle : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.appAccent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: context.appDivider,
          disabledForegroundColor: context.appTextHint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isCreating
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Text(
                '사이클 시작',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _createCycle() async {
    if (!_canCreate) return;

    setState(() => _isCreating = true);

    try {
      final exchangeRate = ref.read(currentExchangeRateProvider);

      await ref.read(cycleListProvider.notifier).addCycle(
            ticker: _selectedTicker!,
            name: _selectedName ?? _selectedTicker!,
            seedAmount: _seedAmount,
            exchangeRate: exchangeRate,
            strategyType: _selectedStrategy,
            // Strategy A
            initialEntryRatio: _initialEntryRatio,
            weightedBuyThreshold: _weightedBuyThreshold,
            weightedBuyDivisor: _weightedBuyDivisor,
            panicBuyThreshold: _panicBuyThreshold,
            panicBuyMultiplier: _panicBuyMultiplier,
            firstProfitTarget: _firstProfitTarget,
            profitTargetStep: _profitTargetStep,
            minProfitTarget: _minProfitTarget,
            cashSecureRatio: _cashSecureRatio,
            // Strategy B
            takeProfitPercent: _takeProfitPercent,
            totalRounds: _totalRounds,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedTicker!} 사이클이 시작되었습니다',
            ),
            backgroundColor: AppColors.green600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('사이클 생성 실패: $e'),
            backgroundColor: AppColors.red500,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// 자동 계산 행
// ═══════════════════════════════════════════════════════════════

class _CalcRow extends StatelessWidget {
  final String label;
  final String value;
  final String? subLabel;

  const _CalcRow({
    required this.label,
    required this.value,
    this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: context.appTextSecondary,
              ),
            ),
            if (subLabel != null) ...[
              const SizedBox(width: 4),
              Text(
                subLabel!,
                style: TextStyle(
                  fontSize: 11,
                  color: context.appTextHint,
                ),
              ),
            ],
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 직접 입력 필드
// ═══════════════════════════════════════════════════════════════

class _ManualTickerInput extends StatefulWidget {
  final void Function(String ticker, String? name) onSubmitted;

  const _ManualTickerInput({required this.onSubmitted});

  @override
  State<_ManualTickerInput> createState() => _ManualTickerInputState();
}

class _ManualTickerInputState extends State<_ManualTickerInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim().toUpperCase();
    if (text.isEmpty) return;
    widget.onSubmitted(text, null);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: '티커 직접 입력 (예: TQQQ)',
              hintStyle: TextStyle(
                fontSize: 14,
                color: context.appTextHint,
                fontWeight: FontWeight.w400,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              filled: true,
              fillColor: context.appBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  Icons.arrow_forward,
                  color: context.appAccent,
                  size: 20,
                ),
                onPressed: _submit,
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// KRW 입력 포맷터 (쉼표 자동 삽입)
// ═══════════════════════════════════════════════════════════════

