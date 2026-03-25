"""
Steady Cycle 전버전 백테스트: V1 vs V2.2 vs V3.0 vs Buy&Hold
==============================================================
구간 1: 2025 상승장 (2025-01 ~ 2026-01)
구간 2: 2022 하락장 (2022-01 ~ 2023-01)
구간 3: 2022-2023 하락→회복 (2022-01 ~ 2024-01)

시드: 1억 | 환율: 1,350
"""

import csv, math
from datetime import datetime
from dataclasses import dataclass, field
from typing import List, Tuple


SEED_KRW = 100_000_000
XR = 1350

DATA = {
    "TQQQ": "/home/dandy02/possible/stocktrading/tqqq_data.csv",
    "SOXL": "/home/dandy02/possible/stocktrading/soxl_data.csv",
}

PERIODS = [
    ("2025 상승장", "2025-01-01", "2026-02-01"),
    ("2022 하락장", "2022-01-01", "2023-01-01"),
    ("2022-2023 하락→회복", "2022-01-01", "2024-01-01"),
]


def load(path, start, end):
    rows = []
    with open(path) as f:
        for r in csv.DictReader(f):
            d = r['Date'][:10]
            if start <= d <= end:
                rows.append((d, float(r['Close'])))
    rows.sort()
    return rows


@dataclass
class R:
    name: str = ""
    final_usd: float = 0.0
    cash_usd: float = 0.0
    shares: float = 0.0
    cycles: int = 0
    trades: int = 0
    mdd: float = 0.0
    monthly: dict = field(default_factory=dict)


def vwap(shares, avg, new_shares, price):
    if shares + new_shares == 0:
        return 0
    return (shares * avg + new_shares * price) / (shares + new_shares)


# ============================================================================
# V1: Simple (현재 앱)
# ============================================================================
def run_v1(prices, ticker=""):
    seed = SEED_KRW / XR
    cash = seed; sh = 0.0; avg = 0.0; unit = seed / 40
    cyc = 0; trd = 0; pk = seed; md = 0.0; mo = {}

    for date, p in prices:
        if sh == 0:
            amt = min(unit, cash)
            if amt > 0:
                bs = amt / p; sh = bs; avg = p; cash -= amt; trd += 1
        else:
            amt = unit if p <= avg else unit * 0.5
            amt = min(amt, cash)
            if amt > 0:
                bs = amt / p; avg = vwap(sh, avg, bs, p); sh += bs; cash -= amt; trd += 1
            if sh > 0 and p >= avg * 1.10:
                cash += sh * p; sh = 0; avg = 0; trd += 1; cyc += 1
                unit = cash / 40

        tv = cash + sh * p
        if tv > pk: pk = tv
        dd = (pk - tv) / pk if pk > 0 else 0
        if dd > md: md = dd
        mo[date[:7]] = tv

    return R(name="V1(현재)", final_usd=cash + sh * prices[-1][1], cash_usd=cash,
             shares=sh, cycles=cyc, trades=trd, mdd=md, monthly=mo)


# ============================================================================
# V2.2: Original (라오어 2022)
# ============================================================================
def run_v22(prices, ticker=""):
    seed = SEED_KRW / XR
    cash = seed; sh = 0.0; avg = 0.0
    c_seed = seed; c_cash = seed
    cyc = 0; trd = 0; pk = seed; md = 0.0; mo = {}

    for date, p in prices:
        # T값
        invested = c_seed - c_cash
        unit = c_seed / 40
        t = math.ceil(invested / unit) if unit > 0 and invested > 0 else 0

        # 매도 (매수와 동시)
        sold_all = False
        if sh > 0 and avg > 0:
            loc_pct = (10 - t / 2) / 100
            loc_sell_p = avg * (1 + loc_pct)
            lim_sell_p = avg * 1.10

            proceeds = 0.0; sold_sh = 0.0

            # 1/4 LOC 매도
            if loc_sell_p <= p:
                s = sh * 0.25
                proceeds += s * p; sold_sh += s; trd += 1

            # 3/4 지정가 매도
            if lim_sell_p <= p:
                s = sh * 0.75
                proceeds += s * lim_sell_p; sold_sh += s; trd += 1

            if sold_sh > 0:
                sh -= sold_sh; cash += proceeds; c_cash += proceeds

            if sh < 1e-9:
                sh = 0; avg = 0; sold_all = True
                c_seed = cash; c_cash = cash; cyc += 1

        # 매수
        if not sold_all:
            invested = c_seed - c_cash
            unit = c_seed / 40
            t = math.ceil(invested / unit) if unit > 0 and invested > 0 else 0
            half = unit / 2

            if sh == 0:
                amt = min(unit, cash)
                if amt > 0:
                    bs = amt / p; sh = bs; avg = p; cash -= amt; c_cash -= amt; trd += 1
            elif t < 20:
                # A: 평단가 LOC
                if p <= avg:
                    amt = min(half, cash)
                    if amt > 0:
                        bs = amt / p; avg = vwap(sh, avg, bs, p); sh += bs
                        cash -= amt; c_cash -= amt; trd += 1
                # B: 평단 + (10-T/2)%
                b_pct = (10 - t / 2) / 100
                b_lim = avg * (1 + b_pct)
                if p <= b_lim:
                    amt = min(half, cash)
                    if amt > 0:
                        bs = amt / p; avg = vwap(sh, avg, bs, p); sh += bs
                        cash -= amt; c_cash -= amt; trd += 1
            else:
                # 후반전: 단일 (10-T/2)%
                buy_pct = (10 - t / 2) / 100
                buy_lim = avg * (1 + buy_pct)
                if p <= buy_lim:
                    amt = min(unit, cash)
                    if amt > 0:
                        bs = amt / p; avg = vwap(sh, avg, bs, p); sh += bs
                        cash -= amt; c_cash -= amt; trd += 1

        tv = cash + sh * p
        if tv > pk: pk = tv
        dd = (pk - tv) / pk if pk > 0 else 0
        if dd > md: md = dd
        mo[date[:7]] = tv

    return R(name="V2.2(정통)", final_usd=cash + sh * prices[-1][1], cash_usd=cash,
             shares=sh, cycles=cyc, trades=trd, mdd=md, monthly=mo)


# ============================================================================
# V3.0: Aggressive (라오어 2024)
# ============================================================================
def run_v30(prices, ticker="TQQQ"):
    seed = SEED_KRW / XR
    cash = seed; sh = 0.0; avg = 0.0
    c_seed = seed; c_cash = seed
    divisions = 20  # V3.0은 20분할
    cyc = 0; trd = 0; pk = seed; md = 0.0; mo = {}

    # V3.0 종목별 지정가 익절
    lim_tp = 1.15 if ticker == "TQQQ" else 1.20  # TQQQ +15%, SOXL +20%

    for date, p in prices:
        invested = c_seed - c_cash
        unit = c_seed / divisions
        t = math.ceil(invested / unit) if unit > 0 and invested > 0 else 0

        # 매도
        sold_all = False
        if sh > 0 and avg > 0:
            loc_pct = (15 - 1.5 * t) / 100  # V3.0 공식
            loc_sell_p = avg * (1 + loc_pct)
            lim_sell_p = avg * lim_tp

            proceeds = 0.0; sold_sh = 0.0

            # 1/4 LOC 매도
            if loc_sell_p <= p:
                s = sh * 0.25
                proceeds += s * p; sold_sh += s; trd += 1

            # 3/4 지정가 매도
            if lim_sell_p <= p:
                s = sh * 0.75
                proceeds += s * lim_sell_p; sold_sh += s; trd += 1

            if sold_sh > 0:
                sh -= sold_sh; cash += proceeds; c_cash += proceeds
                # V3.0 복리: 수익금 즉시 반영 → unit 재계산
                # c_seed는 유지, c_cash 증가 → T값 감소 → 더 공격적 매수 가능

            if sh < 1e-9:
                sh = 0; avg = 0; sold_all = True
                c_seed = cash; c_cash = cash; cyc += 1

        # 매수
        if not sold_all:
            invested = c_seed - c_cash
            unit = c_seed / divisions
            t = math.ceil(invested / unit) if unit > 0 and invested > 0 else 0
            half = unit / 2

            if sh == 0:
                amt = min(unit, cash)
                if amt > 0:
                    bs = amt / p; sh = bs; avg = p; cash -= amt; c_cash -= amt; trd += 1
            elif t <= 19:
                # V3.0 전반전 (T ≤ 19)
                # A주문: (15-1.5T)% LOC 매수
                a_pct = (15 - 1.5 * t) / 100
                a_lim = avg * (1 + a_pct)
                if p <= a_lim:
                    amt = min(half, cash)
                    if amt > 0:
                        bs = amt / p; avg = vwap(sh, avg, bs, p); sh += bs
                        cash -= amt; c_cash -= amt; trd += 1
                # B주문: 평단가 LOC 매수
                if p <= avg:
                    amt = min(half, cash)
                    if amt > 0:
                        bs = amt / p; avg = vwap(sh, avg, bs, p); sh += bs
                        cash -= amt; c_cash -= amt; trd += 1
            else:
                # V3.0 후반전 (T > 19)
                buy_pct = (15 - 1.5 * t) / 100
                buy_lim = avg * (1 + buy_pct)
                if p <= buy_lim:
                    amt = min(unit, cash)
                    if amt > 0:
                        bs = amt / p; avg = vwap(sh, avg, bs, p); sh += bs
                        cash -= amt; c_cash -= amt; trd += 1

        tv = cash + sh * p
        if tv > pk: pk = tv
        dd = (pk - tv) / pk if pk > 0 else 0
        if dd > md: md = dd
        mo[date[:7]] = tv

    tp_label = "+15%" if ticker == "TQQQ" else "+20%"
    return R(name=f"V3.0(공격)", final_usd=cash + sh * prices[-1][1], cash_usd=cash,
             shares=sh, cycles=cyc, trades=trd, mdd=md, monthly=mo)


# ============================================================================
# Buy & Hold
# ============================================================================
def run_bnh(prices):
    seed = SEED_KRW / XR
    sh = seed / prices[0][1]
    pk = seed; md = 0.0; mo = {}
    for date, p in prices:
        tv = sh * p
        if tv > pk: pk = tv
        dd = (pk - tv) / pk if pk > 0 else 0
        if dd > md: md = dd
        mo[date[:7]] = tv
    return R(name="Buy&Hold", final_usd=sh * prices[-1][1], mdd=md, monthly=mo)


# ============================================================================
# Output
# ============================================================================
def fpct(v): return f"{v:+.2f}%"
def fkrw(usd): return f"{usd * XR / 10000:,.0f}만"
def fman(krw): return f"{krw / 10000:,.0f}만"


def print_results(ticker, period_name, prices, results):
    seed = SEED_KRW / XR
    fp = prices[0][1]; lp = prices[-1][1]
    chg = (lp - fp) / fp * 100

    print(f"\n{'━'*120}")
    print(f"  {ticker} — {period_name} | {prices[0][0]} ~ {prices[-1][0]} | {len(prices)}거래일")
    print(f"  ${fp:.2f} → ${lp:.2f} ({chg:+.1f}%)")
    print(f"{'━'*120}")

    w = 16
    names = [r.name for r in results]
    print(f"  {'':>14}" + "".join(f" │ {n:>{w}}" for n in names))
    print(f"  {'─'*14}" + ("─┼─" + "─"*w) * len(results))

    rows = [
        ("수익률", [fpct((r.final_usd / seed - 1) * 100) for r in results]),
        ("최종자산", [fkrw(r.final_usd) for r in results]),
        ("잔여현금", [fkrw(r.cash_usd) for r in results]),
        ("사이클", [f"{r.cycles}회" if r.cycles > 0 else "N/A" for r in results]),
        ("거래수", [f"{r.trades}회" if r.trades > 0 else "1회" for r in results]),
        ("MDD", [fpct(-r.mdd * 100) for r in results]),
    ]
    for label, vals in rows:
        print(f"  {label:>14}" + "".join(f" │ {v:>{w}}" for v in vals))

    # Monthly (condensed - show every 3 months for long periods)
    months = sorted(set().union(*[r.monthly.keys() for r in results]))
    show_all = len(months) <= 15
    print(f"\n  📊 월별 수익률:")
    mh = f"  {'':>8}" + "".join(f" │ {n:>{w}}" for n in names)
    print(mh)
    print(f"  {'─'*8}" + ("─┼─" + "─"*w) * len(results))
    for i, m in enumerate(months):
        if show_all or i % 3 == 0 or i == len(months) - 1:
            row = f"  {m:>8}"
            for r in results:
                v = r.monthly.get(m, seed)
                row += f" │ {fpct((v/seed-1)*100):>{w}}"
            print(row)

    # Rankings
    scored = [(r, (r.final_usd / seed - 1) * 100) for r in results]

    print(f"\n  🏆 수익률: ", end="")
    for i, (r, ret) in enumerate(sorted(scored, key=lambda x: -x[1])):
        print(f"{'★ ' if i==0 else ''}{r.name}({fpct(ret)})", end="  ")

    print(f"\n  🛡️ MDD:   ", end="")
    for i, r in enumerate(sorted(results, key=lambda x: x.mdd)):
        print(f"{'★ ' if i==0 else ''}{r.name}({fpct(-r.mdd*100)})", end="  ")

    print(f"\n  ⚖️ 효율(수익/MDD): ", end="")
    eff = [(r, ((r.final_usd/seed-1)*100) / (r.mdd*100) if r.mdd > 0 else 0) for r in results]
    for i, (r, e) in enumerate(sorted(eff, key=lambda x: -x[1])):
        print(f"{'★ ' if i==0 else ''}{r.name}({e:.2f})", end="  ")
    print()


def main():
    print("=" * 120)
    print("  Steady Cycle 전버전 백테스트: V1 vs V2.2 vs V3.0 vs Buy&Hold")
    print(f"  시드: {SEED_KRW/10000:,.0f}만원 | 환율: {XR}원/USD")
    print(f"  V1: 40분할, +10% 전량매도")
    print(f"  V2.2: 40분할, (10-T/2)%, 매일 1/4 LOC + 3/4 지정가 매도")
    print(f"  V3.0: 20분할, (15-1.5T)%, TQQQ +15% / SOXL +20% 지정가")
    print("=" * 120)

    for period_name, start, end in PERIODS:
        print(f"\n\n{'#'*120}")
        print(f"  ▶ {period_name} ({start[:4]}~{end[:4]})")
        print(f"{'#'*120}")

        for ticker, path in DATA.items():
            prices = load(path, start, end)
            if not prices:
                print(f"  {ticker}: 데이터 없음"); continue

            v1 = run_v1(prices, ticker)
            v22 = run_v22(prices, ticker)
            v30 = run_v30(prices, ticker)
            bnh = run_bnh(prices)

            print_results(ticker, period_name, prices, [v1, v22, v30, bnh])

    # ============================================================================
    # 최종 종합 분석
    # ============================================================================
    print(f"\n\n{'='*120}")
    print(f"  💡 전버전 종합 분석")
    print(f"{'='*120}")
    print("""
  ┌──────────────────────────────────────────────────────────────────────┐
  │                    V1 (현재)    V2.2 (정통)    V3.0 (공격)          │
  ├──────────────────────────────────────────────────────────────────────┤
  │  분할 수          40            40              20                  │
  │  익절 방식        +10% 전량     1/4 LOC + 3/4   1/4 LOC + 3/4      │
  │  매수 공식        평단 비교     (10-T/2)%       (15-1.5T)%          │
  │  복리 방식        사이클 종료   사이클 종료      부분매도 즉시반영   │
  │  TQQQ 지정가      +10%         +10%             +15%               │
  │  SOXL 지정가      +10%         +10%             +20%               │
  ├──────────────────────────────────────────────────────────────────────┤
  │  상승장 적합도     ★★★          ★★              ★★★★               │
  │  하락장 방어력     ★★           ★★★             ★                  │
  │  단순성            ★★★★★        ★★              ★★                 │
  │  복리 효과         ★★★          ★★              ★★★★               │
  └──────────────────────────────────────────────────────────────────────┘

  추천 시나리오:
  - V1: 입문자, 단순한 기계적 실행 선호
  - V2.2: 하락장 방어 + LOC 가격 전략 활용 (중급자)
  - V3.0: 상승장 공격적 복리 추구, 높은 변동성 감수 (상급자)
""")

    print(f"{'='*120}")
    print(f"  백테스트 완료!")
    print(f"{'='*120}")


if __name__ == "__main__":
    main()
