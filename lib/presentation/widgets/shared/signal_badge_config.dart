import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/trade.dart';

// ═══════════════════════════════════════════════════════════════
// 신호 배지 설정 (공유 유틸)
// ═══════════════════════════════════════════════════════════════

class SignalBadgeConfig {
  final String label;
  final Color color;

  const SignalBadgeConfig({required this.label, required this.color});

  /// 전체 신호에 대한 배지 설정 반환
  static SignalBadgeConfig fromSignal(TradeSignal signal) {
    switch (signal) {
      case TradeSignal.initial:
        return SignalBadgeConfig(label: '초기진입', color: AppColors.green600);
      case TradeSignal.weightedBuy:
        return SignalBadgeConfig(label: '가중매수', color: AppColors.blue500);
      case TradeSignal.panicBuy:
        return SignalBadgeConfig(label: '승부수', color: AppColors.red500);
      case TradeSignal.cashSecure:
        return SignalBadgeConfig(label: '현금확보', color: AppColors.amber500);
      case TradeSignal.takeProfit:
        return SignalBadgeConfig(label: '익절', color: AppColors.green500);
      case TradeSignal.locAB:
        return SignalBadgeConfig(label: 'LOC A+B', color: AppColors.blue500);
      case TradeSignal.locA:
        return SignalBadgeConfig(label: 'LOC A', color: AppColors.blue500);
      case TradeSignal.locB:
        return SignalBadgeConfig(label: 'LOC B', color: AppColors.blue400);
      case TradeSignal.manual:
        return SignalBadgeConfig(label: '수동', color: AppColors.gray500);
      case TradeSignal.hold:
        return SignalBadgeConfig(label: '대기', color: AppColors.gray400);
      case TradeSignal.sellLocQuarter:
        return SignalBadgeConfig(label: 'LOC매도¼', color: AppColors.green500);
      case TradeSignal.sellLimitThreeQ:
        return SignalBadgeConfig(label: '지정가¾', color: AppColors.green600);
      case TradeSignal.takeProfitFull:
        return SignalBadgeConfig(label: '전량익절', color: AppColors.green500);
      case TradeSignal.buySingle:
        return SignalBadgeConfig(label: '단일매수', color: AppColors.blue500);
      case TradeSignal.noFill:
        return SignalBadgeConfig(label: '미체결', color: AppColors.gray400);
      case TradeSignal.ladderStep1:
        return SignalBadgeConfig(label: 'MDD 1단계', color: AppColors.amber500);
      case TradeSignal.ladderStep2:
        return SignalBadgeConfig(label: 'MDD 2단계', color: AppColors.amber500);
      case TradeSignal.ladderStep3:
        return SignalBadgeConfig(label: 'MDD 3단계', color: AppColors.amber500);
      case TradeSignal.ladderStep4:
        return SignalBadgeConfig(label: 'MDD 4단계', color: AppColors.amber500);
      case TradeSignal.ladderStep5:
        return SignalBadgeConfig(label: 'MDD 5단계', color: AppColors.amber500);
      case TradeSignal.ladderStep6:
        return SignalBadgeConfig(label: 'MDD 6단계', color: AppColors.amber500);
    }
  }
}
