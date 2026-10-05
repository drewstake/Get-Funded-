# Trading and UI fixes — September 28, 2026

Implemented in local source and the open Roblox Studio place. Studio confirmed “Saved new changes in \"Get Funded!\" to Roblox.” The updated place was exported to `output/Get Funded! Trading Fixes.rbxl` and copied to `Get Funded!.rbxl`. This saved the Studio draft; it did not publish a live release.

## Changes

- **Stable trade controls:** rejection shake previously captured a button position before deferred anchor centering completed, then restored that position under the new anchor. Feedback now centers before capturing geometry. BUY/SELL use fixed geometry with ring feedback, without hover lift, press scaling, shake translation, or success scaling. Error text uses a readable toast, and reserved ticket space keeps fills and position details from shifting the buttons.
- **NQ capacity:** simulated margin is $750 per contract. The existing 80% equity margin budget permits every requested fresh-account quantity. NQ remains $20 per point and $5 per 0.25-point tick. Default protection remains 40 stop ticks and 120 target ticks.
- **Server validation:** per-order and account limits now support up to 100 contracts. Capacity considers existing positions, pending entry orders, other instruments, equity, and stop risk; pending orders are checked again before execution. Reduce-only exits do not reserve new exposure. Rejections explain the constraint and state the maximum currently available quantity.
- **Copy trading:** each follower's exact requested same/proportional quantity reaches its own server capacity checks, instead of silently trimming to a global cap. Existing account/checkpoint loading adopts current limits and margin policy while retaining player progress, balances, positions, and history.
- **Chart:** removed the visible bid/ask/spread label and its reserved spacing. Quote data remains available for execution and validation.
- **Open P&L:** the decorative arrow always points up. Numeric P&L, negative signs, and profit/loss colors continue updating.
- **Instrument selectors:** chart and ticket selectors share a left-aligned ticker label and a separate drawn downward chevron on the right. The whole selector remains clickable on desktop and mobile.

| Starting account | Maximum NQ position | Margin at maximum |
| --- | ---: | ---: |
| $5K | 5 | $3,750 |
| $10K | 10 | $7,500 |
| $25K | 25 | $18,750 |
| $50K | 50 | $37,500 |
| $100K | 100 | $75,000 |

Maximums assume full starting equity and no other exposure. Losses and pending orders can reduce current capacity.

## Verification

All **70 server scenarios passed**: MarketTests 11, FundedTests 11, WorldTests 6, ProgressionTests 10, TradeLimitsTests 19, and LeaderboardTests 13.

The new server tests cover all five account tiers both long and short at their exact NQ maximum with default protection; maximum-plus-one rejection; mixed existing/pending exposure; cancellation; opposite-side entries; reduce-only orders; reduced equity; stop risk; fill-time revalidation; partial fills; invalid quantities; same/proportional copying in both directions; and migration of saved margins/caps without changing progress.

The focused UI validation passed on **seven viewports**: 320×568, 390×844, 844×390, 1000×600, 1280×720, 1440×900, and 1920×1080.

- 56 repeated rejections and 14 successful order replies.
- 3,451 geometry samples checking both buttons' positions, dimensions, anchors, absolute geometry, and scale through feedback and input effects.
- 35 positive, negative, and zero P&L updates with fixed arrow rotation and preserved numeric/color behavior.
- 44 selector checks covering ES, NQ, RTY, and YM, including spacing, text fit, and clickability.
- Long rejection text fits its toast; the BidAsk label is absent while underlying quote data remains present.
- Existing regression validation also passed 37 trade-control interactions and 21 market/limit/protection layout combinations.

Desktop and iPhone 13 portrait/landscape previews were visually inspected using Studio's device simulator. The simulator was restored to its default viewport. Tests used isolated in-memory accounts/engines and cloned UI fixtures in Edit mode; no saved player DataStore records were changed. Temporary validation objects were removed. Automated UI replies were simulated; this was not a physical-device or multiplayer network test.

All **32 Studio source files match local source** after synchronization. The seeded preview regenerated 30 candles from 23,162 executions, with zero cash/inventory conservation error and only floating-point equity rounding error.

## Artifacts

- `trading-ui-validation-results.json` — complete test and preview results.
- `output/trading-ui-source-hashes.json` — synchronized source hashes.
- `design-previews/trading-fixes-desktop.jpg` — desktop preview.
- `design-previews/trading-fixes-phone.jpg` — phone portrait preview.
- `design-previews/trading-fixes-landscape.jpg` — phone landscape preview.
- `backups/trading-ui-before-20260928/` — original source and place backup.
- `tools/ValidateTradingUIFixes.luau` and `src/TradeLimitsTests.luau` — repeatable regression validation.

Both updated local place copies have SHA-256 `D6BD4C55F60998A77F6D2F5D4A3644089857DFA0CB636AE721CC4E24A38B17C5`.
