"""
3-Strategy Backtest Comparison Script
======================================
Strategy A: Alpha Cycle V3 (consecutive take-profit reduction + cash secure + panic buy on evaluated amount)
Strategy B: Standard Infinite Buy V2.1 (40 rounds, LOC split A/B, +10% take profit)
Strategy C: RSI + Bollinger Bands Custom (45 rounds, indicator-weighted buys, conditional take profit)

Data: TQQQ & SOXL historical daily OHLCV
Seed: 30,000,000 KRW | Exchange rate: 1,350 KRW/USD
"""

import csv
from datetime import datetime
from dataclasses import dataclass, field
from typing import List, Tuple, Optional


# ============================================================================
# Technical Indicators
# ============================================================================

def calculate_rsi(closes: List[float], period: int = 14) -> List[Optional[float]]:
    """RSI (Wilder's smoothing). Returns list aligned with closes (None for first `period` entries)."""
    if len(closes) < period + 1:
        return [None] * len(closes)

    deltas = [closes[i] - closes[i - 1] for i in range(1, len(closes))]
    gains = [max(0, d) for d in deltas]
    losses = [max(0, -d) for d in deltas]

    avg_gain = sum(gains[:period]) / period
    avg_loss = sum(losses[:period]) / period

    # First period entries + first delta entry = period+1 None values mapped to closes indices
    result: List[Optional[float]] = [None] * (period + 1)

    # RSI at index period (after first `period` deltas)
    if avg_loss == 0:
        result.append(100.0)
    else:
        rs = avg_gain / avg_loss
        result.append(100 - (100 / (1 + rs)))

    for i in range(period, len(deltas)):
        avg_gain = (avg_gain * (period - 1) + gains[i]) / period
        avg_loss = (avg_loss * (period - 1) + losses[i]) / period
        if avg_loss == 0:
            result.append(100.0)
        else:
            rs = avg_gain / avg_loss
            result.append(100 - (100 / (1 + rs)))

    # Pad if needed (should not happen but safety)
    while len(result) < len(closes):
        result.append(None)
    return result[:len(closes)]


def calculate_bb(closes: List[float], idx: int, period: int = 20, num_std: float = 2.0) -> Tuple[Optional[float], Optional[float], Optional[float], Optional[float]]:
    """Bollinger Bands at index `idx`. Returns (upper, middle, lower, %B) or all None."""
    if idx < period - 1:
        return None, None, None, None
    window = closes[idx - period + 1: idx + 1]
    middle = sum(window) / period
    variance = sum((c - middle) ** 2 for c in window) / period
    std = variance ** 0.5
    upper = middle + num_std * std
    lower = middle - num_std * std
    if upper != lower:
        pct_b = (closes[idx] - lower) / (upper - lower)
    else:
        pct_b = 0.5
    return upper, middle, lower, pct_b


# ============================================================================
# Data Loading
# ============================================================================

def load_csv(path: str) -> List[dict]:
    """Load CSV and return list of dicts with Date (str), Open, High, Low, Close, Volume."""
    rows = []
    with open(path, 'r') as f:
        reader = csv.DictReader(f)
        for r in reader:
            rows.append({
                'date': r['Date'][:10],  # YYYY-MM-DD
                'open': float(r['Open']),
                'high': float(r['High']),
                'low': float(r['Low']),
                'close': float(r['Close']),
                'volume': int(float(r['Volume'])),
            })
    # Sort by date
    rows.sort(key=lambda x: x['date'])
    return rows


# ============================================================================
# Strategy A: Alpha Cycle V3
# ============================================================================

@dataclass
class AlphaCycleV3Result:
    total_return_pct: float = 0.0
    cycles_completed: int = 0
    mdd_pct: float = 0.0
    cash_remaining: float = 0.0
    total_trades: int = 0
    days_to_first_tp: int = 0
    final_value: float = 0.0


def run_alpha_cycle_v3(data: List[dict], seed: float, exchange_rate: float) -> AlphaCycleV3Result:
    """
    Alpha Cycle V3:
    - Initial entry: seed * 20%
    - Weighted buy: lossRate <= -20% -> initialEntry * |lossRate| / 1000
    - Panic buy: lossRate <= -50% -> evaluatedAmount * 50%
    - Take profit: consecutive reduction max(10, 30-(N-1)*5)%
    - Cash secure: returnRate >= 0% AND cash < totalAssets/3 -> partial sell
    - Priority: takeProfit > cashSecure > panicBuy > weightedBuy > hold
    """
    cash = seed
    shares = 0.0
    avg_price = 0.0
    initial_entry_price = 0.0
    initial_entry_amount = seed * 0.20
    current_seed = seed
    panic_used = False
    first_buy_done = False
    cycles_completed = 0
    consecutive_profit_count = 0
    total_trades = 0
    first_tp_day = 0  # day index of first take profit

    # MDD tracking
    peak_value = seed
    max_drawdown = 0.0

    # Daily value history for MDD
    for day_idx, row in enumerate(data):
        price = row['close']

        # Calculate current total value
        holdings_krw = shares * price * exchange_rate
        total_value = cash + holdings_krw

        # MDD tracking
        if total_value > peak_value:
            peak_value = total_value
        dd = (peak_value - total_value) / peak_value * 100
        if dd > max_drawdown:
            max_drawdown = dd

        # --- Initial entry ---
        if not first_buy_done:
            buy_amount = initial_entry_amount
            if buy_amount > cash:
                buy_amount = cash
            if buy_amount > 0:
                shares_to_buy = (buy_amount / exchange_rate) / price
                shares = shares_to_buy
                avg_price = price
                initial_entry_price = price
                cash -= buy_amount
                total_trades += 1
                first_buy_done = True
            continue

        # Current rates
        loss_rate = ((price - initial_entry_price) / initial_entry_price) * 100 if initial_entry_price > 0 else 0
        return_rate = ((price - avg_price) / avg_price) * 100 if avg_price > 0 and shares > 0 else 0

        holdings_krw = shares * price * exchange_rate
        total_value = cash + holdings_krw
        evaluated_amount = holdings_krw  # current stock value

        # --- Signal priority: takeProfit > cashSecure > panicBuy > weightedBuy > hold ---

        # [1] Take Profit: consecutive reduction
        tp_threshold = max(10, 30 - (consecutive_profit_count) * 5)
        if return_rate >= tp_threshold and shares > 0:
            # Sell percentage: max(10, 30 - (N-1)*5) where N = consecutive_profit_count + 1 (this one)
            sell_pct_val = max(10, 30 - consecutive_profit_count * 5)
            sell_ratio = sell_pct_val / 100.0

            shares_to_sell = shares * sell_ratio
            sell_value_krw = shares_to_sell * price * exchange_rate
            cash += sell_value_krw
            shares -= shares_to_sell
            total_trades += 1
            consecutive_profit_count += 1

            if first_tp_day == 0:
                first_tp_day = day_idx

            # If all shares sold or nearly zero, new cycle
            if shares < 0.0001:
                cycles_completed += 1
                new_seed = cash
                current_seed = new_seed
                initial_entry_amount = new_seed * 0.20
                shares = 0.0
                avg_price = 0.0
                initial_entry_price = 0.0
                panic_used = False
                first_buy_done = False
                consecutive_profit_count = 0
            continue

        # Reset consecutive count if not taking profit
        # (only reset when price drops below avg, not just because we skip)
        if return_rate < 0:
            consecutive_profit_count = 0

        # [2] Cash Secure: returnRate >= 0% AND cash < totalAssets / 3
        if return_rate >= 0 and shares > 0:
            total_assets = cash + shares * price * exchange_rate
            if cash < total_assets / 3:
                # Sell enough to bring cash to totalAssets / 3
                needed = total_assets / 3 - cash
                shares_to_sell = needed / (price * exchange_rate)
                if shares_to_sell > shares:
                    shares_to_sell = shares
                if shares_to_sell > 0:
                    sell_value = shares_to_sell * price * exchange_rate
                    cash += sell_value
                    shares -= shares_to_sell
                    total_trades += 1
                    if shares > 0:
                        # avg_price unchanged (just selling)
                        pass
            continue

        # [3] Panic Buy: lossRate <= -50%, evaluatedAmount * 50%
        if loss_rate <= -50 and not panic_used:
            panic_amount = evaluated_amount * 0.50  # V3: based on evaluated amount
            if panic_amount > cash:
                panic_amount = cash
            if panic_amount > 0:
                shares_to_buy = (panic_amount / exchange_rate) / price
                total_cost = shares * avg_price + shares_to_buy * price
                shares += shares_to_buy
                avg_price = total_cost / shares if shares > 0 else price
                cash -= panic_amount
                total_trades += 1
                panic_used = True
            # Fall through to weighted buy as well

        # [4] Weighted Buy: lossRate <= -20%
        if loss_rate <= -20:
            buy_amount = initial_entry_amount * abs(loss_rate) / 1000
            if buy_amount > cash:
                buy_amount = cash
            if buy_amount > 0:
                shares_to_buy = (buy_amount / exchange_rate) / price
                total_cost = shares * avg_price + shares_to_buy * price
                shares += shares_to_buy
                avg_price = total_cost / shares if shares > 0 else price
                cash -= buy_amount
                total_trades += 1

    # Final value
    final_price = data[-1]['close']
    holdings_krw = shares * final_price * exchange_rate
    final_value = cash + holdings_krw
    total_return = ((final_value - seed) / seed) * 100

    return AlphaCycleV3Result(
        total_return_pct=total_return,
        cycles_completed=cycles_completed,
        mdd_pct=max_drawdown,
        cash_remaining=cash,
        total_trades=total_trades,
        days_to_first_tp=first_tp_day if first_tp_day > 0 else len(data),
        final_value=final_value,
    )


# ============================================================================
# Strategy B: Standard Infinite Buy V2.1
# ============================================================================

@dataclass
class InfiniteBuyResult:
    total_return_pct: float = 0.0
    cycles_completed: int = 0
    mdd_pct: float = 0.0
    cash_remaining: float = 0.0
    total_trades: int = 0
    days_to_first_tp: int = 0
    final_value: float = 0.0


def run_infinite_buy(data: List[dict], seed: float, exchange_rate: float) -> InfiniteBuyResult:
    """
    Standard Infinite Buy V2.1:
    - Total rounds: 40
    - Unit amount: seed / 40
    - If close <= avg_price: A+B both fill -> 1.0 unit consumed
    - If close > avg_price: only B fills -> 0.5 unit consumed
    - Take profit: returnRate >= +10% -> sell all
    - After 40 rounds: hold and wait
    - On take profit: new cycle with (cash + proceeds) as new seed
    """
    cash = seed
    shares = 0.0
    avg_price = 0.0
    current_seed = seed
    total_rounds = 40
    rounds_used = 0.0
    unit_amount = seed / total_rounds
    cycles_completed = 0
    total_trades = 0
    first_tp_day = 0
    first_buy_done = False

    peak_value = seed
    max_drawdown = 0.0

    for day_idx, row in enumerate(data):
        price = row['close']

        # MDD tracking
        holdings_krw = shares * price * exchange_rate
        total_value = cash + holdings_krw
        if total_value > peak_value:
            peak_value = total_value
        dd = (peak_value - total_value) / peak_value * 100
        if dd > max_drawdown:
            max_drawdown = dd

        # Check take profit first (if we have shares)
        if shares > 0 and avg_price > 0:
            return_rate = ((price - avg_price) / avg_price) * 100
            if return_rate >= 10.0:
                # Sell all
                sell_value = shares * price * exchange_rate
                cash += sell_value
                shares = 0.0
                avg_price = 0.0
                total_trades += 1
                cycles_completed += 1

                if first_tp_day == 0:
                    first_tp_day = day_idx

                # New cycle
                current_seed = cash
                rounds_used = 0.0
                unit_amount = current_seed / total_rounds
                first_buy_done = False
                continue

        # Buy logic
        if rounds_used >= total_rounds:
            continue  # Hold and wait, no more buys

        if not first_buy_done or shares == 0:
            # First buy of cycle: always buy 1 unit (A+B)
            buy_amount = unit_amount * 1.0
            units_consumed = 1.0
        else:
            if price <= avg_price:
                # A+B both fill
                buy_amount = unit_amount * 1.0
                units_consumed = 1.0
            else:
                # Only B fills
                buy_amount = unit_amount * 0.5
                units_consumed = 0.5

        if rounds_used + units_consumed > total_rounds:
            # Partial fill for remaining rounds
            remaining = total_rounds - rounds_used
            if remaining <= 0:
                continue
            buy_amount = unit_amount * remaining
            units_consumed = remaining

        if buy_amount > cash:
            buy_amount = cash
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

    # Final
    final_price = data[-1]['close']
    holdings_krw = shares * final_price * exchange_rate
    final_value = cash + holdings_krw
    total_return = ((final_value - seed) / seed) * 100

    return InfiniteBuyResult(
        total_return_pct=total_return,
        cycles_completed=cycles_completed,
        mdd_pct=max_drawdown,
        cash_remaining=cash,
        total_trades=total_trades,
        days_to_first_tp=first_tp_day if first_tp_day > 0 else len(data),
        final_value=final_value,
    )


# ============================================================================
# Strategy C: RSI + Bollinger Bands Custom
# ============================================================================

@dataclass
class RSIBBResult:
    total_return_pct: float = 0.0
    cycles_completed: int = 0
    mdd_pct: float = 0.0
    cash_remaining: float = 0.0
    total_trades: int = 0
    days_to_first_tp: int = 0
    final_value: float = 0.0


def run_rsi_bb(data: List[dict], seed: float, exchange_rate: float) -> RSIBBResult:
    """
    RSI + Bollinger Bands Custom:
    - Base: 45 rounds (5 buffer), LOC-style
    - RSI weight: >=70->0.5, 30~70->1.0, <=30->1.5
    - BB weight (%B): >1.0->0.5, 0~1->1.0, <0->2.0
    - Final W = W_rsi * W_bb, clamped [0.25, 3.0]
    - When remaining < 10 rounds, clamp W to max 1.5
    - Take profit: +10%, but if RSI<50, sell only 50%
      - Remaining 50%: sell when R>=15% OR RSI>=65 OR 7 days passed OR R<=3%
    """
    closes_all = [row['close'] for row in data]
    rsi_all = calculate_rsi(closes_all, 14)

    cash = seed
    shares = 0.0
    avg_price = 0.0
    current_seed = seed
    total_rounds = 45.0
    rounds_used = 0.0
    base_unit = seed / total_rounds
    cycles_completed = 0
    total_trades = 0
    first_tp_day = 0
    first_buy_done = False

    # Half-sell tracking
    half_sold = False
    half_sell_day = 0

    peak_value = seed
    max_drawdown = 0.0

    for day_idx, row in enumerate(data):
        price = row['close']

        # MDD
        holdings_krw = shares * price * exchange_rate
        total_value = cash + holdings_krw
        if total_value > peak_value:
            peak_value = total_value
        dd = (peak_value - total_value) / peak_value * 100
        if dd > max_drawdown:
            max_drawdown = dd

        # Get indicators
        rsi = rsi_all[day_idx]
        _, _, _, pct_b = calculate_bb(closes_all, day_idx, 20, 2.0)

        # --- Check take profit / half-sell logic ---
        if shares > 0 and avg_price > 0:
            return_rate = ((price - avg_price) / avg_price) * 100

            # If half-sold, check remaining exit conditions
            if half_sold:
                days_since = day_idx - half_sell_day
                should_sell_remaining = False
                if return_rate >= 15.0:
                    should_sell_remaining = True
                elif rsi is not None and rsi >= 65:
                    should_sell_remaining = True
                elif days_since >= 7:
                    should_sell_remaining = True
                elif return_rate <= 3.0:
                    should_sell_remaining = True

                if should_sell_remaining:
                    sell_value = shares * price * exchange_rate
                    cash += sell_value
                    shares = 0.0
                    avg_price = 0.0
                    total_trades += 1
                    cycles_completed += 1
                    half_sold = False

                    if first_tp_day == 0:
                        first_tp_day = day_idx

                    # New cycle
                    current_seed = cash
                    rounds_used = 0.0
                    base_unit = current_seed / total_rounds
                    first_buy_done = False
                    continue

            # Normal take profit check
            elif return_rate >= 10.0:
                if rsi is not None and rsi < 50:
                    # Half sell
                    shares_to_sell = shares * 0.5
                    sell_value = shares_to_sell * price * exchange_rate
                    cash += sell_value
                    shares -= shares_to_sell
                    total_trades += 1
                    half_sold = True
                    half_sell_day = day_idx

                    if first_tp_day == 0:
                        first_tp_day = day_idx
                    continue
                else:
                    # Full sell
                    sell_value = shares * price * exchange_rate
                    cash += sell_value
                    shares = 0.0
                    avg_price = 0.0
                    total_trades += 1
                    cycles_completed += 1

                    if first_tp_day == 0:
                        first_tp_day = day_idx

                    # New cycle
                    current_seed = cash
                    rounds_used = 0.0
                    base_unit = current_seed / total_rounds
                    first_buy_done = False
                    continue

        # --- Buy logic ---
        if half_sold:
            continue  # Don't buy while waiting to sell remaining half

        if rounds_used >= total_rounds:
            continue

        # Calculate weights
        if rsi is None or pct_b is None:
            # Not enough data for indicators yet, buy 1 base unit
            w_final = 1.0
        else:
            # RSI weight
            if rsi >= 70:
                w_rsi = 0.5
            elif rsi <= 30:
                w_rsi = 1.5
            else:
                w_rsi = 1.0

            # BB weight
            if pct_b > 1.0:
                w_bb = 0.5
            elif pct_b < 0.0:
                w_bb = 2.0
            else:
                w_bb = 1.0

            w_final = w_rsi * w_bb
            w_final = max(0.25, min(3.0, w_final))

            # Buffer protection: when remaining < 10, clamp to 1.5
            remaining = total_rounds - rounds_used
            if remaining < 10:
                w_final = min(w_final, 1.5)

        # LOC-style: if price <= avg, full; if price > avg, half (applied to weighted amount)
        if not first_buy_done or shares == 0:
            loc_mult = 1.0
        else:
            if price <= avg_price:
                loc_mult = 1.0
            else:
                loc_mult = 0.5

        buy_amount = base_unit * w_final * loc_mult
        units_consumed = w_final * loc_mult

        if rounds_used + units_consumed > total_rounds:
            remaining = total_rounds - rounds_used
            if remaining <= 0:
                continue
            ratio = remaining / units_consumed
            buy_amount *= ratio
            units_consumed = remaining

        if buy_amount > cash:
            buy_amount = cash
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

    # Final
    final_price = data[-1]['close']
    holdings_krw = shares * final_price * exchange_rate
    final_value = cash + holdings_krw
    total_return = ((final_value - seed) / seed) * 100

    return RSIBBResult(
        total_return_pct=total_return,
        cycles_completed=cycles_completed,
        mdd_pct=max_drawdown,
        cash_remaining=cash,
        total_trades=total_trades,
        days_to_first_tp=first_tp_day if first_tp_day > 0 else len(data),
        final_value=final_value,
    )


# ============================================================================
# Buy & Hold Baseline
# ============================================================================

def calc_buy_and_hold(data: List[dict], seed: float) -> Tuple[float, float]:
    """Returns (return_pct, mdd_pct)."""
    first_price = data[0]['close']
    last_price = data[-1]['close']
    bnh_return = ((last_price - first_price) / first_price) * 100

    # MDD
    peak = first_price
    max_dd = 0.0
    for row in data:
        p = row['close']
        if p > peak:
            peak = p
        dd = (peak - p) / peak * 100
        if dd > max_dd:
            max_dd = dd

    return bnh_return, max_dd


# ============================================================================
# Output formatting
# ============================================================================

def fmt_krw(val: float) -> str:
    """Format KRW value with commas."""
    return f"{val:,.0f}"


def fmt_pct(val: float) -> str:
    """Format percentage."""
    return f"{val:+.2f}%"


def print_individual_result(ticker: str, strat_name: str, result, seed: float, bnh_return: float):
    """Print detailed result for one strategy/ticker combination."""
    print(f"\n  [{strat_name}]")
    print(f"    총수익률:      {fmt_pct(result.total_return_pct)}")
    print(f"    최종자산:      {fmt_krw(result.final_value)}원")
    print(f"    잔여현금:      {fmt_krw(result.cash_remaining)}원")
    print(f"    완료 사이클:   {result.cycles_completed}회")
    print(f"    총 거래 횟수:  {result.total_trades}회")
    print(f"    MDD:           {fmt_pct(-result.mdd_pct)}")
    print(f"    첫 익절까지:   {result.days_to_first_tp}거래일")
    diff = result.total_return_pct - bnh_return
    print(f"    vs B&H:        {fmt_pct(diff)}p")


def print_comparison_table(results: dict):
    """Print final comparison table."""
    print(f"\n{'='*90}")
    print(f"  최종 비교 테이블")
    print(f"{'='*90}")

    header = f"{'':>22} | {'Alpha Cycle V3':>16} | {'순정 무한매수':>14} | {'RSI+BB 커스텀':>14} | {'Buy & Hold':>12}"
    print(header)
    print("-" * 90)

    for ticker in ['TQQQ', 'SOXL']:
        r = results[ticker]
        a, b, c, bnh = r['alpha'], r['infinite'], r['rsibb'], r['bnh']

        # Total return
        print(f"  {ticker} 총수익률        | {fmt_pct(a.total_return_pct):>16} | {fmt_pct(b.total_return_pct):>14} | {fmt_pct(c.total_return_pct):>14} | {fmt_pct(bnh[0]):>12}")
        # Cycles
        print(f"  {ticker} 완료 사이클     | {a.cycles_completed:>15}회 | {b.cycles_completed:>13}회 | {c.cycles_completed:>13}회 | {'N/A':>12}")
        # MDD
        print(f"  {ticker} MDD             | {fmt_pct(-a.mdd_pct):>16} | {fmt_pct(-b.mdd_pct):>14} | {fmt_pct(-c.mdd_pct):>14} | {fmt_pct(-bnh[1]):>12}")
        # Total trades
        print(f"  {ticker} 총거래          | {a.total_trades:>15}회 | {b.total_trades:>13}회 | {c.total_trades:>13}회 | {'1':>11}회")
        # Cash remaining
        print(f"  {ticker} 잔여현금(만원)  | {a.cash_remaining/10000:>14,.0f} | {b.cash_remaining/10000:>12,.0f} | {c.cash_remaining/10000:>12,.0f} | {'0':>12}")
        # First TP
        print(f"  {ticker} 첫익절(거래일)  | {a.days_to_first_tp:>15} | {b.days_to_first_tp:>13} | {c.days_to_first_tp:>13} | {'N/A':>12}")

        if ticker == 'TQQQ':
            print("-" * 90)

    print("=" * 90)


# ============================================================================
# Main
# ============================================================================

def main():
    SEED = 30_000_000  # 3천만원
    EXCHANGE_RATE = 1_350  # KRW/USD

    tickers = {
        'TQQQ': '/home/dandy02/possible/stocktrading/tqqq_data.csv',
        'SOXL': '/home/dandy02/possible/stocktrading/soxl_data.csv',
    }

    print("=" * 90)
    print("  3-Strategy Backtest Comparison")
    print("  Alpha Cycle V3 vs 순정 무한매수법 vs RSI+BB 커스텀")
    print(f"  시드머니: {fmt_krw(SEED)}원 | 환율: {fmt_krw(EXCHANGE_RATE)}원/USD")
    print("=" * 90)

    all_results = {}

    for ticker, path in tickers.items():
        data = load_csv(path)
        first_date = data[0]['date']
        last_date = data[-1]['date']
        first_price = data[0]['close']
        last_price = data[-1]['close']

        print(f"\n{'─'*90}")
        print(f"  {ticker} | {first_date} ~ {last_date} | {len(data)}거래일")
        print(f"  시작가: ${first_price:.2f} -> 종가: ${last_price:.2f}")
        print(f"{'─'*90}")

        # Run strategies
        alpha_result = run_alpha_cycle_v3(data, SEED, EXCHANGE_RATE)
        infinite_result = run_infinite_buy(data, SEED, EXCHANGE_RATE)
        rsibb_result = run_rsi_bb(data, SEED, EXCHANGE_RATE)
        bnh = calc_buy_and_hold(data, SEED)

        print_individual_result(ticker, "Strategy A: Alpha Cycle V3", alpha_result, SEED, bnh[0])
        print_individual_result(ticker, "Strategy B: 순정 무한매수법 V2.1", infinite_result, SEED, bnh[0])
        print_individual_result(ticker, "Strategy C: RSI+BB 커스텀", rsibb_result, SEED, bnh[0])

        print(f"\n  [Buy & Hold (기준)]")
        print(f"    총수익률:      {fmt_pct(bnh[0])}")
        bnh_final = SEED * (1 + bnh[0] / 100)
        print(f"    최종자산:      {fmt_krw(bnh_final)}원")
        print(f"    MDD:           {fmt_pct(-bnh[1])}")

        all_results[ticker] = {
            'alpha': alpha_result,
            'infinite': infinite_result,
            'rsibb': rsibb_result,
            'bnh': bnh,
        }

    # Comparison table
    print_comparison_table(all_results)

    # Winner analysis
    print(f"\n{'='*90}")
    print(f"  승자 분석")
    print(f"{'='*90}")

    for ticker in ['TQQQ', 'SOXL']:
        r = all_results[ticker]
        strategies = [
            ('Alpha Cycle V3', r['alpha'].total_return_pct),
            ('순정 무한매수', r['infinite'].total_return_pct),
            ('RSI+BB 커스텀', r['rsibb'].total_return_pct),
            ('Buy & Hold', r['bnh'][0]),
        ]
        strategies.sort(key=lambda x: x[1], reverse=True)
        print(f"\n  {ticker} 수익률 순위:")
        for rank, (name, ret) in enumerate(strategies, 1):
            print(f"    {rank}위: {name:20s} {fmt_pct(ret)}")

        # MDD comparison
        mdds = [
            ('Alpha Cycle V3', r['alpha'].mdd_pct),
            ('순정 무한매수', r['infinite'].mdd_pct),
            ('RSI+BB 커스텀', r['rsibb'].mdd_pct),
            ('Buy & Hold', r['bnh'][1]),
        ]
        mdds.sort(key=lambda x: x[1])  # Lower MDD is better
        print(f"\n  {ticker} MDD 순위 (낮을수록 좋음):")
        for rank, (name, mdd) in enumerate(mdds, 1):
            print(f"    {rank}위: {name:20s} {fmt_pct(-mdd)}")

    print(f"\n{'='*90}")
    print(f"  백테스트 완료!")
    print(f"{'='*90}")


if __name__ == "__main__":
    main()
