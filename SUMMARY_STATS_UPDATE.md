# Accounts, projected unlock progress, and six-card Stats — September 29, 2026

Implemented in the open **Get Funded!** place (`137759823569682`) and the corresponding local source files.

## Behavior

- **NEXT UNLOCK** shows projected dollars and percentage, with a live bar, a separate confirmed amount, and a cyan confirmed marker on the desktop summary. The mobile header/bar and Accounts page use the same server projection. Negative amounts remain negative; the bar clamps to 0–100% while the number can exceed 100%.
- The server sends an atomic portfolio snapshot with every market broadcast. Projection is confirmed eligible progress plus unrealized P&L from that same eligible ledger, deduplicated by attempt. Switching accounts does not change the portfolio scope. Actual unlock evaluation still reads realized profit only.
- For a forfeited $10K+ tier, projection uses its saved fresh-profit baseline and exclusions. A blown/excluded attempt, frozen write-off, legacy practice account, or copied account counted a second time cannot inflate progress. Closing positions moves P&L from open to realized in the same snapshot.
- **Accounts** replaces the top Funded Balance card. It counts healthy activated funded accounts (locked/blown accounts and unlocked tiers awaiting activation are excluded), identifies the selected account, and opens Accounts from the whole card, including its value. The account list marks SELECTED, OWNED, READY, LOCKED, RE-EARN and BLOWN states using the existing colorful theme.
- **Stats** now uses six cards: Total P&L (closed trades only), Trade Win %, Avg Win / Avg Loss, Day Win %, Profit Factor, and Best Day % of Total Profit. Three columns become two below 940px of page width and one below 620px. Question marks support desktop hover/focus and tap to toggle a dismissible explanation.

## Statistics and dates

All six cards use the selected account scope and period. Lifetime includes retired/blown attempts; Current includes current attempts only; Dated history includes only closes with recorded dates, across attempts. Legacy practice accounts remain separate from funded totals.

New closing fills save `ClosedAt=os.time()`. A trading day is **00:00:00 through 23:59:59 UTC**. Daily counters and net P&L are persisted on each account inside the existing checkpoint; bounded Trade History trimming does not remove them. Aggregation combines accounts by UTC date before determining profitable days or best day.

Earlier history only stored a simulation `HH:MM:SS`, which cannot recover a calendar date. Its realized P&L and existing counters remain intact. Daily metrics show unavailable in a scope containing undated results. Dated history applies the same filter to all six cards so players can inspect complete dated results without silently mixing scopes. Migration is additive and idempotent; the checkpoint version stays v5.

- Trades are closing fills, matching the existing history: partial/multi-level closes count per closing fill.
- Break-even closes count in the trade denominator. Break-even days count in the day denominator; neither is a win. Classification rounds to cents.
- Average win = gross positive P&L / winning fills; average loss = absolute gross negative P&L / losing fills. The ratio divides these averages.
- Profit factor = gross positive P&L / absolute gross negative P&L. Positive gains with no losses show infinity, labeled “No gross losses.” No trades or all-even results show unavailable.
- Best-day share = highest net daily profit / total net realized profit. It is unavailable for zero/negative total profit or incomplete dates and may legitimately exceed 100%.
- Incomplete old win/loss breakdowns retain full Total P&L but show unavailable ratios. Missing values never become fabricated zeroes.

## Verification

Full results: `output/summary-stats-validation.json`.

- 7 focused calculation scenarios: positive/negative and multi-position projection; above-goal open profit without unlocking; closure reconciliation; copied accounts and switching; fresh re-earn exclusions; all six statistics across UTC boundaries; zero/negative/no-loss denominators; undated migration; trimmed history and JSON round trips.
- Existing server suites: Stats 12, Reearn 9, Funded 11, Depletion 11, Progression 10, Market 12, TradeLimits 40, World 6, Leaderboard 13. All passed. TradeAmendment checks: 166 passed.
- Native UI: 80 Stats views across 8 viewport sizes and scope/state combinations; 24 trading/account layouts; 28 trade-control layouts; 39 existing control interactions, including stop/target toggles and direct dollar entry. No layout issues reported.
- New UI integration checks exercise real callbacks and market-update paths: five rising/falling projections; equity/open P&L; Accounts navigation; selected/locked states; six cards; Dated scope; help visibility/bounds; desktop/tablet/phone columns; live mobile progress bar and projected/confirmed labels.
- Actual Play-mode sandbox: real clicks opened an ES trade with SL/TP disabled; both positive and negative open P&L updated the projection; confirming Close produced realized **$287.50**, zero open P&L, zero positions, and matching confirmed/projected progress. Stats then displayed $287.50, 100% trade/day wins, no-loss infinity ratios, and 100% best-day share. Clicking the Accounts card's numeric value opened the account page. Desktop hover help was verified.
- Visual inspection: desktop, phone portrait, scrolled phone cards, and phone landscape. Captures are in `design-previews/summary-*.png`. The Stats captures use isolated visual fixtures, not player history.
- The Play sandbox had persistence disabled. Test commands, cloned modules and fixtures were removed; `WorldConfig.Enabled=true` was restored before delivery. Saved player DataStores were not edited by the tests. Physical mobile devices and multiplayer load were not tested.
- Saved GUI preview regenerated from the seeded exchange: 31 candles, 27,071 executions, zero cash/inventory audit error. No fixture Stats data is saved in the final preview.

Backups: `backups/summary-stats-before-20260929/`. Existing Studio tests were preserved. All 39 local source files match the final Studio sources after normalizing line endings and trailing whitespace.

Changed source: `FundedAccounts`, `MarketEngine`, `TradeStats`, `MarketServer`, `MarketClient`, `TerminalUI`, `StatsView`. New verification scripts: `tools/ValidateSummaryStats.luau`, `tools/ValidateSummaryStatsUI.luau`, `tools/PreviewSummaryStats.luau`; the saved-preview generator and existing progression readout assertion were updated.

Published successfully from Studio on September 29, 2026 at 21:18:24 UTC (5:18 PM Eastern). Studio logged `Published new changes in "Get Funded!" to Roblox.` and linked publish notes for v110. The active edit session's `game.PlaceVersion` still reports its originally opened version, so the Studio publication result is the delivery confirmation.

Downloaded the updated cloud place through Studio at 21:20:07 UTC and refreshed both `Get Funded!.rbxl` and `output/Get Funded! Summary Stats.rbxl`. Both files have SHA-256 `469ed7b9e672ea4266ccf58811b6914a489e6046469ae6429547fb58d70458ef`. The saved GUI preview is included. Publication evidence is recorded in `output/summary-stats-publication.txt`.
