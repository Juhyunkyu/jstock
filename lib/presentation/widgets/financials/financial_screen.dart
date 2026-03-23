import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/financial_data.dart';
import '../../providers/financial_providers.dart';

import 'financial_overview_card.dart';
import 'financial_metrics_card.dart';
import 'financial_revenue_chart.dart';
import 'financial_eps_chart.dart';
import 'financial_analysis_card.dart';

/// 재무 탭 전체 화면
///
/// [financialDataProvider]를 watch하여 로딩/에러/데이터 상태를 처리한다.
/// ETF인 경우 재무제표 미제공 안내를 표시한다.
class FinancialScreen extends ConsumerWidget {
  final String symbol;

  const FinancialScreen({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(financialDataProvider(symbol));

    return asyncData.when(
      loading: () => _buildLoading(context),
      error: (e, _) => _buildError(context, ref),
      data: (data) => _buildContent(context, data),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: context.appAccent,
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: context.appTextHint,
            ),
            const SizedBox(height: 16),
            Text(
              '재무 데이터를 불러올 수 없습니다',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '네트워크 연결을 확인하고 다시 시도해주세요',
              style: TextStyle(
                fontSize: 13,
                color: context.appTextHint,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(financialDataProvider(symbol)),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('재시도'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.appAccent,
                side: BorderSide(color: context.appBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, FinancialData data) {
    // ETF 감지: 재무제표 미제공 안내
    if (data.profile?.isEtf == true) {
      return _buildEtfNotice(context);
    }

    // 데이터가 완전히 비어있는 경우
    if (data.isEmpty) {
      return _buildEmptyNotice(context);
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 섹션 1: 기업 개요
            if (data.profile != null)
              FinancialOverviewCard(profile: data.profile!),
            if (data.profile != null) const SizedBox(height: 12),

            // 섹션 2: 핵심 투자 지표
            if (data.metrics != null)
              FinancialMetricsCard(metrics: data.metrics!),
            if (data.metrics != null) const SizedBox(height: 12),

            // 섹션 3: 실적 추이 차트
            if (data.annualStatements.isNotEmpty || data.quarterlyStatements.isNotEmpty)
              FinancialRevenueChart(
                annualStatements: data.annualStatements,
                quarterlyStatements: data.quarterlyStatements,
              ),
            if (data.annualStatements.isNotEmpty || data.quarterlyStatements.isNotEmpty)
              const SizedBox(height: 12),

            // 섹션 4: EPS Beat/Miss 차트
            if (data.earnings.isNotEmpty)
              FinancialEpsChart(earnings: data.earnings),
            if (data.earnings.isNotEmpty) const SizedBox(height: 12),

            // 섹션 5: 기업 분석 요약
            FinancialAnalysisCard(data: data),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEtfNotice(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 48,
              color: context.appTextHint,
            ),
            const SizedBox(height: 16),
            Text(
              'ETF는 재무제표가 제공되지 않습니다',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '개별 종목을 선택해주세요',
              style: TextStyle(
                fontSize: 13,
                color: context.appTextHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyNotice(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: context.appTextHint,
            ),
            const SizedBox(height: 16),
            Text(
              '재무 데이터가 없습니다',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '해당 종목의 재무 정보를 찾을 수 없습니다',
              style: TextStyle(
                fontSize: 13,
                color: context.appTextHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
