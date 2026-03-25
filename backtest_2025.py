"""
2025년 3-Strategy Backtest (정밀 분석)
======================================
Strategy A: Alpha Cycle V3
Strategy B: 순정 무한매수법 V2.1
Strategy C: RSI + Bollinger Bands Custom

기간: 2025-01-02 ~ 2025-12-31
워밍업: 2024-10-01~ (RSI 14일 + BB 20일 지표 안정화)
시드: 30,000,000 KRW | 환율: 1,350 KRW/USD
"""

import csv
from datetime import datetime
from dataclasses import dataclass, field
from typing import List, Tuple, Optional


# ============================================================================
# Technical Indicators
# ============================================================================

def calculate_rsi(closes: List[float], period: int = 14) -> List[Optional[float]]:
    """RSI (Wilder's smoothing)."""
    if len(closes) < period + 1:
        return [None] * len(closes)

    deltas = [closes[i] - closes[i - 1] for i in range(1, len(closes))]
    gains = [max(0, d) for d in deltas]
    losses = [max(0, -d) for d in deltas]

    avg_gain = sum(gains[:period]) / period
    avg_loss = sum(losses[:period]) / period

    result: List[Optional[float]] = [None] * (period + 1)

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

    return result


def calculate_bb(closes: List[float], idx: int, period: int = 20, num_std: float = 2.0):
    """Bollinger Bands at index idx. Returns (upper, middle, lower, %B) or Nones."""
    if idx < period - 1:
        return None, None, None, None
    window = closes[idx - period + 1: idx + 1]
    middle = sum(window) / period
    variance = sum((x - middle) ** 2 for x in window) / period
    std = variance ** 0.5
    upper = middle + num_std * std
    lower = middle - num_std * std
    if upper == lower:
        pct_b = 0.5
    else:
        pct_b = (closes[idx] - lower) / (upper - lower)
    return upper, middle, lower, pct_b


def load_csv(path: str) -> List[dict]:
    """Load CSV and return list of dicts with date, OHLCV."""
    rows = []
    with open(path, 'r') as f:
        reader = csv.DictReader(f)
        for r in reader:
            rows.append({
                'date': r['Date'][:10],
                'open': float(r['Open']),
                'high': float(r['High']),
                'low': float(r['Low']),
                'close': float(r['Close']),
                'volume': int(float(r['Volume'])),
            })
    rows.sort(key=lambda x: x['date'])
    return rows


def filter_with_warmup(data: List[dict], warmup_start: str, trade_start: str, trade_end: str):
    """
    워밍업 포함 데이터 + 실제 거래 시작 인덱스 반환.
    Returns: (filtered_data, trade_start_index)
    """
    filtered = [row for row in data if warmup_start <= row['date'] <= trade_end]
    trade_start_idx = 0
    for i, row in enumerate(filtered):
        if row['date'] >= trade_start:
            trade_start_idx = i
            break
    return filtered, trade_start_idx


# ============================================================================
# Strategy A: Alpha Cycle V3
# ============================================================================

@dataclass
class AlphaCycleV3Result:
    total_return_pct: float = 0.0
    cycles_completed: int = 0
    mdd_pct: float = 0.0
    cash_remaining: float = 0.0
    shares_remaining: float = 0.0
    avg_price_remaining: float = 0.0
    total_trades: int = 0
    days_to_first_tp: int = 0
    final_value: float = 0.0
    # 일별 기록
    daily_values: List[dict] = field(default_factory=list)
    cycle_log: List[str] = field(default_factory=list)


def run_alpha_cycle_v3(data: List[dict], trade_start_idx: int, seed: float, exchange_rate: float) -> AlphaCycleV3Result:
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
    first_tp_day = 0
    cycle_start_day = 0

    peak_value = seed
    max_drawdown = 0.0
    daily_values = []
    cycle_log = []

    for day_idx in range(trade_start_idx, len(data)):
        row = data[day_idx]
        price = row['close']
        date = row['date']
        trade_day = day_idx - trade_start_idx

        holdings_krw = shares * price * exchange_rate
        total_value = cash + holdings_krw

        if total_value > peak_value:
            peak_value = total_value
        dd = (peak_value - total_value) / peak_value * 100
        if dd > max_drawdown:
            max_drawdown = dd

        daily_values.append({
            'date': date, 'value': total_value, 'cash': cash,
            'holdings': holdings_krw, 'shares': shares, 'price': price
        })

        # Initial entry
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
                cycle_start_day = trade_day
                cycle_log.append(f"  [{date}] 초기진입: ${price:.2f} x {shares_to_buy:.4f}주 = {buy_amount:,.0f}원")
            continue

        loss_rate = ((price - initial_entry_price) / initial_entry_price) * 100 if initial_entry_price > 0 else 0
        return_rate = ((price - avg_price) / avg_price) * 100 if avg_price > 0 and shares > 0 else 0

        holdings_krw = shares * price * exchange_rate
        total_value = cash + holdings_krw
        evaluated_amount = holdings_krw

        # [1] Take Profit
        tp_threshold = max(10, 30 - consecutive_profit_count * 5)
        if return_rate >= tp_threshold and shares > 0:
            sell_pct_val = max(10, 30 - consecutive_profit_count * 5)
            sell_ratio = sell_pct_val / 100.0

            shares_to_sell = shares * sell_ratio
            sell_value_krw = shares_to_sell * price * exchange_rate
            cash += sell_value_krw
            shares -= shares_to_sell
            total_trades += 1
            consecutive_profit_count += 1

            if first_tp_day == 0:
                first_tp_day = trade_day

            cycle_log.append(f"  [{date}] 익절 #{consecutive_profit_count}: R={return_rate:.1f}% >= {tp_threshold}%, "
                             f"매도 {sell_pct_val}% ({shares_to_sell:.4f}주) = {sell_value_krw:,.0f}원")

            if shares < 0.0001:
                cycles_completed += 1
                cycle_log.append(f"  [{date}] === 사이클 #{cycles_completed} 완료 "
                                 f"(소요 {trade_day - cycle_start_day}일, 시드 {current_seed:,.0f} -> {cash:,.0f}원) ===")
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

        if return_rate < 0:
            consecutive_profit_count = 0

        # [2] Cash Secure
        if return_rate >= 0 and shares > 0:
            total_assets = cash + shares * price * exchange_rate
            if cash < total_assets / 3:
                needed = total_assets / 3 - cash
                shares_to_sell = needed / (price * exchange_rate)
                if shares_to_sell > shares:
                    shares_to_sell = shares
                if shares_to_sell > 0:
                    sell_value = shares_to_sell * price * exchange_rate
                    cash += sell_value
                    shares -= shares_to_sell
                    total_trades += 1
                    cycle_log.append(f"  [{date}] 현금확보: R={return_rate:.1f}%, 매도 {shares_to_sell:.4f}주 = {sell_value:,.0f}원")
            continue

        # [3] Panic Buy
        if loss_rate <= -50 and not panic_used:
            panic_amount = evaluated_amount * 0.50
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
                cycle_log.append(f"  [{date}] 패닉바이: L={loss_rate:.1f}%, {panic_amount:,.0f}원 매수")

        # [4] Weighted Buy
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
                cycle_log.append(f"  [{date}] 가중매수: L={loss_rate:.1f}%, {buy_amount:,.0f}원 매수")

    final_price = data[-1]['close']
    holdings_krw = shares * final_price * exchange_rate
    final_value = cash + holdings_krw
    total_return = ((final_value - seed) / seed) * 100

    return AlphaCycleV3Result(
        total_return_pct=total_return,
        cycles_completed=cycles_completed,
        mdd_pct=max_drawdown,
        cash_remaining=cash,
        shares_remaining=shares,
        avg_price_remaining=avg_price,
        total_trades=total_trades,
        days_to_first_tp=first_tp_day if first_tp_day > 0 else (len(data) - trade_start_idx),
        final_value=final_value,
        daily_values=daily_values,
        cycle_log=cycle_log,
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
    shares_remaining: float = 0.0
    avg_price_remaining: float = 0.0
    total_trades: int = 0
    days_to_first_tp: int = 0
    final_value: float = 0.0
    rounds_used_final: float = 0.0
    daily_values: List[dict] = field(default_factory=list)
    cycle_log: List[str] = field(default_factory=list)


def run_infinite_buy(data: List[dict], trade_start_idx: int, seed: float, exchange_rate: float) -> InfiniteBuyResult:
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
    cycle_start_day = 0

    peak_value = seed
    max_drawdown = 0.0
    daily_values = []
    cycle_log = []

    for day_idx in range(trade_start_idx, len(data)):
        row = data[day_idx]
        price = row['close']
        date = row['date']
        trade_day = day_idx - trade_start_idx

        holdings_krw = shares * price * exchange_rate
        total_value = cash + holdings_krw
        if total_value > peak_value:
            peak_value = total_value
        dd = (peak_value - total_value) / peak_value * 100
        if dd > max_drawdown:
            max_drawdown = dd

        daily_values.append({
            'date': date, 'value': total_value, 'cash': cash,
            'holdings': holdings_krw, 'shares': shares, 'price': price
        })

        # Check take profit
        if shares > 0 and avg_price > 0:
            return_rate = ((price - avg_price) / avg_price) * 100
            if return_rate >= 10.0:
                sell_value = shares * price * exchange_rate
                cash += sell_value
                total_trades += 1
                cycles_completed += 1

                cycle_log.append(f"  [{date}] 익절: R={return_rate:.2f}%, 전량매도 {shares:.4f}주 = {sell_value:,.0f}원 "
                                 f"(사이클 #{cycles_completed}, 라운드 {rounds_used:.1f}/40, 소요 {trade_day - cycle_start_day}일)")

                shares = 0.0
                avg_price = 0.0

                if first_tp_day == 0:
                    first_tp_day = trade_day

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
            order_type = "A+B(초기)"
        else:
            if price <= avg_price:
                buy_amount = unit_amount * 1.0
                units_consumed = 1.0
                order_type = "A+B(평단이하)"
            else:
                buy_amount = unit_amount * 0.5
                units_consumed = 0.5
                order_type = "B만(평단이상)"

        if rounds_used + units_consumed > total_rounds:
            remaining = total_rounds - rounds_used
            if remaining <= 0:
                continue
            buy_amount = unit_amount * remaining
            units_consumed = remaining
            order_type += f"(잔여{remaining:.1f})"

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
            cycle_start_day = trade_day

        cash -= buy_amount
        rounds_used += units_consumed
        total_trades += 1
        first_buy_done = True

        # 주요 매수만 로그 (매 10라운드 또는 첫매수)
        if rounds_used <= 1.0 or int(rounds_used) % 10 == 0 or rounds_used >= total_rounds:
            cycle_log.append(f"  [{date}] 매수 R{rounds_used:.1f}/40 {order_type}: "
                             f"${price:.2f} x {shares_to_buy:.4f}주 = {buy_amount:,.0f}원 (평단 ${avg_price:.2f})")

    final_price = data[-1]['close']
    holdings_krw = shares * final_price * exchange_rate
    final_value = cash + holdings_krw
    total_return = ((final_value - seed) / seed) * 100

    return InfiniteBuyResult(
        total_return_pct=total_return,
        cycles_completed=cycles_completed,
        mdd_pct=max_drawdown,
        cash_remaining=cash,
        shares_remaining=shares,
        avg_price_remaining=avg_price,
        total_trades=total_trades,
        days_to_first_tp=first_tp_day if first_tp_day > 0 else (len(data) - trade_start_idx),
        final_value=final_value,
        rounds_used_final=rounds_used,
        daily_values=daily_values,
        cycle_log=cycle_log,
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
    shares_remaining: float = 0.0
    avg_price_remaining: float = 0.0
    total_trades: int = 0
    days_to_first_tp: int = 0
    final_value: float = 0.0
    rounds_used_final: float = 0.0
    daily_values: List[dict] = field(default_factory=list)
    cycle_log: List[str] = field(default_factory=list)


def run_rsi_bb(data: List[dict], trade_start_idx: int, seed: float, exchange_rate: float) -> RSIBBResult:
    # 전체 데이터로 지표 계산 (워밍업 포함)
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
    cycle_start_day = 0

    half_sold = False
    half_sell_day = 0

    peak_value = seed
    max_drawdown = 0.0
    daily_values = []
    cycle_log = []

    for day_idx in range(trade_start_idx, len(data)):
        row = data[day_idx]
        price = row['close']
        date = row['date']
        trade_day = day_idx - trade_start_idx

        holdings_krw = shares * price * exchange_rate
        total_value = cash + holdings_krw
        if total_value > peak_value:
            peak_value = total_value
        dd = (peak_value - total_value) / peak_value * 100
        if dd > max_drawdown:
            max_drawdown = dd

        daily_values.append({
            'date': date, 'value': total_value, 'cash': cash,
            'holdings': holdings_krw, 'shares': shares, 'price': price
        })

        # 지표 (전체 인덱스 기준)
        rsi = rsi_all[day_idx] if day_idx < len(rsi_all) else None
        _, _, _, pct_b = calculate_bb(closes_all, day_idx, 20, 2.0)

        # Take profit / half-sell
        if shares > 0 and avg_price > 0:
            return_rate = ((price - avg_price) / avg_price) * 100

            if half_sold:
                days_since = day_idx - half_sell_day
                should_sell = False
                reason = ""
                if return_rate >= 15.0:
                    should_sell = True
                    reason = f"R={return_rate:.1f}%>=15%"
                elif rsi is not None and rsi >= 65:
                    should_sell = True
                    reason = f"RSI={rsi:.1f}>=65"
                elif days_since >= 7:
                    should_sell = True
                    reason = f"7일경과"
                elif return_rate <= 3.0:
                    should_sell = True
                    reason = f"R={return_rate:.1f}%<=3%(하락방어)"

                if should_sell:
                    sell_value = shares * price * exchange_rate
                    cash += sell_value
                    total_trades += 1
                    cycles_completed += 1
                    cycle_log.append(f"  [{date}] 잔여매도({reason}): {shares:.4f}주 = {sell_value:,.0f}원 "
                                     f"(사이클 #{cycles_completed}, 소요 {trade_day - cycle_start_day}일)")
                    shares = 0.0
                    avg_price = 0.0
                    half_sold = False

                    if first_tp_day == 0:
                        first_tp_day = trade_day

                    current_seed = cash
                    rounds_used = 0.0
                    base_unit = current_seed / total_rounds
                    first_buy_done = False
                    continue

            elif return_rate >= 10.0:
                if rsi is not None and rsi < 50:
                    shares_to_sell = shares * 0.5
                    sell_value = shares_to_sell * price * exchange_rate
                    cash += sell_value
                    shares -= shares_to_sell
                    total_trades += 1
                    half_sold = True
                    half_sell_day = day_idx
                    cycle_log.append(f"  [{date}] 반매도(RSI={rsi:.1f}<50): R={return_rate:.1f}%, "
                                     f"{shares_to_sell:.4f}주 = {sell_value:,.0f}원 (잔여 대기)")
                    if first_tp_day == 0:
                        first_tp_day = trade_day
                    continue
                else:
                    sell_value = shares * price * exchange_rate
                    cash += sell_value
                    total_trades += 1
                    cycles_completed += 1
                    rsi_str = f"RSI={rsi:.1f}" if rsi else "RSI=N/A"
                    cycle_log.append(f"  [{date}] 전량익절({rsi_str}>=50): R={return_rate:.1f}%, "
                                     f"{shares:.4f}주 = {sell_value:,.0f}원 (사이클 #{cycles_completed}, 소요 {trade_day - cycle_start_day}일)")
                    shares = 0.0
                    avg_price = 0.0

                    if first_tp_day == 0:
                        first_tp_day = trade_day

                    current_seed = cash
                    rounds_used = 0.0
                    base_unit = current_seed / total_rounds
                    first_buy_done = False
                    continue

        # Buy logic
        if half_sold:
            continue

        if rounds_used >= total_rounds:
            continue

        if rsi is None or pct_b is None:
            w_final = 1.0
            w_rsi_val = 1.0
            w_bb_val = 1.0
        else:
            if rsi >= 70:
                w_rsi_val = 0.5
            elif rsi <= 30:
                w_rsi_val = 1.5
            else:
                w_rsi_val = 1.0

            if pct_b > 1.0:
                w_bb_val = 0.5
            elif pct_b < 0.0:
                w_bb_val = 2.0
            else:
                w_bb_val = 1.0

            w_final = w_rsi_val * w_bb_val
            w_final = max(0.25, min(3.0, w_final))

            remaining = total_rounds - rounds_used
            if remaining < 10:
                w_final = min(w_final, 1.5)

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
            cycle_start_day = trade_day

        cash -= buy_amount
        rounds_used += units_consumed
        total_trades += 1
        first_buy_done = True

        # 주요 매수만 로그
        if rounds_used <= 1.0 or int(rounds_used) % 10 == 0 or rounds_used >= total_rounds:
            rsi_str = f"RSI={rsi:.1f}" if rsi else "RSI=N/A"
            bb_str = f"%B={pct_b:.2f}" if pct_b else "%B=N/A"
            cycle_log.append(f"  [{date}] 매수 R{rounds_used:.1f}/45 W={w_final:.2f}({rsi_str},{bb_str}): "
                             f"${price:.2f} x {shares_to_buy:.4f}주 = {buy_amount:,.0f}원")

    final_price = data[-1]['close']
    holdings_krw = shares * final_price * exchange_rate
    final_value = cash + holdings_krw
    total_return = ((final_value - seed) / seed) * 100

    return RSIBBResult(
        total_return_pct=total_return,
        cycles_completed=cycles_completed,
        mdd_pct=max_drawdown,
        cash_remaining=cash,
        shares_remaining=shares,
        avg_price_remaining=avg_price,
        total_trades=total_trades,
        days_to_first_tp=first_tp_day if first_tp_day > 0 else (len(data) - trade_start_idx),
        final_value=final_value,
        rounds_used_final=rounds_used,
        daily_values=daily_values,
        cycle_log=cycle_log,
    )


# ============================================================================
# Buy & Hold Baseline
# ============================================================================

def calc_buy_and_hold(data: List[dict], trade_start_idx: int, seed: float, exchange_rate: float):
    """Returns (return_pct, mdd_pct, final_value)."""
    first_price = data[trade_start_idx]['close']
    last_price = data[-1]['close']

    shares = (seed / exchange_rate) / first_price
    final_value = shares * last_price * exchange_rate
    bnh_return = ((final_value - seed) / seed) * 100

    peak = first_price
    max_dd = 0.0
    for i in range(trade_start_idx, len(data)):
        p = data[i]['close']
        if p > peak:
            peak = p
        dd = (peak - p) / peak * 100
        if dd > max_dd:
            max_dd = dd

    return bnh_return, max_dd, final_value


# ============================================================================
# Output
# ============================================================================

def fmt_krw(val: float) -> str:
    return f"{val:,.0f}"

def fmt_pct(val: float) -> str:
    return f"{val:+.2f}%"

def print_price_summary(data: List[dict], trade_start_idx: int, ticker: str):
    """2025년 가격 요약."""
    start_price = data[trade_start_idx]['close']
    end_price = data[-1]['close']
    prices = [data[i]['close'] for i in range(trade_start_idx, len(data))]
    high = max(prices)
    low = min(prices)
    high_date = data[trade_start_idx + prices.index(high)]['date']
    low_date = data[trade_start_idx + prices.index(low)]['date']

    print(f"\n  {ticker} 2025년 가격 요약")
    print(f"  {'─'*50}")
    print(f"    시작가 (01/02): ${start_price:.2f}")
    print(f"    종가   (12/31): ${end_price:.2f}")
    print(f"    최고가:         ${high:.2f} ({high_date})")
    print(f"    최저가:         ${low:.2f} ({low_date})")
    print(f"    연간 수익률:    {((end_price - start_price) / start_price * 100):+.2f}%")
    print(f"    최고-최저 폭:   {((high - low) / low * 100):.1f}%")


def print_strategy_detail(name: str, result, seed: float, bnh_return: float, exchange_rate: float):
    """전략별 상세 결과."""
    print(f"\n  [{name}]")
    print(f"  {'─'*55}")
    print(f"    총수익률:        {fmt_pct(result.total_return_pct)}")
    print(f"    최종자산:        {fmt_krw(result.final_value)}원 (시드 {fmt_krw(seed)}원)")
    print(f"    손익금액:        {fmt_krw(result.final_value - seed)}원")
    print(f"    잔여현금:        {fmt_krw(result.cash_remaining)}원 ({result.cash_remaining / result.final_value * 100:.1f}%)")
    if result.shares_remaining > 0:
        print(f"    보유주식:        {result.shares_remaining:.4f}주 @ ${result.avg_price_remaining:.2f}")
        print(f"    보유평가액:      {fmt_krw(result.final_value - result.cash_remaining)}원")
    print(f"    완료 사이클:     {result.cycles_completed}회")
    print(f"    총 거래 횟수:    {result.total_trades}회")
    print(f"    MDD:             {fmt_pct(-result.mdd_pct)}")
    print(f"    첫 익절까지:     {result.days_to_first_tp}거래일")
    diff = result.total_return_pct - bnh_return
    print(f"    vs Buy&Hold:     {fmt_pct(diff)}p")

    if hasattr(result, 'rounds_used_final') and result.rounds_used_final > 0 and result.shares_remaining > 0:
        print(f"    사용 라운드:     {result.rounds_used_final:.1f}")

    # 거래 로그 (최대 20줄)
    if result.cycle_log:
        print(f"\n    [주요 거래 기록]")
        log_to_show = result.cycle_log[:30] if len(result.cycle_log) > 30 else result.cycle_log
        for line in log_to_show:
            print(f"    {line}")
        if len(result.cycle_log) > 30:
            print(f"    ... (외 {len(result.cycle_log) - 30}건)")


def print_comparison(results: dict, seed: float):
    """최종 비교 테이블."""
    print(f"\n{'='*95}")
    print(f"  2025년 최종 비교 테이블 (시드: {fmt_krw(seed)}원)")
    print(f"{'='*95}")

    header = f"  {'항목':>20} | {'Alpha Cycle V3':>16} | {'순정 무한매수':>14} | {'RSI+BB 커스텀':>14} | {'Buy & Hold':>14}"
    print(header)
    print(f"  {'─'*91}")

    for ticker in ['TQQQ', 'SOXL']:
        r = results[ticker]
        a, b, c = r['alpha'], r['infinite'], r['rsibb']
        bnh_ret, bnh_mdd, bnh_final = r['bnh']

        print(f"  {ticker:>20} |{'':>17} |{'':>15} |{'':>15} |{'':>15}")
        print(f"  {'총수익률':>18} | {fmt_pct(a.total_return_pct):>16} | {fmt_pct(b.total_return_pct):>14} | {fmt_pct(c.total_return_pct):>14} | {fmt_pct(bnh_ret):>14}")
        print(f"  {'최종자산(만원)':>16} | {a.final_value/10000:>14,.0f} | {b.final_value/10000:>12,.0f} | {c.final_value/10000:>12,.0f} | {bnh_final/10000:>12,.0f}")
        print(f"  {'손익(만원)':>18} | {(a.final_value-seed)/10000:>+14,.0f} | {(b.final_value-seed)/10000:>+12,.0f} | {(c.final_value-seed)/10000:>+12,.0f} | {(bnh_final-seed)/10000:>+12,.0f}")
        print(f"  {'완료사이클':>18} | {a.cycles_completed:>15}회 | {b.cycles_completed:>13}회 | {c.cycles_completed:>13}회 | {'N/A':>14}")
        print(f"  {'총거래':>20} | {a.total_trades:>15}회 | {b.total_trades:>13}회 | {c.total_trades:>13}회 | {'1':>13}회")
        print(f"  {'MDD':>20} | {fmt_pct(-a.mdd_pct):>16} | {fmt_pct(-b.mdd_pct):>14} | {fmt_pct(-c.mdd_pct):>14} | {fmt_pct(-bnh_mdd):>14}")
        print(f"  {'잔여현금(만원)':>16} | {a.cash_remaining/10000:>14,.0f} | {b.cash_remaining/10000:>12,.0f} | {c.cash_remaining/10000:>12,.0f} | {'0':>14}")
        print(f"  {'첫익절(거래일)':>16} | {a.days_to_first_tp:>15} | {b.days_to_first_tp:>13} | {c.days_to_first_tp:>13} | {'N/A':>14}")

        if ticker == 'TQQQ':
            print(f"  {'─'*91}")

    print(f"{'='*95}")

    # 순위
    print(f"\n  [순위 요약]")
    for ticker in ['TQQQ', 'SOXL']:
        r = results[ticker]
        strategies = [
            ('Alpha Cycle V3', r['alpha'].total_return_pct, r['alpha'].mdd_pct),
            ('순정 무한매수', r['infinite'].total_return_pct, r['infinite'].mdd_pct),
            ('RSI+BB 커스텀', r['rsibb'].total_return_pct, r['rsibb'].mdd_pct),
            ('Buy & Hold', r['bnh'][0], r['bnh'][1]),
        ]

        by_return = sorted(strategies, key=lambda x: x[1], reverse=True)
        by_mdd = sorted(strategies, key=lambda x: x[2])  # lower MDD is better

        print(f"\n  {ticker} 수익률 순위: ", end="")
        for i, (name, ret, _) in enumerate(by_return):
            print(f"{i+1}.{name}({fmt_pct(ret)})", end="  ")

        print(f"\n  {ticker} 안정성 순위: ", end="")
        for i, (name, _, mdd) in enumerate(by_mdd):
            print(f"{i+1}.{name}(MDD {fmt_pct(-mdd)})", end="  ")
    print()


# ============================================================================
# Main
# ============================================================================

def main():
    SEED = 30_000_000
    EXCHANGE_RATE = 1_350

    WARMUP_START = '2024-09-01'   # RSI(14) + BB(20) 안정화를 위한 충분한 워밍업
    TRADE_START = '2025-01-02'
    TRADE_END = '2025-12-31'

    tickers = {
        'TQQQ': '/home/dandy02/possible/stocktrading/tqqq_data.csv',
        'SOXL': '/home/dandy02/possible/stocktrading/soxl_data.csv',
    }

    print("=" * 95)
    print("  2025년 3-Strategy Backtest (정밀 분석)")
    print("  Alpha Cycle V3 vs 순정 무한매수법 vs RSI+BB 커스텀")
    print(f"  기간: {TRADE_START} ~ {TRADE_END} (워밍업: {WARMUP_START}~)")
    print(f"  시드: {fmt_krw(SEED)}원 | 환율: {fmt_krw(EXCHANGE_RATE)}원/USD")
    print("=" * 95)

    all_results = {}

    for ticker, path in tickers.items():
        raw_data = load_csv(path)
        data, trade_start_idx = filter_with_warmup(raw_data, WARMUP_START, TRADE_START, TRADE_END)

        trade_days = len(data) - trade_start_idx
        print(f"\n{'─'*95}")
        print(f"  {ticker}: 총 {len(data)}일 로드 (워밍업 {trade_start_idx}일 + 거래 {trade_days}일)")

        # 가격 요약
        print_price_summary(data, trade_start_idx, ticker)

        # Run strategies
        alpha_result = run_alpha_cycle_v3(data, trade_start_idx, SEED, EXCHANGE_RATE)
        infinite_result = run_infinite_buy(data, trade_start_idx, SEED, EXCHANGE_RATE)
        rsibb_result = run_rsi_bb(data, trade_start_idx, SEED, EXCHANGE_RATE)
        bnh = calc_buy_and_hold(data, trade_start_idx, SEED, EXCHANGE_RATE)

        # Print details
        print_strategy_detail("Strategy A: Alpha Cycle V3", alpha_result, SEED, bnh[0], EXCHANGE_RATE)
        print_strategy_detail("Strategy B: 순정 무한매수법 V2.1", infinite_result, SEED, bnh[0], EXCHANGE_RATE)
        print_strategy_detail("Strategy C: RSI+BB 커스텀", rsibb_result, SEED, bnh[0], EXCHANGE_RATE)

        print(f"\n  [Buy & Hold 기준]")
        print(f"    수익률: {fmt_pct(bnh[0])}, MDD: {fmt_pct(-bnh[1])}, 최종자산: {fmt_krw(bnh[2])}원")

        all_results[ticker] = {
            'alpha': alpha_result,
            'infinite': infinite_result,
            'rsibb': rsibb_result,
            'bnh': bnh,
        }

    # Final comparison
    print_comparison(all_results, SEED)

    print(f"\n  주의사항:")
    print(f"  - 실제 과거 데이터 기반이지만 슬리피지, 수수료, 세금 미반영")
    print(f"  - LOC 주문(장 시작가 기반)이 아닌 종가 기준 시뮬레이션")
    print(f"  - 환율 고정 {fmt_krw(EXCHANGE_RATE)}원/USD (실제는 변동)")
    print(f"  - 과거 수익이 미래 수익을 보장하지 않음")


if __name__ == '__main__':
    main()
