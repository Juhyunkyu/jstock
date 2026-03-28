import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/cycle.dart';
import '../../../../domain/trading/steady_order_guide.dart';
import '../../../providers/providers.dart';
import '../../../widgets/common/top_toast.dart';

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
                onTap: () {
                  final cycles = ref.read(cycleListProvider);
                  final cycle = cycles.where((c) => c.id == cycleId).firstOrNull;
                  final version = cycle?.steadyVersion ?? SteadyVersion.v1;
                  _showHelpDialog(context, version);
                },
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
              _buildSectionTitle(
                context,
                guide.sellLocOrder != null && guide.sellLimitOrder != null
                    ? '매도 주문 (동시)'
                    : '매도 주문',
                AppColors.green500,
              ),
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
    final isV1 = cycle?.steadyVersion == SteadyVersion.v1;
    final progress = (guide.tValue / totalRounds).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isV1
                  ? '회차: ${guide.tValue.toInt()} / $totalRounds'
                  : 'T: ${guide.tValue.toStringAsFixed(1)} / $totalRounds',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: context.appTextPrimary,
              ),
            ),
            if (!isV1)
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
              isV1 ? AppColors.green500 : (guide.isFirstHalf ? AppColors.blue500 : AppColors.amber500),
            ),
          ),
        ),
        if (!isV1) ...[
          const SizedBox(height: 4),
          Text(
            '오프셋: ${guide.locOffsetPercent >= 0 ? '+' : ''}${guide.locOffsetPercent.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              color: context.appTextHint,
            ),
          ),
        ],
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
                  showTopToast(context, '복사됨: \$${order.price.toStringAsFixed(2)} / ${order.shares.floor()}주');
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

  static void _showHelpDialog(BuildContext context, SteadyVersion version) {
    final content = switch (version) {
      SteadyVersion.v1 => '── 매수 (매일) ──\n\n'
          'LOC A (평단가)\n'
          '0.5unit을 평단가에 LOC 주문.\n'
          '종가가 평단 이하이면 종가에 체결됩니다.\n'
          '현재가 > 평단이면 A는 주문하지 않습니다.\n\n'
          'LOC B (+10% 큰수매수)\n'
          '0.5unit을 평단×1.1에 LOC 주문.\n'
          '종가가 이 가격 이하이면 체결 (거의 항상 체결).\n\n'
          'LOC (Limit On Close)\n'
          '설정 가격 이하로 종가가 형성되면 종가에 체결.\n'
          '종가가 설정 가격보다 높으면 미체결.\n\n'
          '── 매도 (매일) ──\n\n'
          '지정가 매도 (전량)\n'
          '보유 전량을 평단+10%에 매도 주문.\n'
          '장중 이 가격에 도달하면 전량 매도 → 사이클 완료.\n\n'
          '── 기타 ──\n\n'
          '40회 소진\n'
          '모든 금액을 투입한 상태. 매수 중단.\n'
          '매도 주문만 유지하며 익절을 기다립니다.\n\n'
          '미체결 (정상)\n'
          'LOC A가 체결되지 않는 날이 있습니다.\n'
          '이는 현금이 보존되는 것이므로 정상입니다.',
      SteadyVersion.v2_2 => '── 매수 ──\n\n'
          'T값: 투자금 ÷ 1회 매수금 (소수점 올림)\n'
          'T가 클수록 원금 소진. 예: T=5 → 5회분 투입\n\n'
          '오프셋: LOC 주문가를 평단 대비 몇%로 설정할지.\n'
          'T가 커질수록 낮아져 → 더 싼 가격에서만 매수.\n\n'
          'LOC A (평단): 0.5unit, 종가 ≤ 평단 시 체결\n'
          'LOC B (오프셋): 0.5unit, 종가 ≤ 오프셋가 시 체결\n\n'
          '전반전 (T<20): A+B 2종 주문\n'
          '후반전 (T≥20): 오프셋 LOC 1종만\n\n'
          '── 매도 ──\n\n'
          'LOC 매도 (1/4): 보유 25%를 오프셋가에 LOC\n'
          '지정가 매도 (3/4): 보유 75%를 +10%에 지정가\n'
          '매일 매수+매도를 동시에 설정합니다.\n\n'
          '── 특수 ──\n\n'
          '쿼터모드 (T≥39.1): 원금 소진 안전장치\n'
          '1/4 MOC 손절 + 3/4 +10% 지정가 매도\n\n'
          'MOC: 종가에 무조건 체결되는 시장가 주문',
      SteadyVersion.v3_0 => '── 매수 ──\n\n'
          'T값: 투자금 ÷ 1회 매수금 (소수점 올림)\n'
          '반복리 시 매도 수익금도 포함하여 계산.\n\n'
          '오프셋: TQQQ형 15-1.5T / SOXL형 20-2T\n'
          'T가 커질수록 낮아져 → 더 싼 가격에서만 매수.\n\n'
          'LOC A (오프셋): 0.5unit, 종가 ≤ 오프셋가 시 체결\n'
          'LOC B (평단): 0.5unit, 종가 ≤ 평단 시 체결\n\n'
          '전반전 (T<10): A+B 2종 주문\n'
          '후반전 (T≥10): 오프셋 LOC 1종만\n\n'
          '── 매도 ──\n\n'
          'LOC 매도 (1/4): 보유 25%를 오프셋가에 LOC\n'
          '지정가 매도 (3/4): TQQQ +15% / SOXL +20%\n\n'
          '── 특수 ──\n\n'
          '반복리: 매도 수익 ÷ 40을 다음 매수금에 추가\n'
          '손해 시 매수금 유지.\n\n'
          '쿼터모드 (19<T<20): 원금 소진 안전장치\n'
          '1/4 MOC 매도 + 3/4 지정가 매도 + 추가매수 5회',
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        title: Row(
          children: [
            Icon(Icons.help_outline, size: 20, color: ctx.appAccent),
            const SizedBox(width: 8),
            Text(
              switch (version) {
                SteadyVersion.v1 => 'V1 Simple 가이드',
                SteadyVersion.v2_2 => 'V2.2 Original 가이드',
                SteadyVersion.v3_0 => 'V3.0 Aggressive 가이드',
              },
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ctx.appTextPrimary),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            content,
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
