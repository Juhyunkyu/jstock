"""
Steady Cycle 1사이클 백테스트 (구현 로직 검증용)
=================================================
2022년 랜덤 시작일에서 V1/V2.2/V3.0 각 1사이클만 실행.
앱 구현과 동일한 로직(T값 소수점 올림, V3.0 전반전 T<10, 반복리 수익/40)으로 테스트.

시드: 1억 | 환율: 1,350
"""

import csv, math, random
from datetime import datetime
from dataclasses import dataclass

SEED_KRW = 100_000_000
XR = 1350

DATA = {
    "TQQQ": "/home/dandy02/possible/stocktrading/tqqq_data.csv",
    "SOXL": "/home/dandy02/possible/stocktrading/soxl_data.csv",
}


def load(path, start, end):
    rows = []
    with open(path) as f:
        for r in csv.DictReader(f):
            d = r['Date'][:10]
            if start <= d <= end:
                rows.append((d, float(r['Close'])))
    rows.sort()
    return rows


def vwap(shares, avg, new_shares, price):
    if shares + new_shares == 0:
        return 0
    return (shares * avg + new_shares * price) / (shares + new_shares)


def t_ceil(raw):
    """소수점 둘째 자리에서 올림 (앱 구현과 동일)"""
    return math.ceil(raw * 10) / 10


# ============================================================================
# V1: Simple (40분할)
# ============================================================================
def run_v1(prices):
    seed = SEED_KRW / XR
    cash = seed; sh = 0.0; avg = 0.0; unit = seed / 40
    trades = 0; days = 0

    log = []
    for date, p in prices:
        days += 1
        action = ""

        if sh == 0:
            amt = min(unit, cash)
            if amt > 0:
                bs = amt / p; sh = bs; avg = p; cash -= amt; trades += 1
                action = f"매수(첫) {bs:.1f}주 @${p:.2f}"
        else:
            # 익절 체크
            ret = (p - avg) / avg * 100 if avg > 0 else 0
            if ret >= 10:
                sell_amt = sh * p
                profit_pct = ret
                cash += sell_amt; sh = 0; avg = 0; trades += 1
                action = f"★ 익절! +{profit_pct:.1f}% → 새시드 ${cash:.0f}"
                unit = cash / 40
                log.append((date, days, p, action, cash + sh * p))
                return cash, 0, days, trades, log

            amt = unit if p <= avg else unit * 0.5
            amt = min(amt, cash)
            if amt > 0:
                bs = amt / p; avg = vwap(sh, avg, bs, p); sh += bs; cash -= amt; trades += 1
                tag = "A+B" if p <= avg else "B만"
                action = f"매수({tag}) {bs:.1f}주 @${p:.2f}"

        total = cash + sh * p
        if action:
            log.append((date, days, p, action, total))

    return cash, sh, days, trades, log


# ============================================================================
# V2.2: Original (40분할, offsetA=10, offsetB=0.5)
# ============================================================================
def run_v22(prices):
    seed = SEED_KRW / XR
    cash = seed; sh = 0.0; avg = 0.0
    c_seed = seed; c_cash = seed
    trades = 0; days = 0
    offset_a = 10; offset_b = 0.5  # V2.2 기본: 10 - 0.5*T

    log = []
    for date, p in prices:
        days += 1
        actions = []

        invested = c_seed - c_cash
        unit = c_seed / 40
        t = t_ceil(invested / unit) if unit > 0 and invested > 0 else 0
        offset_pct = (offset_a - offset_b * t) / 100

        # 매도 (매수와 동시)
        sold_all = False
        if sh > 0 and avg > 0:
            loc_sell_p = avg * (1 + offset_pct)
            lim_sell_p = avg * 1.10

            proceeds = 0.0; sold_sh = 0.0

            if p >= loc_sell_p:
                s = sh * 0.25
                proceeds += s * p; sold_sh += s; trades += 1
                actions.append(f"매도LOC¼ {s:.1f}주 @${p:.2f}")

            if p >= lim_sell_p:
                s = sh * 0.75
                proceeds += s * lim_sell_p; sold_sh += s; trades += 1
                actions.append(f"매도지정¾ {s:.1f}주 @${lim_sell_p:.2f}")

            if sold_sh > 0:
                sh -= sold_sh; cash += proceeds; c_cash += proceeds

            if sh < 1e-9:
                sh = 0; avg = 0; sold_all = True
                profit_pct = (cash - seed) / seed * 100
                actions.append(f"★ 사이클완료! 자산 ${cash:.0f} ({profit_pct:+.1f}%)")
                log.append((date, days, p, t, " | ".join(actions), cash))
                return cash, 0, days, trades, log

        # 매수
        if not sold_all:
            invested = c_seed - c_cash
            t = t_ceil(invested / unit) if unit > 0 and invested > 0 else 0
            offset_pct = (offset_a - offset_b * t) / 100
            half = unit / 2

            if sh == 0:
                amt = min(unit, cash)
                if amt > 0:
                    bs = amt / p; sh = bs; avg = p; cash -= amt; c_cash -= amt; trades += 1
                    actions.append(f"매수(첫) {bs:.1f}주 @${p:.2f}")
            elif t < 20:  # 전반전
                # A: 평단 LOC
                if p <= avg:
                    amt = min(half, cash)
                    if amt > 0:
                        bs = amt / p; avg = vwap(sh, avg, bs, p); sh += bs
                        cash -= amt; c_cash -= amt; trades += 1
                        actions.append(f"매수A(평단) {bs:.1f}주")
                # B: 오프셋 LOC
                b_lim = avg * (1 + offset_pct)
                if p <= b_lim:
                    amt = min(half, cash)
                    if amt > 0:
                        bs = amt / p; avg = vwap(sh, avg, bs, p); sh += bs
                        cash -= amt; c_cash -= amt; trades += 1
                        actions.append(f"매수B(+{offset_pct*100:.1f}%) {bs:.1f}주")
            else:  # 후반전
                buy_lim = avg * (1 + offset_pct)
                if p <= buy_lim:
                    amt = min(unit, cash)
                    if amt > 0:
                        bs = amt / p; avg = vwap(sh, avg, bs, p); sh += bs
                        cash -= amt; c_cash -= amt; trades += 1
                        actions.append(f"매수단일({offset_pct*100:+.1f}%) {bs:.1f}주")

        total = cash + sh * p
        if actions:
            log.append((date, days, p, t, " | ".join(actions), total))

    return cash, sh, days, trades, log


# ============================================================================
# V3.0: Aggressive (20분할, 반복리, 전반전 T<10)
# ============================================================================
def run_v30(prices, ticker="TQQQ"):
    seed = SEED_KRW / XR
    cash = seed; sh = 0.0; avg = 0.0
    c_seed = seed; c_cash = seed
    divisions = 20
    trades = 0; days = 0
    sell_profit_total = 0.0  # 반복리용 누적 매도 순수익

    # V3.0 종목별 오프셋
    if ticker == "SOXL":
        offset_a = 20; offset_b = 2.0; lim_tp = 1.20
    else:
        offset_a = 15; offset_b = 1.5; lim_tp = 1.15

    log = []
    for date, p in prices:
        days += 1
        actions = []

        invested = c_seed - c_cash
        unit = c_seed / divisions
        # V3.0 반복리: T값 보정
        raw_invested = invested + sell_profit_total if sell_profit_total > 0 else invested
        t = t_ceil(raw_invested / unit) if unit > 0 and raw_invested > 0 else 0
        t = min(t, divisions)

        offset_pct = (offset_a - offset_b * t) / 100

        # 반복리 매수금 계산
        if sell_profit_total > 0:
            adj_unit = unit + (sell_profit_total / 40)  # 수익/40 추가
        else:
            adj_unit = unit

        # 매도
        sold_all = False
        if sh > 0 and avg > 0:
            loc_sell_p = avg * (1 + offset_pct)
            lim_sell_p = avg * lim_tp

            proceeds = 0.0; sold_sh = 0.0

            if p >= loc_sell_p:
                s = sh * 0.25
                cost = s * avg  # 원가
                profit = s * p - cost  # 순수익
                proceeds += s * p; sold_sh += s; trades += 1
                sell_profit_total += profit  # 반복리 누적
                actions.append(f"매도LOC¼ {s:.1f}주 (수익${profit:.0f})")

            if p >= lim_sell_p:
                s = sh * 0.75
                cost = s * avg
                profit = s * lim_sell_p - cost
                proceeds += s * lim_sell_p; sold_sh += s; trades += 1
                sell_profit_total += profit
                actions.append(f"매도지정¾ {s:.1f}주")

            if sold_sh > 0:
                sh -= sold_sh; cash += proceeds; c_cash += proceeds

            if sh < 1e-9:
                sh = 0; avg = 0; sold_all = True
                profit_pct = (cash - seed) / seed * 100
                actions.append(f"★ 사이클완료! 자산 ${cash:.0f} ({profit_pct:+.1f}%)")
                log.append((date, days, p, t, " | ".join(actions), cash))
                return cash, 0, days, trades, log, sell_profit_total

        # 매수
        if not sold_all:
            invested = c_seed - c_cash
            raw_invested = invested + sell_profit_total if sell_profit_total > 0 else invested
            t = t_ceil(raw_invested / unit) if unit > 0 and raw_invested > 0 else 0
            t = min(t, divisions)
            offset_pct = (offset_a - offset_b * t) / 100
            half = adj_unit / 2

            if sh == 0:
                amt = min(adj_unit, cash)
                if amt > 0:
                    bs = amt / p; sh = bs; avg = p; cash -= amt; c_cash -= amt; trades += 1
                    actions.append(f"매수(첫) {bs:.1f}주 @${p:.2f}")
            elif t < 10:  # V3.0 전반전 (T < 10)
                # A: 오프셋 LOC (V3.0: A=오프셋)
                a_lim = avg * (1 + offset_pct)
                if p <= a_lim:
                    amt = min(half, cash)
                    if amt > 0:
                        bs = amt / p; avg = vwap(sh, avg, bs, p); sh += bs
                        cash -= amt; c_cash -= amt; trades += 1
                        actions.append(f"매수A(오프셋{offset_pct*100:+.1f}%) {bs:.1f}주")
                # B: 평단 LOC (V3.0: B=평단)
                if p <= avg:
                    amt = min(half, cash)
                    if amt > 0:
                        bs = amt / p; avg = vwap(sh, avg, bs, p); sh += bs
                        cash -= amt; c_cash -= amt; trades += 1
                        actions.append(f"매수B(평단) {bs:.1f}주")
            else:  # V3.0 후반전 (T >= 10)
                buy_lim = avg * (1 + offset_pct)
                if p <= buy_lim:
                    amt = min(adj_unit, cash)
                    if amt > 0:
                        bs = amt / p; avg = vwap(sh, avg, bs, p); sh += bs
                        cash -= amt; c_cash -= amt; trades += 1
                        actions.append(f"매수단일({offset_pct*100:+.1f}%) {bs:.1f}주")

        total = cash + sh * p
        if actions:
            log.append((date, days, p, t, " | ".join(actions), total))

    return cash, sh, days, trades, log, sell_profit_total


# ============================================================================
# Main
# ============================================================================
def main():
    # 2022년 랜덤 시작일 (3~6월 중)
    random.seed(42)  # 재현 가능
    start_month = random.choice(["03", "04", "05", "06"])
    start_day = random.randint(1, 28)
    start_date = f"2022-{start_month}-{start_day:02d}"
    end_date = "2024-01-01"  # 충분한 기간

    print(f"{'='*80}")
    print(f"Steady Cycle 1사이클 백테스트 (구현 로직 검증)")
    print(f"시작일: {start_date} | 시드: {SEED_KRW/10000:.0f}만원 | 환율: {XR}")
    print(f"{'='*80}")

    for ticker in ["TQQQ", "SOXL"]:
        prices = load(DATA[ticker], start_date, end_date)
        if not prices:
            print(f"\n{ticker}: 데이터 없음")
            continue

        print(f"\n{'─'*80}")
        print(f"  {ticker} | 시작가: ${prices[0][1]:.2f} ({prices[0][0]})")
        print(f"{'─'*80}")

        # V1
        cash1, sh1, days1, trd1, log1 = run_v1(prices)
        final1 = (cash1 + sh1 * prices[-1][1]) * XR
        ret1 = (final1 - SEED_KRW) / SEED_KRW * 100
        completed1 = sh1 == 0

        print(f"\n  ── V1 Simple (40분할) ──")
        print(f"  {'사이클 완료!' if completed1 else '미완료 (진행중)'}")
        print(f"  거래일: {days1}일 | 거래: {trd1}건")
        print(f"  최종자산: {final1/10000:,.0f}만원 ({ret1:+.1f}%)")
        if log1:
            print(f"  마지막 5건:")
            for entry in log1[-5:]:
                print(f"    {entry[0]} D{entry[1]:3d} ${entry[2]:.2f} | {entry[3]}")

        # V2.2
        cash2, sh2, days2, trd2, log2 = run_v22(prices)
        final2 = (cash2 + sh2 * prices[-1][1]) * XR
        ret2 = (final2 - SEED_KRW) / SEED_KRW * 100
        completed2 = sh2 == 0

        print(f"\n  ── V2.2 Original (40분할, LOC) ──")
        print(f"  {'사이클 완료!' if completed2 else '미완료 (진행중)'}")
        print(f"  거래일: {days2}일 | 거래: {trd2}건")
        print(f"  최종자산: {final2/10000:,.0f}만원 ({ret2:+.1f}%)")
        if log2:
            print(f"  마지막 5건:")
            for entry in log2[-5:]:
                print(f"    {entry[0]} D{entry[1]:3d} T={entry[3]:.1f} ${entry[2]:.2f} | {entry[4]}")

        # V3.0
        result3 = run_v30(prices, ticker)
        cash3, sh3, days3, trd3, log3, sp3 = result3
        final3 = (cash3 + sh3 * prices[-1][1]) * XR
        ret3 = (final3 - SEED_KRW) / SEED_KRW * 100
        completed3 = sh3 == 0

        tp_label = "+15%" if ticker == "TQQQ" else "+20%"
        print(f"\n  ── V3.0 Aggressive (20분할, {tp_label}, 반복리) ──")
        print(f"  {'사이클 완료!' if completed3 else '미완료 (진행중)'}")
        print(f"  거래일: {days3}일 | 거래: {trd3}건")
        print(f"  누적 매도순수익: ${sp3:.0f} (반복리 추가분: ${sp3/40:.1f}/회)")
        print(f"  최종자산: {final3/10000:,.0f}만원 ({ret3:+.1f}%)")
        if log3:
            print(f"  마지막 5건:")
            for entry in log3[-5:]:
                print(f"    {entry[0]} D{entry[1]:3d} T={entry[3]:.1f} ${entry[2]:.2f} | {entry[4]}")

        # 비교 요약
        print(f"\n  ── 비교 요약 ──")
        print(f"  {'버전':<15} {'최종자산':>10} {'수익률':>8} {'거래':>5} {'완료':>4}")
        print(f"  {'─'*45}")
        print(f"  {'V1 Simple':<15} {final1/10000:>8,.0f}만 {ret1:>+7.1f}% {trd1:>5}건 {'✅' if completed1 else '❌'}")
        print(f"  {'V2.2 Original':<15} {final2/10000:>8,.0f}만 {ret2:>+7.1f}% {trd2:>5}건 {'✅' if completed2 else '❌'}")
        print(f"  {'V3.0 Aggr':<15} {final3/10000:>8,.0f}만 {ret3:>+7.1f}% {trd3:>5}건 {'✅' if completed3 else '❌'}")


if __name__ == "__main__":
    main()
