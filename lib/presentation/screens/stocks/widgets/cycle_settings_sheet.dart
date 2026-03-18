import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/korean_number_formatter.dart';
import '../../../../data/models/cycle.dart';

/// 대기중 사이클의 설정 수정 바텀시트
/// 시드 금액 + 전략별 파라미터 슬라이더
class CycleSettingsSheet extends StatefulWidget {
  final Cycle cycle;
  final Future<void> Function(Cycle) onSave;

  const CycleSettingsSheet({
    super.key,
    required this.cycle,
    required this.onSave,
  });

  @override
  State<CycleSettingsSheet> createState() => _CycleSettingsSheetState();
}

class _CycleSettingsSheetState extends State<CycleSettingsSheet> {
  late final TextEditingController _seedController;
  late final TextEditingController _nicknameController;
  bool _isSaving = false;

  // Smart Cycle 파라미터
  late double _initialEntryRatio;
  late double _weightedBuyThreshold;
  late double _weightedBuyPerPercent;
  late double _panicBuyThreshold;
  late double _panicBuyMultiplier;
  late double _firstProfitTarget;
  late double _profitTargetStep;
  late double _minProfitTarget;
  late double _cashSecureRatio;

  // Steady Cycle 파라미터
  late double _takeProfitPercent;
  late int _totalRounds;

  // Steady V2.2/V3.0
  late double _sellQuarterPercent;

  @override
  void initState() {
    super.initState();
    final c = widget.cycle;
    _seedController = TextEditingController(
      text: c.seedAmount.round().toString(),
    );
    _nicknameController = TextEditingController(text: c.nickname);
    _initialEntryRatio = c.initialEntryRatio;
    _weightedBuyThreshold = c.weightedBuyThreshold;
    _weightedBuyPerPercent = c.weightedBuyPerPercent;
    _panicBuyThreshold = c.panicBuyThreshold;
    _panicBuyMultiplier = c.panicBuyMultiplier;
    _firstProfitTarget = c.firstProfitTarget;
    _profitTargetStep = c.profitTargetStep;
    _minProfitTarget = c.minProfitTarget;
    _cashSecureRatio = c.cashSecureRatio;
    _takeProfitPercent = c.takeProfitPercent;
    _totalRounds = c.totalRounds;
    _sellQuarterPercent = c.sellQuarterPercent;
  }

  @override
  void dispose() {
    _seedController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  double get _seedAmount {
    final text = _seedController.text.replaceAll(',', '');
    return double.tryParse(text) ?? 0;
  }

  double get _effectivePerPercent =>
      _weightedBuyPerPercent > 0 ? _weightedBuyPerPercent : _seedAmount * 0.00007;

  @override
  Widget build(BuildContext context) {
    final isAlpha = widget.cycle.strategyType == StrategyType.alphaCycleV3;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 드래그 핸들
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '설정 변경',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '첫 매수 전에만 수정할 수 있습니다',
              style: TextStyle(fontSize: 12, color: context.appTextHint),
            ),
            const SizedBox(height: 20),

            // === 별명 ===
            Text(
              '별명 (선택)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
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
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.appBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.appAccent),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // === 시드 금액 ===
            Text(
              '시드 금액',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _seedController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
              onChanged: (_) => setState(() {
                _weightedBuyPerPercent = 0.0; // 시드 변경 시 자동 계산 모드로 리셋
              }),
              decoration: InputDecoration(
                suffixText: '원',
                suffixStyle: TextStyle(color: context.appTextSecondary),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.appBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.appAccent),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            if (_seedAmount > 0) ...[
              const SizedBox(height: 4),
              Text(
                formatKoreanAmountShort(_seedAmount),
                style: TextStyle(fontSize: 12, color: context.appTextHint),
              ),
            ],
            const SizedBox(height: 20),

            // === 전략 파라미터 ===
            Text(
              '전략 파라미터',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 12),

            if (isAlpha) ..._buildAlphaSliders(context)
            else ..._buildSteadySliders(context),

            const SizedBox(height: 24),

            // === 저장 버튼 ===
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _seedAmount >= 10000 && !_isSaving ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.appAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '저장',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAlphaSliders(BuildContext context) {
    return [
      _buildSlider(
        context,
        label: '초기 진입 비율 (시드의)',
        value: _initialEntryRatio,
        min: 0.05,
        max: 0.50,
        divisions: 9,
        format: (v) => '${(v * 100).toStringAsFixed(0)}%',
        onChanged: (v) => setState(() => _initialEntryRatio = v),
      ),
      _buildSlider(
        context,
        label: '가중매수 발동 기준 (손실률)',
        value: _weightedBuyThreshold,
        min: -50.0,
        max: -5.0,
        divisions: 9,
        format: (v) => '${v.toStringAsFixed(0)}%',
        onChanged: (v) => setState(() => _weightedBuyThreshold = v),
      ),
      if (_seedAmount > 0)
        _buildSlider(
          context,
          label: '가중매수 1%당 금액',
          value: _effectivePerPercent,
          min: _seedAmount * 0.00003,
          max: _seedAmount * 0.00015,
          divisions: 12,
          format: (v) => '${(v / 10000).toStringAsFixed(1)}만원',
          onChanged: (v) => setState(() => _weightedBuyPerPercent = v),
        ),
      _buildSlider(
        context,
        label: '승부수 발동 기준 (손실률)',
        value: _panicBuyThreshold,
        min: -80.0,
        max: -30.0,
        divisions: 10,
        format: (v) => '${v.toStringAsFixed(0)}%',
        onChanged: (v) => setState(() => _panicBuyThreshold = v),
      ),
      _buildSlider(
        context,
        label: '승부수 투입 배율 (평가금의)',
        value: _panicBuyMultiplier,
        min: 0.10,
        max: 1.0,
        divisions: 9,
        format: (v) => '${(v * 100).toStringAsFixed(0)}%',
        onChanged: (v) => setState(() => _panicBuyMultiplier = v),
      ),
      _buildSlider(
        context,
        label: '첫 익절 목표 (수익률)',
        value: _firstProfitTarget,
        min: 10.0,
        max: 50.0,
        divisions: 8,
        format: (v) => '+${v.toStringAsFixed(0)}%',
        onChanged: (v) => setState(() => _firstProfitTarget = v),
      ),
      _buildSlider(
        context,
        label: '연속 익절 감소폭',
        value: _profitTargetStep,
        min: 1.0,
        max: 10.0,
        divisions: 9,
        format: (v) => '${v.toStringAsFixed(0)}%p',
        onChanged: (v) => setState(() => _profitTargetStep = v),
      ),
      _buildSlider(
        context,
        label: '최소 익절 목표 (수익률)',
        value: _minProfitTarget,
        min: 3.0,
        max: 20.0,
        divisions: 17,
        format: (v) => '+${v.toStringAsFixed(0)}%',
        onChanged: (v) => setState(() => _minProfitTarget = v),
      ),
      _buildSlider(
        context,
        label: '현금 확보 비율 (총자산의)',
        value: _cashSecureRatio,
        min: 0.10,
        max: 0.50,
        divisions: 8,
        format: (v) => '${(v * 100).toStringAsFixed(1)}%',
        onChanged: (v) => setState(() => _cashSecureRatio = v),
      ),
    ];
  }

  List<Widget> _buildSteadySliders(BuildContext context) {
    return [
      _buildSlider(
        context,
        label: '분할 횟수',
        value: _totalRounds.toDouble(),
        min: 10,
        max: 80,
        divisions: 14,
        format: (v) => '${v.toStringAsFixed(0)}회',
        onChanged: (v) => setState(() => _totalRounds = v.round()),
      ),
      _buildSlider(
        context,
        label: '익절 목표 (수익률)',
        value: _takeProfitPercent,
        min: 3.0,
        max: 30.0,
        divisions: 27,
        format: (v) => '+${v.toStringAsFixed(0)}%',
        onChanged: (v) => setState(() => _takeProfitPercent = v),
      ),
      // V2.2/V3.0 전용: 매도 LOC 비율
      if (widget.cycle.steadyVersion != SteadyVersion.v1)
        _buildSlider(
          context,
          label: '매도 LOC 비율 (보유량의)',
          value: _sellQuarterPercent,
          min: 0.10,
          max: 0.50,
          divisions: 8,
          format: (v) => '${(v * 100).toStringAsFixed(0)}%',
          onChanged: (v) => setState(() => _sellQuarterPercent = v),
        ),
    ];
  }

  Widget _buildSlider(
    BuildContext context, {
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
                style: TextStyle(fontSize: 12, color: context.appTextSecondary),
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
              value: value.clamp(min, max),
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

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final cycle = widget.cycle;
      final newSeed = _seedAmount;

      cycle.nickname = _nicknameController.text.trim();
      cycle.seedAmount = newSeed;
      cycle.remainingCash = newSeed; // 대기중이라 전액 현금
      cycle.initialEntryRatio = _initialEntryRatio;
      cycle.weightedBuyThreshold = _weightedBuyThreshold;
      cycle.weightedBuyPerPercent = _weightedBuyPerPercent;
      cycle.panicBuyThreshold = _panicBuyThreshold;
      cycle.panicBuyMultiplier = _panicBuyMultiplier;
      cycle.firstProfitTarget = _firstProfitTarget;
      cycle.profitTargetStep = _profitTargetStep;
      cycle.minProfitTarget = _minProfitTarget;
      cycle.cashSecureRatio = _cashSecureRatio;
      cycle.takeProfitPercent = _takeProfitPercent;
      cycle.totalRounds = _totalRounds;
      cycle.sellQuarterPercent = _sellQuarterPercent;

      await widget.onSave(cycle);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // _formatKoreanAmount → korean_number_formatter.dart의 formatKoreanAmountShort() 사용
}
