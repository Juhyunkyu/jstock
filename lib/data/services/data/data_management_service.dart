import '../../models/cycle.dart';
import '../../models/trade.dart';
import '../../models/watchlist_item.dart';
import '../../models/watchlist_group.dart';
import '../../models/recent_view_item.dart';
import '../../models/holding.dart';
import '../../models/holding_transaction.dart';
import '../../models/notification_record.dart';
import '../../models/settings.dart';
import '../../repositories/cycle_repository.dart';
import '../../repositories/trade_repository.dart';
import '../../repositories/watchlist_repository.dart';
import '../../repositories/watchlist_group_repository.dart';
import '../../repositories/recent_view_repository.dart';
import '../../repositories/holding_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/memo_repository.dart';
import '../../repositories/chart_drawing_repository.dart';
import '../../models/memo.dart';
import '../../models/chart_drawing.dart';

/// 데이터 백업/복원/내보내기/초기화 서비스
class DataManagementService {
  final WatchlistRepository watchlistRepository;
  final HoldingRepository holdingRepository;
  final NotificationRepository notificationRepository;
  final SettingsRepository settingsRepository;
  final CycleRepository cycleRepository;
  final TradeRepository tradeRepository;
  final WatchlistGroupRepository watchlistGroupRepository;
  final RecentViewRepository recentViewRepository;
  final MemoRepository memoRepository;
  final ChartDrawingRepository chartDrawingRepository;

  DataManagementService({
    required this.watchlistRepository,
    required this.holdingRepository,
    required this.notificationRepository,
    required this.settingsRepository,
    required this.cycleRepository,
    required this.tradeRepository,
    required this.watchlistGroupRepository,
    required this.recentViewRepository,
    required this.memoRepository,
    required this.chartDrawingRepository,
  });

  /// 전체 데이터를 JSON Map으로 백업
  Map<String, dynamic> createBackup() {
    return {
      'version': 8,
      'createdAt': DateTime.now().toIso8601String(),
      'data': {
        'settings': settingsRepository.settings.toJson(),
        'watchlist': watchlistRepository.getAll().map((w) => w.toJson()).toList(),
        'holdings': holdingRepository.getAll().map((h) => h.toJson()).toList(),
        'holdingTransactions': holdingRepository.getAllTransactions().map((t) => t.toJson()).toList(),
        'notifications': notificationRepository.getAll().map((n) => n.toJson()).toList(),
        'cycles': cycleRepository.getAll().map((c) => c.toJson()).toList(),
        'trades': tradeRepository.getAll().map((t) => t.toJson()).toList(),
        'watchlistGroups': watchlistGroupRepository.getAll().map((g) => g.toJson()).toList(),
        'recentViews': recentViewRepository.getAll().map((r) => r.toJson()).toList(),
        'memos': memoRepository.getAll().map((m) => m.toJson()).toList(),
        'chartDrawings': chartDrawingRepository.getAll().map((d) => d.toJson()).toList(),
      },
    };
  }

  /// JSON Map에서 데이터 복원 (기존 데이터 전체 삭제 후 삽입)
  Future<void> restoreFromBackup(Map<String, dynamic> backup) async {
    final version = backup['version'] as int? ?? 1;
    if (version > 8) {
      throw FormatException('지원하지 않는 백업 버전: $version');
    }

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

    // 3. Watchlist 복원
    if (data['watchlist'] != null) {
      for (final json in (data['watchlist'] as List)) {
        final item = WatchlistItem.fromJson(json as Map<String, dynamic>);
        await watchlistRepository.update(item);
      }
    }

    // 4. Holdings 복원
    if (data['holdings'] != null) {
      for (final json in (data['holdings'] as List)) {
        final holding = Holding.fromJson(json as Map<String, dynamic>);
        await holdingRepository.save(holding);
      }
    }

    // 5. Holding Transactions 복원
    if (data['holdingTransactions'] != null) {
      for (final json in (data['holdingTransactions'] as List)) {
        final transaction = HoldingTransaction.fromJson(json as Map<String, dynamic>);
        await holdingRepository.saveTransaction(transaction);
      }
    }

    // 6. Notifications 복원
    if (data['notifications'] != null) {
      for (final json in (data['notifications'] as List)) {
        final notification = NotificationRecord.fromJson(json as Map<String, dynamic>);
        await notificationRepository.add(notification);
      }
    }

    // 7. Cycles 복원
    if (data['cycles'] != null) {
      for (final json in (data['cycles'] as List)) {
        final cycle = Cycle.fromJson(json as Map<String, dynamic>);
        await cycleRepository.save(cycle);
      }
    }

    // 8. Trades 복원
    if (data['trades'] != null) {
      for (final json in (data['trades'] as List)) {
        final trade = Trade.fromJson(json as Map<String, dynamic>);
        await tradeRepository.save(trade);
      }
    }

    // 9. Watchlist Groups 복원 (v3+)
    if (data['watchlistGroups'] != null) {
      for (final json in (data['watchlistGroups'] as List)) {
        final group = WatchlistGroup.fromJson(json as Map<String, dynamic>);
        await watchlistGroupRepository.save(group);
      }
    }

    // 10. Recent Views 복원 (v3+)
    if (data['recentViews'] != null) {
      for (final json in (data['recentViews'] as List)) {
        final item = RecentViewItem.fromJson(json as Map<String, dynamic>);
        await recentViewRepository.recordView(item);
      }
    }

    // 11. Memos 복원 (v5+)
    if (data['memos'] != null) {
      for (final json in (data['memos'] as List)) {
        final memo = Memo.fromJson(json as Map<String, dynamic>);
        await memoRepository.save(memo);
      }
    }

    // 12. Chart Drawings 복원 (v8+)
    if (data['chartDrawings'] != null) {
      for (final json in (data['chartDrawings'] as List)) {
        final drawing = ChartDrawing.fromJson(json as Map<String, dynamic>);
        await chartDrawingRepository.add(drawing);
      }
    }
  }

  /// 거래내역을 CSV 문자열로 내보내기
  String exportToCsv() {
    final buffer = StringBuffer();
    buffer.write('\uFEFF'); // BOM (Excel 한글 호환)

    // ── 사이클 거래내역 (사이클별 블록) ──
    final allCycles = cycleRepository.getAll();
    // 진행중 먼저 → 완료. 각 그룹 내 최근 먼저
    allCycles.sort((a, b) {
      final ao = a.status == CycleStatus.active ? 0 : 1;
      final bo = b.status == CycleStatus.active ? 0 : 1;
      if (ao != bo) return ao.compareTo(bo);
      return b.startDate.compareTo(a.startDate);
    });

    if (allCycles.isNotEmpty) {
      buffer.writeln('[사이클 거래내역]');
      for (final cycle in allCycles) {
        buffer.writeln();
        _writeCycleBlock(buffer, cycle);
      }
    }

    // ── 일반 보유 거래내역 (종목별 블록) ──
    final allHoldings = holdingRepository.getAll();
    if (allHoldings.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('[일반 보유 거래내역]');
      for (final holding in allHoldings) {
        buffer.writeln();
        _writeHoldingBlock(buffer, holding);
      }
    }

    return buffer.toString();
  }

  void _writeCycleBlock(StringBuffer buffer, Cycle cycle) {
    final strategy = _strategyLabel(cycle.strategyType);
    final status = cycle.status == CycleStatus.completed ? '완료' : '진행중';
    final startStr = _formatCsvDate(cycle.firstTradeDate ?? cycle.startDate);
    final endStr = cycle.status == CycleStatus.completed && cycle.lastTradeDate != null
        ? ' ~ ${_formatCsvDate(cycle.lastTradeDate!)}'
        : ' ~';

    // 구분선
    buffer.writeln('--- ${cycle.ticker} ($strategy) | $status | $startStr$endStr ---');

    // 요약
    if (cycle.status == CycleStatus.completed) {
      final profit = cycle.realizedProfitKrw;
      final rate = cycle.realizedProfitRate;
      final sign = profit >= 0 ? '+' : '';
      buffer.writeln(
        '"시드: ${_w(cycle.seedAmount)}",'
        '"총매수: ${_w(cycle.totalBuyAmountKrw)}",'
        '"총매도: ${_w(cycle.totalSellAmountKrw)}",'
        '"실현손익: ${_w(profit)} ($sign${rate.toStringAsFixed(1)}%)"',
      );
    } else {
      buffer.writeln(
        '"시드: ${_w(cycle.seedAmount)}",'
        '"총매수: ${_w(cycle.totalBuyAmountKrw)}",'
        '"잔여현금: ${_w(cycle.remainingCash)}",'
        '"보유: ${cycle.totalShares.toStringAsFixed(4)}주 @ \$${cycle.averagePrice.toStringAsFixed(2)}"',
      );
    }
    if (cycle.isExchangeSettled && cycle.settledExchangeRate > 0) {
      buffer.writeln('"환전확정: ${_w(cycle.settledExchangeRate)}"');
    }

    // 거래 테이블
    final trades = tradeRepository.getByCycleId(cycle.id);
    if (trades.isEmpty) {
      buffer.writeln('(거래 내역 없음)');
      return;
    }
    trades.sort((a, b) => a.tradedAt.compareTo(b.tradedAt));
    buffer.writeln('날짜,매매,신호,단가(USD),수량,원화금액,환율,메모');
    for (final t in trades) {
      buffer.writeln(
        '${_formatCsvDate(t.tradedAt)},'
        '${t.action == TradeAction.buy ? "매수" : "매도"},'
        '${_signalLabel(t.signal)},'
        '\$${t.price.toStringAsFixed(2)},'
        '${t.shares.toStringAsFixed(4)},'
        '"${_fmtNum(t.amountKrw)}",'
        '"${_fmtNum(t.exchangeRate)}",'
        '${_escapeCsv(t.memo ?? "")}',
      );
    }
  }

  void _writeHoldingBlock(StringBuffer buffer, Holding holding) {
    final status = holding.isArchivedItem ? '아카이브' : '보유중';
    buffer.writeln('--- ${holding.ticker} (${holding.name}) | $status ---');

    if (holding.totalShares > 0) {
      buffer.writeln(
        '"보유: ${holding.totalShares.toStringAsFixed(4)}주 @ \$${holding.averagePrice.toStringAsFixed(2)}",'
        '"투자금: ${_w(holding.totalInvestedAmount)}",'
        '"매입환율: ${_w(holding.exchangeRate)}"',
      );
    } else {
      buffer.writeln('"전량 매도"');
    }
    if (holding.isExchangeSettled && holding.settledExchangeRate > 0) {
      buffer.writeln('"환전확정: ${_w(holding.settledExchangeRate)}"');
    }

    final txns = holdingRepository.getTransactionsByHoldingId(holding.id);
    if (txns.isEmpty) {
      buffer.writeln('(거래 내역 없음)');
      return;
    }
    txns.sort((a, b) => a.date.compareTo(b.date));
    buffer.writeln('날짜,매매,단가(USD),수량,원화금액,환율,실현손익,메모');
    for (final t in txns) {
      buffer.writeln(
        '${_formatCsvDate(t.date)},'
        '${t.isBuy ? "매수" : "매도"},'
        '\$${t.price.toStringAsFixed(2)},'
        '${t.shares.toStringAsFixed(4)},'
        '"${_fmtNum(t.amountKrw)}",'
        '"${_fmtNum(t.exchangeRate)}",'
        '${t.realizedPnlKrw != null ? "\"${_fmtNum(t.realizedPnlKrw!)}\"" : ""},'
        '${_escapeCsv(t.note ?? "")}',
      );
    }
  }

  /// 원화 포맷 헬퍼: ₩1,234,567
  static String _w(double v) => '₩${_fmtNum(v)}';

  static String _strategyLabel(StrategyType? type) {
    return switch (type) {
      StrategyType.alphaCycleV3 => 'Smart',
      StrategyType.infiniteBuy => 'Steady',
      StrategyType.ladderCycle => 'Ladder',
      null => '',
    };
  }

  static String _signalLabel(TradeSignal signal) {
    return switch (signal) {
      // Smart Cycle
      TradeSignal.initial => '초기진입',
      TradeSignal.weightedBuy => '가중매수',
      TradeSignal.panicBuy => '승부수',
      TradeSignal.cashSecure => '현금확보',
      TradeSignal.takeProfit => '익절',
      // Steady Cycle
      TradeSignal.locA => 'LOC-A 매수',
      TradeSignal.locB => 'LOC-B 매수',
      TradeSignal.locAB => 'LOC-AB 매수',
      TradeSignal.buySingle => '1회분 매수',
      TradeSignal.sellLocQuarter => 'LOC 1/4 매도',
      TradeSignal.sellLimitThreeQ => '지정가 3/4 매도',
      TradeSignal.takeProfitFull => '전량 익절',
      TradeSignal.noFill => '미체결',
      // Ladder Cycle
      TradeSignal.ladderStep1 => '1단계 매수',
      TradeSignal.ladderStep2 => '2단계 매수',
      TradeSignal.ladderStep3 => '3단계 매수',
      TradeSignal.ladderStep4 => '4단계 매수',
      TradeSignal.ladderStep5 => '5단계 매수',
      TradeSignal.ladderStep6 => '6단계 매수',
      // 공통
      TradeSignal.manual => '수동',
      TradeSignal.hold => '보유',
    };
  }

  /// 숫자를 쉼표 포맷으로 변환. CSV에서는 "로 감싸서 사용.
  static String _fmtNum(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buf = StringBuffer();
    if (intVal < 0) buf.write('-');
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  /// 모든 데이터 초기화
  Future<void> resetAllData() async {
    await Future.wait([
      watchlistRepository.clear(),
      holdingRepository.clearAll(),
      notificationRepository.clear(),
      settingsRepository.reset(),
      cycleRepository.clearAll(),
      tradeRepository.clearAll(),
      watchlistGroupRepository.clear(),
      recentViewRepository.clear(),
      memoRepository.clear(),
      chartDrawingRepository.clearAll(),
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
