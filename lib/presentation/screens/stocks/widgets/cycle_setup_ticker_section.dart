import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../providers/providers.dart';
import '../../../widgets/shared/ticker_logo.dart';
import 'cycle_setup_helpers.dart';

/// 종목 선택 섹션 (선택된 티커 표시 또는 선택 버튼)
class CycleTickerSelector extends ConsumerWidget {
  final String? selectedTicker;
  final String? selectedName;
  final VoidCallback onPickTicker;
  final VoidCallback onClearTicker;

  const CycleTickerSelector({
    super.key,
    required this.selectedTicker,
    required this.selectedName,
    required this.onPickTicker,
    required this.onClearTicker,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedTicker != null) {
      return _SelectedTickerDisplay(
        ticker: selectedTicker!,
        name: selectedName,
        onClear: onClearTicker,
      );
    }
    return _TickerPickerButton(onTap: onPickTicker);
  }
}

class _SelectedTickerDisplay extends ConsumerWidget {
  final String ticker;
  final String? name;
  final VoidCallback onClear;

  const _SelectedTickerDisplay({
    required this.ticker,
    required this.name,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quote = ref.watch(
      stockQuoteProvider.select((s) => s.quotes[ticker]),
    );
    final currentPrice = quote?.currentPrice ?? 0.0;
    final changePercent = quote?.changePercent ?? 0.0;
    final isUp = changePercent >= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appAccent, width: 1),
      ),
      child: Row(
        children: [
          TickerLogo(
            ticker: ticker,
            size: 28,
            borderRadius: 6,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text(
                      ticker,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.appTickerColor,
                      ),
                    ),
                    if (currentPrice > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: context.appBackground,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '\$${currentPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.appTextPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${isUp ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: changePercent == 0
                                    ? context.appTextSecondary
                                    : isUp
                                        ? AppColors.red500
                                        : AppColors.blue500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (name != null)
                  Text(
                    name!,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appTextSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: context.appTextHint, size: 20),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class _TickerPickerButton extends StatelessWidget {
  final VoidCallback onTap;

  const _TickerPickerButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: context.appTextHint,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '종목을 선택하세요 (예: TQQQ, SOXL)',
                style: TextStyle(
                  fontSize: 14,
                  color: context.appTextHint,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.appTextHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// 티커 선택 모달 바텀시트를 표시합니다.
void showTickerPickerSheet(
  BuildContext context,
  WidgetRef ref, {
  required void Function(String ticker, String? name) onSelected,
}) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: context.appSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Text(
                  '종목 선택',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: ManualTickerInput(
                  onSubmitted: (ticker, name) {
                    Navigator.pop(context);
                    final t = ticker.toUpperCase();
                    onSelected(t, name);
                    ref.read(stockQuoteProvider.notifier).fetchQuote(t);
                  },
                ),
              ),
              Divider(color: context.appDivider),
              Expanded(
                child: RecentTickerList(
                  scrollController: scrollController,
                  onSelected: (ticker, name) {
                    Navigator.pop(context);
                    onSelected(ticker, name);
                    ref.read(stockQuoteProvider.notifier).fetchQuote(ticker);
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
