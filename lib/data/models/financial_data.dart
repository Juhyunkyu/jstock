/// 재무제표 데이터 모델
///
/// FMP + Finnhub API 응답을 파싱하는 immutable 모델 클래스.
/// Hive 미사용 — API 전용 모델 (adapter/typeId 불필요).

/// 기업 프로필 (FMP /profile 응답)
class CompanyProfile {
  final String symbol;
  final String companyName;
  final String? sector;
  final String? industry;
  final String? ceo;
  final double? mktCap;
  final String? fullTimeEmployees;
  final String? ipoDate;
  final String? image;
  final String? description;
  final double? beta;
  final String? exchange;
  final bool isEtf;

  const CompanyProfile({
    required this.symbol,
    required this.companyName,
    this.sector,
    this.industry,
    this.ceo,
    this.mktCap,
    this.fullTimeEmployees,
    this.ipoDate,
    this.image,
    this.description,
    this.beta,
    this.exchange,
    this.isEtf = false,
  });

  /// FMP /profile 응답에서 생성
  /// FMP는 배열 [{ ... }]로 응답하므로, 호출측에서 첫 번째 요소를 전달해야 함
  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    return CompanyProfile(
      symbol: json['symbol'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      sector: json['sector'] as String?,
      industry: json['industry'] as String?,
      ceo: json['ceo'] as String?,
      mktCap: (json['mktCap'] as num?)?.toDouble(),
      fullTimeEmployees: json['fullTimeEmployees']?.toString(),
      ipoDate: json['ipoDate'] as String?,
      image: json['image'] as String?,
      description: json['description'] as String?,
      beta: (json['beta'] as num?)?.toDouble(),
      exchange: json['exchange'] as String?,
      isEtf: json['isEtf'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'CompanyProfile(symbol: $symbol, companyName: $companyName, sector: $sector)';
}

/// 핵심 투자 지표 (Finnhub /stock/metric 응답)
class FinancialMetrics {
  final double? peRatio;
  final double? pbRatio;
  final double? roe;
  final double? roa;
  final double? dividendYield;
  final double? debtToEquity;
  final double? operatingMargin;
  final double? netMargin;
  final double? grossMargin;
  final double? currentRatio;
  final double? eps;
  final double? week52High;
  final double? week52Low;
  final double? beta;

  const FinancialMetrics({
    this.peRatio,
    this.pbRatio,
    this.roe,
    this.roa,
    this.dividendYield,
    this.debtToEquity,
    this.operatingMargin,
    this.netMargin,
    this.grossMargin,
    this.currentRatio,
    this.eps,
    this.week52High,
    this.week52Low,
    this.beta,
  });

  /// Finnhub /stock/metric 응답에서 생성
  /// JSON 구조: { "metric": { "peTTM": 30.5, ... }, "metricType": "all" }
  factory FinancialMetrics.fromFinnhubJson(Map<String, dynamic> json) {
    final metric = json['metric'] as Map<String, dynamic>? ?? {};
    return FinancialMetrics(
      peRatio: (metric['peTTM'] as num?)?.toDouble(),
      pbRatio: (metric['pbQuarterly'] as num?)?.toDouble(),
      roe: (metric['roeTTM'] as num?)?.toDouble(),
      roa: (metric['roaTTM'] as num?)?.toDouble(),
      dividendYield:
          (metric['dividendYieldIndicatedAnnual'] as num?)?.toDouble(),
      debtToEquity: (metric['totalDebtToEquity'] as num?)?.toDouble(),
      operatingMargin: (metric['operatingMarginTTM'] as num?)?.toDouble(),
      netMargin: (metric['netProfitMarginTTM'] as num?)?.toDouble(),
      grossMargin: (metric['grossMarginTTM'] as num?)?.toDouble(),
      currentRatio: (metric['currentRatioQuarterly'] as num?)?.toDouble(),
      eps: (metric['epsBasicExclExtraItemsTTM'] as num?)?.toDouble(),
      week52High: (metric['52WeekHigh'] as num?)?.toDouble(),
      week52Low: (metric['52WeekLow'] as num?)?.toDouble(),
      beta: (metric['beta'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() =>
      'FinancialMetrics(PE: $peRatio, PB: $pbRatio, ROE: $roe)';
}

/// 손익계산서 (FMP /income-statement 응답)
class IncomeStatement {
  final String date;
  final String? calendarYear;
  final String? period;
  final double revenue;
  final double grossProfit;
  final double operatingIncome;
  final double netIncome;
  final double? eps;
  final double? operatingIncomeRatio;
  final double? netIncomeRatio;

  const IncomeStatement({
    required this.date,
    this.calendarYear,
    this.period,
    required this.revenue,
    required this.grossProfit,
    required this.operatingIncome,
    required this.netIncome,
    this.eps,
    this.operatingIncomeRatio,
    this.netIncomeRatio,
  });

  /// FMP /income-statement 응답에서 생성
  /// FMP는 배열 [{ ... }, { ... }]로 응답하므로 List.map으로 변환
  factory IncomeStatement.fromJson(Map<String, dynamic> json) {
    return IncomeStatement(
      date: json['date'] as String? ?? '',
      calendarYear: json['calendarYear'] as String?,
      period: json['period'] as String?,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      grossProfit: (json['grossProfit'] as num?)?.toDouble() ?? 0,
      operatingIncome: (json['operatingIncome'] as num?)?.toDouble() ?? 0,
      netIncome: (json['netIncome'] as num?)?.toDouble() ?? 0,
      eps: (json['epsdiluted'] as num?)?.toDouble(),
      operatingIncomeRatio:
          (json['operatingIncomeRatio'] as num?)?.toDouble(),
      netIncomeRatio: (json['netIncomeRatio'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() =>
      'IncomeStatement(date: $date, period: $period, revenue: $revenue)';
}

/// EPS 실적 (Finnhub /stock/earnings 응답)
class EarningsResult {
  final double? actual;
  final double? estimate;
  final String? period;
  final int? quarter;
  final int? year;
  final double? surprise;
  final double? surprisePercent;

  const EarningsResult({
    this.actual,
    this.estimate,
    this.period,
    this.quarter,
    this.year,
    this.surprise,
    this.surprisePercent,
  });

  /// 실제 EPS가 예상치 이상인지 여부
  bool get isBeat =>
      actual != null && estimate != null && actual! >= estimate!;

  /// Finnhub /stock/earnings 응답에서 생성
  /// JSON 구조: [{ "actual": 1.52, "estimate": 1.43, ... }]
  factory EarningsResult.fromJson(Map<String, dynamic> json) {
    return EarningsResult(
      actual: (json['actual'] as num?)?.toDouble(),
      estimate: (json['estimate'] as num?)?.toDouble(),
      period: json['period'] as String?,
      quarter: (json['quarter'] as num?)?.toInt(),
      year: (json['year'] as num?)?.toInt(),
      surprise: (json['surprise'] as num?)?.toDouble(),
      surprisePercent: (json['surprisePercent'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() =>
      'EarningsResult(period: $period, actual: $actual, estimate: $estimate, beat: $isBeat)';
}

/// 재무 데이터 통합 모델
///
/// 여러 API 소스의 재무 데이터를 하나로 묶어 UI에 전달한다.
class FinancialData {
  final CompanyProfile? profile;
  final FinancialMetrics? metrics;
  final List<IncomeStatement> annualStatements;
  final List<IncomeStatement> quarterlyStatements;
  final List<EarningsResult> earnings;

  const FinancialData({
    this.profile,
    this.metrics,
    this.annualStatements = const [],
    this.quarterlyStatements = const [],
    this.earnings = const [],
  });

  /// 데이터가 비어있는지 확인
  bool get isEmpty =>
      profile == null &&
      metrics == null &&
      annualStatements.isEmpty &&
      quarterlyStatements.isEmpty &&
      earnings.isEmpty;

  @override
  String toString() =>
      'FinancialData(profile: ${profile?.symbol}, '
      'metrics: ${metrics != null}, '
      'annual: ${annualStatements.length}, '
      'quarterly: ${quarterlyStatements.length}, '
      'earnings: ${earnings.length})';
}
