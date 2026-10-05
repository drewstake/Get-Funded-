# Progression, E-minis and pacing update

Implemented September 28, 2026. Source modules and the open Studio place are synchronized. The Roblox save is independently verified in the Studio log: at 17:56:11.952 UTC (1:56 PM Eastern), CreatorOutput reported that new changes in Get Funded! were saved to Roblox. Studio reports place version 18. The local `Get Funded!.rbxl` remains the earlier version: its export dialog could not be completed because Windows automation repeatedly failed to activate the window. All updated source files are saved locally. The colorful palette, rounded Fredoka typography, chart tools, order controls, protection editing and copy trading remain in place. The engine-generated Edit preview has been regenerated; a captured image is saved at `design-previews/emini-progression-final.jpg`.

## Progression and account rules

| Current stage | Additional net realized profit | Result | New-player cumulative profit | Maximum loss |
| --- | ---: | --- | ---: | ---: |
| $5K | $3,000 | Unlock $10K | $3,000 | $5,000 |
| $10K | $5,000 | Unlock $25K | $8,000 | $10,000 |
| $25K | $10,000 | Unlock $50K | $18,000 | $25,000 |
| $50K | $20,000 | Unlock $100K | $38,000 | $50,000 |
| $100K | $40,000 | Top-tier completion | $78,000 | $100,000 |

Progress remains lifetime closed-trade profits minus losses across funded accounts and all restarted attempts. Starting capital, unrealized P&L and legacy practice accounts are excluded. Account switching cannot reset or duplicate it. The objective displays the current stage: at $3,000 lifetime realized profit it reads $0 / $5,000 toward $25K. Unlocks and completion remain earned after subsequent losses.

Existing profiles receive a one-time, separately saved migration credit equal to the new unlock floor minus the old floor of their highest earned tier. This preserves their progress above or below that floor without changing actual realized profit, balances or history. For example, an old $25K unlock at $1,500 receives $6,500 credit and starts the new $10,000 stage at $0; an extra $200 already earned remains $200 toward that stage. Loading the migration again cannot add credit twice.

Account equity is balance plus unrealized P&L. Depletion at zero or below fails the account; daily and trailing loss rules no longer fail it earlier. A margin exit while equity is positive leaves the account active and does not grant a restart. Depletion is latched on individual executions, including crossings and recoveries within one scheduler step. A depleted account can restart after positions close; prior realized losses and retained history remain in its ledger. Slippage can leave a negative balance before restart.

## Instruments and saved data

| Selectable instrument | Dollars per point per contract | Tick size | Dollars per tick | Simulated margin |
| --- | ---: | ---: | ---: | ---: |
| ES â€” E-mini S&P 500 | $50 | 0.25 | $12.50 | $1,200 |
| NQ â€” E-mini Nasdaq-100 | $20 | 0.25 | $5.00 | $2,000 |
| RTY â€” E-mini Russell 2000 | $50 | 0.10 | $5.00 | $800 |
| YM â€” E-mini Dow | $5 | 1.00 | $5.00 | $1,000 |

Margins are game settings, not broker quotes. A new $5K account can enter one ES or NQ with default quantity 1. Matching, stops, targets, P&L, estimated risk, account caps and follower checks use these economics. Tutorials, selectors, default symbols, fixtures and previews use E-minis.

Checkpoint version 3 reads versions 1â€“3. Existing micro positions keep their symbol, quantity, entry, multiplier, stop and target, and can be closed or protected at their original exposure. Retained closed trades and balances are not rescaled. Unfilled player micro entry orders are cancelled on migration; reduce-only exits/protection remain. New micro entries are rejected. Original micro books, participants, executed candles and prices remain available for compatibility; fresh E-mini books start from the saved corresponding last price through a real opening auction. No micro volume is relabelled as E-mini volume. Restoring version 3 again does not create duplicate books.

Fresh worlds have 176 participants; migrated worlds retain the micro participants and add E-mini participants, for 352. Legacy quotes are omitted from normal client packets unless the account holds the corresponding legacy position. Positive-equity accounts locked under older loss rules are reopened during old-checkpoint migration; retired attempts remain retired.

## Market pacing

`SimulationSpeed = 18`, with unchanged `Volatility = 1`, deterministic 0.25 simulated-second steps and 10 Hz market broadcasts. This executes 72 scheduler steps per real second. Individual matched trades still set prices, OHLCV and protection triggers. Server authority, shared order books, private runtime random state and two-sided participant behavior are preserved. The scheduler retains catch-up work instead of skipping simulation steps.

Measured in the migrated cloud test world: **18.009 simulated seconds per real second**, equivalent to **3.332 real seconds per one-minute candle**. The preview is static and labelled PREVIEW; Play connects the live chart.

## Verification

Full outputs are in `emini-progression-validation-results.json`; normalized SHA-256 comparison matched all 26 local and Studio source modules.

- **38 server scenarios passed:** 11 matching/risk/protection/replay, 11 funded-account/copy, 6 continuity/storage and 10 progression/E-mini/migration cases. Exact boundaries, closed losses, switching, one-time credit, completion, long/short/partial P&L, positive-equity margin exits, depletion, restarts and intrastep stop/target crossings passed.
- **UI:** 37 control interactions and 21 layouts passed; 14 summary-card checks and 70 progression views passed with no text-fit issues. Stage boundaries and completion were checked on desktop, 320Ã—568, 390Ã—844 and landscape phone sizes. The full overlay/dashboard audit passed. A narrow-phone empty-chart message was shortened after the audit caught overflow.
- **Cloud restart:** a copy of the existing version 2 Studio checkpoint migrated successfully. Existing $50K practice balance $50,362.50 and $5K funded balance $4,923.75, realized values and retained histories matched. In the isolated copy, Stop/Play retained an ES entry, stop and target; a saved pending NQ order resumed and filled afterward. Repeated codec/migration restoration preserved balances and did not duplicate progress or markets.
- **Simulation cost:** 2,160 steps per profile (30 seconds of real-time-equivalent work). Fresh world: mean 0.162 ms/step, p99 0.370 ms, max 0.642 ms. Migrated world: mean 0.458 ms, p99 0.971 ms, max 1.360 ms. Cash/inventory conserved; floating-point P&L reconciliation error was around 1e-8.
- **Live client:** approximately 10 batches/second, roughly 2.0â€“2.3 KB average JSON payload, no repeated full snapshots. Fresh-world p95/p99 frame intervals were 5.24/5.85 ms on this Studio host. Migrated chart mean paint cost was 0.723 ms with responsive open P&L; no candle recoloring errors or completed-candle mutations.
- **Chart interaction:** 720 cached candles, 577 visible, 240 hover samples; mean 0.080 ms, p95 0.102 ms, zero new GUI objects and zero full chart paints during hover. All 12 interaction/integrity checks passed.

All mutations and restart tests used the separate keys `emini-progression-isolated-20260928` and `emini-migration-isolated-20260928`. The original `primary-exchange` checkpoint was read for comparison/copy only and remains version 2. Studio was returned to Edit with the original WorldConfig restored. The primary world migrates when the new build next owns it. No live publication was performed.

Measurements cover this Studio host and emulated viewports. Physical-device touch/performance, many concurrent clients and live cross-server teleport behavior are not verified. Network sizes are JSON payload estimates, not measured Roblox transport bytes. Before a future deployment, use the existing single-writer ownership workflow and retire old servers; old builds cannot read version 3 checkpoints.

Backups: `backups/src.before-emini-progression/`, `backups/studio-before-emini-progression.json` and `backups/Get Funded!.before-emini-progression.rbxl`.
