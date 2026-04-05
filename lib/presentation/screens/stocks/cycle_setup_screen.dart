import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/korean_number_formatter.dart';
import '../../../data/models/cycle.dart';
import '../../../domain/trading/ladder_cycle_service.dart';
import '../../providers/providers.dart';
import '../../widgets/common/top_toast.dart';
import 'widgets/cycle_setup_advanced_section.dart';
import 'widgets/cycle_setup_ladder_ticker_section.dart';
import 'widgets/cycle_setup_seed_section.dart';
import 'widgets/cycle_setup_strategy_section.dart';
import 'widgets/cycle_setup_ticker_section.dart';

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
  int _ladderPreset = 0; // 0=가속, 1=피보나치, 2=마틴게일, 3=커스텀
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
      final text = _seedController.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (text.isNotEmpty) {
        final trimmed = text.replaceFirst(RegExp(r'^0+'), '');
        final effective = trimmed.isEmpty ? '0' : trimmed;
        _seedController.text = addCommas(effective);
      }
    } else {
      final digits = _seedController.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty && digits != _seedController.text) {
        _seedController.text = digits;
        _seedController.selection = TextSelection.collapsed(offset: digits.length);
      }
    }
    setState(() {});
  }

  double get _seedAmount {
    final text = _seedController.text.replaceAll(',', '');
    return double.tryParse(text) ?? 0;
  }

  double get _effectivePerPercent =>
      _weightedBuyPerPercent > 0 ? _weightedBuyPerPercent : _seedAmount * 0.00007;

  double _calculateActualSeed(double baseSeed) {
    if (_ladderPreset != 3) return baseSeed;
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
      if (_ladderMode == 1 && _buyTicker == null) return false;
      if (_ladderMode == 0 && (_buyTicker1x == null || _buyTicker2x == null || _buyTicker3x == null)) return false;
    }
    return true;
  }

  // ═══════════════════════════════════════════════════════════════
  // Ladder 프리셋/트리거 로직
  // ═══════════════════════════════════════════════════════════════

  static List<int> _presetWeights(int preset, int steps) {
    switch (preset) {
      case 1: // 피보나치형
        return switch (steps) {
          3 => [1, 2, 3],
          4 => [1, 1, 2, 3],
          5 => [1, 1, 2, 3, 5],
          _ => [1, 1, 2, 3, 5, 8],
        };
      case 2: // 마틴게일
        return List.generate(steps, (i) => 1 << i);
      default: // 가속형
        return switch (steps) {
          3 => [2, 3, 5],
          4 => [1, 2, 3, 4],
          5 => [1, 1, 2, 3, 3],
          _ => [1, 1, 2, 3, 4, 5],
        };
    }
  }

  void _updateLadderWeightsFromPreset() {
    if (_ladderPreset == 3) return;
    final weights = _presetWeights(_ladderPreset, _ladderSteps);
    _ladderWeights = weights.join(',');
    final total = weights.fold<int>(0, (s, w) => s + w);
    _customWeightPercents = weights
        .map((w) => total > 0 ? (w / total * 100) : 0.0)
        .toList();
  }

  void _updateLadderTriggersFromSteps() {
    final triggers = parseLadderTriggers('', steps: _ladderSteps);
    _ladderTriggers = triggers.map((t) => t.toStringAsFixed(0)).join(',');
  }

  void _applyCustomWeightsToLadder() {
    final percents = _customWeightPercents.take(_ladderSteps).toList();
    final weights = percents.map((p) => p.round().clamp(0, 100)).toList();
    _ladderWeights = weights.join(',');
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

  // ═══════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════

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
            CycleStrategySelector(
              selectedStrategy: _selectedStrategy,
              onChanged: (v) => setState(() => _selectedStrategy = v),
            ),
            const SizedBox(height: 12),
            CycleStrategyDescription(
              selectedStrategy: _selectedStrategy,
              steadyVersion: _steadyVersion,
            ),

            // Steady 버전 선택
            if (_selectedStrategy == StrategyType.infiniteBuy) ...[
              const SizedBox(height: 16),
              SteadyVersionSelector(
                steadyVersion: _steadyVersion,
                onChanged: (v) => setState(() {
                  _steadyVersion = v;
                  _applyVersionDefaults();
                }),
              ),
            ],

            // Ladder 매수 모드 선택
            if (_selectedStrategy == StrategyType.ladderCycle) ...[
              const SizedBox(height: 16),
              LadderModeSelector(
                ladderMode: _ladderMode,
                onChanged: (v) => setState(() => _ladderMode = v),
              ),
            ],

            const SizedBox(height: 24),

            // 2. 종목 선택 (Ladder: ATH → 기준 티커 → 매수 티커)
            if (_selectedStrategy == StrategyType.ladderCycle) ...[
              _buildSectionLabel('ATH 가격 (USD)'),
              const SizedBox(height: 8),
              AthPriceInput(
                controller: _athController,
                onChanged: (v) => setState(() => _athPrice = v),
              ),
              const SizedBox(height: 24),

              _buildSectionLabel('기준 티커 (MDD 계산용)'),
              const SizedBox(height: 8),
              CycleTickerSelector(
                selectedTicker: _selectedTicker,
                selectedName: _selectedName,
                onPickTicker: () => showTickerPickerSheet(
                  context, ref,
                  onSelected: (ticker, name) => setState(() {
                    _selectedTicker = ticker;
                    _selectedName = name;
                  }),
                ),
                onClearTicker: () => setState(() {
                  _selectedTicker = null;
                  _selectedName = null;
                }),
              ),
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

              LadderBuyTickerSection(
                ladderMode: _ladderMode,
                buyTicker: _buyTicker,
                buyTickerName: _buyTickerName,
                onBuyTickerSelected: (t, n) => setState(() {
                  _buyTicker = t;
                  _buyTickerName = n;
                  ref.read(stockQuoteProvider.notifier).fetchQuote(t);
                }),
                onBuyTickerClear: () => setState(() {
                  _buyTicker = null;
                  _buyTickerName = null;
                }),
                buyTicker1x: _buyTicker1x,
                buyTicker1xName: _buyTicker1xName,
                onBuyTicker1xSelected: (t, n) => setState(() {
                  _buyTicker1x = t;
                  _buyTicker1xName = n;
                  ref.read(stockQuoteProvider.notifier).fetchQuote(t);
                }),
                onBuyTicker1xClear: () => setState(() {
                  _buyTicker1x = null;
                  _buyTicker1xName = null;
                }),
                buyTicker2x: _buyTicker2x,
                buyTicker2xName: _buyTicker2xName,
                onBuyTicker2xSelected: (t, n) => setState(() {
                  _buyTicker2x = t;
                  _buyTicker2xName = n;
                  ref.read(stockQuoteProvider.notifier).fetchQuote(t);
                }),
                onBuyTicker2xClear: () => setState(() {
                  _buyTicker2x = null;
                  _buyTicker2xName = null;
                }),
                buyTicker3x: _buyTicker3x,
                buyTicker3xName: _buyTicker3xName,
                onBuyTicker3xSelected: (t, n) => setState(() {
                  _buyTicker3x = t;
                  _buyTicker3xName = n;
                  ref.read(stockQuoteProvider.notifier).fetchQuote(t);
                }),
                onBuyTicker3xClear: () => setState(() {
                  _buyTicker3x = null;
                  _buyTicker3xName = null;
                }),
              ),
            ] else ...[
              _buildSectionLabel('종목 선택'),
              const SizedBox(height: 8),
              CycleTickerSelector(
                selectedTicker: _selectedTicker,
                selectedName: _selectedName,
                onPickTicker: () => showTickerPickerSheet(
                  context, ref,
                  onSelected: (ticker, name) => setState(() {
                    _selectedTicker = ticker;
                    _selectedName = name;
                  }),
                ),
                onClearTicker: () => setState(() {
                  _selectedTicker = null;
                  _selectedName = null;
                }),
              ),
            ],

            const SizedBox(height: 24),

            // 2.5. 별명
            _buildSectionLabel('별명 (선택)'),
            const SizedBox(height: 8),
            CycleNicknameInput(controller: _nicknameController),

            const SizedBox(height: 24),

            // 3. 시드 금액
            _buildSectionLabel('시드 금액'),
            const SizedBox(height: 8),
            CycleSeedInput(
              controller: _seedController,
              focusNode: _seedFocusNode,
              seedAmount: _seedAmount,
              onChanged: () => setState(() {
                _weightedBuyPerPercent = 0.0;
              }),
            ),
            if (_seedAmount > 0) ...[
              const SizedBox(height: 12),
              CycleCalculationPreview(
                selectedStrategy: _selectedStrategy,
                seedAmount: _seedAmount,
                selectedTicker: _selectedTicker,
                initialEntryRatio: _initialEntryRatio,
                firstProfitTarget: _firstProfitTarget,
                takeProfitPercent: _takeProfitPercent,
                totalRounds: _totalRounds,
                ladderSteps: _ladderSteps,
                ladderPreset: _ladderPreset,
                ladderWeights: _ladderWeights,
                ladderTriggers: _ladderTriggers,
                customWeightPercents: _customWeightPercents,
                calculateActualSeed: _calculateActualSeed,
              ),
            ],

            const SizedBox(height: 24),

            // 4. 고급 설정
            CycleAdvancedSettings(
              selectedStrategy: _selectedStrategy,
              showAdvanced: _showAdvanced,
              onExpansionChanged: (v) => setState(() => _showAdvanced = v),
              child: _buildAdvancedContent(),
            ),

            const SizedBox(height: 32),

            // 5. 시작 버튼
            _buildStartButton(),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

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

  Widget _buildAdvancedContent() {
    if (_selectedStrategy == StrategyType.alphaCycleV3) {
      return AlphaAdvancedSettings(
        initialEntryRatio: _initialEntryRatio,
        weightedBuyThreshold: _weightedBuyThreshold,
        effectivePerPercent: _effectivePerPercent,
        seedAmount: _seedAmount,
        panicBuyThreshold: _panicBuyThreshold,
        panicBuyMultiplier: _panicBuyMultiplier,
        firstProfitTarget: _firstProfitTarget,
        profitTargetStep: _profitTargetStep,
        minProfitTarget: _minProfitTarget,
        cashSecureRatio: _cashSecureRatio,
        onInitialEntryRatioChanged: (v) => setState(() => _initialEntryRatio = v),
        onWeightedBuyThresholdChanged: (v) => setState(() => _weightedBuyThreshold = v),
        onWeightedBuyPerPercentChanged: (v) => setState(() => _weightedBuyPerPercent = v),
        onPanicBuyThresholdChanged: (v) => setState(() => _panicBuyThreshold = v),
        onPanicBuyMultiplierChanged: (v) => setState(() => _panicBuyMultiplier = v),
        onFirstProfitTargetChanged: (v) => setState(() => _firstProfitTarget = v),
        onProfitTargetStepChanged: (v) => setState(() => _profitTargetStep = v),
        onMinProfitTargetChanged: (v) => setState(() => _minProfitTarget = v),
        onCashSecureRatioChanged: (v) => setState(() => _cashSecureRatio = v),
      );
    } else if (_selectedStrategy == StrategyType.ladderCycle) {
      return LadderAdvancedSettings(
        ladderSteps: _ladderSteps,
        ladderPreset: _ladderPreset,
        seedAmount: _seedAmount,
        ladderWeights: _ladderWeights,
        ladderTriggers: _ladderTriggers,
        customWeightPercents: _customWeightPercents,
        calculateActualSeed: _calculateActualSeed,
        onStepsChanged: (v) => setState(() {
          _ladderSteps = v;
          _updateLadderTriggersFromSteps();
          _updateLadderWeightsFromPreset();
        }),
        onPresetChanged: (newPreset) => setState(() {
          if (newPreset == 3 && _ladderPreset != 3) {
            final weights = _presetWeights(_ladderPreset, _ladderSteps);
            final total = weights.fold<int>(0, (s, w) => s + w);
            _customWeightPercents = total > 0
                ? weights.map((w) => double.parse((w / total * 100).toStringAsFixed(1))).toList()
                : List.filled(_ladderSteps, (100.0 / _ladderSteps));
            _applyCustomWeightsToLadder();
          }
          _ladderPreset = newPreset;
          _updateLadderWeightsFromPreset();
        }),
        onCustomWeightChanged: (i, v) => setState(() {
          while (_customWeightPercents.length < _ladderSteps) {
            _customWeightPercents.add(0);
          }
          _customWeightPercents[i] = v;
          _applyCustomWeightsToLadder();
        }),
      );
    } else {
      return SteadyAdvancedSettings(
        steadyVersion: _steadyVersion,
        takeProfitPercent: _takeProfitPercent,
        totalRounds: _totalRounds,
        sellQuarterPercent: _sellQuarterPercent,
        compoundEnabled: _compoundEnabled,
        onTakeProfitPercentChanged: (v) => setState(() => _takeProfitPercent = v),
        onTotalRoundsChanged: (v) => setState(() {
          _totalRounds = v;
          if (_steadyVersion == SteadyVersion.v2_2) {
            _offsetB = 0.5 * (40 / _totalRounds);
          }
        }),
        onSellQuarterPercentChanged: (v) => setState(() => _sellQuarterPercent = v),
        onCompoundEnabledChanged: (v) => setState(() => _compoundEnabled = v),
      );
    }
  }

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
