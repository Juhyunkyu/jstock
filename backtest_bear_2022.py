"""
2022년 하락장 백테스트 — Alpha Cycle V3 vs 순정 무한매수법
=========================================================
2022년은 나스닥이 연초~연말 지속 하락한 대표적 베어마켓
TQQQ: $42.78 → $8.65 (-79.8%)
SOXL: $72.10 → $9.67 (-86.6%)

핵심 질문: 하락장에서 익절이 나는가? 얼마나 걸리나? 자산은 어떻게 되나?
"""

import csv
from dataclasses import dataclass, field
from typing import List, Optional


def load_csv(path: str) -> List[dict]:
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


def filter_with_warmup(data, warmup_start, trade_start, trade_end):
    filtered = [row for row in data if warmup_start <= row['date'] <= trade_end]
    trade_start_idx = 0
    for i, row in enumerate(filtered):
        if row['date'] >= trade_start:
            trade_start_idx = i
            break
    return filtered, trade_start_idx


# ============================================================================
# Alpha Cycle V3 (상세 로그 포함)
# ============================================================================

@dataclass
class DetailResult:
    name: str = ""
    total_return_pct: float = 0.0
    cycles_completed: int = 0
    mdd_pct: float = 0.0
    cash_remaining: float = 0.0
    shares_remaining: float = 0.0
    avg_price_remaining: float = 0.0
    final_value: float = 0.0
    total_trades: int = 0
    first_tp_day: int = 0
    unrealized_pnl_pct: float = 0.0
    monthly_values: List[dict] = field(default_factory=list)
    events: List[str] = field(default_factory=list)


def run_alpha_v3(data, si, seed, er) -> DetailResult:
    cash = seed; shares = 0.0; avg_price = 0.0
    initial_entry_price = 0.0; initial_entry_amount = seed * 0.20
    current_seed = seed; panic_used = False; first_buy_done = False
    cycles = 0; consec = 0; trades = 0; first_tp = 0
    peak_value = seed; max_dd = 0.0
    events = []; monthly = []
    last_month = ""

    for day_idx in range(si, len(data)):
        price = data[day_idx]['close']; date = data[day_idx]['date']
        td = day_idx - si
        hkrw = shares * price * er; tv = cash + hkrw
        if tv > peak_value: peak_value = tv
        dd = (peak_value - tv) / peak_value * 100
        if dd > max_dd: max_dd = dd

        # 월별 기록
        month = date[:7]
        if month != last_month:
            monthly.append({'month': month, 'value': tv, 'cash': cash, 'holdings': hkrw,
                           'shares': shares, 'price': price, 'return_pct': ((tv - seed) / seed) * 100})
            last_month = month

        if not first_buy_done:
            buy_amt = min(initial_entry_amount, cash)
            if buy_amt > 0:
                stb = (buy_amt / er) / price
                shares = stb; avg_price = price; initial_entry_price = price
                cash -= buy_amt; trades += 1; first_buy_done = True
                events.append(f"[{date}] D{td:>3d} 초기진입 ${price:.2f} x {stb:.2f}주 = {buy_amt:,.0f}원")
            continue

        loss_rate = ((price - initial_entry_price) / initial_entry_price) * 100 if initial_entry_price > 0 else 0
        rr = ((price - avg_price) / avg_price) * 100 if avg_price > 0 and shares > 0 else 0
        hkrw = shares * price * er; tv = cash + hkrw; eval_amt = hkrw

        # [1] Take Profit
        tp_thr = max(10, 30 - consec * 5)
        if rr >= tp_thr and shares > 0:
            sell_pct = max(10, 30 - consec * 5)
            sell_ratio = sell_pct / 100.0
            sts = shares * sell_ratio
            sv = sts * price * er
            cash += sv; shares -= sts; trades += 1; consec += 1
            if not first_tp: first_tp = td
            events.append(f"[{date}] D{td:>3d} ★ 익절#{consec} R={rr:.1f}%>={tp_thr}%, 매도{sell_pct}% = {sv:,.0f}원")
            if shares < 0.0001:
                cycles += 1
                events.append(f"[{date}]      ═══ 사이클#{cycles} 완료 (시드 {current_seed:,.0f} → {cash:,.0f}) ═══")
                current_seed = cash; initial_entry_amount = cash * 0.20
                shares = 0.0; avg_price = 0.0; initial_entry_price = 0.0
                panic_used = False; first_buy_done = False; consec = 0
            continue

        if rr < 0: consec = 0

        # [2] Cash Secure
        if rr >= 0 and shares > 0:
            ta = cash + shares * price * er
            if cash < ta / 3:
                needed = ta / 3 - cash
                sts = min(needed / (price * er), shares)
                if sts > 0:
                    sv = sts * price * er; cash += sv; shares -= sts; trades += 1
                    events.append(f"[{date}] D{td:>3d} 현금확보 R={rr:.1f}%, 매도{sts:.2f}주 = {sv:,.0f}원")
            continue

        # [3] Panic Buy
        if loss_rate <= -50 and not panic_used:
            pa = min(eval_amt * 0.50, cash)
            if pa > 0:
                stb = (pa / er) / price
                tc = shares * avg_price + stb * price
                shares += stb; avg_price = tc / shares; cash -= pa; trades += 1; panic_used = True
                events.append(f"[{date}] D{td:>3d} 패닉바이 L={loss_rate:.1f}%, {pa:,.0f}원 (평단 ${avg_price:.2f})")

        # [4] Weighted Buy
        if loss_rate <= -20:
            ba = min(initial_entry_amount * abs(loss_rate) / 1000, cash)
            if ba > 0:
                stb = (ba / er) / price
                tc = shares * avg_price + stb * price
                shares += stb; avg_price = tc / shares; cash -= ba; trades += 1
                # 주요 시점만 로그
                if td % 20 == 0 or loss_rate <= -50:
                    events.append(f"[{date}] D{td:>3d} 가중매수 L={loss_rate:.1f}%, {ba:,.0f}원 (평단 ${avg_price:.2f})")

    fp = data[-1]['close']
    hkrw = shares * fp * er; fv = cash + hkrw
    ur = ((fp - avg_price) / avg_price * 100) if avg_price > 0 and shares > 0 else 0

    return DetailResult(
        name="Alpha Cycle V3", total_return_pct=((fv - seed) / seed) * 100,
        cycles_completed=cycles, mdd_pct=max_dd, cash_remaining=cash,
        shares_remaining=shares, avg_price_remaining=avg_price,
        final_value=fv, total_trades=trades,
        first_tp_day=first_tp if first_tp else (len(data) - si),
        unrealized_pnl_pct=ur, monthly_values=monthly, events=events)


# ============================================================================
# 순정 무한매수법 V2.1 (상세 로그 포함)
# ============================================================================

def run_infinite_buy(data, si, seed, er) -> DetailResult:
    cash = seed; shares = 0.0; avg_price = 0.0
    current_seed = seed; total_rounds = 40
    rounds_used = 0.0; unit_amount = seed / total_rounds
    cycles = 0; trades = 0; first_tp = 0; first_buy = False
    cycle_start = 0
    peak_value = seed; max_dd = 0.0
    events = []; monthly = []
    last_month = ""

    for day_idx in range(si, len(data)):
        price = data[day_idx]['close']; date = data[day_idx]['date']
        td = day_idx - si
        hkrw = shares * price * er; tv = cash + hkrw
        if tv > peak_value: peak_value = tv
        dd = (peak_value - tv) / peak_value * 100
        if dd > max_dd: max_dd = dd

        month = date[:7]
        if month != last_month:
            monthly.append({'month': month, 'value': tv, 'cash': cash, 'holdings': hkrw,
                           'shares': shares, 'price': price, 'return_pct': ((tv - seed) / seed) * 100})
            last_month = month

        # Take profit
        if shares > 0 and avg_price > 0:
            rr = ((price - avg_price) / avg_price) * 100
            if rr >= 10.0:
                sv = shares * price * er; cash += sv; trades += 1; cycles += 1
                events.append(f"[{date}] D{td:>3d} ★ 익절 R={rr:.1f}%, 전량매도 {shares:.2f}주 = {sv:,.0f}원 "
                             f"(사이클#{cycles}, R{rounds_used:.0f}/40, {td-cycle_start}일)")
                shares = 0.0; avg_price = 0.0
                if not first_tp: first_tp = td
                current_seed = cash; rounds_used = 0.0
                unit_amount = current_seed / total_rounds; first_buy = False
                continue

        if rounds_used >= total_rounds:
            continue

        if not first_buy or shares == 0:
            ba = unit_amount * 1.0; uc = 1.0; ot = "초기"
        else:
            if price <= avg_price:
                ba = unit_amount * 1.0; uc = 1.0; ot = "A+B(평단하)"
            else:
                ba = unit_amount * 0.5; uc = 0.5; ot = "B만(평단상)"

        if rounds_used + uc > total_rounds:
            rem = total_rounds - rounds_used
            if rem <= 0: continue
            ba = unit_amount * rem; uc = rem

        if ba > cash: ba = cash
        if ba <= 0: continue

        stb = (ba / er) / price
        if shares > 0:
            tc = shares * avg_price + stb * price; shares += stb; avg_price = tc / shares
        else:
            shares = stb; avg_price = price; cycle_start = td

        cash -= ba; rounds_used += uc; trades += 1; first_buy = True

        # 주요 시점 로그
        if rounds_used <= 1.0 or rounds_used >= total_rounds or int(rounds_used) % 10 == 0:
            events.append(f"[{date}] D{td:>3d} 매수 R{rounds_used:.0f}/40 {ot}: ${price:.2f} (평단 ${avg_price:.2f})")

    fp = data[-1]['close']
    hkrw = shares * fp * er; fv = cash + hkrw
    ur = ((fp - avg_price) / avg_price * 100) if avg_price > 0 and shares > 0 else 0

    return DetailResult(
        name="순정 무한매수법", total_return_pct=((fv - seed) / seed) * 100,
        cycles_completed=cycles, mdd_pct=max_dd, cash_remaining=cash,
        shares_remaining=shares, avg_price_remaining=avg_price,
        final_value=fv, total_trades=trades,
        first_tp_day=first_tp if first_tp else (len(data) - si),
        unrealized_pnl_pct=ur, monthly_values=monthly, events=events)


# ============================================================================
# Output
# ============================================================================

def fmt_krw(v): return f"{v:,.0f}"
def fmt_pct(v): return f"{v:+.2f}%"


def print_detail(r: DetailResult, seed: float):
    print(f"\n  [{r.name}]")
    print(f"  {'━'*65}")
    print(f"    총수익률:        {fmt_pct(r.total_return_pct)}")
    print(f"    최종자산:        {fmt_krw(r.final_value)}원 (시드 {fmt_krw(seed)}원)")
    print(f"    손익금액:        {fmt_krw(r.final_value - seed)}원")
    print(f"    잔여현금:        {fmt_krw(r.cash_remaining)}원 ({r.cash_remaining/max(r.final_value,1)*100:.1f}%)")
    if r.shares_remaining > 0.001:
        print(f"    보유주식:        {r.shares_remaining:.4f}주 @ ${r.avg_price_remaining:.2f}")
        print(f"    미실현손익:      {fmt_pct(r.unrealized_pnl_pct)}")
    print(f"    완료사이클:      {r.cycles_completed}회")
    if r.cycles_completed > 0:
        print(f"    첫 익절:         {r.first_tp_day}거래일째")
    else:
        print(f"    첫 익절:         없음 (1년간 익절 0회)")
    print(f"    총거래:          {r.total_trades}회")
    print(f"    MDD:             {fmt_pct(-r.mdd_pct)}")

    # 월별 자산 추이
    if r.monthly_values:
        print(f"\n    [월별 자산 추이]")
        print(f"    {'월':>8} | {'총자산(만원)':>12} | {'수익률':>8} | {'현금(만원)':>10} | {'주가':>8}")
        print(f"    {'─'*58}")
        for m in r.monthly_values:
            print(f"    {m['month']:>8} | {m['value']/10000:>10,.0f} | {fmt_pct(m['return_pct']):>8} | "
                  f"{m['cash']/10000:>8,.0f} | ${m['price']:.2f}")

    # 주요 이벤트
    if r.events:
        print(f"\n    [주요 이벤트]")
        for ev in r.events:
            print(f"    {ev}")


def main():
    SEED = 30_000_000
    ER = 1_350

    # 2022년 하락장
    WARMUP = '2021-09-01'
    START = '2022-01-03'
    END = '2022-12-30'

    tickers = {
        'TQQQ': '/home/dandy02/possible/stocktrading/tqqq_data.csv',
        'SOXL': '/home/dandy02/possible/stocktrading/soxl_data.csv',
    }

    print("=" * 80)
    print("  2022년 하락장 백테스트")
    print("  Alpha Cycle V3 vs 순정 무한매수법")
    print(f"  기간: {START} ~ {END}")
    print(f"  시드: {fmt_krw(SEED)}원 | 환율: {fmt_krw(ER)}원/USD")
    print("=" * 80)

    for ticker, path in tickers.items():
        raw = load_csv(path)
        data, si = filter_with_warmup(raw, WARMUP, START, END)
        td = len(data) - si

        sp = data[si]['close']; ep = data[-1]['close']
        bnh = ((ep - sp) / sp) * 100

        # 최고가/최저가
        prices = [data[i]['close'] for i in range(si, len(data))]
        hi = max(prices); lo = min(prices)
        hi_d = data[si + prices.index(hi)]['date']
        lo_d = data[si + prices.index(lo)]['date']

        print(f"\n{'━'*80}")
        print(f"  {ticker} 2022년 — {td}거래일")
        print(f"  시작: ${sp:.2f} → 종료: ${ep:.2f} (B&H: {fmt_pct(bnh)})")
        print(f"  최고: ${hi:.2f} ({hi_d}) | 최저: ${lo:.2f} ({lo_d})")
        print(f"  낙폭: {((hi-lo)/hi*100):.1f}% (고점→저점)")
        print(f"{'━'*80}")

        alpha = run_alpha_v3(data, si, SEED, ER)
        infinite = run_infinite_buy(data, si, SEED, ER)

        print_detail(alpha, SEED)
        print_detail(infinite, SEED)

        # 비교
        print(f"\n  {'─'*70}")
        print(f"  [비교 요약]")
        print(f"  {'항목':>16} | {'Alpha Cycle V3':>18} | {'순정 무한매수':>18} | {'Buy & Hold':>14}")
        print(f"  {'─'*70}")
        print(f"  {'총수익률':>14} | {fmt_pct(alpha.total_return_pct):>18} | {fmt_pct(infinite.total_return_pct):>18} | {fmt_pct(bnh):>14}")
        print(f"  {'최종자산(만원)':>12} | {alpha.final_value/10000:>16,.0f} | {infinite.final_value/10000:>16,.0f} | {SEED*(1+bnh/100)/10000:>12,.0f}")
        print(f"  {'MDD':>16} | {fmt_pct(-alpha.mdd_pct):>18} | {fmt_pct(-infinite.mdd_pct):>18} | {fmt_pct(-((hi-lo)/hi*100)):>14}")
        print(f"  {'완료사이클':>14} | {alpha.cycles_completed:>17}회 | {infinite.cycles_completed:>17}회 | {'N/A':>14}")
        print(f"  {'첫익절':>16} | ", end="")
        if alpha.cycles_completed > 0:
            print(f"{alpha.first_tp_day:>16}일 | ", end="")
        else:
            print(f"{'없음':>17} | ", end="")
        if infinite.cycles_completed > 0:
            print(f"{infinite.first_tp_day:>16}일 | ", end="")
        else:
            print(f"{'없음':>17} | ", end="")
        print(f"{'N/A':>14}")
        if alpha.shares_remaining > 0.001:
            print(f"  {'미실현손익':>14} | {fmt_pct(alpha.unrealized_pnl_pct):>18} | {fmt_pct(infinite.unrealized_pnl_pct):>18} | {'N/A':>14}")
        print(f"  {'─'*70}")

    # 추가: 2022~2023 연장 테스트 (하락→회복)
    print(f"\n\n{'='*80}")
    print(f"  [보너스] 2022~2023 연장 테스트 (하락 → 회복)")
    print(f"  2022년 하락장을 버틴 후 2023년에 회복되는가?")
    print(f"{'='*80}")

    END2 = '2023-12-29'
    for ticker, path in tickers.items():
        raw = load_csv(path)
        data2, si2 = filter_with_warmup(raw, WARMUP, START, END2)
        td2 = len(data2) - si2

        sp2 = data2[si2]['close']; ep2 = data2[-1]['close']
        bnh2 = ((ep2 - sp2) / sp2) * 100

        print(f"\n  {ticker} 2022-2023 ({td2}거래일) | ${sp2:.2f} → ${ep2:.2f} | B&H: {fmt_pct(bnh2)}")

        alpha2 = run_alpha_v3(data2, si2, SEED, ER)
        infinite2 = run_infinite_buy(data2, si2, SEED, ER)

        print(f"  {'전략':>18} | {'수익률':>10} | {'MDD':>10} | {'사이클':>6} | {'최종자산(만원)':>14}")
        print(f"  {'─'*65}")
        print(f"  {'Alpha Cycle V3':>18} | {fmt_pct(alpha2.total_return_pct):>10} | {fmt_pct(-alpha2.mdd_pct):>10} | {alpha2.cycles_completed:>5}회 | {alpha2.final_value/10000:>12,.0f}")
        print(f"  {'순정 무한매수':>16} | {fmt_pct(infinite2.total_return_pct):>10} | {fmt_pct(-infinite2.mdd_pct):>10} | {infinite2.cycles_completed:>5}회 | {infinite2.final_value/10000:>12,.0f}")
        print(f"  {'Buy & Hold':>18} | {fmt_pct(bnh2):>10} | {'N/A':>10} | {'N/A':>6} | {SEED*(1+bnh2/100)/10000:>12,.0f}")

        # 월별 추이 (순정만)
        if infinite2.monthly_values:
            print(f"\n  [순정 무한매수 월별 추이 — {ticker}]")
            print(f"  {'월':>8} | {'총자산(만원)':>12} | {'수익률':>8} | {'주가':>8}")
            print(f"  {'─'*44}")
            for m in infinite2.monthly_values:
                marker = " ★" if m['return_pct'] > 0 else ""
                print(f"  {m['month']:>8} | {m['value']/10000:>10,.0f} | {fmt_pct(m['return_pct']):>8} | ${m['price']:.2f}{marker}")


if __name__ == '__main__':
    main()
