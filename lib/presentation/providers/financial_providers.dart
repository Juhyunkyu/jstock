import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/financial_data.dart';
import '../../data/services/api/financial_service.dart';

/// FinancialService 싱글톤
final financialServiceProvider = Provider<FinancialService>((ref) {
  return FinancialService();
});

/// 종목별 재무 데이터 (autoDispose + family)
///
/// 재무 탭 진입 시 활성화, 탭 이탈 시 자동 해제
/// 서비스 내부 메모리 캐시(30분)가 있으므로 재진입 시 빠르게 반환
final financialDataProvider = FutureProvider.autoDispose
    .family<FinancialData, String>((ref, symbol) async {
  final service = ref.read(financialServiceProvider);
  return service.getFinancialData(symbol);
});
