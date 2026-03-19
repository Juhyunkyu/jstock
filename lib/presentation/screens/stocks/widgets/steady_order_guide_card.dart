import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/trading/steady_order_guide.dart';
import '../../../providers/providers.dart';

class SteadyOrderGuideCard extends ConsumerWidget {
  final String cycleId;

  const SteadyOrderGuideCard({super.key, required this.cycleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guide = ref.watch(steadyOrderGuideProvider(cycleId));
    if (guide == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.appBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: T값 진행률
          _buildTProgressBar(context, ref, guide),
          const SizedBox(height: 12),

          // 쿼터모드 경고
          if (guide.isQuarterMode) ...[
            _buildQuarterModeAlert(context),
            const SizedBox(height: 10),
          ],

          // 주문 가이드 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📊 주문 가이드',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.appTextPrimary),
              ),
              GestureDetector(
                onTap: () => _showHelpDialog(context),
                child: Icon(Icons.help_outline, size: 18, color: context.appTextHint),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 첫 매수 안내
          if (guide.isFirstBuy) ...[
            _buildFirstBuyGuide(context, guide),
          ] else ...[
            // 매수 주문
            if (guide.canBuy && !guide.isQuarterMode) ...[
              _buildSectionTitle(context, '매수 주문', AppColors.blue500),
              const SizedBox(height: 6),
              if (guide.buyOrderA != null)
                _buildOrderRow(context, guide.buyOrderA!, AppColors.blue500, hint: _buyHint(guide.buyOrderA!)),
              if (guide.buyOrderB != null)
                _buildOrderRow(context, guide.buyOrderB!, AppColors.blue500, hint: _buyHint(guide.buyOrderB!)),
              if (guide.buySingleOrder != null)
                _buildOrderRow(context, guide.buySingleOrder!, AppColors.blue500, hint: '종가 ≤ 이 가격일 때 체결'),
              const SizedBox(height: 10),
            ],

            // 미체결 안내
            if (!guide.canBuy && !guide.isQuarterMode && !guide.isFirstBuy)
              _buildNoFillGuide(context, guide),

            // 매도 주문
            if (guide.sellLocOrder != null || guide.sellLimitOrder != null) ...[
              _buildSectionTitle(context, '매도 주문 (동시)', AppColors.green500),
              const SizedBox(height: 6),
              if (guide.sellLocOrder != null)
                _buildOrderRow(context, guide.sellLocOrder!, AppColors.green500, hint: '종가 ≥ 이 가격일 때 체결'),
              if (guide.sellLimitOrder != null)
                _buildOrderRow(context, guide.sellLimitOrder!, AppColors.green500, hint: '장중 이 가격 이상 도달 시 체결'),
            ],
          ],

          // 쿼터모드 매도/매수
          if (guide.isQuarterMode) ...[
            if (guide.sellLocOrder != null)
              _buildOrderRow(context, guide.sellLocOrder!, AppColors.red500, hint: '종가 ≥ 이 가격일 때 체결'),
            if (guide.sellLimitOrder != null)
              _buildOrderRow(context, guide.sellLimitOrder!, AppColors.green500, hint: '장중 이 가격 이상 도달 시 체결'),
            if (guide.buySingleOrder != null) ...[
              const SizedBox(height: 8),
              _buildOrderRow(context, guide.buySingleOrder!, AppColors.blue500, hint: '종가 ≤ 이 가격일 때 체결'),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTProgressBar(BuildContext context, WidgetRef ref, SteadyOrderGuide guide) {
    final cycles = ref.watch(cycleListProvider);
    final cycle = cycles.where((c) => c.id == cycleId).firstOrNull;
    final totalRounds = cycle?.totalRounds ?? 40;
    final progress = (guide.tValue / totalRounds).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'T: ${guide.tValue.toStringAsFixed(1)} / $totalRounds',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: context.appTextPrimary,
              ),
            ),
            Text(
              guide.isFirstHalf ? '전반전' : '후반전',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: guide.isFirstHalf ? AppColors.blue500 : AppColors.amber500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: context.appDivider,
            valueColor: AlwaysStoppedAnimation(
              guide.isFirstHalf ? AppColors.blue500 : AppColors.amber500,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '오프셋: ${guide.locOffsetPercent >= 0 ? '+' : ''}${guide.locOffsetPercent.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 11,
            color: context.appTextHint,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  Widget _buildOrderRow(BuildContext context, OrderItem order, Color color, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4, height: 4,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(
                  '${order.label}: \$${order.price.toStringAsFixed(2)} \u00d7 ${order.shares.floor()}주 (${order.shares.toStringAsFixed(1)})',
                  style: TextStyle(fontSize: 12, color: context.appTextPrimary),
                ),
              ),
              Text(order.description, style: TextStyle(fontSize: 11, color: context.appTextHint)),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(
                    text: '\$${order.price.toStringAsFixed(2)} / ${order.shares.floor()}주',
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('복사됨: \$${order.price.toStringAsFixed(2)} / ${order.shares.floor()}주'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
                child: Icon(Icons.copy, size: 14, color: context.appTextHint),
              ),
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Text(hint, style: TextStyle(fontSize: 10, color: context.appTextHint)),
            ),
        ],
      ),
    );
  }

  String _buyHint(OrderItem order) {
    if (order.label.contains('평단')) return '종가 ≤ 평단가일 때 체결';
    return '종가 ≤ 이 가격일 때 체결';
  }

  Widget _buildQuarterModeAlert(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.amber500.withValues(alpha: context.isDarkMode ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, size: 18, color: AppColors.amber500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '쿼터모드 — MOC 매도 + 지정가 매도를 진행합니다',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.amber500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstBuyGuide(BuildContext context, SteadyOrderGuide guide) {
    if (guide.buySingleOrder == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '첫 매수', AppColors.blue500),
        const SizedBox(height: 6),
        _buildOrderRow(context, guide.buySingleOrder!, AppColors.blue500),
      ],
    );
  }

  static void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        title: Row(
          children: [
            Icon(Icons.help_outline, size: 20, color: ctx.appAccent),
            const SizedBox(width: 8),
            Text('용어 설명', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ctx.appTextPrimary)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            '── 매수 ──\n\n'
            'T값 (회차)\n'
            '투자한 금액 ÷ 1회 매수금. T가 클수록 원금 소진.\n'
            '예: T=5 → 5회분 투입 완료\n\n'
            '오프셋 (별%)\n'
            'LOC 주문가를 평단 대비 몇%로 설정할지 결정.\n'
            'T가 커질수록 낮아져 → 더 싼 가격에서만 매수.\n'
            '예: +10% → 평단보다 비싸도 매수\n'
            '    -5% → 평단보다 싸야만 매수\n\n'
            'LOC A / LOC B (전반전)\n'
            '전반전에 2종 매수 주문을 동시에 설정.\n'
            'V2.2: A=평단가, B=오프셋가\n'
            'V3.0: A=오프셋가, B=평단가\n\n'
            '전반전 / 후반전\n'
            '총 분할의 절반 기준 (V2.2: T=20, V3.0: T=10).\n'
            '전반전: 2종 주문 / 후반전: 1종 주문\n\n'
            '── 매도 ──\n\n'
            '매일 매수+매도를 동시에 설정\n'
            '증권사에서 매수 LOC와 매도 주문을 같은 날 걸어놓습니다.\n'
            '다음 날 체결 여부를 확인하고 앱에 기록합니다.\n\n'
            'LOC 매도 (1/4)\n'
            '보유수량의 25%를 별% 가격에 LOC 매도.\n'
            '종가 ≥ 별% 가격이면 체결. 부분 수익 실현.\n\n'
            '지정가 매도 (3/4)\n'
            '보유수량의 75%를 익절 목표가에 지정가 매도.\n'
            '장중 목표가 이상 도달 시 즉시 체결.\n'
            'V2.2: +10%, V3.0: TQQQ +15% / SOXL +20%\n\n'
            '미체결 (정상)\n'
            'LOC 주문이 체결되지 않을 수 있습니다.\n'
            '이는 "현금 보존"이며 하락장 방어의 핵심입니다.\n\n'
            '── 특수 ──\n\n'
            '반복리 (V3.0)\n'
            '매도 수익의 1/40을 다음 매수금에 추가.\n'
            '손해 시에는 매수금을 유지합니다.\n\n'
            '쿼터모드\n'
            '원금 소진 시 발동하는 안전장치.\n'
            'V2.2: 1/4 MOC 손절 → 10회 재진입\n'
            'V3.0: 1/4 MOC 매도 + 지정가 매도\n\n'
            'MOC (Market On Close)\n'
            '종가에 무조건 체결되는 시장가 주문.\n'
            'LOC와 달리 가격 조건 없이 확실하게 체결됩니다.',
            style: TextStyle(fontSize: 13, color: ctx.appTextSecondary, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoFillGuide(BuildContext context, SteadyOrderGuide guide) {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.appBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.mail_outline, size: 16, color: context.appTextHint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              !guide.canBuy
                  ? '매수 완료 — 매도 주문만 대기'
                  : '잔여 현금 부족',
              style: TextStyle(
                fontSize: 12,
                color: context.appTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
