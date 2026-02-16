import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/holding.dart';
import '../../../providers/holding_providers.dart';
import 'profit_loss_section.dart'; // for formatKrwWithComma

/// 보유 정보 카드
class HoldingInfoCard extends ConsumerStatefulWidget {
  final Holding holding;
  final double currentPrice;
  final double currentExchangeRate;
  final double cumulativeRealizedPnlKrw;

  const HoldingInfoCard({
    super.key,
    required this.holding,
    required this.currentPrice,
    required this.currentExchangeRate,
    this.cumulativeRealizedPnlKrw = 0,
  });

  @override
  ConsumerState<HoldingInfoCard> createState() => HoldingInfoCardState();
}

class HoldingInfoCardState extends ConsumerState<HoldingInfoCard> {
  bool _showCurrencyPL = false;

  @override
  Widget build(BuildContext context) {
    final holding = widget.holding;
    final currentPrice = widget.currentPrice;
    final currentExchangeRate = widget.currentExchangeRate;

    // 평가금 = 현재가 × 수량 × 현재환율
    final marketValueKrw = currentPrice * holding.quantity * currentExchangeRate;
    // 환차손익 기준 평가금 = 현재가 × 수량 × 매입환율
    final marketValueAtPurchaseRate = currentPrice * holding.quantity * holding.exchangeRate;
    // 환차손익 = 환율 변동분 × 현재가 × 수량
    final currencyPL = (currentExchangeRate - holding.exchangeRate) * currentPrice * holding.quantity;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InfoRow(label: '보유 수량', value: '${holding.quantity}주'),
          const Divider(height: 16),
          InfoRow(label: '매입가 (손익분기)', value: '\$${holding.averagePrice.toStringAsFixed(2)}'),
          const Divider(height: 16),
          InfoRow(label: '총 투자금 (원)', value: _formatKrw(holding.totalInvestedAmount)),
          const Divider(height: 16),
          // 평가금
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    _showCurrencyPL ? '평가금 (매입환율)' : '평가금 (원)',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _showCurrencyPL = !_showCurrencyPL),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _showCurrencyPL
                            ? AppColors.secondary.withValues(alpha: 0.15)
                            : context.appBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '환차',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _showCurrencyPL
                              ? AppColors.secondary
                              : context.appTextSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                _showCurrencyPL
                    ? _formatKrw(marketValueAtPurchaseRate)
                    : _formatKrw(marketValueKrw),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
          // 환차손익 상세
          if (_showCurrencyPL) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (currencyPL >= 0 ? AppColors.red500 : AppColors.blue500)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '환차손익',
                        style: TextStyle(fontSize: 12, color: context.appTextSecondary),
                      ),
                      Text(
                        '${currencyPL >= 0 ? '+' : ''}${_formatKrw(currencyPL)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: currencyPL >= 0 ? AppColors.red500 : AppColors.blue500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '매입환율 → 현재환율',
                        style: TextStyle(fontSize: 11, color: context.appTextHint),
                      ),
                      Text(
                        '₩${holding.exchangeRate.toStringAsFixed(0)} → ₩${currentExchangeRate.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 11, color: context.appTextHint),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 16),
          // 평균 매입 환율 — 편집 가능
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '평균 매입 환율',
                style: TextStyle(
                  fontSize: 13,
                  color: context.appTextSecondary,
                ),
              ),
              Row(
                children: [
                  Text(
                    '\u20a9${holding.exchangeRate.toStringAsFixed(2)} / \$1',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _showExchangeRateEditDialog(context, ref, holding),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: context.appTextHint,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 16),
          InfoRow(label: '기준환율', value: '\u20a9${currentExchangeRate.toStringAsFixed(2)} / \$1'),
          const Divider(height: 16),
          // 누적손익 (매도 실현손익 합계)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '누적 실현손익',
                style: TextStyle(
                  fontSize: 13,
                  color: context.appTextSecondary,
                ),
              ),
              Text(
                widget.cumulativeRealizedPnlKrw == 0
                    ? '0원'
                    : '${widget.cumulativeRealizedPnlKrw >= 0 ? '+' : ''}${_formatKrw(widget.cumulativeRealizedPnlKrw)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.cumulativeRealizedPnlKrw == 0
                      ? context.appTextPrimary
                      : widget.cumulativeRealizedPnlKrw > 0
                          ? AppColors.stockUp
                          : AppColors.stockDown,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showExchangeRateEditDialog(BuildContext context, WidgetRef ref, Holding holding) {
    final controller = TextEditingController(
      text: holding.exchangeRate.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('평균 매입환율 수정'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          decoration: const InputDecoration(
            prefixText: '\u20a9',
            suffixText: '/ \$1',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final newRate = double.tryParse(controller.text);
              if (newRate != null && newRate > 0) {
                ref.read(holdingListProvider.notifier).updateExchangeRate(
                  holdingId: holding.id,
                  newExchangeRate: newRate,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('저장', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  String _formatKrw(double amount) {
    return formatKrwWithComma(amount);
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: context.appTextSecondary,
          ),
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

class DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const DetailRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: context.appTextSecondary),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
