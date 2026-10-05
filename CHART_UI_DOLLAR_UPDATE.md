# Chart and UI update — 29 September 2026

Implemented in the local sources and the open Roblox Studio place, retaining the existing colors, gradients, borders, and controls.

## Changes

- Rectangle right-edge handles render and accept hits only for the selected rectangle. Hover uses the horizontal resize cursor. The chart transform stays fixed during resizing.
- Pending limit lines and labels support vertical dragging. Release snaps to the instrument tick and requests an amendment to the same order ID. The server checks ownership, current price/quantity, account state, price band, and capacity before changing the order. Rejections show an error and restore the confirmed marker. Labels use `Limit Buy 1` / `Limit Sell 1`; the separate X region cancels only that order and consumes the gesture.
- Candle zoom uses at least seven pixels per bar, a viewport-dependent visible count, and bounded zoom. One-minute candles remain genuine one-minute candles. History can still be panned. Removed the volume histogram and reclaimed its height for price rendering.
- Accounts and Stats use larger labels, values, descriptions, and roomier responsive cards. Narrow screens stack content and retain scrollable sections.
- Next-unlock amounts and bars follow server-provided qualifying realized profit and the actual stage goal. The initial $3,000 goal and following $5,000 goal reset and update through the existing progression rules.
- Stop Loss and Take Profit accept estimated total dollars for the selected quantity. Shared client/server conversion uses `tick dollars = Tick × Multiplier × quantity`, rounds to the nearest whole tick (minimum one), and displays the effective total. Instrument, quantity, and entry changes recalculate prices. Server requests carry dollars; legacy tick requests remain compatible with existing engine tests and integrations.

## Verification in Roblox Studio

- Ten chart/server regression suites passed: ChartTools 33, ChartViewport 39, ChartPaintPool 10, TradeAmendment 166, TradeLimits 40, Funded 11, Progression 10, Depletion 11, Market 12, Stats 12 — 344 checks total.
- Trade controls: 39 interactions passed, including submission, draft/cancel/save behavior, quantity-dependent dollar caps, and no unintended amendments to existing positions. All 21 ticket/protection layouts passed text and bounds checks from 320×568 to 1920×1080, including landscape.
- Accounts/progression: 70 layout views checked with no reported issues. Stats: 80 layout views checked with no reported issues. Desktop and iPhone portrait/landscape screens were also visually inspected in Studio.
- Existing trading UI validation passed seven resolutions, 14 success cases, 56 rejection cases, 35 live P&L updates, and 44 selector checks.
- Actual desktop mouse interaction verified rectangle selection/deselection, horizontal cursor, and smooth right-edge extension while preserving the left edge and prices.
- A pending buy moved from 5706.50 to 5730.00 with the same order ID. Clicking its X removed only that order, leaving the other pending order intact.
- An actual out-of-band limit amendment produced `Limit is outside the simulated price band.` and restored the confirmed 5873.00 marker. Test pending orders were cancelled; no test positions remained open.
- Repeated wheel zoom reached a 165-bar limit on a 1155-pixel plot with three-pixel candle bodies, the selected timeframe still `1m`, and zero volume bars.
- Isolated live UI/session updates displayed $0 / $3,000, $1,250 / $3,000, $0 / $5,000 after the stage transition, and $1,250 / $5,000 subsequently. These used the actual progression view builder.
- For quantity three, requested $100/$200 protection rounded to $112.50/$187.50 on ES and $105/$195 on NQ. A 22000 NQ entry gave a 21998.25 buy stop and 22001.75 sell stop. The server suite also covers all four instruments, both directions, several quantities, stale amendments, rejection atomicity, and cancellation.
- All 14 changed/new production and regression modules matched the local source byte-for-byte before saving. The regenerated Edit preview rendered 31 candles and its exchange audit reported zero cash discrepancy.

## Limits and test-account impact

- Mobile verification used Studio's device emulator and fixed-size UI fixtures, not physical phone touch or pinch gestures.
- Dollar protection is an estimate. Tick rounding is shown explicitly; execution price, slippage, partial fills, or combining trades with an existing position can change the final realized result.
- During mobile input testing, a misdirected navigation click opened one simulated ES trade. It was closed at a $350 realized loss. The existing **Studio** $5K account balance changed from $8,570 to $8,220 and qualifying progress from $570 to $220. The game's separate `Live` DataStore scope was not modified. No test position was left open.
- Saved locally; no publish action was performed. Original sources are preserved under `backups/chart-ui-dollar-before-20260929`.
