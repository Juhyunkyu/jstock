import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/holding.dart';
import '../../../../data/models/holding_transaction.dart';
import '../../../providers/holding_providers.dart';
import '../../../providers/providers.dart';
import '../../../widgets/shared/confirm_dialog.dart';
import 'edit_transaction_sheet.dart'; // EditTransactionSheet to be extracted later

/// KRW 금액을 천 단위 콤마로 포맷팅 (거래 카드용)
String _formatKrwWithComma(double amount) {
  final intAmount = amount.round();
  final absAmount = intAmount.abs();
  final formatted = absAmount.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
  return intAmount < 0 ? '-$formatted' : formatted;
}

/// 거래 내역 카드
class TransactionCard extends ConsumerWidget {
  final HoldingTransaction transaction;
  final Holding? holding;
  final bool isFirst;
  final bool isLast;
  final bool isEarliestBuy;
  final bool readOnly;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.holding,
    this.isFirst = false,
    this.isLast = false,
    this.isEarliestBuy = false,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBuy = transaction.isBuy;
    // Use isEarliestBuy (dynamically calculated) instead of transaction.isInitialPurchase
    final isInitial = isEarliestBuy && isBuy;
    final dateFormat = DateFormat('yyyy.MM.dd');
    // 환율 연동: holding의 환율로 재계산
    final exchangeRate = holding?.exchangeRate ?? transaction.exchangeRate;
    final amountKrw = transaction.price * transaction.shares * exchangeRate;

    // 거래 유형별 색상, 텍스트 설정
    final Color typeColor;
    final Color typeBgColor;
    final String typeText;

    if (isInitial) {
      // 첫매수 - 에메랄드 그린 (특별한 스타일)
      typeColor = AppColors.initialBuy;
      typeBgColor = AppColors.initialBuy50;
      typeText = '첫매수';
    } else if (isBuy) {
      // 매수 - 빨강 (한국 주식시장 스타일)
      typeColor = AppColors.buyAction;
      typeBgColor = AppColors.buyAction50;
      typeText = '매수';
    } else {
      // 매도 - 파랑 (한국 주식시장 스타일)
      typeColor = AppColors.sellAction;
      typeBgColor = AppColors.sellAction50;
      typeText = '매도';
    }

    return GestureDetector(
      onTap: () => _showTransactionDetail(context, transaction, exchangeRate),
      child: Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        top: isFirst ? 0 : 3,
        bottom: isLast ? 0 : 3,
      ),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // 거래 유형 텍스트 컨테이너 (아이콘 대신 텍스트)
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 36,
                  decoration: BoxDecoration(
                    color: typeBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      typeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: typeColor,
                      ),
                    ),
                  ),
                ),
                // 첫매수인 경우 스파클 아이콘 표시 (우측 상단)
                if (isInitial)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: typeColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),

            // 거래 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 날짜 표시
                  Text(
                    dateFormat.format(transaction.date),
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${transaction.price.toStringAsFixed(2)} x ${transaction.shares.toStringAsFixed(transaction.shares == transaction.shares.roundToDouble() ? 0 : 2)}주',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                  if (transaction.note != null && transaction.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      transaction.note!,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTextHint,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // 거래 금액
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${transaction.amountUsd.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatKrwFull(amountKrw),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextSecondary,
                  ),
                ),
                // 매도 거래 실현손익 표시
                if (transaction.isSell && transaction.realizedPnlKrw != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${transaction.realizedPnlKrw! >= 0 ? '+' : ''}${_formatKrwWithComma(transaction.realizedPnlKrw!)}원',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: transaction.realizedPnlKrw! >= 0
                          ? AppColors.stockUp
                          : AppColors.stockDown,
                    ),
                  ),
                ],
              ],
            ),

            // 수정 버튼 (readOnly일 때 숨김)
            if (!readOnly) ...[
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showTransactionOptions(context, ref, transaction),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: context.appTextHint,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }

  void _showTransactionDetail(
    BuildContext context,
    HoldingTransaction transaction,
    double exchangeRate,
  ) {
    final isBuy = transaction.isBuy;
    final typeText = isBuy ? '매수' : '매도';
    final typeColor = isBuy ? AppColors.buyAction : AppColors.sellAction;
    final dateFormat = DateFormat('yyyy.MM.dd (E)', 'ko_KR');
    final amountUsd = transaction.price * transaction.shares;
    final amountKrw = amountUsd * exchangeRate;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        typeText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: typeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      dateFormat.format(transaction.date),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            // 상세 정보
            _DetailRow(label: '단가', value: '\$${transaction.price.toStringAsFixed(2)}'),
            const SizedBox(height: 10),
            _DetailRow(
              label: '수량',
              value: '${transaction.shares.toStringAsFixed(transaction.shares == transaction.shares.roundToDouble() ? 0 : 2)}주',
            ),
            const SizedBox(height: 10),
            _DetailRow(label: '거래금액 (USD)', value: '\$${amountUsd.toStringAsFixed(2)}'),
            const SizedBox(height: 10),
            _DetailRow(
              label: '거래금액 (원)',
              value: '${_formatKrwWithComma(amountKrw)}원',
            ),
            const SizedBox(height: 10),
            _DetailRow(
              label: '적용환율',
              value: '₩${exchangeRate.toStringAsFixed(0)} / \$1',
            ),
            if (transaction.isSell && transaction.realizedPnlKrw != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '실현손익',
                    style: TextStyle(fontSize: 14, color: context.appTextSecondary),
                  ),
                  Text(
                    '${transaction.realizedPnlKrw! >= 0 ? '+' : ''}${_formatKrwWithComma(transaction.realizedPnlKrw!)}원',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: transaction.realizedPnlKrw! >= 0
                          ? AppColors.stockUp
                          : AppColors.stockDown,
                    ),
                  ),
                ],
              ),
            ],
            if (transaction.note != null && transaction.note!.isNotEmpty) ...[
              const SizedBox(height: 10),
              _DetailRow(label: '메모', value: transaction.note!),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showTransactionOptions(
    BuildContext context,
    WidgetRef ref,
    HoldingTransaction transaction,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.isDarkMode ? const Color(0xFF2D333B) : AppColors.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_outlined, color: AppColors.blue500),
              ),
              title: const Text('수정'),
              subtitle: const Text('거래 정보를 수정합니다'),
              onTap: () {
                Navigator.pop(context);
                _showEditTransactionSheet(context, transaction);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.red50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline, color: AppColors.red500),
              ),
              title: const Text('삭제', style: TextStyle(color: AppColors.red500)),
              subtitle: const Text('거래 내역을 삭제합니다'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await ConfirmDialog.show(
                  context: context,
                  title: '거래 내역 삭제',
                  message: '이 거래 내역을 삭제하시겠습니까?\n삭제된 내역은 복구할 수 없습니다.',
                  confirmText: '삭제',
                  isDanger: true,
                );
                if (confirmed) {
                  await ref.read(holdingListProvider.notifier).deleteTransaction(transaction.id);
                  refreshTransactions(ref);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('거래 내역이 삭제되었습니다'),
                        backgroundColor: AppColors.secondary,
                      ),
                    );
                  }
                }
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  void _showEditTransactionSheet(BuildContext context, HoldingTransaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height,
        child: EditTransactionSheet(transaction: transaction),
      ),
    );
  }

  String _formatKrwFull(double amount) {
    return '${_formatKrwWithComma(amount)}원';
  }

  String _getTypeLabel(HoldingTransaction transaction) {
    return transaction.isBuy ? '매수' : '매도';
  }

  Color _getTypeColor(HoldingTransaction transaction) {
    return transaction.isBuy ? AppColors.buyAction : AppColors.sellAction;
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

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
