import '../../models/cycle.dart';
import '../../models/trade.dart';
import '../../models/watchlist_item.dart';
import '../../models/holding.dart';
import '../../models/holding_transaction.dart';
import '../../models/notification_record.dart';
import '../../models/settings.dart';
import '../../repositories/cycle_repository.dart';
import '../../repositories/trade_repository.dart';
import '../../repositories/watchlist_repository.dart';
import '../../repositories/holding_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/settings_repository.dart';

/// 데이터 백업/복원/내보내기/초기화 서비스
class DataManagementService {
  final CycleRepository cycleRepository;
  final TradeRepository tradeRepository;
  final WatchlistRepository watchlistRepository;
  final HoldingRepository holdingRepository;
  final NotificationRepository notificationRepository;
  final SettingsRepository settingsRepository;

  DataManagementService({
    required this.cycleRepository,
    required this.tradeRepository,
    required this.watchlistRepository,
    required this.holdingRepository,
    required this.notificationRepository,
    required this.settingsRepository,
  });

  /// 전체 데이터를 JSON Map으로 백업
  Map<String, dynamic> createBackup() {
    return {
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'data': {
        'settings': settingsRepository.settings.toJson(),
        'cycles': cycleRepository.getAll().map((c) => c.toJson()).toList(),
        'trades': tradeRepository.getAll().map((t) => t.toJson()).toList(),
        'watchlist': watchlistRepository.getAll().map((w) => w.toJson()).toList(),
        'holdings': holdingRepository.getAll().map((h) => h.toJson()).toList(),
        'holdingTransactions': holdingRepository.getAllTransactions().map((t) => t.toJson()).toList(),
        'notifications': notificationRepository.getAll().map((n) => n.toJson()).toList(),
      },
    };
  }

  /// JSON Map에서 데이터 복원 (기존 데이터 전체 삭제 후 삽입)
  Future<void> restoreFromBackup(Map<String, dynamic> backup) async {
    final data = backup['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw FormatException('백업 파일 형식이 올바르지 않습니다');
    }

    // 1. 기존 데이터 전체 삭제
    await resetAllData();

    // 2. Settings 복원
    if (data['settings'] != null) {
      final settings = Settings.fromJson(data['settings'] as Map<String, dynamic>);
      await settingsRepository.save(settings);
    }

    // 3. Cycles 복원
    if (data['cycles'] != null) {
      for (final json in (data['cycles'] as List)) {
        final cycle = Cycle.fromJson(json as Map<String, dynamic>);
        await cycleRepository.save(cycle);
      }
    }

    // 4. Trades 복원
    if (data['trades'] != null) {
      for (final json in (data['trades'] as List)) {
        final trade = Trade.fromJson(json as Map<String, dynamic>);
        await tradeRepository.save(trade);
      }
    }

    // 5. Watchlist 복원
    if (data['watchlist'] != null) {
      for (final json in (data['watchlist'] as List)) {
        final item = WatchlistItem.fromJson(json as Map<String, dynamic>);
        await watchlistRepository.update(item);
      }
    }

    // 6. Holdings 복원
    if (data['holdings'] != null) {
      for (final json in (data['holdings'] as List)) {
        final holding = Holding.fromJson(json as Map<String, dynamic>);
        await holdingRepository.save(holding);
      }
    }

    // 7. Holding Transactions 복원
    if (data['holdingTransactions'] != null) {
      for (final json in (data['holdingTransactions'] as List)) {
        final transaction = HoldingTransaction.fromJson(json as Map<String, dynamic>);
        await holdingRepository.saveTransaction(transaction);
      }
    }

    // 8. Notifications 복원
    if (data['notifications'] != null) {
      for (final json in (data['notifications'] as List)) {
        final notification = NotificationRecord.fromJson(json as Map<String, dynamic>);
        await notificationRepository.add(notification);
      }
    }
  }

  /// 거래내역을 CSV 문자열로 내보내기
  String exportToCsv() {
    final buffer = StringBuffer();

    // BOM (Excel 한글 호환)
    buffer.write('\uFEFF');

    // 알파 사이클 거래내역
    buffer.writeln('=== 알파 사이클 거래내역 ===');
    buffer.writeln('날짜,종목,사이클#,거래유형,단가(USD),수량,권장금액(KRW),실투자금액(KRW),체결여부,손실률(%),수익률(%),메모');

    final trades = tradeRepository.getAll();
    final cycles = {for (final c in cycleRepository.getAll()) c.id: c};

    for (final trade in trades) {
      final cycle = cycles[trade.cycleId];
      final cycleNum = cycle?.cycleNumber ?? 0;
      buffer.writeln(
        '${_formatCsvDate(trade.date)},'
        '${trade.ticker},'
        '$cycleNum,'
        '${trade.actionDisplayName},'
        '${trade.price.toStringAsFixed(2)},'
        '${trade.shares.toStringAsFixed(4)},'
        '${trade.recommendedAmount.toStringAsFixed(0)},'
        '${trade.actualAmount?.toStringAsFixed(0) ?? ""},'
        '${trade.isExecuted ? "Y" : "N"},'
        '${trade.lossRate.toStringAsFixed(2)},'
        '${trade.returnRate.toStringAsFixed(2)},'
        '${_escapeCsv(trade.note ?? "")}',
      );
    }

    // 일반 보유 거래내역
    buffer.writeln();
    buffer.writeln('=== 일반 보유 거래내역 ===');
    buffer.writeln('날짜,종목,거래유형,단가(USD),수량,금액(KRW),환율,실현손익(KRW),메모');

    final holdingTxns = holdingRepository.getAllTransactions();
    for (final txn in holdingTxns) {
      buffer.writeln(
        '${_formatCsvDate(txn.date)},'
        '${txn.ticker},'
        '${txn.isBuy ? "매수" : "매도"},'
        '${txn.price.toStringAsFixed(2)},'
        '${txn.shares.toStringAsFixed(4)},'
        '${txn.amountKrw.toStringAsFixed(0)},'
        '${txn.exchangeRate.toStringAsFixed(2)},'
        '${txn.realizedPnlKrw?.toStringAsFixed(0) ?? ""},'
        '${_escapeCsv(txn.note ?? "")}',
      );
    }

    return buffer.toString();
  }

  /// 모든 데이터 초기화
  Future<void> resetAllData() async {
    await Future.wait([
      cycleRepository.clearAll(),
      tradeRepository.clearAll(),
      watchlistRepository.clear(),
      holdingRepository.clearAll(),
      notificationRepository.clear(),
      settingsRepository.reset(),
    ]);
  }

  String _formatCsvDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
