import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 피봇 포인트 기술적 지표 섹션 위젯
class PivotPointSection extends StatelessWidget {
  final Map<String, double>? pivotLevels;
  final double currentPrice;
  final bool showPivotLines;
  final VoidCallback onTogglePivotLines;

  const PivotPointSection({
    super.key,
    required this.pivotLevels,
    required this.currentPrice,
    required this.showPivotLines,
    required this.onTogglePivotLines,
  });

  @override
  Widget build(BuildContext context) {
    if (pivotLevels == null) return const SizedBox.shrink();

    return Container(
      color: context.appBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '기술적 지표',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.appTextPrimary),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _showPivotHelpDialog(context),
                child: Icon(Icons.help_outline, size: 18, color: context.appTextHint),
              ),
              const Spacer(),
              Text(
                '차트 표시',
                style: TextStyle(
                  fontSize: 12,
                  color: showPivotLines ? context.appTextPrimary : context.appTextHint,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 36,
                height: 20,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: showPivotLines,
                    onChanged: (v) => onTogglePivotLines(),
                    activeColor: context.appTextPrimary,
                    activeTrackColor: context.appBorder,
                    inactiveThumbColor: context.appTextHint,
                    inactiveTrackColor: context.appIconBg,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildIndicatorPairRow(
            context,
            '저항선 2 (R2)', pivotLevels!['R2']!, AppColors.stockUp,
            '저항선 1 (R1)', pivotLevels!['R1']!, AppColors.stockUp,
          ),
          const SizedBox(height: 6),
          _buildIndicatorPairRow(
            context,
            '피봇 포인트', pivotLevels!['P']!, context.appTextPrimary,
            '현재가', currentPrice, context.appTextPrimary,
          ),
          const SizedBox(height: 6),
          _buildIndicatorPairRow(
            context,
            '지지선 1 (S1)', pivotLevels!['S1']!, AppColors.stockDown,
            '지지선 2 (S2)', pivotLevels!['S2']!, AppColors.stockDown,
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorPairRow(
    BuildContext context,
    String label1, double value1, Color color1,
    String label2, double value2, Color color2,
  ) {
    Widget buildCell(String label, double value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appDivider, width: 1),
          ),
          child: Row(
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: color.withAlpha(180), fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(_formatPrice(value), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        buildCell(label1, value1, color1),
        const SizedBox(width: 6),
        buildCell(label2, value2, color2),
      ],
    );
  }

  void _showPivotHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface,
        title: Text(
          '피봇 포인트 (Pivot Point)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appTextPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '피봇 포인트는 전일 고가, 저가, 종가를 이용하여 당일의 지지선과 저항선을 계산하는 기술적 지표입니다.',
                style: TextStyle(fontSize: 13, color: context.appTextSecondary, height: 1.5),
              ),
              const SizedBox(height: 12),
              _helpFormulaRow(context, '피봇 (P)', '(고가 + 저가 + 종가) / 3'),
              _helpFormulaRow(context, '저항1 (R1)', '(2 × P) - 저가'),
              _helpFormulaRow(context, '저항2 (R2)', 'P + (고가 - 저가)'),
              _helpFormulaRow(context, '지지1 (S1)', '(2 × P) - 고가'),
              _helpFormulaRow(context, '지지2 (S2)', 'P - (고가 - 저가)'),
              const SizedBox(height: 12),
              Text('읽는 법', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.appTextPrimary)),
              const SizedBox(height: 6),
              Text(
                '• 현재가가 피봇 위에 있으면 상승 추세\n'
                '• 현재가가 피봇 아래에 있으면 하락 추세\n'
                '• 저항선(R1, R2): 가격 상승 시 저항받는 구간\n'
                '• 지지선(S1, S2): 가격 하락 시 지지받는 구간',
                style: TextStyle(fontSize: 12, color: context.appTextSecondary, height: 1.6),
              ),
            ],
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

  Widget _helpFormulaRow(BuildContext context, String label, String formula) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appTextPrimary)),
          ),
          Expanded(
            child: Text(formula, style: TextStyle(fontSize: 12, color: context.appTextSecondary)),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }
}
