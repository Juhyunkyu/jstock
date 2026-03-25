"""
V2.2 무한매수법 백테스트 — TQQQ / SOXL 비교
V1 (현재 앱) vs V2.2 vs Buy & Hold
"""
from __future__ import annotations

import csv
import math
from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Optional, Tuple


# ── 설정 ──────────────────────────────────────────
SEED_KRW = 100_000_000       # 시드 1억 원
EXCHANGE_RATE = 1350          # 환율
DIVISIONS = 40                # 40분할
START_DATE = datetime(2025, 1, 1)
END_DATE = datetime(2026, 2, 1)

DATA_FILES = {
    "TQQQ": "/home/dandy02/possible/stocktrading/tqqq_data.csv",
    "SOXL": "/home/dandy02/possible/stocktrading/soxl_data.csv",
}


# ── 데이터 로드 ──────────────────────────────────
def load_prices(path: str) -> List[Tuple[datetime, float]]:
    rows: List[Tuple[datetime, float]] = []
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            dt = datetime.strptime(row["Date"][:10], "%Y-%m-%d")
            if START_DATE <= dt <= END_DATE:
                rows.append((dt, float(row["Close"])))
    rows.sort(key=lambda x: x[0])
    return rows


# ── V1 전략 ──────────────────────────────────────
@dataclass
class V1State:
    seed_usd: float
    cash_usd: float
    shares: float = 0.0
    avg_price: float = 0.0
    cycles: int = 1
    trades: int = 0
    peak_value: float = 0.0
    max_dd: float = 0.0
    unit_usd: float = 0.0
    monthly_values: dict = field(default_factory=dict)

    def __post_init__(self):
        self.unit_usd = self.seed_usd / DIVISIONS
        self.peak_value = self.cash_usd


def run_v1(prices: list[tuple[datetime, float]]) -> V1State:
    seed_usd = SEED_KRW / EXCHANGE_RATE
    st = V1State(seed_usd=seed_usd, cash_usd=seed_usd)

    for dt, close in prices:
        if st.shares == 0:
            # 첫 매수: 1유닛
            buy_shares = st.unit_usd / close
            if st.cash_usd >= st.unit_usd:
                st.shares += buy_shares
                st.avg_price = close
                st.cash_usd -= st.unit_usd
                st.trades += 1
        else:
            # 매수
            if close <= st.avg_price:
                amount = st.unit_usd  # 1유닛
            else:
                amount = st.unit_usd * 0.5  # 0.5유닛

            if st.cash_usd >= amount:
                buy_shares = amount / close
                st.avg_price = (st.shares * st.avg_price + buy_shares * close) / (st.shares + buy_shares)
                st.shares += buy_shares
                st.cash_usd -= amount
                st.trades += 1

            # 매도: +10% 전량
            if close >= st.avg_price * 1.10:
                sell_proceeds = st.shares * close
                st.cash_usd += sell_proceeds
                st.shares = 0
                st.avg_price = 0
                st.trades += 1
                # 새 사이클 (복리)
                st.seed_usd = st.cash_usd
                st.unit_usd = st.seed_usd / DIVISIONS
                st.cycles += 1

        # MDD / 월별
        total_val = st.cash_usd + st.shares * close
        if total_val > st.peak_value:
            st.peak_value = total_val
        dd = (st.peak_value - total_val) / st.peak_value if st.peak_value > 0 else 0
        if dd > st.max_dd:
            st.max_dd = dd

        month_key = dt.strftime("%Y-%m")
        st.monthly_values[month_key] = total_val

    return st


# ── V2.2 전략 ────────────────────────────────────
@dataclass
class V22State:
    seed_usd: float
    cash_usd: float
    shares: float = 0.0
    avg_price: float = 0.0
    cycles: int = 1
    trades: int = 0
    peak_value: float = 0.0
    max_dd: float = 0.0
    monthly_values: dict = field(default_factory=dict)
    # 사이클 내 잔여현금 추적
    cycle_seed_usd: float = 0.0
    cycle_cash_usd: float = 0.0

    def __post_init__(self):
        self.cycle_seed_usd = self.seed_usd
        self.cycle_cash_usd = self.cash_usd


def calc_t(cycle_seed: float, cycle_cash: float) -> int:
    """T값 = ceil(누적매수액 / (시드/40))"""
    invested = cycle_seed - cycle_cash
    if invested <= 0:
        return 0
    unit = cycle_seed / DIVISIONS
    return math.ceil(invested / unit)


def run_v22(prices: list[tuple[datetime, float]]) -> V22State:
    seed_usd = SEED_KRW / EXCHANGE_RATE
    st = V22State(seed_usd=seed_usd, cash_usd=seed_usd)

    for dt, close in prices:
        t_val = calc_t(st.cycle_seed_usd, st.cycle_cash_usd)
        unit_full = st.cycle_seed_usd / DIVISIONS   # 1회분
        unit_half = unit_full / 2                     # 반회분

        # ── 매도 주문 (매수와 동시에 걸어놓음) ──
        sold_all = False
        if st.shares > 0 and st.avg_price > 0:
            loc_sell_pct = (10 - t_val / 2) / 100
            loc_sell_price = st.avg_price * (1 + loc_sell_pct)
            limit_sell_price = st.avg_price * 1.10

            loc_sell_shares = st.shares * 0.25    # 1/4
            limit_sell_shares = st.shares * 0.75  # 3/4

            sell_proceeds = 0.0
            shares_sold = 0.0

            # LOC 매도: 설정가 <= 종가 이면 종가에 체결
            if loc_sell_price <= close:
                sell_proceeds += loc_sell_shares * close
                shares_sold += loc_sell_shares
                st.trades += 1

            # 지정가 매도: 설정가 <= 종가 이면 설정가에 체결
            if limit_sell_price <= close:
                sell_proceeds += limit_sell_shares * limit_sell_price
                shares_sold += limit_sell_shares
                st.trades += 1

            if shares_sold > 0:
                st.shares -= shares_sold
                st.cash_usd += sell_proceeds
                st.cycle_cash_usd += sell_proceeds

            # 전량 매도 → 새 사이클
            if st.shares < 1e-9:
                st.shares = 0
                st.avg_price = 0
                sold_all = True
                # 복리: 새 사이클
                st.cycle_seed_usd = st.cash_usd
                st.cycle_cash_usd = st.cash_usd
                st.seed_usd = st.cash_usd
                st.cycles += 1

        # ── 매수 주문 ──
        if not sold_all:
            # T값 재계산 (매도 후 변경 가능)
            t_val = calc_t(st.cycle_seed_usd, st.cycle_cash_usd)
            unit_full = st.cycle_seed_usd / DIVISIONS
            unit_half = unit_full / 2

            if st.shares == 0:
                # 첫 매수(T=0): 무조건 1회분 전액
                amount = min(unit_full, st.cash_usd)
                if amount > 0:
                    buy_shares = amount / close
                    st.avg_price = close
                    st.shares += buy_shares
                    st.cash_usd -= amount
                    st.cycle_cash_usd -= amount
                    st.trades += 1
            elif t_val < 20:
                # 전반전: A주문 + B주문
                # A주문: LOC 매수가 = 평단가, 종가 <= 평단가 이면 체결
                if close <= st.avg_price:
                    amount_a = min(unit_half, st.cash_usd)
                    if amount_a > 0:
                        buy_shares = amount_a / close
                        st.avg_price = (st.shares * st.avg_price + buy_shares * close) / (st.shares + buy_shares)
                        st.shares += buy_shares
                        st.cash_usd -= amount_a
                        st.cycle_cash_usd -= amount_a
                        st.trades += 1

                # B주문: LOC 매수가 = 평단가 * (1 + (10-T/2)/100)
                b_pct = (10 - t_val / 2) / 100
                b_limit = st.avg_price * (1 + b_pct)
                if close <= b_limit:
                    amount_b = min(unit_half, st.cash_usd)
                    if amount_b > 0:
                        buy_shares = amount_b / close
                        st.avg_price = (st.shares * st.avg_price + buy_shares * close) / (st.shares + buy_shares)
                        st.shares += buy_shares
                        st.cash_usd -= amount_b
                        st.cycle_cash_usd -= amount_b
                        st.trades += 1
            else:
                # 후반전 (T >= 20): 단일주문
                buy_pct = (10 - t_val / 2) / 100
                buy_limit = st.avg_price * (1 + buy_pct)
                if close <= buy_limit:
                    amount = min(unit_full, st.cash_usd)
                    if amount > 0:
                        buy_shares = amount / close
                        st.avg_price = (st.shares * st.avg_price + buy_shares * close) / (st.shares + buy_shares)
                        st.shares += buy_shares
                        st.cash_usd -= amount
                        st.cycle_cash_usd -= amount
                        st.trades += 1

        # MDD / 월별
        total_val = st.cash_usd + st.shares * close
        if total_val > st.peak_value:
            st.peak_value = total_val
        dd = (st.peak_value - total_val) / st.peak_value if st.peak_value > 0 else 0
        if dd > st.max_dd:
            st.max_dd = dd

        month_key = dt.strftime("%Y-%m")
        st.monthly_values[month_key] = total_val

    return st


# ── Buy & Hold ───────────────────────────────────
@dataclass
class BHState:
    initial_usd: float
    shares: float = 0.0
    entry_price: float = 0.0
    peak_value: float = 0.0
    max_dd: float = 0.0
    monthly_values: dict = field(default_factory=dict)


def run_bh(prices: list[tuple[datetime, float]]) -> BHState:
    seed_usd = SEED_KRW / EXCHANGE_RATE
    st = BHState(initial_usd=seed_usd)
    first_close = prices[0][1]
    st.shares = seed_usd / first_close
    st.entry_price = first_close
    st.peak_value = seed_usd

    for dt, close in prices:
        total_val = st.shares * close
        if total_val > st.peak_value:
            st.peak_value = total_val
        dd = (st.peak_value - total_val) / st.peak_value if st.peak_value > 0 else 0
        if dd > st.max_dd:
            st.max_dd = dd

        month_key = dt.strftime("%Y-%m")
        st.monthly_values[month_key] = total_val

    return st


# ── 출력 ─────────────────────────────────────────
def fmt_krw(usd: float) -> str:
    return f"{usd * EXCHANGE_RATE:,.0f}"


def fmt_pct(val: float) -> str:
    return f"{val:+.2f}%"


def print_results(ticker: str, prices: list[tuple[datetime, float]],
                  v1: V1State, v22: V22State, bh: BHState):
    seed_usd = SEED_KRW / EXCHANGE_RATE
    last_close = prices[-1][1]

    v1_total = v1.cash_usd + v1.shares * last_close
    v22_total = v22.cash_usd + v22.shares * last_close
    bh_total = bh.shares * last_close

    v1_ret = (v1_total / seed_usd - 1) * 100
    v22_ret = (v22_total / seed_usd - 1) * 100
    bh_ret = (bh_total / seed_usd - 1) * 100

    print(f"\n{'='*80}")
    print(f"  {ticker} 백테스트 결과")
    print(f"  기간: {prices[0][0].strftime('%Y-%m-%d')} ~ {prices[-1][0].strftime('%Y-%m-%d')} ({len(prices)}거래일)")
    print(f"  시드: {SEED_KRW:,}원 (${seed_usd:,.2f})")
    print(f"  시작가: ${prices[0][1]:.4f}  →  종료가: ${last_close:.4f}  (B&H 기준 {fmt_pct(bh_ret)})")
    print(f"{'='*80}")

    # 비교표
    print(f"\n{'─'*80}")
    print(f"  {'항목':<16} {'V1 (현재앱)':>20} {'V2.2':>20} {'Buy & Hold':>20}")
    print(f"{'─'*80}")
    print(f"  {'최종 자산(원)':<14} {fmt_krw(v1_total):>20} {fmt_krw(v22_total):>20} {fmt_krw(bh_total):>20}")
    print(f"  {'최종 자산($)':<14} {'$'+f'{v1_total:,.2f}':>20} {'$'+f'{v22_total:,.2f}':>20} {'$'+f'{bh_total:,.2f}':>20}")
    print(f"  {'수익률':<16} {fmt_pct(v1_ret):>20} {fmt_pct(v22_ret):>20} {fmt_pct(bh_ret):>20}")
    print(f"  {'MDD':<16} {fmt_pct(-v1.max_dd*100):>20} {fmt_pct(-v22.max_dd*100):>20} {fmt_pct(-bh.max_dd*100):>20}")
    print(f"  {'사이클 수':<15} {v1.cycles:>20} {v22.cycles:>20} {'N/A':>20}")
    print(f"  {'거래 수':<16} {v1.trades:>20} {v22.trades:>20} {'1':>20}")
    print(f"  {'잔여현금(원)':<13} {fmt_krw(v1.cash_usd):>20} {fmt_krw(v22.cash_usd):>20} {'0':>20}")
    print(f"  {'보유수량':<16} {v1.shares:>20.4f} {v22.shares:>20.4f} {bh.shares:>20.4f}")
    if v1.shares > 0:
        print(f"  {'평단가($)':<15} {'$'+f'{v1.avg_price:.4f}':>20} {'$'+f'{v22.avg_price:.4f}' if v22.shares > 0 else 'N/A':>20} {'$'+f'{bh.entry_price:.4f}':>20}")
    print(f"{'─'*80}")

    # 월별 수익률
    all_months = sorted(set(list(v1.monthly_values.keys()) +
                            list(v22.monthly_values.keys()) +
                            list(bh.monthly_values.keys())))

    print(f"\n  월별 자산가치 추이 (원)")
    print(f"  {'월':>8} {'V1':>18} {'V2.2':>18} {'B&H':>18}")
    print(f"  {'─'*62}")
    for m in all_months:
        v1_v = v1.monthly_values.get(m, 0)
        v22_v = v22.monthly_values.get(m, 0)
        bh_v = bh.monthly_values.get(m, 0)
        v1_r = (v1_v / seed_usd - 1) * 100
        v22_r = (v22_v / seed_usd - 1) * 100
        bh_r = (bh_v / seed_usd - 1) * 100
        print(f"  {m:>8} {fmt_krw(v1_v):>12} ({fmt_pct(v1_r):>7}) {fmt_krw(v22_v):>12} ({fmt_pct(v22_r):>7}) {fmt_krw(bh_v):>12} ({fmt_pct(bh_r):>7})")

    # 순위
    strategies = [("V1", v1_ret, v1.max_dd), ("V2.2", v22_ret, v22.max_dd), ("B&H", bh_ret, bh.max_dd)]
    by_ret = sorted(strategies, key=lambda x: x[1], reverse=True)
    by_mdd = sorted(strategies, key=lambda x: x[2])

    print(f"\n  수익률 순위: {' > '.join(f'{s[0]}({fmt_pct(s[1])})' for s in by_ret)}")
    print(f"  MDD 순위 (낮을수록 좋음): {' > '.join(f'{s[0]}({fmt_pct(-s[2]*100)})' for s in by_mdd)}")

    # V1 vs V2.2 차이
    diff_ret = v22_ret - v1_ret
    diff_mdd = (v22.max_dd - v1.max_dd) * 100
    print(f"\n  V1 vs V2.2 차이점 분석:")
    print(f"    수익률 차이: {fmt_pct(diff_ret)} ({'V2.2 우위' if diff_ret > 0 else 'V1 우위'})")
    print(f"    MDD 차이: {fmt_pct(diff_mdd)} ({'V1 안정적' if diff_mdd > 0 else 'V2.2 안정적'})")
    print(f"    사이클: V1 {v1.cycles}회 vs V2.2 {v22.cycles}회")
    print(f"    거래 수: V1 {v1.trades}회 vs V2.2 {v22.trades}회")
    if v22.cycles > v1.cycles:
        print(f"    → V2.2가 부분 매도(1/4+3/4)로 더 빈번한 사이클 완료")
    elif v22.cycles < v1.cycles:
        print(f"    → V1이 +10% 전량 매도로 더 빈번한 사이클 완료")
    else:
        print(f"    → 사이클 수 동일")


# ── 메인 ─────────────────────────────────────────
def main():
    print(f"{'#'*80}")
    print(f"#  V2.2 무한매수법 백테스트")
    print(f"#  시드: {SEED_KRW:,}원 | 환율: {EXCHANGE_RATE} | {DIVISIONS}분할")
    print(f"#  기간: {START_DATE.strftime('%Y-%m-%d')} ~ {END_DATE.strftime('%Y-%m-%d')}")
    print(f"{'#'*80}")

    for ticker, path in DATA_FILES.items():
        prices = load_prices(path)
        if not prices:
            print(f"\n  {ticker}: 데이터 없음!")
            continue

        v1 = run_v1(prices)
        v22 = run_v22(prices)
        bh = run_bh(prices)

        print_results(ticker, prices, v1, v22, bh)

    print(f"\n{'='*80}")
    print(f"  백테스트 완료")
    print(f"{'='*80}")


if __name__ == "__main__":
    main()
