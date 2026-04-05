import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../providers/providers.dart';

/// 자동 계산 행 — 라벨 + 값 + (선택) 서브 라벨
class CalcRow extends StatelessWidget {
  final String label;
  final String value;
  final String? subLabel;

  const CalcRow({
    super.key,
    required this.label,
    required this.value,
    this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: context.appTextSecondary,
              ),
            ),
            if (subLabel != null) ...[
              const SizedBox(width: 4),
              Text(
                subLabel!,
                style: TextStyle(
                  fontSize: 11,
                  color: context.appTextHint,
                ),
              ),
            ],
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
      ],
    );
  }
}

/// 티커 직접 입력 필드 (모달 내부용)
class ManualTickerInput extends StatefulWidget {
  final void Function(String ticker, String? name) onSubmitted;

  const ManualTickerInput({super.key, required this.onSubmitted});

  @override
  State<ManualTickerInput> createState() => _ManualTickerInputState();
}

class _ManualTickerInputState extends State<ManualTickerInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim().toUpperCase();
    if (text.isEmpty) return;
    widget.onSubmitted(text, null);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: '티커 직접 입력 (예: TQQQ)',
              hintStyle: TextStyle(
                fontSize: 14,
                color: context.appTextHint,
                fontWeight: FontWeight.w400,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              filled: true,
              fillColor: context.appBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  Icons.arrow_forward,
                  color: context.appAccent,
                  size: 20,
                ),
                onPressed: _submit,
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
      ],
    );
  }
}

/// 최근 조회 종목 목록 (티커 선택 모달용)
class RecentTickerList extends ConsumerWidget {
  final ScrollController scrollController;
  final void Function(String ticker, String name) onSelected;

  const RecentTickerList({
    super.key,
    required this.scrollController,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentItems = ref.watch(recentViewProvider);

    if (recentItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 40, color: context.appTextHint),
            const SizedBox(height: 12),
            Text(
              '최근 조회한 종목이 없습니다',
              style: TextStyle(fontSize: 13, color: context.appTextSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '위 입력란에 티커를 직접 입력해주세요',
              style: TextStyle(fontSize: 12, color: context.appTextHint),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '최근 조회',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.appTextSecondary,
              ),
            ),
          ),
          ...recentItems.map((item) => ListTile(
                onTap: () => onSelected(item.ticker, item.name),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      item.ticker.substring(0, item.ticker.length > 2 ? 2 : item.ticker.length),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  item.ticker,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                subtitle: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextSecondary,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: context.appTextHint,
                ),
              )),
        ],
      ),
    );
  }
}
