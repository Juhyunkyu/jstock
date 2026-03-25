"""
Smart Cycle (v7.0) vs Steady Cycle Backtest
============================================
Strategy A: Smart Cycle (Alpha Cycle V3 v7.0) — 수정된 가중매수 공식
Strategy B: Steady Cycle (순정 무한매수법 V2.1) — 40분할 LOC

Data: TQQQ & SOXL 2025-01-02 ~ 2026-01-28
Seed: 100,000,000 KRW (1억) | Exchange rate: 1,350 KRW/USD
"""

import csv
from datetime import datetime
from dataclasses import dataclass, field
from typing import List, Tuple, Optional


# ============================================================================
# Data Loading
# ============================================================================

def load_csv(path: str, start_date: str = '2025-01-01', end_date: str = '2026-02-01') -> List[dict]:
    rows = []
    with open(path, 'r') as f:
        reader = csv.DictReader(f)
        for r in reader:
            d = r['Date'][:10]
            if start_date <= d <= end_date:
                rows.append({
                    'date': d,
                    'open': float(r['Open']),
                    'high': float(r['High']),
                    'low': float(r['Low']),
                    'close': float(r['Close']),
                    'volume': int(float(r['Volume'])),
                })
    rows.sort(key=lambda x: x['date'])
    return rows


# ============================================================================
# Strategy A: Smart Cycle (Alpha Cycle V3 v7.0)
# ============================================================================

@dataclass
class TradeLog:
    day: int
    date: str
    action: str
    amount_krw: float
    shares: float
    price: float
    loss_rate: float
    return_rate: float
    cash_after: float
    total_value: float
    note: str = ""


@dataclass
class SmartCycleResult:
    total_return_pct: float = 0.0
    cycles_completed: int = 0
    mdd_pct: float = 0.0
    cash_remaining: float = 0.0
    total_trades: int = 0
    final_value: float = 0.0
    trades: List[TradeLog] = field(default_factory=list)
    monthly_values: dict = field(default_factory=dict)


def run_smart_cycle(data: List[dict], seed: float, exchange_rate: float) -> SmartCycleResult:
    """
    Smart Cycle v7.0:
    - Initial entry: seed × 20%
    - Weighted buy: lossRate <= -20% → |lossRate| × weightedBuyPerPercent
      - weightedBuyPerPercent = seed × 0.00007 (7,000원 for 1억)
    - Panic buy: lossRate <= -50% → evaluatedAmount × 50% (1회)
    - Take profit: 전량 매도, 목표 = max(10, 30 - consecutiveCount × 5)%
    - Cash secure: returnRate >= 0% AND cash < totalAssets/3 → 부분 매도
    - Priority: takeProfit > cashSecure > panicBuy > weightedBuy > hold
    """
    cash = seed
    shares = 0.0
    avg_price = 0.0
    entry_price = 0.0
    initial_entry_ratio = 0.20
    initial_entry_amount = seed * initial_entry_ratio
    per_percent_amount = seed * 0.00007  # v7.0: 1억 → 7,000원/1%
    weighted_buy_threshold = -20.0
    panic_threshold = -50.0
    panic_multiplier = 0.50
    panic_used = False
    first_buy_done = False
    cycle_num = 0
    consecutive_profit_count = 0
    total_trades = 0
    trades = []
    monthly_values = {}

    peak_value = seed
    max_drawdown = 0.0

    for day_idx, row in enumerate(data):
        price = row['close']
        date = row['date']
        month_key = date[:7]

        holdings_krw = shares * price * exchange_rate
        total_value = cash + holdings_krw

        # MDD
        if total_value > peak_value:
            peak_value = total_value
        dd = (peak_value - total_value) / peak_value * 100
        if dd > max_drawdown:
            max_drawdown = dd

        # Monthly snapshot (last day of month)
        monthly_values[month_key] = {
            'value': total_value,
            'cash': cash,
            'shares': shares,
            'price': price,
            'return_pct': (total_value - seed) / seed * 100,
        }

        # Initial entry
        if not first_buy_done:
            buy_amount = min(initial_entry_amount, cash)
            if buy_amount > 0:
                shares_to_buy = (buy_amount / exchange_rate) / price
                shares = shares_to_buy
                avg_price = price
                entry_price = price
                cash -= buy_amount
                total_trades += 1
                trades.append(TradeLog(
                    day=day_idx, date=date, action="초기진입",
                    amount_krw=buy_amount, shares=shares_to_buy, price=price,
                    loss_rate=0, return_rate=0, cash_after=cash,
                    total_value=cash + shares * price * exchange_rate,
                    note=f"시드 {seed/10000:.0f}만 × {initial_entry_ratio:.0%}"
                ))
                first_buy_done = True
            continue

        loss_rate = ((price - entry_price) / entry_price) * 100 if entry_price > 0 else 0
        return_rate = ((price - avg_price) / avg_price) * 100 if avg_price > 0 and shares > 0 else 0
        holdings_krw = shares * price * exchange_rate
        total_value = cash + holdings_krw

        # [1] Take Profit — 전량 매도 (v7.0 원본 전략)
        sell_target = max(10, 30 - consecutive_profit_count * 5)
        if return_rate >= sell_target and shares > 0:
            sell_value = shares * price * exchange_rate
            cash += sell_value
            total_trades += 1
            trades.append(TradeLog(
                day=day_idx, date=date, action="익절(전량)",
                amount_krw=sell_value, shares=shares, price=price,
                loss_rate=loss_rate, return_rate=return_rate, cash_after=cash,
                total_value=cash,
                note=f"목표 {sell_target}% | 연속 #{consecutive_profit_count+1}"
            ))
            consecutive_profit_count += 1
            cycle_num += 1

            # New cycle
            new_seed = cash
            initial_entry_amount = new_seed * initial_entry_ratio
            per_percent_amount = new_seed * 0.00007
            shares = 0.0
            avg_price = 0.0
            entry_price = 0.0
            panic_used = False
            first_buy_done = False
            continue

        # consecutiveCount reset: 사이클 수동 종료 시에만 리셋 (원본 전략)
        # 현재 백테스트에서는 익절이 유일한 사이클 종료이므로 리셋 없음

        # [2] Cash Secure
        if return_rate >= 0 and shares > 0:
            total_assets = cash + shares * price * exchange_rate
            if cash < total_assets / 3:
                needed = total_assets / 3 - cash
                shares_to_sell = min(needed / (price * exchange_rate), shares)
                if shares_to_sell > 0:
                    sell_value = shares_to_sell * price * exchange_rate
                    cash += sell_value
                    shares -= shares_to_sell
                    total_trades += 1
                    trades.append(TradeLog(
                        day=day_idx, date=date, action="현금확보",
                        amount_krw=sell_value, shares=shares_to_sell, price=price,
                        loss_rate=loss_rate, return_rate=return_rate, cash_after=cash,
                        total_value=cash + shares * price * exchange_rate,
                        note=f"현금비율 → 33%"
                    ))
            continue

        # [3] Panic Buy
        if loss_rate <= panic_threshold and not panic_used:
            evaluated = shares * price * exchange_rate
            panic_amount = min(evaluated * panic_multiplier, cash)
            if panic_amount > 0:
                shares_to_buy = (panic_amount / exchange_rate) / price
                total_cost = shares * avg_price + shares_to_buy * price
                shares += shares_to_buy
                avg_price = total_cost / shares if shares > 0 else price
                cash -= panic_amount
                total_trades += 1
                trades.append(TradeLog(
                    day=day_idx, date=date, action="승부수",
                    amount_krw=panic_amount, shares=shares_to_buy, price=price,
                    loss_rate=loss_rate, return_rate=return_rate, cash_after=cash,
                    total_value=cash + shares * price * exchange_rate,
                    note=f"평가금액 {evaluated/10000:.0f}만 × 50%"
                ))
                panic_used = True
            # Fall through to weighted buy

        # [4] Weighted Buy — v7.0 수정된 공식
        if loss_rate <= weighted_buy_threshold and cash > 0:
            buy_amount = abs(loss_rate) * per_percent_amount  # v7.0!
            buy_amount = min(buy_amount, cash)
            if buy_amount > 0:
                shares_to_buy = (buy_amount / exchange_rate) / price
                total_cost = shares * avg_price + shares_to_buy * price
                shares += shares_to_buy
                avg_price = total_cost / shares if shares > 0 else price
                cash -= buy_amount
                total_trades += 1
                trades.append(TradeLog(
                    day=day_idx, date=date, action="가중매수",
                    amount_krw=buy_amount, shares=shares_to_buy, price=price,
                    loss_rate=loss_rate, return_rate=return_rate, cash_after=cash,
                    total_value=cash + shares * price * exchange_rate,
                    note=f"|{loss_rate:.1f}%| × {per_percent_amount:,.0f}원"
                ))

    # Final
    final_price = data[-1]['close']
    holdings_krw = shares * final_price * exchange_rate
    final_value = cash + holdings_krw
    total_return = ((final_value - seed) / seed) * 100

    return SmartCycleResult(
        total_return_pct=total_return,
        cycles_completed=cycle_num,
        mdd_pct=max_drawdown,
        cash_remaining=cash,
        total_trades=total_trades,
        final_value=final_value,
        trades=trades,
        monthly_values=monthly_values,
    )


# ============================================================================
# Strategy B: Steady Cycle (순정 무한매수법 V2.1)
# ============================================================================

@dataclass
class SteadyCycleResult:
    total_return_pct: float = 0.0
    cycles_completed: int = 0
    mdd_pct: float = 0.0
    cash_remaining: float = 0.0
    total_trades: int = 0
    final_value: float = 0.0
    trades: List[TradeLog] = field(default_factory=list)
    monthly_values: dict = field(default_factory=dict)


def run_steady_cycle(data: List[dict], seed: float, exchange_rate: float) -> SteadyCycleResult:
    """
    Steady Cycle (순정 무한매수법 V2.1):
    - 40분할 매수
    - close <= avg_price: A+B 둘 다 체결 (1.0 unit)
    - close > avg_price: B만 체결 (0.5 unit)
    - 익절: returnRate >= +10% → 전량 매도 → 새 사이클
    """
    cash = seed
    shares = 0.0
    avg_price = 0.0
    current_seed = seed
    total_rounds = 40
    rounds_used = 0.0
    unit_amount = seed / total_rounds
    cycle_num = 0
    total_trades = 0
    first_buy_done = False
    trades = []
    monthly_values = {}

    peak_value = seed
    max_drawdown = 0.0

    for day_idx, row in enumerate(data):
        price = row['close']
        date = row['date']
        month_key = date[:7]

        holdings_krw = shares * price * exchange_rate
        total_value = cash + holdings_krw

        if total_value > peak_value:
            peak_value = total_value
        dd = (peak_value - total_value) / peak_value * 100
        if dd > max_drawdown:
            max_drawdown = dd

        monthly_values[month_key] = {
            'value': total_value,
            'cash': cash,
            'shares': shares,
            'price': price,
            'return_pct': (total_value - seed) / seed * 100,
        }

        # Take profit check
        if shares > 0 and avg_price > 0:
            return_rate = ((price - avg_price) / avg_price) * 100
            if return_rate >= 10.0:
                sell_value = shares * price * exchange_rate
                cash += sell_value
                total_trades += 1
                trades.append(TradeLog(
                    day=day_idx, date=date, action="익절(전량)",
                    amount_krw=sell_value, shares=shares, price=price,
                    loss_rate=0, return_rate=return_rate, cash_after=cash,
                    total_value=cash,
                    note=f"사이클 #{cycle_num+1} 완료 | {rounds_used:.1f}/{total_rounds}회차"
                ))
                cycle_num += 1
                shares = 0.0
                avg_price = 0.0
                current_seed = cash
                rounds_used = 0.0
                unit_amount = current_seed / total_rounds
                first_buy_done = False
                continue

        # Buy logic
        if rounds_used >= total_rounds:
            continue

        if not first_buy_done or shares == 0:
            buy_amount = unit_amount * 1.0
            units_consumed = 1.0
        else:
            if price <= avg_price:
                buy_amount = unit_amount * 1.0
                units_consumed = 1.0
            else:
                buy_amount = unit_amount * 0.5
                units_consumed = 0.5

        if rounds_used + units_consumed > total_rounds:
            remaining = total_rounds - rounds_used
            if remaining <= 0:
                continue
            buy_amount = unit_amount * remaining
            units_consumed = remaining

        buy_amount = min(buy_amount, cash)
        if buy_amount <= 0:
            continue

        shares_to_buy = (buy_amount / exchange_rate) / price
        if shares > 0:
            total_cost = shares * avg_price + shares_to_buy * price
            shares += shares_to_buy
            avg_price = total_cost / shares
        else:
            shares = shares_to_buy
            avg_price = price

        cash -= buy_amount
        rounds_used += units_consumed
        total_trades += 1
        first_buy_done = True

        # Log only significant trades (initial, every 10th, take profit already logged)
        if rounds_used <= 1 or rounds_used % 10 < 1.5:
            trades.append(TradeLog(
                day=day_idx, date=date, action="매수",
                amount_krw=buy_amount, shares=shares_to_buy, price=price,
                loss_rate=0, return_rate=((price - avg_price) / avg_price * 100) if avg_price > 0 else 0,
                cash_after=cash, total_value=cash + shares * price * exchange_rate,
                note=f"회차 {rounds_used:.1f}/{total_rounds}"
            ))

    final_price = data[-1]['close']
    holdings_krw = shares * final_price * exchange_rate
    final_value = cash + holdings_krw
    total_return = ((final_value - seed) / seed) * 100

    return SteadyCycleResult(
        total_return_pct=total_return,
        cycles_completed=cycle_num,
        mdd_pct=max_drawdown,
        cash_remaining=cash,
        total_trades=total_trades,
        final_value=final_value,
        trades=trades,
        monthly_values=monthly_values,
    )


# ============================================================================
# Buy & Hold Baseline
# ============================================================================

def calc_buy_and_hold(data: List[dict], seed: float, exchange_rate: float) -> dict:
    first_price = data[0]['close']
    last_price = data[-1]['close']
    bnh_return = ((last_price - first_price) / first_price) * 100

    shares = (seed / exchange_rate) / first_price
    peak = first_price
    max_dd = 0.0
    monthly = {}

    for row in data:
        p = row['close']
        if p > peak:
            peak = p
        dd = (peak - p) / peak * 100
        if dd > max_dd:
            max_dd = dd

        month_key = row['date'][:7]
        val = shares * p * exchange_rate
        monthly[month_key] = {
            'value': val,
            'return_pct': (val - seed) / seed * 100,
        }

    return {
        'return_pct': bnh_return,
        'mdd_pct': max_dd,
        'final_value': seed * (1 + bnh_return / 100),
        'monthly': monthly,
    }


# ============================================================================
# Output
# ============================================================================

def fmt_krw(val: float) -> str:
    return f"{val:,.0f}"

def fmt_pct(val: float) -> str:
    return f"{val:+.2f}%"

def fmt_man(val: float) -> str:
    """만원 단위"""
    return f"{val/10000:,.1f}만"


def print_trades_detail(trades: List[TradeLog], title: str, max_show: int = 50):
    """Print detailed trade log."""
    print(f"\n  📋 {title} 거래 상세 (총 {len(trades)}건, 주요 {min(len(trades), max_show)}건 표시)")
    print(f"  {'날짜':>12} {'액션':>10} {'금액(만원)':>12} {'주가($)':>10} {'손실률':>8} {'수익률':>8} {'잔여현금(만)':>14} {'비고'}")
    print(f"  {'-'*100}")

    shown = 0
    for t in trades:
        if shown >= max_show:
            print(f"  ... 외 {len(trades) - max_show}건 생략")
            break
        print(f"  {t.date:>12} {t.action:>10} {fmt_man(t.amount_krw):>12} "
              f"${t.price:>8.2f} {t.loss_rate:>+7.1f}% {t.return_rate:>+7.1f}% "
              f"{fmt_man(t.cash_after):>14} {t.note}")
        shown += 1


def print_monthly_comparison(smart_mv: dict, steady_mv: dict, bnh_mv: dict, seed: float):
    """Print month-by-month comparison."""
    months = sorted(set(list(smart_mv.keys()) + list(steady_mv.keys())))

    print(f"\n  📊 월별 자산 추이 (시작: {fmt_krw(seed)}원)")
    print(f"  {'월':>8} | {'Smart Cycle':>16} {'수익률':>10} | {'Steady Cycle':>16} {'수익률':>10} | {'Buy & Hold':>16} {'수익률':>10}")
    print(f"  {'-'*100}")

    for m in months:
        sm = smart_mv.get(m, {})
        st = steady_mv.get(m, {})
        bh = bnh_mv.get(m, {})

        sm_val = sm.get('value', 0)
        sm_ret = sm.get('return_pct', 0)
        st_val = st.get('value', 0)
        st_ret = st.get('return_pct', 0)
        bh_val = bh.get('value', 0)
        bh_ret = bh.get('return_pct', 0)

        print(f"  {m:>8} | {fmt_krw(sm_val):>16}원 {fmt_pct(sm_ret):>10} | "
              f"{fmt_krw(st_val):>16}원 {fmt_pct(st_ret):>10} | "
              f"{fmt_krw(bh_val):>16}원 {fmt_pct(bh_ret):>10}")


def main():
    SEED = 100_000_000  # 1억
    EXCHANGE_RATE = 1_350

    tickers = {
        'TQQQ': '/home/dandy02/possible/stocktrading/tqqq_data.csv',
        'SOXL': '/home/dandy02/possible/stocktrading/soxl_data.csv',
    }

    print("=" * 110)
    print("  Smart Cycle (v7.0) vs Steady Cycle 백테스트")
    print(f"  기간: 2025-01-02 ~ 2026-01-28 | 시드: {fmt_krw(SEED)}원 | 환율: {EXCHANGE_RATE}원/USD")
    print(f"  Smart Cycle 핵심: weightedBuyPerPercent = {SEED * 0.00007:,.0f}원/1% (v7.0 수정)")
    print("=" * 110)

    all_results = {}

    for ticker, path in tickers.items():
        data = load_csv(path)
        first_date = data[0]['date']
        last_date = data[-1]['date']
        first_price = data[0]['close']
        last_price = data[-1]['close']

        print(f"\n{'━'*110}")
        print(f"  🏷️ {ticker} | {first_date} ~ {last_date} | {len(data)}거래일")
        print(f"  시작가: ${first_price:.2f} → 종가: ${last_price:.2f} ({(last_price-first_price)/first_price*100:+.1f}%)")
        print(f"{'━'*110}")

        smart = run_smart_cycle(data, SEED, EXCHANGE_RATE)
        steady = run_steady_cycle(data, SEED, EXCHANGE_RATE)
        bnh = calc_buy_and_hold(data, SEED, EXCHANGE_RATE)

        # Summary
        print(f"\n  ┌─────────────────────────────────────────────────────────────────────────────┐")
        print(f"  │  {'':>22} │ {'Smart Cycle':>16} │ {'Steady Cycle':>16} │ {'Buy & Hold':>14} │")
        print(f"  ├─────────────────────────────────────────────────────────────────────────────┤")
        print(f"  │  {'총 수익률':>20} │ {fmt_pct(smart.total_return_pct):>16} │ {fmt_pct(steady.total_return_pct):>16} │ {fmt_pct(bnh['return_pct']):>14} │")
        print(f"  │  {'최종 자산':>20} │ {fmt_man(smart.final_value):>16} │ {fmt_man(steady.final_value):>16} │ {fmt_man(bnh['final_value']):>14} │")
        print(f"  │  {'잔여 현금':>20} │ {fmt_man(smart.cash_remaining):>16} │ {fmt_man(steady.cash_remaining):>16} │ {'0':>14} │")
        print(f"  │  {'완료 사이클':>20} │ {smart.cycles_completed:>15}회 │ {steady.cycles_completed:>15}회 │ {'N/A':>14} │")
        print(f"  │  {'총 거래':>20} │ {smart.total_trades:>15}회 │ {steady.total_trades:>15}회 │ {'1':>13}회 │")
        print(f"  │  {'MDD':>22} │ {fmt_pct(-smart.mdd_pct):>16} │ {fmt_pct(-steady.mdd_pct):>16} │ {fmt_pct(-bnh['mdd_pct']):>14} │")
        print(f"  └─────────────────────────────────────────────────────────────────────────────┘")

        # Monthly
        print_monthly_comparison(smart.monthly_values, steady.monthly_values, bnh.get('monthly', {}), SEED)

        # Trade details
        print_trades_detail(smart.trades, f"{ticker} Smart Cycle")
        print_trades_detail(steady.trades, f"{ticker} Steady Cycle", max_show=30)

        all_results[ticker] = {'smart': smart, 'steady': steady, 'bnh': bnh}

    # ============================================================================
    # Cross-ticker comparison
    # ============================================================================
    print(f"\n{'='*110}")
    print(f"  📈 종합 분석 및 전략 아이디어")
    print(f"{'='*110}")

    for ticker in ['TQQQ', 'SOXL']:
        r = all_results[ticker]
        sm, st, bh = r['smart'], r['steady'], r['bnh']

        print(f"\n  [{ticker}] 수익률 순위:")
        ranking = sorted([
            ('Smart Cycle', sm.total_return_pct),
            ('Steady Cycle', st.total_return_pct),
            ('Buy & Hold', bh['return_pct']),
        ], key=lambda x: -x[1])
        for i, (name, ret) in enumerate(ranking, 1):
            print(f"    {i}위: {name:20s} {fmt_pct(ret)}")

        print(f"\n  [{ticker}] MDD 순위 (낮을수록 안전):")
        mdd_rank = sorted([
            ('Smart Cycle', sm.mdd_pct),
            ('Steady Cycle', st.mdd_pct),
            ('Buy & Hold', bh['mdd_pct']),
        ], key=lambda x: x[1])
        for i, (name, mdd) in enumerate(mdd_rank, 1):
            print(f"    {i}위: {name:20s} {fmt_pct(-mdd)}")

    # Strategy Ideas
    print(f"\n{'='*110}")
    print(f"  💡 전략 아이디어 및 개선 제안")
    print(f"{'='*110}")

    print("""
  1. 하이브리드 전략 (Smart + Steady 병행)
     - 시드를 50:50 또는 60:40으로 분할하여 두 전략 동시 운용
     - Smart Cycle: 방어적 포지션 (MDD 관리)
     - Steady Cycle: 공격적 복리 (사이클 회전)
     - 효과: 개별 전략 대비 리스크 분산 + 안정적 수익

  2. 동적 시드 재분배
     - VIX 30 이상 (공포 구간): Smart 비중 ↑ (70:30)
     - VIX 20 이하 (안정 구간): Steady 비중 ↑ (30:70)
     - Fear & Greed Index 연동 자동 리밸런싱

  3. weightedBuyPerPercent 구간별 조절
     - 기본: seed × 0.00007 (-20%~-35%)
     - 심화: seed × 0.00010 (-35%~-50%) — 폭락 시 공격적 평단 낮추기
     - 2단계 가중매수로 -50% 미만 구간 대비 강화

  4. 익절 전략 세분화
     - Smart: 현재 연속 감소 (30→25→20→15→10%) 유지
     - Steady: 10% 고정 → 트레일링 스탑 옵션 추가
       - 10% 도달 후 최고점 대비 -3% 시 매도 (더 높은 수익 가능)

  5. 환율 변동 헤지
     - 원화 강세(환율↓) 시 달러 매수량 증가 효과 → 유리
     - 원화 약세(환율↑) 시 평가금액 증가 → 조기 익절 가능
     - 환율 1,300 이하 시 추가 매수, 1,400 이상 시 부분 환전 규칙

  6. 종목별 최적 파라미터
     - TQQQ (나스닥 3배): 변동성 높음 → weightedBuyThreshold -25% 권장
     - SOXL (반도체 3배): 변동성 극대 → weightedBuyThreshold -30% + panic -60%
     - QQQ/SPY (1배): 변동성 낮음 → 무한매수법이 더 적합

  7. 시간 기반 규칙 추가
     - 90일 이상 매수만 하는 경우 → 손실률 기준 -15%로 완화
     - 180일 이상 사이클 → 강제 리밸런싱 또는 손절 검토
     - 월초/월말 효과 활용 (레버리지 ETF 리밸런싱 영향)
""")

    print(f"\n{'='*110}")
    print(f"  백테스트 완료!")
    print(f"{'='*110}")


if __name__ == "__main__":
    main()
