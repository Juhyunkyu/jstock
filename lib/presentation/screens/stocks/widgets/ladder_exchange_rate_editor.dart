import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/trading/ladder_cycle_service.dart';

/// 안정형 티커별 환율 편집 위젯
///
/// 기본: "평균 매입환율 ₩1,351.67 / $1 [✏️]" (1줄)
/// ✏️ 클릭 시 확장: 3개 티커별 개별 편집 + [저장]
class LadderExchangeRateEditor extends StatefulWidget {
  final List<TickerHolding> holdings;
  final double overallAvgExRate;
  final ValueChanged<Map<String, double>>? onSave;

  const LadderExchangeRateEditor({
    super.key,
    required this.holdings,
    required this.overallAvgExRate,
    this.onSave,
  });

  @override
  State<LadderExchangeRateEditor> createState() => _LadderExchangeRateEditorState();
}

class _LadderExchangeRateEditorState extends State<LadderExchangeRateEditor> {
  bool _isExpanded = false;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    for (final h in widget.holdings) {
      _controllers[h.ticker] = TextEditingController(
        text: h.avgExRate.toStringAsFixed(2),
      );
    }
  }

  @override
  void didUpdateWidget(covariant LadderExchangeRateEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 홀딩 변경 시 컨트롤러 갱신
    if (oldWidget.holdings.length != widget.holdings.length) {
      _disposeControllers();
      _initControllers();
    }
  }

  void _disposeControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 기본 행: 평균 매입환율
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '평균 매입환율',
                style: TextStyle(
                  fontSize: 13,
                  color: context.appTextSecondary,
                ),
              ),
              Row(
                children: [
                  Text(
                    '₩${widget.overallAvgExRate.toStringAsFixed(2)} / \$1',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                  if (widget.onSave != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Icon(
                        _isExpanded ? Icons.expand_less : Icons.edit_outlined,
                        size: 14,
                        color: context.appTextHint,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // 확장: 티커별 편집
          if (_isExpanded && widget.holdings.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.appBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  ...widget.holdings.map((h) => _buildTickerExRateRow(context, h)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _handleSave,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '저장',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.appAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTickerExRateRow(BuildContext context, TickerHolding holding) {
    final controller = _controllers[holding.ticker];
    if (controller == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              holding.ticker,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTextPrimary,
                ),
                decoration: InputDecoration(
                  prefixText: '₩',
                  prefixStyle: TextStyle(fontSize: 12, color: context.appTextPrimary),
                  suffixText: '/ \$1',
                  suffixStyle: TextStyle(fontSize: 10, color: context.appTextSecondary),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  isDense: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: context.appBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: context.appAccent),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSave() {
    final rates = <String, double>{};
    for (final entry in _controllers.entries) {
      final val = double.tryParse(entry.value.text);
      if (val != null && val > 0) {
        rates[entry.key] = val;
      }
    }
    widget.onSave?.call(rates);
    setState(() => _isExpanded = false);
  }
}
