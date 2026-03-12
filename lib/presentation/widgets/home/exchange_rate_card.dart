import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/api_providers.dart';

/// 컴팩트 환율 표시 칩
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
              final isDesktop = MediaQuery.sizeOf(context).width >= 768;
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
                fontSize: MediaQuery.sizeOf(context).width >= 768 ? 14 : 12,
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
