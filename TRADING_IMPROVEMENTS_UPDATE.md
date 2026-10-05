# Trading improvements — September 29, 2026

Five changes to Get Funded!, implemented in `src/` and in the open Studio session (all 36 scripts match). Backup of the previous source: `backups/five-improvements-before-20260929/`. Full results: `five-improvements-validation-results.json`.

## 1. Right-click chart orders

- Right-click the price area of the chart to open an order menu at the clicked price (snapped to the tick).
  - **Above** the last traded price: **Limit Sell** and **Stop Buy**.
  - **Below**: **Limit Buy** and **Stop Sell**.
  - **At** the last price: a note to click above/below (use BUY/SELL for market orders).
- The menu shows the contract and price, the live last price, a contract quantity stepper (shared with the order ticket), the account's current maximum ("Max 5" or "Max ↑2 ↓8" when sides differ) and the ticket's SL/TP distances.
- Submitting uses the ticket's own order path (`submitOrder` in TerminalUI): same client checks, pending state, toasts and reply handling; the server validates exactly as for the ticket. A right-click during a drawing/drag still cancels it. The menu closes on Esc, a click elsewhere, focus loss, instrument change or a popup; right-clicking elsewhere moves it. If the market crosses the clicked price while it's open, the choices switch sides. Desktop only (no right-click on touch).
- **New engine order type: Stop (entry).** Stop buys must be above the last trade and stop sells below it; tick size, price band and player-account rules apply; not reduce-only. An armed stop waits off the order book, reserves capacity like a working limit, appears in Orders as "Buy stop / Sell stop · Armed", and can be cancelled. It latches on the execution that reaches its price and becomes a market order carrying the ticket's SL/TP. If the book is momentarily empty the rest stays triggered and retries for 5 simulated seconds before being cancelled. Each trigger is reported once to the player (filled or not, with the reason).
- Checkpoint format **v4** (reads v1–v4): armed stops are saved and restored off-book. Older server builds fail closed on v4.

## 2. Consistent 5-contract maximum

- ES, RTY and YM now use NQ's **$750** simulated margin (was $1,200 / $800 / $1,000). A fresh $5K account (80% of equity = $4,000 buying power) can hold **5 contracts of any of the four**; the 6th is rejected. Bigger tiers keep their account limits (10 / 25 / 50 / 100). Restored worlds adopt the new margins automatically (existing behaviour).
- Server: unchanged rules, now consistent across instruments. Pending limit and stop orders reserve capacity when placed, and every fill is re-validated (resting limits at match time; stops when they trigger), so a pending order can't push the position past the cap.
- Interface: each account packet now carries the server-computed maximum per instrument and side. The ticket shows "Max 5 ES" by the quantity (live), the chart menu shows the same, and orders over the maximum are stopped client-side with the server's wording before sending.
- Note: participants (bots) also use these margins, so the simulated market's flow differs slightly from before.

## 3. More zoom-out range

- Scroll-wheel zoom now reaches **one candle per pixel** (was one per 2 px), up to 2,000 bars, and chart history per series is **1,200 candles** (was 720). On a 1920×1080 layout the chart zooms out to ~1,155 bars (was ~577).
- Zooming out keeps the right edge in place, so the extra room shows older candles rather than empty space. Cursor anchoring, pinch, pan, axis scaling, auto-fit and Live are unchanged.
- Cost: checkpoint grows with history (measured on an 8-book stress world: 0.32 → 0.57 MB encoded, encode 26 → 47 ms; limit 3.5 MB). Fully zoomed-out paints measured ~3 ms, frame p95 6 ms in Studio.

## 4. Horizontal rectangle dragging

- Dragging a rectangle's body moves it **horizontally only**: width, height and both price levels stay exactly as they were (the magnet doesn't apply to slides). With a mouse, pressing anywhere on a rectangle grabs it (selects + slides), so dragging a rectangle never pans the chart; on touch an unselected rectangle still pans (tap to select first). Middle-mouse always pans. Corner resize, undo/redo and styling are unchanged. Cursor shows ↔ over rectangles.

## 5. Blown-account losses don't carry into unlock progress

- When a funded attempt is blown (equity reached $0) or replaced by a restart, and it is flat, its losses are **written off for unlock progress**. Example: an attempt that ends at −$5,000 leaves the next attempt at **$0 / $3,000**, and $3,000 of new profit unlocks $10K.
- If the blown attempt had banked profit toward an unlock the player already reached, it keeps just enough of it to return the player to the start of the current stage, never more (blowing an account can't raise progress or forgive another account's losses).
- History is preserved separately: lifetime net realized (dashboard KPI), Stats (all attempts, blown count), leaderboard profit, the attempt's trade history and `PriorRealized` are unchanged.
- Persistence: the frozen amounts are saved on the profile (`WriteOffs`, `Banked`, `ResetV`) inside the exchange checkpoint, applied on join/restore, idempotent across repeated joins. Profiles saved before this change have their already-finished blown attempts written off once on load.
- UI copy updated: blown notice ("Its losses don't count against unlocks: you're at $0 / $3,000 toward $10K" and an "Unlock progress" stat), dashboard KPI caption and ladder note.

## Verification

- **Server suites (fresh Play VM):** TradeLimitsTests 40/40, DepletionTests 11/11, FundedTests 11/11, ProgressionTests 10/10, MarketTests 11/11, StatsTests 12/12, LeaderboardTests 13/13, WorldTests 6/6. Chart suites: ChartTools 26, ChartViewport 39, ChartPaintPool 10 checks.
- **New tests:** 5-contract max long/short for ES, NQ, RTY and YM (6th rejected, snapshot capacity); stop validation, off-book arming, capacity reservation, cancel; trigger on the reaching trade with SL/TP; empty-book wait, partial fill and expiry; re-validation at trigger against a tightened limit and reduced buying power; stops through a v4 checkpoint round trip; blown → $0 / $3,000 → $3,000 unlocks $10K with Stats/history kept; nothing frozen while closing; banked-stage rule and no forgiveness of another account's losses; write-off survives save/restore and repeated rejoin without double credit; legacy profile migration.
- **Live Studio play (real mouse input):** right-click above/below market showed the correct pair, price and Max; quantity stepper (rapid clicks) and clicks on the menu background kept it open; Stop Buy ×3 armed and listed in Orders; it triggered and filled with SL/TP; the ticket then showed "Max ↑2 ↓8"; a 3-lot Limit Buy over the maximum was stopped with "Maximum currently available: 2 ES"; a trigger in an empty book was reported to the player. Rectangle: slide moved exactly 120 px with width and prices unchanged and no pan; unselected rectangle grabbed on drag; corner resize still worked. Zoom: 1,200-candle history, wheel zoom-out to 1,155 bars (plot width), 0 completed-candle mutations or colour mismatches.
- **UI fixtures (Edit, isolated):** blown notice at 1920×1022, 1280×720, 390×844, 844×390 and the dashboard at three sizes show $0 / $3,000 with the lifetime −$5,250 kept; no text-fit or off-screen issues.
- Edit preview regenerated (seed 73521, 31 candles, cash error 0). All temporary fixtures removed; `WarmupSeconds` restored to 1800 after the long-history zoom test.

## Not verified / notes

- **Persistence against Roblox DataStores wasn't tested live.** Studio has an unpublished AutoRecovery file open (PlaceId 0), so Play runs as a local sandbox. Leave/rejoin persistence is covered by checkpoint encode→decode→restore→join tests.
- **Save the place:** the open file is `137759823569682_AutoRecovery_3.rbxl`, not the published place. Save it back to the Get Funded! place (File → Save to Roblox / Publish) so the changes aren't lost.
- Deploying: checkpoint v4 means older servers fail closed; use Shut Down All Servers when publishing.
- Physical touch devices and multi-server behaviour not tested.
