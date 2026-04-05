import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../providers/providers.dart';
import '../../../widgets/shared/ticker_logo.dart';
import 'cycle_setup_helpers.dart';

/// Ladder 매수 모드 선택 (안정형 / 공격형)
class LadderModeSelector extends StatelessWidget {
  final int ladderMode;
  final ValueChanged<int> onChanged;

  const LadderModeSelector({
    super.key,
    required this.ladderMode,
    required this.onChanged,
  });

  static const _labels = ['안정형', '공격형'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '매수 모드',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: List.generate(2, (i) => ButtonSegment<int>(
              value: i,
              label: Text(
                _labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ladderMode == i
                      ? Colors.white
                      : context.appTextSecondary,
                ),
              ),
            )),
            selected: {ladderMode},
            onSelectionChanged: (selected) => onChanged(selected.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.amber600;
                }
                return context.appSurface;
              }),
              side: WidgetStateProperty.all(
                BorderSide(color: context.appBorder, width: 0.5),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ATH 가격 입력 필드 (USD)
class AthPriceInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<double> onChanged;

  const AthPriceInput({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        children: [
          Text(
            '\$ ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.appTextSecondary,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.appTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: '542.85',
                hintStyle: TextStyle(
                  color: context.appTextHint,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
              ),
              onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
            ),
          ),
          Text(
            'USD',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ladder 매수 티커 섹션 (공격형: 1개 / 안정형: 1배/2배/3배)
class LadderBuyTickerSection extends StatelessWidget {
  final int ladderMode;

  // 공격형 티커
  final String? buyTicker;
  final String? buyTickerName;
  final void Function(String ticker, String? name) onBuyTickerSelected;
  final VoidCallback onBuyTickerClear;

  // 안정형 티커 (1배/2배/3배)
  final String? buyTicker1x;
  final String? buyTicker1xName;
  final void Function(String ticker, String? name) onBuyTicker1xSelected;
  final VoidCallback onBuyTicker1xClear;

  final String? buyTicker2x;
  final String? buyTicker2xName;
  final void Function(String ticker, String? name) onBuyTicker2xSelected;
  final VoidCallback onBuyTicker2xClear;

  final String? buyTicker3x;
  final String? buyTicker3xName;
  final void Function(String ticker, String? name) onBuyTicker3xSelected;
  final VoidCallback onBuyTicker3xClear;

  const LadderBuyTickerSection({
    super.key,
    required this.ladderMode,
    required this.buyTicker,
    required this.buyTickerName,
    required this.onBuyTickerSelected,
    required this.onBuyTickerClear,
    required this.buyTicker1x,
    required this.buyTicker1xName,
    required this.onBuyTicker1xSelected,
    required this.onBuyTicker1xClear,
    required this.buyTicker2x,
    required this.buyTicker2xName,
    required this.onBuyTicker2xSelected,
    required this.onBuyTicker2xClear,
    required this.buyTicker3x,
    required this.buyTicker3xName,
    required this.onBuyTicker3xSelected,
    required this.onBuyTicker3xClear,
  });

  @override
  Widget build(BuildContext context) {
    if (ladderMode == 1) {
      // 공격형: 매수 티커 1개
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '매수 티커',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _BuyTickerPicker(
            ticker: buyTicker,
            name: buyTickerName,
            hint: '매수할 종목 선택 (예: TQQQ, SOXL)',
            onSelected: onBuyTickerSelected,
            onClear: onBuyTickerClear,
          ),
        ],
      );
    }

    // 안정형: 1배/2배/3배 매수 티커 3개
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '매수 티커 (1배 / 2배 / 3배)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        _LabeledBuyTickerPicker(
          label: '1배',
          ticker: buyTicker1x,
          name: buyTicker1xName,
          hint: '1배 ETF (예: QQQ)',
          onSelected: onBuyTicker1xSelected,
          onClear: onBuyTicker1xClear,
        ),
        const SizedBox(height: 8),
        _LabeledBuyTickerPicker(
          label: '2배',
          ticker: buyTicker2x,
          name: buyTicker2xName,
          hint: '2배 ETF (예: QLD)',
          onSelected: onBuyTicker2xSelected,
          onClear: onBuyTicker2xClear,
        ),
        const SizedBox(height: 8),
        _LabeledBuyTickerPicker(
          label: '3배',
          ticker: buyTicker3x,
          name: buyTicker3xName,
          hint: '3배 ETF (예: TQQQ)',
          onSelected: onBuyTicker3xSelected,
          onClear: onBuyTicker3xClear,
        ),
      ],
    );
  }
}

class _LabeledBuyTickerPicker extends StatelessWidget {
  final String label;
  final String? ticker;
  final String? name;
  final String hint;
  final void Function(String, String?) onSelected;
  final VoidCallback onClear;

  const _LabeledBuyTickerPicker({
    required this.label,
    required this.ticker,
    required this.name,
    required this.hint,
    required this.onSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _BuyTickerPicker(
            ticker: ticker,
            name: name,
            hint: hint,
            onSelected: onSelected,
            onClear: onClear,
          ),
        ),
      ],
    );
  }
}

class _BuyTickerPicker extends ConsumerWidget {
  final String? ticker;
  final String? name;
  final String hint;
  final void Function(String, String?) onSelected;
  final VoidCallback onClear;

  const _BuyTickerPicker({
    required this.ticker,
    required this.name,
    required this.hint,
    required this.onSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ticker != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.appAccent, width: 1),
        ),
        child: Row(
          children: [
            TickerLogo(ticker: ticker!, size: 24, borderRadius: 6),
            const SizedBox(width: 8),
            Text(
              ticker!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.appTickerColor,
              ),
            ),
            if (name != null) ...[
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name!,
                  style: TextStyle(fontSize: 11, color: context.appTextSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Spacer(),
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, color: context.appTextHint, size: 18),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showPickerFor(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: context.appTextHint, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint,
                style: TextStyle(fontSize: 13, color: context.appTextHint),
              ),
            ),
            Icon(Icons.chevron_right, color: context.appTextHint, size: 18),
          ],
        ),
      ),
    );
  }

  void _showPickerFor(BuildContext context, WidgetRef ref) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
}
