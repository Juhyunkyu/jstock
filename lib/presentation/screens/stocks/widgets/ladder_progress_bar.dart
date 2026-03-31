import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/cycle.dart';
import '../../../../domain/trading/ladder_cycle_service.dart';
import 'ladder_simulation_sheet.dart';

/// N단계 진행도 바: 원(●)과 선(━)으로 단계 표시
///
/// - 완료 단계: 채운 원 + accent 색상
/// - 현재 단계: ▶ 표시
/// - 대기 단계: 빈 원 + hint 색상
/// - 각 원 위에 MDD 트리거값 표시
class LadderProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String ladderTriggers;
  final Cycle cycle;

  const LadderProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.ladderTriggers,
    required this.cycle,
  });

  @override
  Widget build(BuildContext context) {
    final triggers = parseLadderTriggers(ladderTriggers, steps: totalSteps);
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 10 : 14,
      ),
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
          // 진행도 바
          LayoutBuilder(
            builder: (context, constraints) {
              return _buildProgressRow(context, triggers, constraints.maxWidth, isMobile);
            },
          ),
          SizedBox(height: isMobile ? 6 : 8),
          // 하단: 시뮬레이션 버튼 + 단계 표시
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 왼쪽: 시뮬레이션 버튼
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: context.appSurface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (_) => LadderSimulationSheet(cycle: cycle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.analytics_outlined, size: 14, color: context.appTextHint),
                    const SizedBox(width: 4),
                    Text(
                      '시뮬레이션',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 13,
                        color: context.appTextHint,
                      ),
                    ),
                  ],
                ),
              ),
              // 오른쪽: 단계
              Text(
                '$currentStep / $totalSteps 단계',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 13,
                  fontWeight: FontWeight.w600,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow(
    BuildContext context,
    List<double> triggers,
    double maxWidth,
    bool isMobile,
  ) {
    final stepCount = triggers.length;
    final dotSize = isMobile ? 20.0 : 24.0;
    final fontSize = isMobile ? 9.0 : 10.0;

    return Column(
      children: [
        // MDD 트리거 값 라벨 행
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(stepCount, (i) {
            final triggerVal = triggers[i];
            return SizedBox(
              width: dotSize + 8,
              child: Text(
                '${triggerVal.toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: i < currentStep
                      ? (context.isDarkMode ? AppColors.amber400 : AppColors.amber500)
                      : context.appTextHint,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        // 원 + 선 행
        Row(
          children: List.generate(stepCount * 2 - 1, (index) {
            if (index.isEven) {
              // 원(dot)
              final stepIndex = index ~/ 2;
              return _buildDot(context, stepIndex, dotSize);
            } else {
              // 선(line)
              final lineStepBefore = index ~/ 2;
              final isCompleted = lineStepBefore < currentStep;
              return Expanded(
                child: Container(
                  height: 2,
                  color: isCompleted
                      ? (context.isDarkMode ? AppColors.amber400 : AppColors.amber500)
                      : context.appDivider,
                ),
              );
            }
          }),
        ),
      ],
    );
  }

  Widget _buildDot(BuildContext context, int stepIndex, double dotSize) {
    final isCompleted = stepIndex < currentStep;
    final isCurrent = stepIndex == currentStep;
    final activeColor = context.isDarkMode ? AppColors.amber400 : AppColors.amber500;

    if (isCompleted) {
      // 완료 단계: 채운 원
      return Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          color: activeColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 12, color: Colors.white),
      );
    }

    if (isCurrent) {
      // 현재 단계: 특수 표시
      return Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          color: activeColor.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: activeColor, width: 2),
        ),
        child: Icon(Icons.play_arrow, size: 12, color: activeColor),
      );
    }

    // 대기 단계: 빈 원
    return Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.appDivider, width: 1.5),
      ),
    );
  }
}
