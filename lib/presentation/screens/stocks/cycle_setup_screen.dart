import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/korean_number_formatter.dart';
import '../../../core/utils/krw_formatter.dart';
import '../../../data/models/cycle.dart';
import '../../../domain/trading/ladder_cycle_service.dart';
import '../../providers/providers.dart';
import '../../widgets/common/top_toast.dart';
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
  final _nicknameController = TextEditingController();
  bool _isCreating = false;

  // === Strategy A: Alpha Cycle V3 파라미터 ===
  double _initialEntryRatio = 0.20;
  double _weightedBuyThreshold = -20.0;
  double _weightedBuyPerPercent = 0.0;
  double _panicBuyThreshold = -50.0;
  double _panicBuyMultiplier = 0.50;
  double _firstProfitTarget = 30.0;
  double _profitTargetStep = 5.0;
  double _minProfitTarget = 10.0;
  double _cashSecureRatio = 0.3333;

  // === Strategy B: 순정 무한매수법 파라미터 ===
  double _takeProfitPercent = 10.0;
  int _totalRounds = 40;

  // === Strategy B V2.2/V3.0 파라미터 ===
  SteadyVersion _steadyVersion = SteadyVersion.v1;
  double _sellQuarterPercent = 0.25;
  bool _compoundEnabled = false;
  double _offsetA = 15.0;
  double _offsetB = 1.5;
  double _quarterModeOffset = -15.0;

  // === Strategy C: Ladder Cycle 파라미터 ===
  int _ladderMode = 1; // 0=안정형, 1=공격형
  double _athPrice = 0;
  int _ladderSteps = 6;
  String _ladderWeights = '1,1,2,3,4,5';
  String _ladderTriggers = '-10,-19,-28,-37,-46,-55';
  int _ladderPreset = 1; // 0=균등, 1=가속, 2=피보나치, 3=마틴게일, 4=커스텀
  List<double> _customWeightPercents = [6.25, 6.25, 12.5, 18.75, 25.0, 31.25];
  final _athController = TextEditingController();

  // === Ladder 매수 티커 (v3.2) ===
  String? _buyTicker;
  String? _buyTickerName;
  String? _buyTicker1x;
  String? _buyTicker1xName;
  String? _buyTicker2x;
  String? _buyTicker2xName;
  String? _buyTicker3x;
  String? _buyTicker3xName;

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
    _nicknameController.dispose();
    _athController.dispose();
    super.dispose();
  }

  void _onSeedFocusChanged() {
    if (!_seedFocusNode.hasFocus) {
      // 포커스 아웃 시 콤마 포맷팅 적용
      final text = _seedController.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (text.isNotEmpty) {
        final trimmed = text.replaceFirst(RegExp(r'^0+'), '');
        final effective = trimmed.isEmpty ? '0' : trimmed;
        _seedController.text = addCommas(effective);
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

  // _addCommas → korean_number_formatter.dart의 addCommas() 사용

  double get _seedAmount {
    final text = _seedController.text.replaceAll(',', '');
    return double.tryParse(text) ?? 0;
  }

  double get _effectivePerPercent =>
      _weightedBuyPerPercent > 0 ? _weightedBuyPerPercent : _seedAmount * 0.00007;

  /// Ladder 커스텀 프리셋의 실제 투입 시드를 계산합니다.
  ///
  /// 커스텀 비율 합계가 100%와 다르면 시드를 비례 조정합니다.
  /// 커스텀이 아니면 baseSeed를 그대로 반환합니다.
  double _calculateActualSeed(double baseSeed) {
    if (_ladderPreset != 4) return baseSeed;
    final customTotal = _customWeightPercents
        .take(_ladderSteps)
        .fold<double>(0, (s, v) => s + v);
    if (customTotal > 0 && (customTotal - 100.0).abs() > 0.5) {
      return baseSeed * customTotal / 100;
    }
    return baseSeed;
  }

  bool get _canCreate {
    if (_selectedTicker == null || _seedAmount < 10000 || _isCreating) {
      return false;
    }
    if (_selectedStrategy == StrategyType.ladderCycle) {
      if (_athPrice <= 0) return false;
      // 공격형: 매수 티커 필수
      if (_ladderMode == 1 && _buyTicker == null) return false;
      // 안정형: 1배/2배/3배 모두 필수
      if (_ladderMode == 0 && (_buyTicker1x == null || _buyTicker2x == null || _buyTicker3x == null)) return false;
      // 커스텀 비율일 때 경고만 표시 (버튼은 활성 유지)
    }
    return true;
  }

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

            // Steady 버전 선택 (Steady 선택 시에만)
            if (_selectedStrategy == StrategyType.infiniteBuy) ...[
              const SizedBox(height: 16),
              _buildSteadyVersionSelector(),
            ],

            // Ladder 매수 모드 선택 (Ladder 선택 시에만)
            if (_selectedStrategy == StrategyType.ladderCycle) ...[
              const SizedBox(height: 16),
              _buildLadderModeSelector(),
            ],

            const SizedBox(height: 24),

            // 2. Ladder: ATH 먼저 → 기준 티커 → 매수 티커
            if (_selectedStrategy == StrategyType.ladderCycle) ...[
              // ATH 가격 (먼저 입력 — 전고점을 기억할 때 바로)
              _buildSectionLabel('ATH 가격 (USD)'),
              const SizedBox(height: 8),
              _buildAthPriceInput(),
              const SizedBox(height: 24),

              // 기준 티커
              _buildSectionLabel('기준 티커 (MDD 계산용)'),
              const SizedBox(height: 8),
              _buildTickerSelector(),
              Padding(
                padding: const EdgeInsets.only(left: 2, top: 6),
                child: Text(
                  '※ ATH 대비 하락률(MDD) 계산에 사용되는 지수/ETF',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appTextHint,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 매수 티커
              _buildLadderBuyTickerSection(),
            ] else ...[
              _buildSectionLabel('종목 선택'),
              const SizedBox(height: 8),
              _buildTickerSelector(),
            ],

            const SizedBox(height: 24),

            // 2.5. 별명 (선택)
            _buildSectionLabel('별명 (선택)'),
            const SizedBox(height: 8),
            _buildNicknameInput(),

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
                  'Smart',
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
                  'Steady',
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
          ButtonSegment<StrategyType>(
            value: StrategyType.ladderCycle,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.stacked_bar_chart,
                  size: 16,
                  color: _selectedStrategy == StrategyType.ladderCycle
                      ? Colors.white
                      : context.appTextSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Ladder',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _selectedStrategy == StrategyType.ladderCycle
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
    final isLadder = _selectedStrategy == StrategyType.ladderCycle;
    final color = isAlpha
        ? AppColors.blue500
        : isLadder
            ? AppColors.amber500
            : AppColors.green500;

    final (title, desc, icon) = isAlpha
        ? (
            '스마트 방어형',
            '하락장에서도 현금을 보존하며\n가중매수와 승부수로 저점 매수 기회를 포착합니다.\n연속 익절 시 목표가 자동 조절됩니다.',
            Icons.shield_outlined,
          )
        : isLadder
            ? (
                'MDD 기반 가속 분할매수형',
                'ATH 대비 하락률에 따라 단계별로 비중을 높여\n하락할수록 공격적으로 매집합니다.\n고급 설정에서 단계 수, 비율을 커스텀할 수 있습니다.\n\n'
                '추천 조합 (기준 → 1배 → 2배 → 3배):\n'
                '• QQQ → QQQ → QLD → TQQQ (나스닥 100)\n'
                '• SPY → SPY → SSO → UPRO (S&P 500)\n'
                '• IWM → IWM → UWM → TNA (러셀 2000)\n'
                '• DIA → DIA → DDM → UDOW (다우존스)',
                Icons.stacked_bar_chart,
              )
            : (
                _steadyVersion == SteadyVersion.v1
                    ? '꾸준한 분할매수형'
                    : _steadyVersion == SteadyVersion.v2_2
                        ? '정통 LOC형 (V2.2)'
                        : '공격적 복리형',
                _steadyVersion == SteadyVersion.v1
                    ? '40회 분할 매수로\n기계적으로 평균단가를 낮추며\n+10% 익절 시 복리 효과를 극대화합니다.'
                    : _steadyVersion == SteadyVersion.v2_2
                        ? 'T값 기반 LOC 주문으로\n매일 매수+매도를 동시에 걸며\n하락장에서 현금을 보존합니다.'
                        : '20분할 공격적 LOC와\n사이클 내 반복리로\n고변동성 종목에서 빠른 사이클 회전.',
                Icons.all_inclusive,
              );

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
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
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
            onTap: () => _showStrategyHelp(isAlpha, isLadder: isLadder),
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

  Widget _buildSteadyVersionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('버전 선택'),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<SteadyVersion>(
            segments: [
              ButtonSegment<SteadyVersion>(
                value: SteadyVersion.v1,
                label: Text(
                  'V1 Simple',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _steadyVersion == SteadyVersion.v1
                        ? Colors.white
                        : context.appTextSecondary,
                  ),
                ),
              ),
              ButtonSegment<SteadyVersion>(
                value: SteadyVersion.v2_2,
                label: Text(
                  'V2.2 Original',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _steadyVersion == SteadyVersion.v2_2
                        ? Colors.white
                        : context.appTextSecondary,
                  ),
                ),
              ),
              ButtonSegment<SteadyVersion>(
                value: SteadyVersion.v3_0,
                label: Text(
                  'V3.0 Aggr',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _steadyVersion == SteadyVersion.v3_0
                        ? Colors.white
                        : context.appTextSecondary,
                  ),
                ),
              ),
            ],
            selected: {_steadyVersion},
            onSelectionChanged: (selected) {
              setState(() {
                _steadyVersion = selected.first;
                _applyVersionDefaults();
              });
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.green600;
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
        ),
        const SizedBox(height: 10),
        _buildVersionCard(),
      ],
    );
  }

  void _applyVersionDefaults() {
    switch (_steadyVersion) {
      case SteadyVersion.v1:
        _totalRounds = 40;
        _takeProfitPercent = 10.0;
        _sellQuarterPercent = 0.25;
        _compoundEnabled = false;
        _offsetA = 10.0;
        _offsetB = 0.5;
        _quarterModeOffset = -10.0;
        break;
      case SteadyVersion.v2_2:
        _totalRounds = 40;
        _takeProfitPercent = 10.0;
        _sellQuarterPercent = 0.25;
        _compoundEnabled = false;
        _offsetA = 10.0;
        _offsetB = 0.5 * (40 / _totalRounds);
        _quarterModeOffset = -10.0;
        break;
      case SteadyVersion.v3_0:
        _totalRounds = 20;
        _takeProfitPercent = 15.0;
        _sellQuarterPercent = 0.25;
        _compoundEnabled = true;
        _offsetA = 15.0;
        _offsetB = 1.5;
        _quarterModeOffset = -15.0;
        break;
    }
  }

  Widget _buildVersionCard() {
    final (title, desc, icon) = switch (_steadyVersion) {
      SteadyVersion.v1 => (
        'V1 Simple',
        '40분할 · 단순 매수 · 전량 익절\n입문자 추천 · 상승장 최고 효율',
        Icons.sentiment_satisfied_alt,
      ),
      SteadyVersion.v2_2 => (
        'V2.2 Original',
        '40분할 · T값 LOC · 매일 매수+매도\n하락장 방어 우수 (MDD -40%)',
        Icons.shield_outlined,
      ),
      SteadyVersion.v3_0 => (
        'V3.0 Aggressive',
        '20분할 · 공격적 LOC · 사이클 내 복리\n고변동성(SOXL) 시너지',
        Icons.bolt,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.green500.withValues(
          alpha: context.isDarkMode ? 0.08 : 0.04,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.green500.withValues(
            alpha: context.isDarkMode ? 0.15 : 0.10,
          ),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.green500),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.green500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appTextSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStrategyHelp(bool isAlpha, {bool isLadder = false}) {
    final title = isLadder ? 'Ladder Cycle' : isAlpha ? 'Smart Cycle' : 'Steady Cycle';
    final description = isLadder
        ? 'Ladder Cycle — MDD 기반 가속 분할매수\n\n'
          'ATH(역사적 신고가) 대비 하락률에 따라 단계별로 매수 비중을 높여가는 전략입니다. '
          '하락이 깊어질수록 더 많은 금액을 투입하여 평균 매입가를 극적으로 낮춥니다.\n\n'
          '6단계 기본 비중 (1-1-2-3-4-5):\n'
          '• 1단계(-10%): 6.25% — 정찰대\n'
          '• 2단계(-19%): 6.25% — 심리적 완충\n'
          '• 3단계(-28%): 12.5% — 본격 매집\n'
          '• 4단계(-37%): 18.75% — 공포 대응\n'
          '• 5단계(-46%): 25% — 패닉 매집\n'
          '• 6단계(-55%): 31.25% — 항복 전량 투입\n\n'
          '고급 설정에서 단계 수(3~6)와 비율을 변경할 수 있습니다.\n\n'
          '매수 모드:\n\n'
          '── 안정형 ──\n'
          '같은 지수를 추종하는 1배/2배/3배 ETF를 단계별로 나눠 매수합니다. '
          '초반엔 안정적인 1배로 시작하고, 하락이 깊어지면 레버리지를 높여갑니다.\n\n'
          '예시) QQQ 기준:\n'
          '• 1단계: QQQ (1배) 매수\n'
          '• 2단계: QLD (2배) 매수\n'
          '• 3~6단계: TQQQ (3배) 매수\n\n'
          '추천 조합 (기준 → 1배 → 2배 → 3배):\n'
          '• QQQ → QQQ → QLD → TQQQ (나스닥 100)\n'
          '• SPY → SPY → SSO → UPRO (S&P 500)\n'
          '• IWM → IWM → UWM → TNA (러셀 2000)\n'
          '• DIA → DIA → DDM → UDOW (다우존스)\n\n'
          '※ 위 조합은 추천이며, 원하는 티커를 자유롭게 선택할 수 있습니다.\n\n'
          '── 공격형 ──\n'
          '처음부터 3배 레버리지 ETF를 모든 단계에서 매수합니다. '
          '기준 지수의 하락률(MDD)로 매수 시점을 판단하되, '
          '실제 매수는 해당 지수의 3배 레버리지로 집중 투입합니다.\n\n'
          '예시) SOXX 기준:\n'
          '• 1~6단계: SOXL (3배) 매수\n\n'
          '※ 기준 지수와 매수 티커는 자유롭게 선택 가능합니다.\n\n'
          '사이클 종료:\n'
          '지수가 새로운 신고점에 도달하면 사이클 종료를 고려합니다. '
          '매도 시점은 매도 가이드를 참고하여 직접 판단합니다.'
        : isAlpha
        ? '시장 하락 시 가중매수로 저점을 잡고, 연속 익절하면 목표가를 높이는 적응형 전략입니다.\n\n'
          '— 작동 방식\n\n'
          '1. 시드의 20%로 첫 매수\n'
          '나머지 80%는 현금으로 보존합니다.\n\n'
          '2. 가격이 떨어지면 자동으로 더 매수\n'
          '하락폭이 클수록 매수 금액이 커지는 가중매수 방식입니다.\n'
          '평균 단가 대비 -20% 이하일 때 가중매수가 시작됩니다.\n\n'
          '3. 급락 시 승부수 (패닉바이)\n'
          '평균 단가 대비 -50% 이하의 급락이면\n'
          '잔여 현금의 50%를 과감하게 투입합니다.\n\n'
          '4. 익절 목표 자동 조절\n'
          '첫 익절 목표는 +30%입니다.\n'
          '연속 익절에 성공하면 목표가 5%씩 낮아져\n'
          '최소 +10%까지 내려갑니다.\n'
          '손실 사이클이 발생하면 다시 +30%로 리셋됩니다.\n\n'
          '5. 익절 시 현금 확보\n'
          '수익의 1/3은 현금으로 확보하여\n'
          '다음 하락에 대비합니다.\n\n'
          '— 추천 대상\n'
          '• 하락장에서도 안정적으로 운용하고 싶은 분\n'
          '• 감정적 매매를 줄이고 규칙 기반으로 투자하고 싶은 분\n'
          '• 한 종목에 장기 집중 투자하는 분'
        : '시드를 40회로 나눠 매회 동일 금액을 매수하고, +10% 수익 시 전량 익절하는 기계적 전략입니다.\n\n'
          '— 작동 방식\n\n'
          '1. 시드를 40등분\n'
          '예: 시드 1,000만원 → 1회당 25만원씩 매수합니다.\n\n'
          '2. 매수 타이밍\n'
          '• 현재가 ≤ 평균단가: 1회분 전액 매수 (LOC A+B)\n'
          '• 현재가 > 평균단가: 1회분의 절반만 매수 (LOC B)\n'
          '이미 수익 중이면 절반만 사서 리스크를 줄입니다.\n\n'
          '3. 익절 조건\n'
          '평가 수익률이 +10%에 도달하면\n'
          '보유 주식 전량을 매도합니다.\n\n'
          '4. 사이클 반복\n'
          '익절 후 수익금 포함하여 다시 1회차부터 시작합니다.\n'
          '복리 효과로 시드가 점점 커집니다.\n\n'
          '5. 40회 소진 시\n'
          '40회차를 모두 매수했으면\n'
          '목표 수익률에 도달할 때까지 보유합니다.\n\n'
          '— 추천 대상\n'
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
    final quote = ref.watch(
      stockQuoteProvider.select((s) => s.quotes[_selectedTicker!]),
    );
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
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
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

                // 최근 조회 종목 목록
                Expanded(
                  child: _RecentTickerList(
                    scrollController: scrollController,
                    onSelected: (ticker, name) {
                      Navigator.pop(context);
                      setState(() {
                        _selectedTicker = ticker;
                        _selectedName = name;
                      });
                      ref.read(stockQuoteProvider.notifier).fetchQuote(ticker);
                    },
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
  // 2-1. Ladder 매수 티커 선택 (v3.2)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLadderBuyTickerSection() {
    if (_ladderMode == 1) {
      // 공격형: 매수 티커 1개
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('매수 티커'),
          const SizedBox(height: 8),
          _buildBuyTickerPicker(
            ticker: _buyTicker,
            name: _buyTickerName,
            hint: '매수할 종목 선택 (예: TQQQ, SOXL)',
            onSelected: (ticker, name) {
              setState(() {
                _buyTicker = ticker;
                _buyTickerName = name;
              });
              ref.read(stockQuoteProvider.notifier).fetchQuote(ticker);
            },
            onClear: () => setState(() {
              _buyTicker = null;
              _buyTickerName = null;
            }),
          ),
        ],
      );
    }

    // 안정형: 1배/2배/3배 매수 티커 3개
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('매수 티커 (1배 / 2배 / 3배)'),
        const SizedBox(height: 8),
        _buildLabeledBuyTickerPicker(
          label: '1배',
          ticker: _buyTicker1x,
          name: _buyTicker1xName,
          hint: '1배 ETF (예: QQQ)',
          onSelected: (ticker, name) {
            setState(() {
              _buyTicker1x = ticker;
              _buyTicker1xName = name;
            });
            ref.read(stockQuoteProvider.notifier).fetchQuote(ticker);
          },
          onClear: () => setState(() {
            _buyTicker1x = null;
            _buyTicker1xName = null;
          }),
        ),
        const SizedBox(height: 8),
        _buildLabeledBuyTickerPicker(
          label: '2배',
          ticker: _buyTicker2x,
          name: _buyTicker2xName,
          hint: '2배 ETF (예: QLD)',
          onSelected: (ticker, name) {
            setState(() {
              _buyTicker2x = ticker;
              _buyTicker2xName = name;
            });
            ref.read(stockQuoteProvider.notifier).fetchQuote(ticker);
          },
          onClear: () => setState(() {
            _buyTicker2x = null;
            _buyTicker2xName = null;
          }),
        ),
        const SizedBox(height: 8),
        _buildLabeledBuyTickerPicker(
          label: '3배',
          ticker: _buyTicker3x,
          name: _buyTicker3xName,
          hint: '3배 ETF (예: TQQQ)',
          onSelected: (ticker, name) {
            setState(() {
              _buyTicker3x = ticker;
              _buyTicker3xName = name;
            });
            ref.read(stockQuoteProvider.notifier).fetchQuote(ticker);
          },
          onClear: () => setState(() {
            _buyTicker3x = null;
            _buyTicker3xName = null;
          }),
        ),
      ],
    );
  }

  Widget _buildLabeledBuyTickerPicker({
    required String label,
    required String? ticker,
    required String? name,
    required String hint,
    required void Function(String, String?) onSelected,
    required VoidCallback onClear,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildBuyTickerPicker(
            ticker: ticker,
            name: name,
            hint: hint,
            onSelected: onSelected,
            onClear: onClear,
          ),
        ),
      ],
    );
  }

  Widget _buildBuyTickerPicker({
    required String? ticker,
    required String? name,
    required String hint,
    required void Function(String, String?) onSelected,
    required VoidCallback onClear,
  }) {
    if (ticker != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.appAccent, width: 1),
        ),
        child: Row(
          children: [
            TickerLogo(ticker: ticker, size: 24, borderRadius: 6),
            const SizedBox(width: 8),
            Text(
              ticker,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.appTickerColor,
              ),
            ),
            if (name != null) ...[
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(fontSize: 11, color: context.appTextSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Spacer(),
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, color: context.appTextHint, size: 18),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showTickerPickerFor(onSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: context.appTextHint, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint,
                style: TextStyle(fontSize: 13, color: context.appTextHint),
              ),
            ),
            Icon(Icons.chevron_right, color: context.appTextHint, size: 18),
          ],
        ),
      ),
    );
  }

  void _showTickerPickerFor(void Function(String, String?) onSelected) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '종목 선택',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _ManualTickerInput(
                    onSubmitted: (ticker, name) {
                      Navigator.pop(context);
                      onSelected(ticker.toUpperCase(), name);
                    },
                  ),
                ),
                Divider(color: context.appDivider),
                Expanded(
                  child: _RecentTickerList(
                    scrollController: scrollController,
                    onSelected: (ticker, name) {
                      Navigator.pop(context);
                      onSelected(ticker, name);
                    },
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
  // 2.5. 별명 입력 (선택)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildNicknameInput() {
    return TextField(
      controller: _nicknameController,
      maxLength: 20,
      style: TextStyle(
        fontSize: 15,
        color: context.appTextPrimary,
      ),
      decoration: InputDecoration(
        hintText: '예: 공격형, 장기투자...',
        hintStyle: TextStyle(color: context.appTextHint),
        counterStyle: TextStyle(color: context.appTextHint),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.appBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.appAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
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
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
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
                  onChanged: (_) => setState(() {
                    _weightedBuyPerPercent = 0.0; // 시드 변경 시 자동 계산 모드로 리셋
                  }),
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
              formatKoreanAmountFull(_seedAmount),
              style: TextStyle(
                fontSize: 13,
                color: context.appTextSecondary,
              ),
            ),
          ),
      ],
    );
  }

  // _formatKoreanAmount, _toKoreanUnit → korean_number_formatter.dart로 이동

  Widget _buildCalculationPreview() {
    final seed = _seedAmount;
    if (seed <= 0) return const SizedBox.shrink();

    final isAlpha = _selectedStrategy == StrategyType.alphaCycleV3;
    final isLadder = _selectedStrategy == StrategyType.ladderCycle;

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
            isLadder ? '자동 계산 — $_ladderSteps단계 투입 계획' : '자동 계산',
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
          ] else if (isLadder) ...[
            // 커스텀 절대 비율: 실제 투입 예정금 표시
            if (_ladderPreset == 4) ...[
              Builder(builder: (_) {
                final actualSeed = _calculateActualSeed(seed);
                final customTotal = _customWeightPercents
                    .take(_ladderSteps)
                    .fold<double>(0, (s, v) => s + v);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CalcRow(
                      label: '시드 금액',
                      value: '${formatKrwWithComma(seed)}\u2009원',
                    ),
                    if ((customTotal - 100.0).abs() > 0.5) ...[
                      const SizedBox(height: 6),
                      _CalcRow(
                        label: '커스텀 합계',
                        value: '${customTotal.toStringAsFixed(0)}%',
                      ),
                      const SizedBox(height: 6),
                      _CalcRow(
                        label: '실제 투입 예정',
                        value: '${formatKrwWithComma(actualSeed)}\u2009원',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '⚠ 시드가 자동으로 조정됩니다',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.amber500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _buildLadderCalcRows(actualSeed),
                  ],
                );
              }),
            ] else ...[
              _buildLadderCalcRows(seed),
            ],
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
    final quote = ref.watch(
      stockQuoteProvider.select((s) => _selectedTicker != null
          ? s.quotes[_selectedTicker!]
          : null),
    );
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
            else if (_selectedStrategy == StrategyType.ladderCycle)
              _buildLadderAdvanced()
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
          label: '초기 진입 비율 (시드의)',
          value: _initialEntryRatio,
          min: 0.05,
          max: 0.50,
          divisions: 9,
          format: (v) => '${(v * 100).toStringAsFixed(0)}%',
          onChanged: (v) => setState(() => _initialEntryRatio = v),
        ),
        _buildParamSlider(
          label: '가중매수 발동 기준 (손실률)',
          value: _weightedBuyThreshold,
          min: -50.0,
          max: -5.0,
          divisions: 9,
          format: (v) => '${v.toStringAsFixed(0)}%',
          onChanged: (v) => setState(() => _weightedBuyThreshold = v),
        ),
        _buildParamSlider(
          label: '가중매수 1%당 금액',
          value: _effectivePerPercent,
          min: _seedAmount * 0.00003,
          max: _seedAmount * 0.00015,
          divisions: 12,
          format: (v) => '${(v / 10000).toStringAsFixed(1)}만원',
          onChanged: (v) => setState(() => _weightedBuyPerPercent = v),
        ),
        _buildParamSlider(
          label: '승부수 발동 기준 (손실률)',
          value: _panicBuyThreshold,
          min: -80.0,
          max: -30.0,
          divisions: 10,
          format: (v) => '${v.toStringAsFixed(0)}%',
          onChanged: (v) => setState(() => _panicBuyThreshold = v),
        ),
        _buildParamSlider(
          label: '승부수 투입 배율 (평가금의)',
          value: _panicBuyMultiplier,
          min: 0.20,
          max: 1.00,
          divisions: 8,
          format: (v) => '${(v * 100).toStringAsFixed(0)}%',
          onChanged: (v) => setState(() => _panicBuyMultiplier = v),
        ),
        _buildParamSlider(
          label: '첫 익절 목표 (수익률)',
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
          label: '최소 익절 목표 (수익률)',
          value: _minProfitTarget,
          min: 5.0,
          max: 20.0,
          divisions: 3,
          format: (v) => '+${v.toStringAsFixed(0)}%',
          onChanged: (v) => setState(() => _minProfitTarget = v),
        ),
        _buildParamSlider(
          label: '현금 확보 비율 (총자산의)',
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
          onChanged: (v) => setState(() {
            _totalRounds = v.toInt();
            // V2.2: offsetB 자동 재계산
            if (_steadyVersion == SteadyVersion.v2_2) {
              _offsetB = 0.5 * (40 / _totalRounds);
            }
          }),
        ),
        // V2.2/V3.0: 매도 LOC 비율
        if (_steadyVersion != SteadyVersion.v1)
          _buildParamSlider(
            label: '매도 LOC 비율 (보유량의)',
            value: _sellQuarterPercent,
            min: 0.10,
            max: 0.50,
            divisions: 8,
            format: (v) => '${(v * 100).toStringAsFixed(0)}%',
            onChanged: (v) => setState(() => _sellQuarterPercent = v),
          ),
        // V3.0: 복리 토글
        if (_steadyVersion == SteadyVersion.v3_0)
          _buildCompoundToggle(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Ladder Cycle 전용 UI
  // ═══════════════════════════════════════════════════════════════

  static const _ladderModeLabels = ['안정형', '공격형'];

  // 프리셋별 비중 데이터 (steps → weights)
  static const _presetNames = ['균등', '가속', '피보', '마틴', '커스텀'];

  static List<int> _presetWeights(int preset, int steps) {
    switch (preset) {
      case 0: // 균등형
        return List.filled(steps, 1);
      case 2: // 피보나치형
        return switch (steps) {
          3 => [1, 2, 3],
          4 => [1, 1, 2, 3],
          5 => [1, 1, 2, 3, 5],
          _ => [1, 1, 2, 3, 5, 8],
        };
      case 3: // 마틴게일 (각 단계 = 이전의 2배)
        return List.generate(steps, (i) => 1 << i); // 1, 2, 4, 8, 16, 32
      default: // 가속형 (1) — ladder_cycle_service 기본값
        return switch (steps) {
          3 => [2, 3, 5],
          4 => [1, 2, 3, 4],
          5 => [1, 1, 2, 3, 3],
          _ => [1, 1, 2, 3, 4, 5],
        };
    }
  }

  void _updateLadderWeightsFromPreset() {
    if (_ladderPreset == 4) return; // 커스텀은 직접 관리
    final weights = _presetWeights(_ladderPreset, _ladderSteps);
    _ladderWeights = weights.join(',');
    // 커스텀 퍼센트도 동기화
    final total = weights.fold<int>(0, (s, w) => s + w);
    _customWeightPercents = weights
        .map((w) => total > 0 ? (w / total * 100) : 0.0)
        .toList();
  }

  void _updateLadderTriggersFromSteps() {
    final triggers = parseLadderTriggers('', steps: _ladderSteps);
    _ladderTriggers = triggers.map((t) => t.toStringAsFixed(0)).join(',');
  }

  Widget _buildLadderModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('매수 모드'),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: List.generate(2, (i) => ButtonSegment<int>(
              value: i,
              label: Text(
                _ladderModeLabels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _ladderMode == i
                      ? Colors.white
                      : context.appTextSecondary,
                ),
              ),
            )),
            selected: {_ladderMode},
            onSelectionChanged: (selected) {
              setState(() => _ladderMode = selected.first);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.amber600;
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
        ),
      ],
    );
  }

  Widget _buildAthPriceInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        children: [
          Text(
            '\$ ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.appTextSecondary,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _athController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.appTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: '542.85',
                hintStyle: TextStyle(
                  color: context.appTextHint,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
              ),
              onChanged: (v) {
                setState(() {
                  _athPrice = double.tryParse(v) ?? 0;
                });
              },
            ),
          ),
          Text(
            'USD',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLadderCalcRows(double seed) {
    final weights = parseLadderWeights(_ladderWeights, steps: _ladderSteps);
    final triggers = parseLadderTriggers(_ladderTriggers, steps: _ladderSteps);
    final totalWeight = weights.fold<int>(0, (s, w) => s + w);

    if (totalWeight == 0) return const SizedBox.shrink();

    return Column(
      children: List.generate(weights.length.clamp(0, _ladderSteps), (i) {
        final amount = seed * weights[i] / totalWeight;
        final pct = weights[i] / totalWeight * 100;
        final triggerStr = i < triggers.length
            ? triggers[i].toStringAsFixed(0)
            : '?';
        return Padding(
          padding: EdgeInsets.only(bottom: i < _ladderSteps - 1 ? 6 : 0),
          child: _CalcRow(
            label: '${i + 1}단계 ($triggerStr%)',
            value: '${formatKrwWithComma(amount)}\u2009원',
            subLabel: '(${pct.toStringAsFixed(2)}%)',
          ),
        );
      }),
    );
  }

  Widget _buildLadderAdvanced() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 분할 단계
        Text(
          '분할 단계',
          style: TextStyle(fontSize: 12, color: context.appTextSecondary),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: [3, 4, 5, 6].map((n) => ButtonSegment<int>(
              value: n,
              label: Text(
                '$n',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _ladderSteps == n
                      ? Colors.white
                      : context.appTextSecondary,
                ),
              ),
            )).toList(),
            selected: {_ladderSteps},
            onSelectionChanged: (selected) {
              setState(() {
                _ladderSteps = selected.first;
                _updateLadderTriggersFromSteps();
                _updateLadderWeightsFromPreset();
              });
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.amber600;
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
        ),
        const SizedBox(height: 16),

        // 비율 프리셋
        Text(
          '비율 프리셋',
          style: TextStyle(fontSize: 12, color: context.appTextSecondary),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: List.generate(5, (i) => ButtonSegment<int>(
              value: i,
              label: Text(
                _presetNames[i],
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: _ladderPreset == i
                      ? Colors.white
                      : context.appTextSecondary,
                ),
              ),
            )),
            selected: {_ladderPreset},
            showSelectedIcon: false,
            onSelectionChanged: (selected) {
              setState(() {
                final newPreset = selected.first;
                // 커스텀으로 전환 시: 이전 프리셋의 비중을 %로 변환하여 초기값 설정
                if (newPreset == 4 && _ladderPreset != 4) {
                  final weights = _presetWeights(_ladderPreset, _ladderSteps);
                  final total = weights.fold<int>(0, (s, w) => s + w);
                  _customWeightPercents = total > 0
                      ? weights.map((w) => double.parse((w / total * 100).toStringAsFixed(1))).toList()
                      : List.filled(_ladderSteps, (100.0 / _ladderSteps));
                  _applyCustomWeightsToLadder();
                }
                _ladderPreset = newPreset;
                _updateLadderWeightsFromPreset();
              });
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.amber600;
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
        ),
        const SizedBox(height: 16),

        // 투입 계획 미리보기
        if (_seedAmount > 0) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '투입 계획 미리보기',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.appTextHint,
                  ),
                ),
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  return _buildLadderCalcRows(_calculateActualSeed(_seedAmount));
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 커스텀 슬라이더 (커스텀 프리셋 선택 시)
        if (_ladderPreset == 4) ...[
          _buildCustomWeightSliders(),
        ],
      ],
    );
  }

  Widget _buildCustomWeightSliders() {
    // customWeightPercents 길이를 ladderSteps에 맞춤
    while (_customWeightPercents.length < _ladderSteps) {
      _customWeightPercents.add(0);
    }
    final sum = _customWeightPercents
        .take(_ladderSteps)
        .fold<double>(0, (s, v) => s + v);
    final isValid = (sum - 100.0).abs() <= 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(_ladderSteps, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    '${i + 1}단계',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppColors.amber500,
                      inactiveTrackColor: context.appDivider,
                      thumbColor: AppColors.amber500,
                      overlayColor: AppColors.amber500.withValues(alpha: 0.12),
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      value: _customWeightPercents[i].clamp(0, 50),
                      min: 0,
                      max: 50,
                      divisions: 50,
                      onChanged: (v) {
                        setState(() {
                          _customWeightPercents[i] = v;
                          _applyCustomWeightsToLadder();
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${_customWeightPercents[i].toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '합계: ${sum.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isValid ? context.appTextSecondary : AppColors.red500,
              ),
            ),
          ],
        ),
        if (!isValid) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '⚠ 합계가 100%가 아닙니다 (현재 ${sum.toStringAsFixed(0)}%)',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.amber500,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'ℹ 시드가 ${sum.toStringAsFixed(0)}%로 자동 조정됩니다'
              ' (시드 × ${sum.toStringAsFixed(0)}%)',
              style: TextStyle(
                fontSize: 10,
                color: context.appTextHint,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _applyCustomWeightsToLadder() {
    // 퍼센트를 정수 비중으로 변환 (최소 1 단위)
    final percents = _customWeightPercents.take(_ladderSteps).toList();
    final weights = percents.map((p) => p.round().clamp(0, 50)).toList();
    _ladderWeights = weights.join(',');
  }

  Widget _buildCompoundToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '반복리 활성화',
            style: TextStyle(
              fontSize: 12,
              color: context.appTextSecondary,
            ),
          ),
          Switch(
            value: _compoundEnabled,
            onChanged: (v) => setState(() => _compoundEnabled = v),
            activeColor: context.appAccent,
          ),
        ],
      ),
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

      // 커스텀 비율: 합계가 100%가 아니면 시드를 조정 (절대 비율 해석)
      final actualSeed = _selectedStrategy == StrategyType.ladderCycle
          ? _calculateActualSeed(_seedAmount)
          : _seedAmount;

      await ref.read(cycleListProvider.notifier).addCycle(
            ticker: _selectedTicker!,
            name: (_selectedStrategy == StrategyType.ladderCycle && _ladderMode != 0 && _buyTickerName != null)
                ? _buyTickerName!
                : (_selectedName ?? _selectedTicker!),
            seedAmount: actualSeed,
            exchangeRate: exchangeRate,
            strategyType: _selectedStrategy,
            nickname: _nicknameController.text.trim(),
            // Strategy A
            initialEntryRatio: _initialEntryRatio,
            weightedBuyThreshold: _weightedBuyThreshold,
            weightedBuyPerPercent: _weightedBuyPerPercent,
            panicBuyThreshold: _panicBuyThreshold,
            panicBuyMultiplier: _panicBuyMultiplier,
            firstProfitTarget: _firstProfitTarget,
            profitTargetStep: _profitTargetStep,
            minProfitTarget: _minProfitTarget,
            cashSecureRatio: _cashSecureRatio,
            // Strategy B
            takeProfitPercent: _takeProfitPercent,
            totalRounds: _totalRounds,
            // Strategy B V2.2/V3.0
            steadyVersion: _steadyVersion,
            sellQuarterPercent: _sellQuarterPercent,
            compoundEnabled: _compoundEnabled,
            offsetA: _offsetA,
            offsetB: _offsetB,
            quarterModeOffset: _quarterModeOffset,
            // Strategy C: Ladder
            athPrice: _athPrice,
            ladderMode: _ladderMode,
            ladderSteps: _ladderSteps,
            ladderWeights: _ladderWeights,
            ladderTriggers: _ladderTriggers,
            buyTicker: _buyTicker ?? '',
            buyTicker1x: _buyTicker1x ?? '',
            buyTicker2x: _buyTicker2x ?? '',
            buyTicker3x: _buyTicker3x ?? '',
          );

      if (mounted) {
        showSuccessToast(context, '${_selectedTicker!} 사이클이 시작되었습니다');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showErrorToast(context, '사이클 생성 실패: $e');
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
// 최근 조회 종목 목록 (티커 선택 모달용)
// ═══════════════════════════════════════════════════════════════

class _RecentTickerList extends ConsumerWidget {
  final ScrollController scrollController;
  final void Function(String ticker, String name) onSelected;

  const _RecentTickerList({
    required this.scrollController,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentItems = ref.watch(recentViewProvider);

    if (recentItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 40, color: context.appTextHint),
            const SizedBox(height: 12),
            Text(
              '최근 조회한 종목이 없습니다',
              style: TextStyle(fontSize: 13, color: context.appTextSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '위 입력란에 티커를 직접 입력해주세요',
              style: TextStyle(fontSize: 12, color: context.appTextHint),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '최근 조회',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.appTextSecondary,
              ),
            ),
          ),
          ...recentItems.map((item) => ListTile(
                onTap: () => onSelected(item.ticker, item.name),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      item.ticker.substring(0, item.ticker.length > 2 ? 2 : item.ticker.length),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  item.ticker,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                subtitle: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextSecondary,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: context.appTextHint,
                ),
              )),
        ],
      ),
    );
  }
}

