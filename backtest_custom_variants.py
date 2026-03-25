"""
5-Strategy Backtest: Original 2 + Custom Variants 3
=====================================================
A: Smart Cycle (v7.0 원본)
B: Steady Cycle (순정 무한매수법)
C: Hybrid 50:50 (Smart + Steady 병행)
D: Smart + 2단계 가중매수 (-35% 이상 seed×0.00010)
E: Steady + 트레일링 스탑 (+10% 후 고점 -3%)

Data: TQQQ & SOXL 2025-01-02 ~ 2026-01-28
Seed: 100,000,000 KRW (1억) | Exchange rate: 1,350 KRW/USD
"""

import csv
from dataclasses import dataclass, field
from typing import List


def load_csv(path, start='2025-01-01', end='2026-02-01'):
    rows = []
    with open(path) as f:
        for r in csv.DictReader(f):
            d = r['Date'][:10]
            if start <= d <= end:
                rows.append({'date': d, 'open': float(r['Open']), 'high': float(r['High']),
                             'low': float(r['Low']), 'close': float(r['Close']), 'volume': int(float(r['Volume']))})
    rows.sort(key=lambda x: x['date'])
    return rows


@dataclass
class Result:
    name: str = ""
    total_return_pct: float = 0.0
    cycles_completed: int = 0
    mdd_pct: float = 0.0
    cash_remaining: float = 0.0
    total_trades: int = 0
    final_value: float = 0.0
    monthly_values: dict = field(default_factory=dict)
    avg_cash_ratio: float = 0.0


def _track(cash, shares, price, xr, seed, peak_val, max_dd, cash_ratios, monthly, month):
    hkrw = shares * price * xr
    tv = cash + hkrw
    if tv > peak_val:
        peak_val = tv
    dd = (peak_val - tv) / peak_val * 100
    if dd > max_dd:
        max_dd = dd
    cash_ratios.append(cash / tv if tv > 0 else 1.0)
    monthly[month] = {'value': tv, 'return_pct': (tv - seed) / seed * 100}
    return tv, peak_val, max_dd


def _vwap_buy(shares, avg_price, price, amount_krw, xr):
    stb = (amount_krw / xr) / price
    if shares > 0:
        tc = shares * avg_price + stb * price
        shares += stb
        avg_price = tc / shares
    else:
        shares = stb
        avg_price = price
    return shares, avg_price


# ============================================================================
# A: Smart Cycle (v7.0)
# ============================================================================
def run_smart(data, seed, xr, name="Smart Cycle", ppp_factor=0.00007, deep_factor=None, deep_thresh=-35.0):
    cash = seed; shares = 0.0; avg = 0.0; entry = 0.0
    ir = 0.20; ia = seed * ir; ppp = seed * ppp_factor
    ppp_d = seed * deep_factor if deep_factor else ppp
    panic_used = False; fb = False; cyc = 0; con = 0; trd = 0
    mo = {}; pv = seed; md = 0.0; cr = []

    for row in data:
        p = row['close']; m = row['date'][:7]
        _, pv, md = _track(cash, shares, p, xr, seed, pv, md, cr, mo, m)

        if not fb:
            ba = min(ia, cash)
            if ba > 0:
                shares, avg = _vwap_buy(0, 0, p, ba, xr)
                entry = p; cash -= ba; trd += 1; fb = True
            continue

        lr = ((p - entry) / entry) * 100 if entry > 0 else 0
        rr = ((p - avg) / avg) * 100 if avg > 0 and shares > 0 else 0

        st = max(10, 30 - con * 5)
        if rr >= st and shares > 0:
            cash += shares * p * xr; trd += 1; con += 1; cyc += 1
            ns = cash; ia = ns * ir; ppp = ns * ppp_factor
            ppp_d = ns * deep_factor if deep_factor else ppp
            shares = 0.0; avg = 0.0; entry = 0.0; panic_used = False; fb = False
            continue

        if rr >= 0 and shares > 0:
            ta = cash + shares * p * xr
            if cash < ta / 3:
                needed = ta / 3 - cash
                sts = min(needed / (p * xr), shares)
                if sts > 0:
                    cash += sts * p * xr; shares -= sts; trd += 1
            continue

        if lr <= -50 and not panic_used:
            ev = shares * p * xr
            pa = min(ev * 0.50, cash)
            if pa > 0:
                shares, avg = _vwap_buy(shares, avg, p, pa, xr)
                cash -= pa; trd += 1; panic_used = True

        if lr <= -20 and cash > 0:
            cur_ppp = ppp_d if (deep_factor and lr <= deep_thresh) else ppp
            ba = min(abs(lr) * cur_ppp, cash)
            if ba > 0:
                shares, avg = _vwap_buy(shares, avg, p, ba, xr)
                cash -= ba; trd += 1

    fv = cash + shares * data[-1]['close'] * xr
    return Result(name=name, total_return_pct=(fv-seed)/seed*100, cycles_completed=cyc,
                  mdd_pct=md, cash_remaining=cash, total_trades=trd, final_value=fv,
                  monthly_values=mo, avg_cash_ratio=sum(cr)/len(cr)*100 if cr else 0)


# ============================================================================
# B: Steady Cycle
# ============================================================================
def run_steady(data, seed, xr, name="Steady Cycle", trailing=False, trail_drop=-3.0):
    cash = seed; shares = 0.0; avg = 0.0; tr = 40; ru = 0.0; unit = seed / tr
    cyc = 0; trd = 0; fb = False; mo = {}; pv = seed; md = 0.0; cr = []
    t_active = False; t_peak = 0.0

    for row in data:
        p = row['close']; m = row['date'][:7]
        _, pv, md = _track(cash, shares, p, xr, seed, pv, md, cr, mo, m)

        if shares > 0 and avg > 0:
            rr = ((p - avg) / avg) * 100

            if trailing and t_active:
                if p > t_peak:
                    t_peak = p
                dfp = ((p - t_peak) / t_peak) * 100
                sell = dfp <= trail_drop or rr < 10.0
                if sell:
                    cash += shares * p * xr; trd += 1; cyc += 1
                    shares = 0.0; avg = 0.0; ru = 0.0; unit = cash / tr; fb = False
                    t_active = False; t_peak = 0.0
                    continue
            elif rr >= 10.0:
                if trailing:
                    t_active = True; t_peak = p
                    continue
                else:
                    cash += shares * p * xr; trd += 1; cyc += 1
                    shares = 0.0; avg = 0.0; ru = 0.0; unit = cash / tr; fb = False
                    continue

        if ru >= tr:
            continue

        if not fb or shares == 0:
            ba = unit; uc = 1.0
        elif p <= avg:
            ba = unit; uc = 1.0
        else:
            ba = unit * 0.5; uc = 0.5

        if ru + uc > tr:
            rem = tr - ru
            if rem <= 0: continue
            ba = unit * rem; uc = rem

        ba = min(ba, cash)
        if ba <= 0: continue

        shares, avg = _vwap_buy(shares, avg, p, ba, xr)
        cash -= ba; ru += uc; trd += 1; fb = True

    fv = cash + shares * data[-1]['close'] * xr
    return Result(name=name, total_return_pct=(fv-seed)/seed*100, cycles_completed=cyc,
                  mdd_pct=md, cash_remaining=cash, total_trades=trd, final_value=fv,
                  monthly_values=mo, avg_cash_ratio=sum(cr)/len(cr)*100 if cr else 0)


# ============================================================================
# C: Hybrid 50:50 (inline combined tracking for accurate MDD)
# ============================================================================
def run_hybrid(data, seed, xr, name="Hybrid 50:50"):
    h = seed / 2

    # Smart state
    s_cash = h; s_sh = 0.0; s_avg = 0.0; s_ent = 0.0
    s_ia = h * 0.20; s_ppp = h * 0.00007; s_panic = False; s_fb = False; s_con = 0; s_cyc = 0; s_trd = 0

    # Steady state
    t_cash = h; t_sh = 0.0; t_avg = 0.0; t_ru = 0.0; t_unit = h / 40; t_fb = False; t_cyc = 0; t_trd = 0

    pv = seed; md = 0.0; mo = {}; cr = []

    for row in data:
        p = row['close']; m = row['date'][:7]

        # === Smart half ===
        if not s_fb:
            ba = min(s_ia, s_cash)
            if ba > 0:
                s_sh, s_avg = _vwap_buy(0, 0, p, ba, xr)
                s_ent = p; s_cash -= ba; s_trd += 1; s_fb = True
        else:
            lr = ((p - s_ent) / s_ent) * 100 if s_ent > 0 else 0
            rr = ((p - s_avg) / s_avg) * 100 if s_avg > 0 and s_sh > 0 else 0
            st = max(10, 30 - s_con * 5)
            did_tp = False
            if rr >= st and s_sh > 0:
                s_cash += s_sh * p * xr; s_trd += 1; s_con += 1; s_cyc += 1
                ns = s_cash; s_ia = ns * 0.20; s_ppp = ns * 0.00007
                s_sh = 0.0; s_avg = 0.0; s_ent = 0.0; s_panic = False; s_fb = False
                did_tp = True
            elif rr >= 0 and s_sh > 0:
                ta = s_cash + s_sh * p * xr
                if s_cash < ta / 3:
                    needed = ta / 3 - s_cash
                    sts = min(needed / (p * xr), s_sh)
                    if sts > 0:
                        s_cash += sts * p * xr; s_sh -= sts; s_trd += 1
            if not did_tp:
                if lr <= -50 and not s_panic:
                    ev = s_sh * p * xr
                    pa = min(ev * 0.50, s_cash)
                    if pa > 0:
                        s_sh, s_avg = _vwap_buy(s_sh, s_avg, p, pa, xr)
                        s_cash -= pa; s_trd += 1; s_panic = True
                if lr <= -20 and s_cash > 0:
                    ba = min(abs(lr) * s_ppp, s_cash)
                    if ba > 0:
                        s_sh, s_avg = _vwap_buy(s_sh, s_avg, p, ba, xr)
                        s_cash -= ba; s_trd += 1

        # === Steady half ===
        sold_steady = False
        if t_sh > 0 and t_avg > 0:
            rr_t = ((p - t_avg) / t_avg) * 100
            if rr_t >= 10.0:
                t_cash += t_sh * p * xr; t_trd += 1; t_cyc += 1
                t_sh = 0.0; t_avg = 0.0; t_ru = 0.0; t_unit = t_cash / 40; t_fb = False
                sold_steady = True

        if not sold_steady and t_ru < 40:
            if not t_fb or t_sh == 0:
                ba_t = t_unit; uc = 1.0
            elif p <= t_avg:
                ba_t = t_unit; uc = 1.0
            else:
                ba_t = t_unit * 0.5; uc = 0.5
            if t_ru + uc > 40:
                rem = 40 - t_ru
                if rem > 0: ba_t = t_unit * rem; uc = rem
                else: ba_t = 0; uc = 0
            ba_t = min(ba_t, t_cash)
            if ba_t > 0:
                t_sh, t_avg = _vwap_buy(t_sh, t_avg, p, ba_t, xr)
                t_cash -= ba_t; t_ru += uc; t_trd += 1; t_fb = True

        # Combined tracking
        tv = (s_cash + s_sh * p * xr) + (t_cash + t_sh * p * xr)
        tc = s_cash + t_cash
        if tv > pv: pv = tv
        dd = (pv - tv) / pv * 100
        if dd > md: md = dd
        cr.append(tc / tv if tv > 0 else 1.0)
        mo[m] = {'value': tv, 'return_pct': (tv - seed) / seed * 100}

    fp = data[-1]['close']
    fv = (s_cash + s_sh * fp * xr) + (t_cash + t_sh * fp * xr)
    return Result(name=name, total_return_pct=(fv-seed)/seed*100,
                  cycles_completed=s_cyc + t_cyc, mdd_pct=md,
                  cash_remaining=s_cash + t_cash, total_trades=s_trd + t_trd,
                  final_value=fv, monthly_values=mo,
                  avg_cash_ratio=sum(cr)/len(cr)*100 if cr else 0)


# ============================================================================
# Output
# ============================================================================
def fmt(v): return f"{v:,.0f}"
def fpct(v): return f"{v:+.2f}%"
def fman(v): return f"{v/10000:,.1f}만"


def main():
    SEED = 100_000_000
    XR = 1_350

    tickers = {
        'TQQQ': '/home/dandy02/possible/stocktrading/tqqq_data.csv',
        'SOXL': '/home/dandy02/possible/stocktrading/soxl_data.csv',
    }

    print("=" * 140)
    print("  5-Strategy Backtest: 원본 2 + 커스텀 변형 3")
    print(f"  기간: 2025-01 ~ 2026-01 | 시드: {fmt(SEED)}원 | 환율: {XR}원/USD")
    print("  A: Smart Cycle (v7.0)  B: Steady Cycle  C: Hybrid 50:50  D: Smart 2단계 가중  E: Steady 트레일링")
    print("=" * 140)

    for ticker, path in tickers.items():
        data = load_csv(path)
        fp = data[0]['close']; lp = data[-1]['close']; chg = (lp-fp)/fp*100

        results = [
            run_smart(data, SEED, XR, "Smart(원본)"),
            run_steady(data, SEED, XR, "Steady(원본)"),
            run_hybrid(data, SEED, XR, "Hybrid 50:50"),
            run_smart(data, SEED, XR, "Smart 2단계", ppp_factor=0.00007, deep_factor=0.00010, deep_thresh=-35.0),
            run_steady(data, SEED, XR, "Steady 트레일링", trailing=True, trail_drop=-3.0),
        ]
        bnh = Result(name="Buy&Hold")
        bnh_shares = (SEED / XR) / fp
        bnh.total_return_pct = chg
        bnh.final_value = SEED * (1 + chg / 100)
        # BnH MDD
        pk = fp; mdd_bnh = 0.0; bnh_mo = {}
        for row in data:
            pp = row['close']
            if pp > pk: pk = pp
            dd = (pk - pp) / pk * 100
            if dd > mdd_bnh: mdd_bnh = dd
            v = bnh_shares * pp * XR
            bnh_mo[row['date'][:7]] = {'value': v, 'return_pct': (v - SEED) / SEED * 100}
        bnh.mdd_pct = mdd_bnh
        bnh.monthly_values = bnh_mo
        results.append(bnh)

        # Print table
        print(f"\n{'━'*140}")
        print(f"  🏷️ {ticker} | {data[0]['date']} ~ {data[-1]['date']} | {len(data)}일 | ${fp:.2f} → ${lp:.2f} ({chg:+.1f}%)")
        print(f"{'━'*140}")

        names = [r.name for r in results]
        w = 18
        h = f"  {'':>16}"
        for n in names:
            h += f" │ {n:>{w}}"
        print(h)
        print(f"  {'─'*16}" + ("─┼─" + "─"*w) * len(results))

        rows_info = [
            ("총 수익률",    [fpct(r.total_return_pct) for r in results]),
            ("최종 자산",    [fman(r.final_value) for r in results]),
            ("잔여 현금",    [fman(r.cash_remaining) for r in results]),
            ("완료 사이클",  [f"{r.cycles_completed}회" if r.cycles_completed > 0 else "N/A" for r in results]),
            ("총 거래",      [f"{r.total_trades}회" for r in results]),
            ("MDD",          [fpct(-r.mdd_pct) for r in results]),
            ("평균 현금비율",[f"{r.avg_cash_ratio:.0f}%" for r in results]),
        ]
        for label, vals in rows_info:
            row = f"  {label:>16}"
            for v in vals:
                row += f" │ {v:>{w}}"
            print(row)

        # Monthly
        print(f"\n  📊 월별 수익률:")
        months = sorted(set().union(*[r.monthly_values.keys() for r in results]))
        mh = f"  {'월':>8}"
        for n in names:
            mh += f" │ {n:>{w}}"
        print(mh)
        print(f"  {'─'*8}" + ("─┼─" + "─"*w) * len(results))
        for mo in months:
            row = f"  {mo:>8}"
            for r in results:
                mv = r.monthly_values.get(mo, {})
                row += f" │ {fpct(mv.get('return_pct', 0)):>{w}}"
            print(row)

        # Rankings
        print(f"\n  🏆 [{ticker}] 수익률 순위:")
        for i, r in enumerate(sorted(results, key=lambda x: -x.total_return_pct), 1):
            star = " ★" if i == 1 else ""
            print(f"    {i}위: {r.name:>18s} {fpct(r.total_return_pct)}{star}")

        print(f"\n  🛡️ [{ticker}] MDD 순위 (낮을수록 안전):")
        for i, r in enumerate(sorted(results, key=lambda x: x.mdd_pct), 1):
            star = " ★" if i == 1 else ""
            print(f"    {i}위: {r.name:>18s} {fpct(-r.mdd_pct)}{star}")

        print(f"\n  ⚖️ [{ticker}] 위험조정수익률 (수익/MDD, 높을수록 효율적):")
        scored = sorted(results, key=lambda r: -(r.total_return_pct / r.mdd_pct if r.mdd_pct > 0 else 0))
        for i, r in enumerate(scored, 1):
            ratio = r.total_return_pct / r.mdd_pct if r.mdd_pct > 0 else 0
            star = " ★" if i == 1 else ""
            print(f"    {i}위: {r.name:>18s} {ratio:.3f} ({fpct(r.total_return_pct)} / MDD {fpct(-r.mdd_pct)}){star}")

        # Variant analysis
        a, b, c, d, e, bnh = results
        print(f"\n  📋 [{ticker}] 변형 전략 vs 원본 비교:")
        print(f"    Hybrid vs Smart원본:      수익 {c.total_return_pct - a.total_return_pct:+.1f}%p, MDD {-(c.mdd_pct - a.mdd_pct):+.1f}%p")
        print(f"    Hybrid vs Steady원본:     수익 {c.total_return_pct - b.total_return_pct:+.1f}%p, MDD {-(c.mdd_pct - b.mdd_pct):+.1f}%p")
        print(f"    Smart2단계 vs Smart원본:  수익 {d.total_return_pct - a.total_return_pct:+.1f}%p, MDD {-(d.mdd_pct - a.mdd_pct):+.1f}%p")
        print(f"    Steady트레일링 vs Steady: 수익 {e.total_return_pct - b.total_return_pct:+.1f}%p, MDD {-(e.mdd_pct - b.mdd_pct):+.1f}%p")

    print(f"\n{'='*140}")
    print(f"  백테스트 완료!")
    print(f"{'='*140}")


if __name__ == "__main__":
    main()
