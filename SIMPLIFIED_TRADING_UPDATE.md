# Get Funded! — trading controls and funded-account update

Implemented and saved in `Get Funded!.rbxl` on September 29, 2026. The corresponding Luau sources are in `src/`. The original place and sources are preserved in `backups/simplified-trading-before-20260929/`.

## Changes

- Stop Loss ($) and Take Profit ($) now use full-width, 52-pixel-high dollar inputs. Removed their increment/decrement buttons, effective-total readouts and quantity-dependent estimate captions. Reduced the protection dialog's height and updated the mobile shortcuts. Amounts still mean total risk/reward for the selected quantity; conversion, tick rounding, quantity handling and server validation remain in place.
- The chart toolbar uses consistent line icons, spacing, alignment, hover feedback and selected states. Removed Undo/Redo buttons from the desktop toolbar and mobile Tools sheet. Existing keyboard history shortcuts remain available. The trend tool displays a small dot at the exact point a click will place, including magnet snapping, and hides it on exit, deselection or cancellation. Existing drawing selection, movement, extension and rectangle resizing remain intact.
- Only the $5K tier permits a free reset after liquidation. A blown higher tier becomes locked immediately, leaves the usable account list and rejects server-side select, activate and restart requests until re-earned. The old attempt, losses and trade statistics remain in the ledger. The active account falls back to a surviving account, and copy trading removes a failed follower or disables a failed leader. Unaffected accounts keep their positions and orders.
- New profit requirements are based on the tier's existing progression stage:

| Blown tier | New net realized profit required |
|---|---:|
| $10K | $3,000 |
| $25K | $5,000 |
| $50K | $10,000 |
| $100K | $20,000 |

Each forfeiture records its own realized-profit baseline. Prior profits, migration credits and loss write-offs cannot unlock that tier again. Accounts already blown when that baseline is captured are excluded; subsequent profits and losses on remaining/new attempts count toward new **net** profit. If multiple tiers are locked, each retains its own baseline and goal. Re-activation creates a new attempt after liquidation has finished. Baselines, locks and copy/active-account changes are part of the existing exchange checkpoint. Previously saved active-but-blown higher accounts adopt these rules on restore/join.

Trade requests also carry an expected account-attempt token. The server rejects a stale request after an account switch or automatic fallback, preventing it from accidentally executing on a different account.

## Verification in Roblox Studio

**All 372 regression checks passed across 13 suites.** These cover chart transforms and editing, trade protection and amendments, quantity limits, account depletion, progression, statistics, copying, checkpoint restoration and world storage behavior. Nine new account tests cover all four higher tiers, fresh-profit boundaries, rejected resets, repeated losses, multiple locked tiers, copy cleanup, history preservation and restore/rejoin persistence.

**39 trade-control interactions passed.** Direct SL/TP entry, decimal parsing, invalid values, quantity-dependent limits, toggles, draft/save/cancel behavior and submitted order settings were exercised. **45 layout checks passed** across desktop sizes and mobile portrait/landscape sizes, from 320×568 to 1920×1080. These include Accounts, higher-tier blown notices, Tools, market/limit tickets and the protection dialog. No text overflow was reported by these checks.

Seven trend-cursor checks passed: point alignment, click equivalence, magnet snapping, cancellation, mouse leave, deselection and price-axis exclusion. Native desktop interaction additionally verified tool selection, readiness feedback, placement of a trendline and right-click cancellation.

The iPhone 13 emulator was visually checked in landscape and portrait. Using native keyboard input in portrait, $123.45 was entered and saved; the shortcut retained that exact dollar amount. A real Play-mode sandbox order submitted one ES contract at 5,818.75 with that stop amount. The server rounded the stop to 5,816.25 ($125), then closed the trade there for -$125. Actual remote requests with a stale account token and a $10K restart were both rejected.

The final Studio source signatures match all 38 corresponding local modules/scripts after normalizing line endings and trailing whitespace. Temporary integration fixtures were removed from the place, the desktop preview was regenerated, and the local `.rbxl` was saved. Raw results are in `output/simplified-trading-validation.json`.

## Limits of verification

- The local place is unpublished (`PlaceId = 0`) and ran in the **LOCAL · NOT SAVED** sandbox. No production player accounts or saved data were changed, and the experience was not published.
- Persistence passed actual compressed checkpoint capture, encode, JSON serialization, decode and restore, followed by repeated joins. A live Roblox DataStore save/reconnect still needs verification in a published test place with persistence configured.
- Mobile verification used Studio's device emulator; physical-device keyboard and touch behavior were not tested.
