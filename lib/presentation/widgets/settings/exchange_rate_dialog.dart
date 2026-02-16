import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

/// 환율 설정 다이얼로그
class ExchangeRateDialog extends StatefulWidget {
  final double currentRate;
  final Function(double) onSave;

  const ExchangeRateDialog({
    super.key,
    required this.currentRate,
    required this.onSave,
  });

  @override
  State<ExchangeRateDialog> createState() => _ExchangeRateDialogState();
}

class _ExchangeRateDialogState extends State<ExchangeRateDialog> {
  late TextEditingController _controller;
  String? _errorText;

  // 일반적인 환율 범위
  static const double minRate = 900.0;
  static const double maxRate = 2000.0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentRate.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate(String value) {
    final rate = double.tryParse(value);
    setState(() {
      if (rate == null) {
        _errorText = '유효한 숫자를 입력해주세요';
      } else if (rate < minRate || rate > maxRate) {
        _errorText = '환율은 $minRate~$maxRate 범위 내여야 합니다';
      } else {
        _errorText = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.currency_exchange_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Text('환율 설정', style: TextStyle(color: context.appTextPrimary)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '달러(USD) 대비 원화(KRW) 환율을 입력하세요.',
            style: TextStyle(
              fontSize: 14,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // 환율 입력
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: _validate,
            decoration: InputDecoration(
              prefixText: '1 USD = ',
              suffixText: '원',
              filled: true,
              fillColor: context.appIconBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              errorText: _errorText,
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.red500, width: 2),
              ),
            ),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          // 프리셋 버튼들
          Text(
            '빠른 선택',
            style: TextStyle(
              fontSize: 12,
              color: context.appTextHint,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _PresetChip(
                label: '1,300',
                onTap: () => _setRate(1300),
              ),
              const SizedBox(width: 8),
              _PresetChip(
                label: '1,350',
                onTap: () => _setRate(1350),
              ),
              const SizedBox(width: 8),
              _PresetChip(
                label: '1,400',
                onTap: () => _setRate(1400),
              ),
              const SizedBox(width: 8),
              _PresetChip(
                label: '1,450',
                onTap: () => _setRate(1450),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _errorText == null
              ? () {
                  final rate = double.tryParse(_controller.text);
                  if (rate != null) {
                    widget.onSave(rate);
                    Navigator.pop(context);
                  }
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('저장'),
        ),
      ],
    );
  }

  void _setRate(double rate) {
    _controller.text = rate.toStringAsFixed(0);
    _validate(_controller.text);
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.appIconBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: context.appTextSecondary,
          ),
        ),
      ),
    );
  }
}

/// 매매 조건 설정 다이얼로그
class TradingConditionsDialog extends StatefulWidget {
  final double buyTrigger;
  final double sellTrigger;
  final double panicTrigger;
  final Function(double, double, double) onSave;

  const TradingConditionsDialog({
    super.key,
    required this.buyTrigger,
    required this.sellTrigger,
    required this.panicTrigger,
    required this.onSave,
  });

  @override
  State<TradingConditionsDialog> createState() =>
      _TradingConditionsDialogState();
}

class _TradingConditionsDialogState extends State<TradingConditionsDialog> {
  late double _buyTrigger;
  late double _sellTrigger;
  late double _panicTrigger;

  @override
  void initState() {
    super.initState();
    _buyTrigger = widget.buyTrigger;
    _sellTrigger = widget.sellTrigger;
    _panicTrigger = widget.panicTrigger;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.tune_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Text('매매 조건 설정', style: TextStyle(color: context.appTextPrimary)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '새로운 사이클에 적용될 기본 매매 조건입니다.',
            style: TextStyle(
              fontSize: 13,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // 매수 시작점
          _ConditionSlider(
            label: '매수 시작점',
            value: _buyTrigger,
            min: -30,
            max: -10,
            color: AppColors.weightedBuy,
            onChanged: (v) => setState(() => _buyTrigger = v),
          ),
          const SizedBox(height: 20),

          // 익절 목표
          _ConditionSlider(
            label: '익절 목표',
            value: _sellTrigger,
            min: 10,
            max: 30,
            color: AppColors.takeProfit,
            isPositive: true,
            onChanged: (v) => setState(() => _sellTrigger = v),
          ),
          const SizedBox(height: 20),

          // 승부수 발동
          _ConditionSlider(
            label: '승부수 발동',
            value: _panicTrigger,
            min: -60,
            max: -40,
            color: AppColors.panicBuy,
            onChanged: (v) => setState(() => _panicTrigger = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _buyTrigger = -20;
              _sellTrigger = 20;
              _panicTrigger = -50;
            });
          },
          child: const Text('기본값'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(_buyTrigger, _sellTrigger, _panicTrigger);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _ConditionSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final Color color;
  final bool isPositive;
  final Function(double) onChanged;

  const _ConditionSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    this.isPositive = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.appTextPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${isPositive ? '+' : ''}${value.toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.2),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
