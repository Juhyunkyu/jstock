"""
Alpha Cycle 백테스팅 스크립트 v2.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

핵심 매매법:
1. 초기 진입: 시드의 20%
2. 손실률 기준: 초기 진입가 대비 (평균단가 X)
3. 가중 매수: 손실률 -20% 이하일 때 매일 (공식: 초기진입금 × |손실률| ÷ 1000)
4. 승부수: -50% 도달 시 초기진입금의 50% + 가중매수도 같이 (1회)
5. 익절: 평균단가 대비 +20% → 전량 매도 → 새 사이클
"""

import pandas as pd
from datetime import datetime
from dataclasses import dataclass
from typing import List, Optional


@dataclass
class Trade:
    """거래 기록"""
    date: str
    action: str  # INITIAL_BUY, BUY, PANIC_BUY, SELL
    price: float
    shares: float
    amount_krw: float
    total_shares: float
    avg_price: float
    loss_from_entry: float  # 초기진입가 대비 손실률
    return_from_avg: float  # 평균단가 대비 수익률
    note: str = ""


class AlphaCycleBacktest:
    """
    알파 사이클 백테스팅 엔진

    핵심 규칙:
    - 손실률: 초기 진입가 기준 (추가 매수해도 변하지 않음)
    - 익절률: 평균단가 기준 (추가 매수하면 개선됨)
    """

    def __init__(
        self,
        initial_seed: float = 100_000_000,  # 1억원
        entry_ratio: float = 0.20,           # 초기 진입 20%
        buy_trigger: float = -20,            # 매수 시작점 -20%
        sell_trigger: float = 20,            # 익절 목표 +20% (평균단가 기준)
        panic_trigger: float = -50,          # 승부수 -50% (초기진입가 기준)
        exchange_rate: float = 1350          # 환율 (고정 가정)
    ):
        self.initial_seed = initial_seed
        self.entry_ratio = entry_ratio
        self.buy_trigger = buy_trigger
        self.sell_trigger = sell_trigger
        self.panic_trigger = panic_trigger
        self.exchange_rate = exchange_rate

        # 상태 변수
        self.reset()

    def reset(self):
        """전체 리셋 (처음 시작)"""
        self.current_seed = self.initial_seed
        self.cash = self.initial_seed
        self.shares = 0.0
        self.avg_price = 0.0
        self.initial_entry_price = 0.0  # ★ 초기 진입가 (손실률 기준점)
        self.initial_entry = self.current_seed * self.entry_ratio
        self.trades: List[Trade] = []
        self.cycles_completed = 0
        self.panic_used = False
        self.first_buy_done = False
        self.cycle_start_dates: List[str] = []

    def start_new_cycle(self, new_seed: float):
        """새 사이클 시작 (익절 후)"""
        self.current_seed = new_seed
        self.initial_entry = new_seed * self.entry_ratio
        self.cash = new_seed
        self.shares = 0.0
        self.avg_price = 0.0
        self.initial_entry_price = 0.0  # 새 사이클이므로 리셋
        self.panic_used = False
        self.first_buy_done = False

    def get_loss_from_entry(self, current_price: float) -> float:
        """
        초기 진입가 대비 손실률 계산
        ★ 가중 매수 조건 판단에 사용 (추가 매수해도 변하지 않음)
        """
        if self.initial_entry_price == 0:
            return 0.0
        return ((current_price - self.initial_entry_price) / self.initial_entry_price) * 100

    def get_return_from_avg(self, current_price: float) -> float:
        """
        평균단가 대비 수익률 계산
        ★ 익절 조건 판단에 사용 (추가 매수하면 개선됨)
        """
        if self.shares == 0 or self.avg_price == 0:
            return 0.0
        return ((current_price - self.avg_price) / self.avg_price) * 100

    def calculate_daily_buy_amount(self, loss_pct: float) -> float:
        """
        가중 매수 금액 계산

        공식: 매수액 = 초기진입금 × |손실률| ÷ 1000

        예시 (1억 시드):
        - 초기진입금: 2,000만원
        - 손실률 -20% → 2000만 × 20 ÷ 1000 = 40만원
        - 손실률 -30% → 2000만 × 30 ÷ 1000 = 60만원
        """
        if loss_pct > self.buy_trigger:
            return 0.0

        loss_abs = abs(loss_pct)
        buy_amount = self.initial_entry * loss_abs / 1000
        return buy_amount

    def execute_buy(self, price: float, amount_krw: float, action: str,
                    loss_from_entry: float, note: str, date_str: str) -> bool:
        """매수 실행 (공통 로직)"""
        if amount_krw <= 0 or amount_krw > self.cash:
            return False

        shares_to_buy = (amount_krw / self.exchange_rate) / price

        # 평균단가 재계산
        if self.shares > 0:
            total_cost = (self.shares * self.avg_price) + (shares_to_buy * price)
            self.shares += shares_to_buy
            self.avg_price = total_cost / self.shares
        else:
            self.shares = shares_to_buy
            self.avg_price = price

        self.cash -= amount_krw

        self.trades.append(Trade(
            date=date_str,
            action=action,
            price=price,
            shares=shares_to_buy,
            amount_krw=amount_krw,
            total_shares=self.shares,
            avg_price=self.avg_price,
            loss_from_entry=loss_from_entry,
            return_from_avg=self.get_return_from_avg(price),
            note=note
        ))
        return True

    def run_backtest(self, csv_path: str = "tqqq_data.csv") -> List[Trade]:
        """백테스팅 실행"""

        # 데이터 로드
        df = pd.read_csv(csv_path)
        df['Date'] = pd.to_datetime(df['Date'])
        df = df.sort_values('Date').reset_index(drop=True)

        start_date = df['Date'].iloc[0].strftime("%Y-%m-%d")
        end_date = df['Date'].iloc[-1].strftime("%Y-%m-%d")
        first_price = df['Close'].iloc[0]
        last_price = df['Close'].iloc[-1]

        print(f"\n{'='*70}")
        print(f"📊 Alpha Cycle 백테스팅 v2.0: TQQQ")
        print(f"{'='*70}")
        print(f"기간: {start_date} ~ {end_date} ({len(df)}거래일)")
        print(f"시작가: ${first_price:.2f} → 종가: ${last_price:.2f}")
        print(f"초기 시드: {self.initial_seed:,.0f}원")
        print(f"초기 진입금 (20%): {self.initial_entry:,.0f}원")
        print(f"{'='*70}")
        print(f"📌 손실률 기준: 초기 진입가 (고정)")
        print(f"📌 익절 기준: 평균단가 대비 +{self.sell_trigger}%")
        print(f"{'='*70}\n")

        # 백테스팅 시작
        self.reset()

        for i, row in df.iterrows():
            date_str = row['Date'].strftime("%Y-%m-%d")
            price = row['Close']

            # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            # [1] 초기 진입 (첫 거래일)
            # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            if not self.first_buy_done:
                self.initial_entry_price = price  # ★ 초기 진입가 저장
                self.execute_buy(
                    price=price,
                    amount_krw=self.initial_entry,
                    action="INITIAL_BUY",
                    loss_from_entry=0.0,
                    note=f"사이클#{self.cycles_completed+1} 시작 (시드의 20%, 기준가 ${price:.2f})",
                    date_str=date_str
                )
                self.first_buy_done = True
                self.cycle_start_dates.append(date_str)
                continue

            # 현재 손실률/수익률 계산
            loss_from_entry = self.get_loss_from_entry(price)  # 초기진입가 기준
            return_from_avg = self.get_return_from_avg(price)   # 평균단가 기준

            # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            # [2] 익절 조건 (평균단가 대비 +20%)
            # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            if return_from_avg >= self.sell_trigger:
                current_value_krw = self.shares * price * self.exchange_rate

                self.trades.append(Trade(
                    date=date_str,
                    action="SELL",
                    price=price,
                    shares=self.shares,
                    amount_krw=current_value_krw,
                    total_shares=0,
                    avg_price=0,
                    loss_from_entry=loss_from_entry,
                    return_from_avg=return_from_avg,
                    note=f"🎯 익절! 평균단가 대비 +{return_from_avg:.1f}%"
                ))

                # 새 사이클 시작
                self.cycles_completed += 1
                new_seed = self.cash + current_value_krw
                profit = new_seed - self.current_seed
                print(f"✅ [{date_str}] 사이클 #{self.cycles_completed} 완료!")
                print(f"   수익률: +{return_from_avg:.1f}% | 수익금: {profit:,.0f}원 | 새 시드: {new_seed:,.0f}원\n")

                self.start_new_cycle(new_seed)
                continue

            # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            # [3] 승부수 조건 (초기진입가 대비 -50%) - 1회만
            # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            if loss_from_entry <= self.panic_trigger and not self.panic_used:
                # 승부수: 초기진입금의 50%
                panic_amount = self.initial_entry * 0.5

                if panic_amount <= self.cash:
                    self.execute_buy(
                        price=price,
                        amount_krw=panic_amount,
                        action="PANIC_BUY",
                        loss_from_entry=loss_from_entry,
                        note=f"🔴 승부수! 초기진입금의 50% ({panic_amount:,.0f}원)",
                        date_str=date_str
                    )
                    self.panic_used = True
                    print(f"🔴 [{date_str}] 승부수 발동! 손실률: {loss_from_entry:.1f}%")
                    print(f"   매수금: {panic_amount:,.0f}원 | 새 평단가: ${self.avg_price:.2f}")

                # ★ 승부수 날에도 가중매수 같이 실행 (continue 없음)

            # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            # [4] 가중 매수 조건 (초기진입가 대비 -20% 이하)
            # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            if loss_from_entry <= self.buy_trigger:
                buy_amount = self.calculate_daily_buy_amount(loss_from_entry)

                if buy_amount > 0 and buy_amount <= self.cash:
                    self.execute_buy(
                        price=price,
                        amount_krw=buy_amount,
                        action="BUY",
                        loss_from_entry=loss_from_entry,
                        note=f"손실률 {loss_from_entry:.1f}% → {buy_amount:,.0f}원 매수",
                        date_str=date_str
                    )

        # 최종 결과 출력
        self.print_results(df)
        return self.trades

    def print_results(self, df):
        """결과 출력"""
        first_price = df['Close'].iloc[0]
        final_price = df['Close'].iloc[-1]

        # 현재 보유 자산 가치
        holdings_value_krw = self.shares * final_price * self.exchange_rate
        final_value_krw = holdings_value_krw + self.cash
        total_return = ((final_value_krw - self.initial_seed) / self.initial_seed) * 100

        # 매수/매도 횟수
        initial_buys = len([t for t in self.trades if t.action == "INITIAL_BUY"])
        buy_count = len([t for t in self.trades if t.action == "BUY"])
        panic_count = len([t for t in self.trades if t.action == "PANIC_BUY"])
        sell_count = len([t for t in self.trades if t.action == "SELL"])

        # 총 투입금
        total_invested = sum(t.amount_krw for t in self.trades
                            if t.action in ["BUY", "INITIAL_BUY", "PANIC_BUY"])

        print(f"\n{'='*70}")
        print(f"📊 최종 결과")
        print(f"{'='*70}")
        print(f"초기 시드:          {self.initial_seed:>25,.0f}원")
        print(f"최종 자산:          {final_value_krw:>25,.0f}원")
        print(f"  └─ 주식 평가금:   {holdings_value_krw:>25,.0f}원")
        print(f"  └─ 잔여 현금:     {self.cash:>25,.0f}원")
        print(f"총 수익률:          {total_return:>24.1f}%")
        print(f"{'='*70}")
        print(f"완료된 사이클:      {self.cycles_completed:>25}회")
        print(f"초기 매수:          {initial_buys:>25}회")
        print(f"일반 매수 (가중):   {buy_count:>25}회")
        print(f"승부수 매수:        {panic_count:>25}회")
        print(f"익절 매도:          {sell_count:>25}회")
        print(f"총 매수금:          {total_invested:>25,.0f}원")
        print(f"{'='*70}")

        # Buy & Hold 비교
        bnh_return = ((final_price - first_price) / first_price) * 100
        bnh_final = self.initial_seed * (1 + bnh_return/100)

        print(f"\n📈 Buy & Hold 비교 (전액 투자 시)")
        print(f"{'='*70}")
        print(f"B&H 수익률:         {bnh_return:>24.1f}%")
        print(f"B&H 최종 자산:      {bnh_final:>25,.0f}원")
        print(f"{'='*70}")

        diff = total_return - bnh_return
        if diff > 0:
            print(f"✅ Alpha Cycle이 Buy & Hold 대비 +{diff:.1f}%p 우수!")
        else:
            print(f"⚠️ Buy & Hold가 Alpha Cycle 대비 +{abs(diff):.1f}%p 우수")
            print(f"   (하지만 Alpha Cycle은 현금 비중으로 리스크 관리)")

        # 현재 상태 (진행 중인 사이클)
        if self.shares > 0:
            loss_from_entry = self.get_loss_from_entry(final_price)
            return_from_avg = self.get_return_from_avg(final_price)

            print(f"\n📍 현재 진행 중인 사이클 #{self.cycles_completed + 1}")
            print(f"{'='*70}")
            print(f"보유 수량:          {self.shares:>25.2f}주")
            print(f"초기 진입가:        ${self.initial_entry_price:>24.2f}")
            print(f"평균 단가:          ${self.avg_price:>24.2f}")
            print(f"현재가:             ${final_price:>24.2f}")
            print(f"{'='*70}")
            print(f"손실률 (진입가 기준): {loss_from_entry:>23.1f}%")
            print(f"수익률 (평단가 기준): {return_from_avg:>23.1f}%")

            if loss_from_entry <= -20:
                daily_buy = self.calculate_daily_buy_amount(loss_from_entry)
                print(f"{'='*70}")
                print(f"⚠️ 오늘 매수 권장:   {daily_buy:>25,.0f}원")

        # 사이클별 요약
        if self.cycles_completed > 0:
            print(f"\n📋 완료된 사이클 요약")
            print(f"{'='*70}")
            sells = [t for t in self.trades if t.action == "SELL"]
            for i, sell in enumerate(sells, 1):
                print(f"사이클 #{i}: {sell.date} | 수익률 +{sell.return_from_avg:.1f}% | 매도금 {sell.amount_krw:,.0f}원")

        # 최근 10개 거래
        print(f"\n📋 최근 거래 내역")
        print(f"{'='*70}")
        for trade in self.trades[-10:]:
            emoji = {
                "INITIAL_BUY": "🟢",
                "BUY": "🔵",
                "PANIC_BUY": "🔴",
                "SELL": "💰"
            }.get(trade.action, "⚪")
            print(f"{emoji} [{trade.date}] {trade.action:12} | ${trade.price:>8.2f} | {trade.amount_krw:>12,.0f}원")
            print(f"   {trade.note}")


def run_parameter_test():
    """다양한 파라미터로 백테스팅 비교"""
    print("\n" + "="*70)
    print("📊 파라미터 비교 테스트")
    print("="*70 + "\n")

    test_cases = [
        {"name": "기본값", "buy_trigger": -20, "sell_trigger": 20, "panic_trigger": -50},
        {"name": "공격적", "buy_trigger": -15, "sell_trigger": 15, "panic_trigger": -40},
        {"name": "보수적", "buy_trigger": -25, "sell_trigger": 25, "panic_trigger": -60},
    ]

    results = []
    for case in test_cases:
        bt = AlphaCycleBacktest(
            initial_seed=100_000_000,
            buy_trigger=case["buy_trigger"],
            sell_trigger=case["sell_trigger"],
            panic_trigger=case["panic_trigger"]
        )
        # 조용히 실행
        import io
        import sys
        old_stdout = sys.stdout
        sys.stdout = io.StringIO()
        bt.run_backtest("tqqq_data.csv")
        sys.stdout = old_stdout

        final_value = bt.shares * 52.0 * bt.exchange_rate + bt.cash  # 대략적인 최종가
        results.append({
            "name": case["name"],
            "cycles": bt.cycles_completed,
            "trades": len(bt.trades)
        })

    print("테스트 완료! 상세 결과는 개별 백테스트를 실행하세요.")


if __name__ == "__main__":
    # 기본 백테스팅 실행
    backtest = AlphaCycleBacktest(
        initial_seed=100_000_000,  # 1억원
        entry_ratio=0.20,          # 20% 초기 진입
        buy_trigger=-20,           # -20%부터 매수 (초기진입가 기준)
        sell_trigger=20,           # +20%에서 익절 (평균단가 기준)
        panic_trigger=-50,         # -50%에서 승부수 (초기진입가 기준)
        exchange_rate=1350         # 환율 (고정)
    )

    backtest.run_backtest("tqqq_data.csv")
