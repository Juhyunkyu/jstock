import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/api_providers.dart';

/// 컴팩트 환율 표시 - 미니멀 디자인
class ExchangeRateChip extends ConsumerWidget {
  const ExchangeRateChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rateState = ref.watch(exchangeRateProvider);
    final hasData = rateState.usdKrw != null;

    return Container(
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
        ],
      ),
    );
  }
}

/// 환율 표시 카드 (풀 사이즈) - 미니멀 디자인
class ExchangeRateCard extends ConsumerWidget {
  const ExchangeRateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rateState = ref.watch(exchangeRateProvider);
    final hasData = rateState.usdKrw != null;

    return Container(
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
                Text(
                  'USD/KRW',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.appTextSecondary,
                  ),
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
          GestureDetector(
            onTap: rateState.isLoading
                ? null
                : () {
                    ref.read(exchangeRateProvider.notifier).refreshRate();
                  },
            child: Icon(
              Icons.refresh_rounded,
              color: rateState.isLoading
                  ? context.appBorder
                  : context.appTextHint,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRate(double rate) {
    return rate.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }
}
