import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/financial_data.dart';

/// 기업 분석 요약 카드
///
/// 재무 데이터를 기반으로 3개 카테고리(실적, 재무 건전성, 밸류에이션)에
/// 자동 생성 텍스트를 표시한다. 하단에 면책 문구 포함.
class FinancialAnalysisCard extends StatelessWidget {
  final FinancialData data;

  const FinancialAnalysisCard({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final analyses = _generateAnalyses();
    if (analyses.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '기업 분석 요약',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // 분석 카테고리 카드들
        ...analyses.map((a) => _AnalysisCategoryCard(analysis: a)),

        const SizedBox(height: 16),

        // 면책 문구
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.appIconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '본 정보는 투자 참고용이며 투자 권유가 아닙니다.',
            style: TextStyle(
              fontSize: 11,
              color: context.appTextHint,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// 재무 데이터 기반 분석 텍스트 자동 생성
  List<_AnalysisCategory> _generateAnalyses() {
    final categories = <_AnalysisCategory>[];

    // === 1. 실적 분석 ===
    final earningsTexts = <String>[];

    // 매출 YoY 연속 성장 체크
    final annual = data.annualStatements;
    if (annual.length >= 2) {
      // FMP 응답은 최신 먼저 → 인덱스 0이 최신
      int consecutiveGrowth = 0;
      for (int i = 0; i < annual.length - 1; i++) {
        if (annual[i].revenue > annual[i + 1].revenue) {
          consecutiveGrowth++;
        } else {
          break;
        }
      }
      if (consecutiveGrowth >= 2) {
        earningsTexts.add('매출이 $consecutiveGrowth년 연속 성장 중입니다.');
      } else if (annual.length >= 2 &&
          annual[0].revenue < annual[1].revenue) {
        earningsTexts.add('매출이 전년 대비 감소했습니다.');
      }
    }

    // 영업이익률
    final opMargin = data.metrics?.operatingMargin;
    if (opMargin != null) {
      if (opMargin > 20) {
        earningsTexts.add(
            '영업이익률 ${opMargin.toStringAsFixed(1)}%로 수익성이 양호합니다.');
      } else if (opMargin < 10) {
        earningsTexts.add(
            '영업이익률 ${opMargin.toStringAsFixed(1)}%로 수익성 개선이 필요합니다.');
      }
    }

    // EPS Beat 연속 체크
    if (data.earnings.length >= 4) {
      int consecutiveBeats = 0;
      for (final e in data.earnings) {
        if (e.isBeat) {
          consecutiveBeats++;
        } else {
          break;
        }
      }
      if (consecutiveBeats >= 4) {
        earningsTexts
            .add('최근 ${consecutiveBeats}분기 연속 EPS 서프라이즈를 기록했습니다.');
      }
    }

    if (earningsTexts.isNotEmpty) {
      categories.add(_AnalysisCategory(
        icon: Icons.trending_up_rounded,
        title: '실적',
        texts: earningsTexts,
        sentiment: _categorySentiment(earningsTexts),
      ));
    }

    // === 2. 재무 건전성 ===
    final healthTexts = <String>[];

    final debtToEquity = data.metrics?.debtToEquity;
    if (debtToEquity != null) {
      if (debtToEquity > 200) {
        healthTexts.add(
            '부채비율 ${debtToEquity.toStringAsFixed(0)}%로 재무 건전성에 주의가 필요합니다.');
      } else if (debtToEquity < 100) {
        healthTexts.add(
            '부채비율 ${debtToEquity.toStringAsFixed(0)}%로 재무 구조가 안정적입니다.');
      }
    }

    final currentRatio = data.metrics?.currentRatio;
    if (currentRatio != null) {
      if (currentRatio >= 2.0) {
        healthTexts.add('유동비율이 양호하여 단기 지급 능력이 충분합니다.');
      } else if (currentRatio < 1.0) {
        healthTexts.add('유동비율이 1 미만으로 단기 유동성에 주의가 필요합니다.');
      }
    }

    if (healthTexts.isNotEmpty) {
      categories.add(_AnalysisCategory(
        icon: Icons.shield_outlined,
        title: '재무 건전성',
        texts: healthTexts,
        sentiment: _categorySentiment(healthTexts),
      ));
    }

    // === 3. 밸류에이션 ===
    final valuationTexts = <String>[];

    final per = data.metrics?.peRatio;
    if (per != null) {
      if (per > 30) {
        valuationTexts
            .add('PER ${per.toStringAsFixed(1)}로 성장 기대가 반영된 수준입니다.');
      } else if (per < 15 && per > 0) {
        valuationTexts
            .add('PER ${per.toStringAsFixed(1)}로 저평가 가능성이 있습니다.');
      } else if (per >= 15 && per <= 30) {
        valuationTexts
            .add('PER ${per.toStringAsFixed(1)}로 적정 수준입니다.');
      }
    }

    final pbr = data.metrics?.pbRatio;
    if (pbr != null) {
      if (pbr > 5) {
        valuationTexts.add('PBR ${pbr.toStringAsFixed(1)}로 높은 프리미엄이 반영되어 있습니다.');
      } else if (pbr < 1 && pbr > 0) {
        valuationTexts.add('PBR ${pbr.toStringAsFixed(1)}로 자산 대비 저평가 구간입니다.');
      }
    }

    final dividendYield = data.metrics?.dividendYield;
    if (dividendYield != null && dividendYield > 3) {
      valuationTexts.add(
          '배당률 ${dividendYield.toStringAsFixed(1)}%로 배당 매력이 있습니다.');
    }

    if (valuationTexts.isNotEmpty) {
      categories.add(_AnalysisCategory(
        icon: Icons.analytics_outlined,
        title: '밸류에이션',
        texts: valuationTexts,
        sentiment: _categorySentiment(valuationTexts),
      ));
    }

    return categories;
  }

  /// 텍스트 내용을 분석하여 전반적 심리 판정
  _Sentiment _categorySentiment(List<String> texts) {
    final joined = texts.join(' ');
    final positiveWords = ['양호', '안정', '성장', '충분', '저평가', '매력'];
    final negativeWords = ['주의', '개선', '감소', '높은 프리미엄', '미만'];

    int positive = 0;
    int negative = 0;
    for (final w in positiveWords) {
      if (joined.contains(w)) positive++;
    }
    for (final w in negativeWords) {
      if (joined.contains(w)) negative++;
    }

    if (positive > negative) return _Sentiment.positive;
    if (negative > positive) return _Sentiment.negative;
    return _Sentiment.neutral;
  }
}

enum _Sentiment { positive, neutral, negative }

class _AnalysisCategory {
  final IconData icon;
  final String title;
  final List<String> texts;
  final _Sentiment sentiment;

  const _AnalysisCategory({
    required this.icon,
    required this.title,
    required this.texts,
    required this.sentiment,
  });
}

class _AnalysisCategoryCard extends StatelessWidget {
  final _AnalysisCategory analysis;

  const _AnalysisCategoryCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final sentimentColor = _sentimentColor(context);
    final sentimentBg = sentimentColor.withValues(alpha: 0.1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.appCardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: context.appBorder.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 아이콘
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: sentimentBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                analysis.icon,
                size: 18,
                color: sentimentColor,
              ),
            ),
            const SizedBox(width: 12),

            // 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analysis.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...analysis.texts.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _sentimentColor(BuildContext context) {
    switch (analysis.sentiment) {
      case _Sentiment.positive:
        return context.appGoodColor;
      case _Sentiment.negative:
        return context.appWarningColor;
      case _Sentiment.neutral:
        return context.appCautionColor;
    }
  }
}
