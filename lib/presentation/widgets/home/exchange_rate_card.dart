import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/api_providers.dart';
import '../../providers/korea_exim_providers.dart';

/// 컴팩트 환율 표시 - 탭하면 상세 바텀시트 열림
class ExchangeRateChip extends ConsumerWidget {
  const ExchangeRateChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rateState = ref.watch(exchangeRateProvider);
    final hasData = rateState.usdKrw != null;

    return GestureDetector(
      onTap: () => _showDetailSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: context.appIconBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Builder(
              builder: (context) {
                final isDesktop = MediaQuery.of(context).size.width >= 768;
                return Text(
                  'USD',
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 11,
                    fontWeight: FontWeight.w500,
                    color: context.appTextSecondary,
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
            if (hasData)
              Text(
                '₩${rateState.usdKrw!.rate.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width >= 768 ? 14 : 12,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
              )
            else if (rateState.isLoading)
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: context.appTextHint,
                ),
              )
            else
              Text(
                '-',
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTextHint,
                ),
              ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: context.appTextHint,
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ExchangeRateDetailSheet(),
    );
  }
}

/// 환율 상세 바텀시트 — 실시간 + 한국수출입은행 매매기준율
class ExchangeRateDetailSheet extends ConsumerWidget {
  const ExchangeRateDetailSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rateState = ref.watch(exchangeRateProvider);
    final eximState = ref.watch(koreaEximProvider);
    final isRefreshing = rateState.isLoading || eximState.isLoading;

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 핸들바
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 타이틀
              Text(
                'USD/KRW 환율',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // 실시간 환율 섹션
              _RealtimeSection(rateState: rateState),
              const SizedBox(height: 12),

              Divider(color: context.appDivider, height: 1),
              const SizedBox(height: 12),

              // 한국수출입은행 섹션
              _KoreaEximSection(eximState: eximState),
              const SizedBox(height: 20),

              // 새로고침 버튼
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: isRefreshing
                      ? null
                      : () {
                          ref
                              .read(exchangeRateProvider.notifier)
                              .refreshRate();
                          ref.read(koreaEximProvider.notifier).refresh();
                        },
                  icon: isRefreshing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.appTextHint,
                          ),
                        )
                      : Icon(
                          Icons.refresh_rounded,
                          size: 18,
                          color: context.appAccent,
                        ),
                  label: Text(
                    isRefreshing ? '갱신 중...' : '새로고침',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isRefreshing
                          ? context.appTextHint
                          : context.appAccent,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: context.appDivider),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 실시간 환율 섹션
class _RealtimeSection extends StatelessWidget {
  final ExchangeRateState rateState;

  const _RealtimeSection({required this.rateState});

  @override
  Widget build(BuildContext context) {
    final hasData = rateState.usdKrw != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '실시간',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.appTextSecondary,
              ),
            ),
            const Spacer(),
            if (hasData && rateState.usdKrw!.source != null)
              Text(
                rateState.usdKrw!.source!,
                style: TextStyle(
                  fontSize: 11,
                  color: context.appTextHint,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (hasData)
          Text(
            '₩${_formatRate(rateState.usdKrw!.rate)}',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          )
        else if (rateState.isLoading)
          SizedBox(
            height: 32,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.appTextHint,
                ),
              ),
            ),
          )
        else
          Text(
            '조회 실패',
            style: TextStyle(
              fontSize: 16,
              color: context.appTextHint,
            ),
          ),
      ],
    );
  }
}

/// 한국수출입은행 섹션
class _KoreaEximSection extends StatelessWidget {
  final KoreaEximState eximState;

  const _KoreaEximSection({required this.eximState});

  @override
  Widget build(BuildContext context) {
    final hasData = eximState.hasData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasData
              ? '한국수출입은행 (${eximState.rate!.formattedDate} 기준)'
              : '한국수출입은행',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        if (hasData) ...[
          _RateRow(
            label: '매매기준',
            value: '₩${_formatRate(eximState.rate!.dealBaseRate)}',
            context: context,
          ),
          const SizedBox(height: 6),
          _RateRow(
            label: '살때',
            value: '₩${_formatRate(eximState.rate!.ttsBuyRate)}',
            context: context,
          ),
          const SizedBox(height: 6),
          _RateRow(
            label: '팔때',
            value: '₩${_formatRate(eximState.rate!.ttbSellRate)}',
            context: context,
          ),
        ] else if (eximState.isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: context.appTextHint,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '조회 중...',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appTextHint,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Text(
            eximState.error ?? '공휴일/주말에는 조회 불가',
            style: TextStyle(
              fontSize: 13,
              color: context.appTextHint,
            ),
          ),
      ],
    );
  }
}

/// 매매기준율 행
class _RateRow extends StatelessWidget {
  final String label;
  final String value;
  final BuildContext context;

  const _RateRow({
    required this.label,
    required this.value,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: context.appTextSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
      ],
    );
  }
}

/// 환율 표시 카드 (풀 사이즈) - 탭하면 상세 바텀시트 열림
class ExchangeRateCard extends ConsumerWidget {
  const ExchangeRateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rateState = ref.watch(exchangeRateProvider);
    final hasData = rateState.usdKrw != null;

    return GestureDetector(
      onTap: () => _showDetailSheet(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appDivider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'USD/KRW',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 16,
                        color: context.appTextHint,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (hasData)
                    Text(
                      '₩${_formatRate(rateState.usdKrw!.rate)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    )
                  else if (rateState.isLoading)
                    SizedBox(
                      height: 20,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: context.appTextHint,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      '-',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: context.appTextHint,
                      ),
                    ),
                ],
              ),
            ),
            if (hasData && rateState.usdKrw!.source != null)
              Text(
                rateState.usdKrw!.source!,
                style: TextStyle(
                  fontSize: 11,
                  color: context.appTextHint,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ExchangeRateDetailSheet(),
    );
  }
}

/// 환율 포맷 (천단위 콤마 + 소수점 2자리)
String _formatRate(double rate) {
  return rate.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
      );
}
