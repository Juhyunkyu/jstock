import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// 손익 게이지 위젯
///
/// 손실률/수익률을 시각적 게이지로 표시합니다.
/// -60% ~ +40% 범위를 표시하며, 매수/익절 트리거 포인트를 표시합니다.
class ProfitLossGauge extends StatelessWidget {
  /// 손실률 (%, 초기진입가 기준)
  final double lossRate;

  /// 수익률 (%, 평균단가 기준)
  final double returnRate;

  /// 매수 시작점 (기본: -20)
  final double buyTrigger;

  /// 익절 목표 (기본: +20)
  final double sellTrigger;

  /// 승부수 발동점 (기본: -50)
  final double panicTrigger;

  /// 승부수 사용 여부
  final bool panicUsed;

  /// 컴팩트 모드 (작은 크기)
  final bool compact;

  const ProfitLossGauge({
    super.key,
    required this.lossRate,
    required this.returnRate,
    this.buyTrigger = -20,
    this.sellTrigger = 20,
    this.panicTrigger = -50,
    this.panicUsed = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // 게이지 범위: -60% ~ +40%
    const minValue = -60.0;
    const maxValue = 40.0;
    const range = maxValue - minValue;

    // 위치 계산
    final currentPosition = ((lossRate - minValue) / range).clamp(0.0, 1.0);
    final buyTriggerPosition = ((buyTrigger - minValue) / range).clamp(0.0, 1.0);
    final sellTriggerPosition = ((sellTrigger - minValue) / range).clamp(0.0, 1.0);
    final panicTriggerPosition = ((panicTrigger - minValue) / range).clamp(0.0, 1.0);
    final zeroPosition = ((0 - minValue) / range).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 손익률 표시
        if (!compact)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RateLabel(
                  label: '손실률',
                  value: lossRate,
                  isLoss: true,
                ),
                _RateLabel(
                  label: '수익률',
                  value: returnRate,
                  isLoss: false,
                ),
              ],
            ),
          ),

        // 게이지 바
        SizedBox(
          height: compact ? 24 : 32,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 배경 그라데이션
                  Positioned(
                    top: compact ? 8 : 12,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.red100,
                            context.appDivider,
                            AppColors.green100,
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // 매수 구간 하이라이트
                  Positioned(
                    top: compact ? 8 : 12,
                    left: 0,
                    child: Container(
                      width: width * buyTriggerPosition,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.blue100.withValues(alpha: 0.7),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  // 승부수 구간 하이라이트
                  if (!panicUsed)
                    Positioned(
                      top: compact ? 8 : 12,
                      left: 0,
                      child: Container(
                        width: width * panicTriggerPosition,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.red200.withValues(alpha: 0.5),
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),

                  // 승부수 트리거 마커
                  if (!panicUsed)
                    _TriggerMarker(
                      position: width * panicTriggerPosition,
                      color: AppColors.red500,
                      compact: compact,
                    ),

                  // 매수 트리거 마커
                  _TriggerMarker(
                    position: width * buyTriggerPosition,
                    color: AppColors.blue500,
                    compact: compact,
                  ),

                  // 익절 트리거 마커
                  _TriggerMarker(
                    position: width * sellTriggerPosition,
                    color: AppColors.amber500,
                    compact: compact,
                  ),

                  // 0% 마커
                  Positioned(
                    left: width * zeroPosition - 0.5,
                    top: compact ? 6 : 10,
                    child: Container(
                      width: 1,
                      height: 12,
                      color: AppColors.gray400,
                    ),
                  ),

                  // 현재 위치 인디케이터
                  Positioned(
                    left: width * currentPosition - (compact ? 5 : 6),
                    top: compact ? 2 : 4,
                    child: Container(
                      width: compact ? 10 : 12,
                      height: compact ? 10 : 12,
                      decoration: BoxDecoration(
                        color: _getIndicatorColor(),
                        shape: BoxShape.circle,
                        border: Border.all(color: context.appSurface, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: _getIndicatorColor().withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // 레이블
        if (!compact)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('-60%', style: _labelStyle),
                if (!panicUsed)
                  Text('${panicTrigger.toInt()}%',
                      style: _labelStyle.copyWith(color: AppColors.red500)),
                Text('${buyTrigger.toInt()}%',
                    style: _labelStyle.copyWith(color: AppColors.blue500)),
                Text('0%', style: _labelStyle),
                Text('+${sellTrigger.toInt()}%',
                    style: _labelStyle.copyWith(color: AppColors.amber500)),
                Text('+40%', style: _labelStyle),
              ],
            ),
          ),
      ],
    );
  }

  Color _getIndicatorColor() {
    if (returnRate >= sellTrigger) return AppColors.amber500;
    if (lossRate <= panicTrigger && !panicUsed) return AppColors.red500;
    if (lossRate <= buyTrigger) return AppColors.blue500;
    return AppColors.gray500;
  }

  TextStyle get _labelStyle => const TextStyle(
        fontSize: 10,
        color: AppColors.gray500,
      );
}

class _RateLabel extends StatelessWidget {
  final String label;
  final double value;
  final bool isLoss;

  const _RateLabel({
    required this.label,
    required this.value,
    required this.isLoss,
  });

  @override
  Widget build(BuildContext context) {
    final isNegative = value < 0;
    final color = isLoss
        ? (isNegative ? AppColors.red500 : AppColors.green500)
        : (isNegative ? AppColors.red500 : AppColors.green500);

    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: context.appTextSecondary,
          ),
        ),
        Text(
          '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TriggerMarker extends StatelessWidget {
  final double position;
  final Color color;
  final bool compact;

  const _TriggerMarker({
    required this.position,
    required this.color,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position - 1,
      top: compact ? 4 : 8,
      child: Container(
        width: 2,
        height: compact ? 12 : 16,
        color: color,
      ),
    );
  }
}
