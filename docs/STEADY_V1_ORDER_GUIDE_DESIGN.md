# Steady V1 Order Guide Upgrade Design

> Status: DESIGN (review required before implementation)
> Date: 2026-03-20
> Scope: Add V1 order guide generation so `SteadyOrderGuideCard` can display V1 orders

---

## 1. Problem Statement

V2.2 and V3.0 Steady Cycles have a rich order guide card (`SteadyOrderGuideCard`) that shows exact buy/sell orders with prices, quantities, and amounts. V1 only has a simple progress card (`_buildV1ProgressCard` in `cycle_detail_screen.dart`) that shows round count, unit amount, remaining cash, and a text hint. This creates an inconsistent user experience across Steady versions.

**Goal**: Generate a `SteadyOrderGuide` for V1 cycles so the same `SteadyOrderGuideCard` widget can render V1 orders.

---

## 2. V1 Buy/Sell Rules (Reference)

### Buy Logic (daily, per round)
- **If first buy OR currentPrice <= averagePrice**: Buy A (0.5 unit at averagePrice LOC) + B (0.5 unit at averagePrice x 1.1 LOC) = 1.0 unit total
- **If currentPrice > averagePrice**: Buy B only (0.5 unit at averagePrice x 1.1 LOC)
- LOC = Limit-On-Close: executes at closing price if closing <= order price

### Sell Logic (daily, always active)
- Place limit sell for ALL shares at averagePrice x 1.1 (= +10%)
- If price reaches +10%, all shares sold, cycle complete

### Exhaustion
- 40 rounds used up: stop buying, keep sell order active until filled

### Key Differences from V2.2/V3.0
- No T-value offset formula (no `offsetA - offsetB * T`)
- No quarter mode
- No LOC sell (1/4) + limit sell (3/4) split -- just one full sell order
- No compound (semi-compound) feature
- A order = averagePrice LOC, B order = averagePrice x 1.1 LOC (fixed, no offset variation)

---

## 3. Data Model Analysis: Can `SteadyOrderGuide` Represent V1?

### Current `SteadyOrderGuide` fields and V1 mapping:

| Field | V2.2/V3.0 Usage | V1 Mapping | Needs Change? |
|---|---|---|---|
| `tValue` | Calculated from invested/unit | `roundsUsed.toDouble()` (simple integer) | No -- works as-is |
| `isFirstHalf` | T < 20 (V2.2) or T < 10 (V3.0) | Always `true` (V1 has no half concept, but front-half logic matches: A+B when price <= avg) | No |
| `locOffsetPercent` | `offsetA - offsetB * T` | Fixed `0.0` (V1 has no offset formula) | No |
| `locPrice` | `averagePrice * (1 + offset%)` | `averagePrice * 1.1` (fixed +10%) | No |
| `limitSellPrice` | `averagePrice * (1 + takeProfit%)` | `averagePrice * 1.1` (same as locPrice for V1) | No |
| `canBuy` | cash > 0 && T < totalRounds | `remainingCash > 0 && roundsUsed < 40` | No |
| `isFirstBuy` | averagePrice == 0 | Same | No |
| `isQuarterMode` | Complex T-based rules | Always `false` | No |
| `adjustedUnitAmount` | Compound-adjusted unit | `cycle.unitAmount` (no compound) | No |
| `buyOrderA` | Front-half A order | 0.5 unit at averagePrice LOC (when price <= avg) | No |
| `buyOrderB` | Front-half B order | 0.5 unit at averagePrice x 1.1 LOC (always when buying) | No |
| `buySingleOrder` | Back-half single order | Used for first buy only | No |
| `sellLocOrder` | LOC sell 1/4 shares | **Not used** -- V1 has no LOC partial sell | No (just null) |
| `sellLimitOrder` | Limit sell 3/4 shares | Repurposed: limit sell ALL shares at +10% | No |

**Conclusion: The existing `SteadyOrderGuide` model can represent V1 orders WITHOUT any structural changes.** All V1 concepts map cleanly onto existing fields. The only semantic difference is that `sellLimitOrder` covers 100% of shares instead of 75%, but the `OrderItem` already carries its own `shares` and `label` fields, so this is just a matter of populating different values.

---

## 4. Design: Where to Add `generateV1Guide()`

### Option A: Add to `SteadyService` (REJECTED)
- `SteadyService` header says "V2.2/V3.0 전용" and `InfiniteBuyService` owns V1
- Mixing V1 logic into SteadyService violates the existing separation

### Option B: Add to `InfiniteBuyService` (REJECTED)
- `InfiniteBuyService` implements `StrategyEngine` for signal detection and amount calculation
- Adding UI-specific guide generation mixes concerns (engine vs presentation support)

### Option C: New static method in a dedicated location (SELECTED)
- Add `generateV1Guide()` as a **static method on `InfiniteBuyService`**
- Rationale: V1 business rules already live in `InfiniteBuyService`. The guide generation is a pure function that takes cycle + market data and returns a DTO. This mirrors exactly how `SteadyService.generateGuide()` works -- it is a static method on the service class, not an instance method.
- The pattern is already established: `SteadyService.generateGuide(...)` is static and called from the provider. We follow the same pattern.

**Decision: Add `static SteadyOrderGuide generateV1Guide(...)` to `InfiniteBuyService`.**

This is the minimal-friction choice. It follows the exact same pattern as `SteadyService.generateGuide()`, keeps V1 logic co-located with other V1 logic, and requires no new files.

---

## 5. Method Signature

```dart
// In infinite_buy_service.dart

/// V1 주문 가이드 생성 -- SteadyOrderGuideCard에서 표시할 오늘의 주문 정보
static SteadyOrderGuide generateV1Guide({
  required Cycle cycle,
  required double currentPrice,
  required double exchangeRate,
}) { ... }
```

**Parameters** (simpler than V2.2/V3.0 -- no `totalSellKrw` or `sellProfit` needed):
- `cycle` -- the V1 Steady cycle with current state
- `currentPrice` -- live USD price of the ticker
- `exchangeRate` -- live KRW/USD exchange rate

**No `totalSellKrw` / `sellProfit`**: V1 has no compound feature and no T-value formula that depends on sell history. The T-value for V1 is simply `roundsUsed`.

---

## 6. Implementation Logic (Pseudocode)

```dart
static SteadyOrderGuide generateV1Guide({
  required Cycle cycle,
  required double currentPrice,
  required double exchangeRate,
}) {
  final tValue = cycle.roundsUsed.toDouble();
  final isFirstBuy = cycle.averagePrice == 0;
  final canBuy = cycle.remainingCash > 0 && cycle.roundsUsed < cycle.totalRounds;
  final sellPrice = cycle.averagePrice * (1 + cycle.takeProfitPercent / 100);
  // takeProfitPercent defaults to 10.0 for V1

  // === FIRST BUY ===
  if (isFirstBuy) {
    final buyAmountKrw = cycle.unitAmount.clamp(0.0, cycle.remainingCash);
    final shares = (exchangeRate > 0 && currentPrice > 0)
        ? buyAmountKrw / (currentPrice * exchangeRate)
        : 0.0;

    return SteadyOrderGuide(
      tValue: tValue,
      isFirstHalf: true,
      locOffsetPercent: 0,
      locPrice: currentPrice,
      limitSellPrice: 0,
      canBuy: canBuy,
      isFirstBuy: true,
      isQuarterMode: false,
      adjustedUnitAmount: cycle.unitAmount,
      buySingleOrder: OrderItem(
        label: '첫 매수',
        price: currentPrice,
        shares: shares,
        amountKrw: buyAmountKrw,
        description: 'T=0 시장가',
      ),
    );
  }

  // === BUY ORDERS ===
  OrderItem? buyOrderA;
  OrderItem? buyOrderB;

  if (canBuy) {
    final halfAmount = (cycle.unitAmount * 0.5).clamp(0.0, cycle.remainingCash);
    final avgPrice = cycle.averagePrice;
    final bPrice = avgPrice * 1.1;  // fixed +10% for V1

    if (currentPrice <= avgPrice) {
      // A + B (1.0 unit total)
      final sharesA = (exchangeRate > 0 && avgPrice > 0)
          ? halfAmount / (avgPrice * exchangeRate)
          : 0.0;
      buyOrderA = OrderItem(
        label: 'LOC A (평단)',
        price: avgPrice,
        shares: sharesA,
        amountKrw: halfAmount,
        description: '평단 \$${avgPrice.toStringAsFixed(2)}',
      );

      final remainAfterA = (cycle.remainingCash - halfAmount).clamp(0.0, double.infinity);
      final halfAmountB = halfAmount.clamp(0.0, remainAfterA);
      final sharesB = (exchangeRate > 0 && bPrice > 0)
          ? halfAmountB / (bPrice * exchangeRate)
          : 0.0;
      buyOrderB = OrderItem(
        label: 'LOC B (+10%)',
        price: bPrice,
        shares: sharesB,
        amountKrw: halfAmountB,
        description: '+10.0%',
      );
    } else {
      // B only (0.5 unit)
      final sharesB = (exchangeRate > 0 && bPrice > 0)
          ? halfAmount / (bPrice * exchangeRate)
          : 0.0;
      buyOrderB = OrderItem(
        label: 'LOC B (+10%)',
        price: bPrice,
        shares: sharesB,
        amountKrw: halfAmount,
        description: '+10.0%',
      );
    }
  }

  // === SELL ORDER ===
  OrderItem? sellLimitOrder;
  if (cycle.totalShares > 0) {
    sellLimitOrder = OrderItem(
      label: '지정가 매도 (전량)',
      price: sellPrice,
      shares: cycle.totalShares,
      amountKrw: cycle.totalShares * sellPrice * exchangeRate,
      description: '+${cycle.takeProfitPercent.toStringAsFixed(1)}%',
    );
  }

  return SteadyOrderGuide(
    tValue: tValue,
    isFirstHalf: true,           // V1 has no half concept; true keeps UI simple
    locOffsetPercent: 0,         // V1 has no offset formula
    locPrice: sellPrice,         // used for display; equals avgPrice * 1.1
    limitSellPrice: sellPrice,
    canBuy: canBuy,
    isFirstBuy: false,
    isQuarterMode: false,        // V1 never enters quarter mode
    adjustedUnitAmount: cycle.unitAmount,
    buyOrderA: buyOrderA,
    buyOrderB: buyOrderB,
    sellLocOrder: null,          // V1 has no LOC partial sell
    sellLimitOrder: sellLimitOrder,
  );
}
```

---

## 7. Provider Changes (`steady_providers.dart`)

### Current State
```dart
// Line 19: V1 is explicitly excluded
if (cycle.steadyVersion == SteadyVersion.v1) return null;
```

### Required Change
Remove the V1 exclusion and route to the appropriate generator:

```dart
final steadyOrderGuideProvider =
    Provider.family<SteadyOrderGuide?, String>((ref, cycleId) {
  final cycles = ref.watch(cycleListProvider);
  final cycle = cycles.where((c) => c.id == cycleId).firstOrNull;
  if (cycle == null) return null;
  if (cycle.strategyType != StrategyType.infiniteBuy) return null;

  final prices = ref.watch(closingPricesProvider);
  final currentPrice = prices[cycle.ticker] ?? 0;
  if (currentPrice == 0) return null;

  final liveExchangeRate = ref.watch(currentExchangeRateProvider);
  if (liveExchangeRate == 0) return null;

  // === V1: simple guide, no sell history needed ===
  if (cycle.steadyVersion == SteadyVersion.v1) {
    return InfiniteBuyService.generateV1Guide(
      cycle: cycle,
      currentPrice: currentPrice,
      exchangeRate: liveExchangeRate,
    );
  }

  // === V2.2 / V3.0: existing logic (unchanged) ===
  final trades = ref.watch(tradeListProvider(cycleId));
  double totalSellKrw = 0;
  double sellProfit = 0;
  for (final t in trades) {
    if (t.action != TradeAction.sell) continue;
    totalSellKrw += t.amountKrw;
    sellProfit += t.amountKrw - (t.shares * cycle.averagePrice * t.exchangeRate);
  }

  return SteadyService.generateGuide(
    cycle: cycle,
    currentPrice: currentPrice,
    exchangeRate: liveExchangeRate,
    totalSellKrw: totalSellKrw,
    sellProfit: sellProfit,
  );
});
```

**New import needed**: `import '../../domain/trading/infinite_buy_service.dart';`

---

## 8. UI Changes (`cycle_detail_screen.dart`)

### Current State (3 separate blocks)

```
Lines 156-170:  SignalDisplay -- shown for V1 only (V2.2/V3.0 hidden)
Lines 172-181:  _buildV1ProgressCard -- V1 only
Lines 183-191:  SteadyOrderGuideCard -- V2.2/V3.0 only
```

### Target State: Unify to single block

Replace the three blocks with:

```dart
// === Steady Cycle 주문 가이드 (V1/V2.2/V3.0 통합) ===
if (cycle.strategyType == StrategyType.infiniteBuy &&
    cycle.status == CycleStatus.active) ...[
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: SteadyOrderGuideCard(cycleId: widget.cycleId),
  ),
  SizedBox(height: isMobile ? 10 : 16),
],
```

Also update the `steadyGuide` watch at line 88-92 to include V1:

```dart
// Before:
final steadyGuide = (cycle.strategyType == StrategyType.infiniteBuy &&
        cycle.steadyVersion != SteadyVersion.v1)
    ? ref.watch(steadyOrderGuideProvider(widget.cycleId))
    : null;

// After:
final steadyGuide = (cycle.strategyType == StrategyType.infiniteBuy)
    ? ref.watch(steadyOrderGuideProvider(widget.cycleId))
    : null;
```

**Delete**: The `_buildV1ProgressCard` method (lines 564-680+) becomes dead code and should be removed.

**Keep**: The `SignalDisplay` block for V1 can be removed since the order guide card now replaces it for all Steady versions. The signal detection still works internally; the guide card provides better UX.

---

## 9. `SteadyOrderGuideCard` UI Compatibility Analysis

Walking through every UI element in the card widget to verify V1 compatibility:

### `_buildTProgressBar` (lines 106-157)
- Shows `T: {tValue} / {totalRounds}` -- V1: `T: 5.0 / 40` (works)
- Shows `전반전 / 후반전` badge -- V1: always `전반전` (acceptable; V1 has no half concept)
- Shows `오프셋: +0.0%` -- V1: always `0.0%` -- **Problem**: This line is meaningless for V1

**Required card change**: Hide the offset line when V1 (offset is always 0 and has no meaning).

```dart
// In _buildTProgressBar, replace the offset Text widget:
if (guide.locOffsetPercent != 0 || !_isV1(ref))  // only show for V2.2/V3.0
  Text(
    '오프셋: ${guide.locOffsetPercent >= 0 ? '+' : ''}${guide.locOffsetPercent.toStringAsFixed(1)}%',
    ...
  ),
```

Alternative (simpler): The card needs to know whether this is V1. Two approaches:
1. Pass a flag through the guide model
2. Look up the cycle from the provider (already done for `totalRounds` at line 107-109)

**Chosen approach**: Read `cycle.steadyVersion` from the same cycle lookup already happening in `_buildTProgressBar`. No model change needed.

### `_buildQuarterModeAlert` (line 37)
- Guarded by `guide.isQuarterMode` -- V1 always `false`. Never shown. OK.

### Buy section (lines 62-73)
- `buyOrderA` / `buyOrderB` -- V1 populates these when price <= avg. Renders correctly.
- `buySingleOrder` -- V1 does not use back-half single orders (except first buy). OK.
- `_buyHint(order)` -- checks `order.label.contains('평단')` -- V1 label is `'LOC A (평단)'`, so hint = `'종가 <= 평단가일 때 체결'`. Correct.
- For B order, V1 label is `'LOC B (+10%)'` -- does not contain '평단', so hint = `'종가 <= 이 가격일 때 체결'`. Correct.

### No-fill section (line 76)
- `!guide.canBuy && !guide.isQuarterMode && !guide.isFirstBuy` -- V1: shows when rounds exhausted or cash depleted. Shows `'매수 완료 - 매도 주문만 대기'`. Correct.

### Sell section (lines 80-87)
- `sellLocOrder` -- V1: always `null`. Not rendered. OK.
- `sellLimitOrder` -- V1: populated with full-share sell. Renders with hint `'장중 이 가격 이상 도달 시 체결'`. Correct.
- **Label difference**: V1 label is `'지정가 매도 (전량)'` vs V2.2/V3.0 `'지정가 매도 (3/4)'`. The card renders whatever label is in the OrderItem. No change needed.

### Sell section title (line 81)
- Shows `'매도 주문 (동시)'` -- for V1, there is no LOC sell, only limit sell. The word "동시" (simultaneous) is misleading since V1 only has one sell order.

**Required card change**: Adjust sell section title for V1:

```dart
// Instead of hardcoded '매도 주문 (동시)', check if both sell orders exist:
_buildSectionTitle(
  context,
  (guide.sellLocOrder != null && guide.sellLimitOrder != null)
      ? '매도 주문 (동시)'
      : '매도 주문',
  AppColors.green500,
),
```

### First buy section (lines 59-61)
- Uses `guide.buySingleOrder` -- V1 first buy populates this. Renders correctly.

### Help dialog (`_showHelpDialog`, lines 260-326)
- Contains V2.2/V3.0 terminology (T값, 오프셋, 전반전/후반전, LOC A/B, 쿼터모드, 반복리, MOC)
- Most of this does not apply to V1

**Required card change**: Show version-appropriate help content. The cycle's `steadyVersion` can be looked up from the provider (same pattern as `totalRounds`). Add a V1-specific help text block.

V1 help content:
```
── 매수 ──

회차 (T값)
몇 회 매수했는지. T가 클수록 원금 소진.
예: T=5 -> 5회분 투입 완료

LOC A (평단)
평균 매입가에 LOC 주문.
종가 <= 평단가일 때 체결.

LOC B (+10%)
평단가 x 1.1 에 LOC 주문.
종가 <= 이 가격일 때 체결.

매수 조건
현재가 <= 평단 -> A + B (1회 매수금)
현재가 > 평단 -> B만 (0.5회 매수금)

── 매도 ──

지정가 매도 (전량)
보유 수량 전체를 평단 +10%에 매도.
장중 이 가격에 도달하면 체결, 사이클 완료.
```

---

## 10. `_buildTProgressBar` Detail: Replace "전반전/후반전" for V1

For V1, the "전반전" badge is meaningless. Two options:

**Option A**: Hide the badge entirely for V1.
**Option B**: Replace with a simpler label like "진행중" (in progress).

**Chosen: Option A** -- hide for V1. The progress bar + T value already convey progress. The front/back-half concept is V2.2/V3.0-specific.

---

## 11. Files Changed Summary

| File | Change Type | Description |
|---|---|---|
| `lib/domain/trading/infinite_buy_service.dart` | ADD method | `static SteadyOrderGuide generateV1Guide(...)` |
| `lib/presentation/providers/steady_providers.dart` | MODIFY | Remove V1 exclusion, add V1 routing + import |
| `lib/presentation/screens/stocks/cycle_detail_screen.dart` | MODIFY | Unify 3 blocks into 1, remove `_buildV1ProgressCard`, update steadyGuide watch |
| `lib/presentation/screens/stocks/widgets/steady_order_guide_card.dart` | MODIFY | 4 small changes (see below) |

### `steady_order_guide_card.dart` Changes Detail:

1. **Hide offset line for V1** in `_buildTProgressBar`
2. **Hide 전반전/후반전 badge for V1** in `_buildTProgressBar`
3. **Dynamic sell section title** -- `'매도 주문 (동시)'` vs `'매도 주문'`
4. **Version-aware help dialog** -- V1-specific terminology

All 4 changes require knowing the `steadyVersion`. The card already looks up the cycle at line 107-109 for `totalRounds`. We extend that lookup to also extract `steadyVersion`.

---

## 12. Data Flow Diagram

```
[cycle_detail_screen.dart]
    |
    | ref.watch(steadyOrderGuideProvider(cycleId))
    v
[steady_providers.dart]
    |
    | cycle.steadyVersion == v1?
    |--- YES --> InfiniteBuyService.generateV1Guide(cycle, price, exchangeRate)
    |--- NO  --> SteadyService.generateGuide(cycle, price, exchangeRate, sellKrw, profit)
    |
    v
[SteadyOrderGuide]  (same DTO for all versions)
    |
    v
[SteadyOrderGuideCard]  (renders uniformly, with minor V1 display tweaks)
```

---

## 13. Trade Record Sheet Impact

`cycle_trade_record_sheet.dart` uses `steadyOrderGuideProvider` at lines 523 and 1099 for:
- `_buildGuideSummary`: Shows T-value, offset, buy/sell order hints in the trade recording flow
- `_buildSplitInputs`: Pre-fills A/B price/shares from the guide for V2.2/V3.0 front-half input

### Impact Analysis:
- `_buildGuideSummary` (line 522): Currently only reached for V2.2/V3.0 cycles. Once V1 returns a non-null guide, this will render for V1 too. The summary shows `T: {tValue} 전반전 오프셋 {offset}%` -- for V1 this would show `T: 5.0 전반전 오프셋 +0.0%`. The "전반전" and "오프셋" parts are meaningless for V1.

**Required change**: Conditionally format the summary header for V1:
```dart
// V1: 'T: 5.0  회차 5/40'
// V2.2/V3.0: 'T: 5.0  전반전  오프셋 +3.5%'
```

- `_buildSplitInputs` (line 1098): Guarded by version check (`isV3`). This method is only called for V2.2/V3.0 front-half A/B split input. V1 uses the standard single-input flow. No change needed as long as the calling code still checks version before calling this method.

**Verify**: Check whether the trade sheet dispatches to `_buildSplitInputs` based on version or based on guide content. If it checks `cycle.steadyVersion != v1`, no change needed.

---

## 14. Risk Assessment

| Risk | Severity | Mitigation |
|---|---|---|
| V1 guide shows V2.2-style offset/half info | Low | Card changes hide these for V1 |
| Trade record sheet pre-fills wrong values | Low | Sheet already version-gates split inputs |
| `SteadyOrderGuide` model changes break V2.2/V3.0 | None | No model changes required |
| Existing V1 signal detection affected | None | `InfiniteBuyService` engine methods untouched |
| Help dialog confuses V1 users with V2.2 terms | Medium | Version-specific help content |

---

## 15. Implementation Order

1. **`infinite_buy_service.dart`** -- Add `generateV1Guide()` static method
2. **`steady_providers.dart`** -- Remove V1 exclusion, add routing + import
3. **`steady_order_guide_card.dart`** -- 4 display tweaks (offset, badge, sell title, help)
4. **`cycle_detail_screen.dart`** -- Unify blocks, remove `_buildV1ProgressCard`, update watch
5. **`cycle_trade_record_sheet.dart`** -- Conditionally format guide summary for V1
6. **Test** -- Build and verify with an existing V1 cycle

No new files. No model changes. No Hive migration. No new providers.
