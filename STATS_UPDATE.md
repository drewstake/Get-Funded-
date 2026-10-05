# Stats page — September 28, 2026

Players get a **Stats** page (desktop sidebar and phone bottom bar, between Accounts and Leaderboard) that shows their trading performance across funded accounts and restarts. The server calculates every number and saves it with the exchange checkpoint.

## What the page shows

- **Scopes:** All Funded Accounts, one tab per tier the player has traded, and one tab per legacy practice account. Legacy practice accounts are labelled "not in funded totals" and are never included in funded totals.
- **Period:** *Lifetime · all attempts* includes previous attempts and restarts. *Current attempt(s) only* shows just the attempt trading now. A banner states what each view includes, for example "$5K Funded · all 3 attempts, including 2 blown…".
- **Headline tiles:** Net realized P&L, Open P&L (live), Total P&L and Accounts blown ("Of N attempts · each once").
- **Trade results:** Total gains, Total losses (shown as a positive amount), Completed trades, Winning, Losing and Break-even trades, Win rate, Best trade, Worst trade and Average per trade.
- **Breakdown by account** (All scope): per tier, the attempts, blown count, trades, win rate and net realized. Tap a row to open that scope.
- **How your stats are counted:** short explanations of the ambiguous metrics.
- **States:** loading (with Retry), waiting for the exchange, error (Retry, with a note that trades and saved results are safe), no account yet (Start a Funded Account), and no completed trades yet.
- **Formatting:** values are signed (+$ / −$) and coloured green or red. $0.00 is neutral.

## Accounting rules

| Metric | Definition |
| --- | --- |
| Completed trade | One closing fill, which is one row of Trade History. A partial close counts once for the contracts it closed; the rest counts when it closes. A reversal counts its closing part. A close that fills at two price levels counts as two rows, matching the history. |
| Win / loss / break-even | Classified by the result rounded to the cent: above $0.00, below $0.00, or exactly $0.00. |
| Win rate | Winning trades divided by completed trades. Break-even trades count as completed but not as wins. |
| Total gains / losses | Sum of positive results, and the absolute sum of negative results. Starting capital, unlocks, activation and restart funding are never gains. |
| Net realized P&L | Total gains minus total losses. Always equal to the ledger's `Realized` (the same value used for unlocks and the leaderboard). |
| Open P&L | Unrealized P&L on active attempts' open positions, taken from the live server portfolio summary. Total P&L = net realized + open. |
| Accounts blown | Funded attempts depleted to $0 equity. Each attempt counts once, including attempts that were later restarted. |
| Copied trades | Counted once for each account that actually traded them (lead and each follower). |

## How it works

- **`TradeStats` (new, server).** Each player account carries a `Stats` record: trades, wins, losses, break-even, gains, losses, best, worst and the last counted trade id. `MarketEngine._fillAccount` updates it on the same execution that changes Balance/Realized, before the 60-row display history is trimmed, so trimming never erases lifetime totals. The engine sets `Depleted` once per attempt when it latches depletion at $0 equity. Only player accounts carry stats.
- **Persistence.** Stats live on the account inside the existing checkpoint, so they save and restore atomically with balances. The checkpoint format is unchanged (still v3). `Engine:Audit` now also checks that stats reconcile with realized P&L.
- **Migration** (`TradeStats.Reconcile`, run on every restore and when `FundedAccounts` is built; idempotent):
  - Accounts saved before stats are rebuilt from their saved trade history. When the rows reconcile with the realized total and the completed-trade counter, and the history was never trimmed, the rebuild is complete ("Recovered").
  - Otherwise the unmatched part is kept as an untracked remainder. Net realized still equals the ledger, and the page labels it: "Win/loss breakdown tracked from Sep 28, 2026. Earlier results without a breakdown (net X across at least N earlier trades) are included in Net realized P&L only." The trade count then shows "N+" and the average is computed over tracked trades.
  - Saved blown attempts are classified from their final state. A retired attempt that still held most of its capital was restarted under the old loss-limit rules; it is reported separately and not counted as blown.
  - Drift repair: rows written by an older server build are picked up once, by trade id, and any remaining mismatch moves into the labelled remainder. Nothing is counted twice.
- **Delivery.** `FundedAccounts:Stats(uid)` builds the scopes. `MarketServer` sends `Stats` on join or full refresh, and whenever `StatsKey` changes (a close, a depletion or a restart). Price moves don't resend it. A read-only `Stats` request (the Retry button, or automatically if the page opens without data) resends it. Failures are isolated and shown as the error state.
- **UI.** `StatsView` (new, ReplicatedStorage) draws the page with the terminal's own helpers: Fredoka, outlined values, glossy tabs and colourful cards. `TerminalUI` adds the nav item, the screen, live open/total updates, and fixture options for Studio validation (`StatsData`, `PortfolioData`, `StatsScope`, `StatsPeriod`).

Files: new `src/TradeStats.luau`, `src/StatsView.luau`, `src/StatsTests.luau`, `tools/ValidateStatsUI.luau`. Changed: `MarketEngine`, `FundedAccounts`, `WorldCheckpoint`, `MarketServer`, `MarketClient`, `TerminalUI`. Backup: `backups/stats-before-20260928/`.

## Verification

Full results are in `stats-validation-results.json`.

- **StatsTests 12/12 (isolated engines):** wins, losses and break-even trades (including sub-cent rounding); partial, multi-level and reversal closes; open P&L changes without a resend; copied trades once per account; repeated depletion updates; restarts; history trimming (75 trades); migration (complete, trimmed, no-counter, idempotent); old-rule breaches; older-build drift; legacy separation; checkpoint round trips. Every case reconciles with the ledger.
- **Regressions:** MarketTests 11/11, FundedTests 11/11, DepletionTests 7/7, ProgressionTests 10/10, TradeLimitsTests 27/27, LeaderboardTests 13/13, WorldTests 6/6, and the chart suites (35, 10 and 24 cases). The Edit preview regenerated identically: seed 73521, 23,162 executions, 30 candles.
- **Real saved data (read-only):** the `primary-exchange` checkpoint (SaveSequence 815) was restored in memory with the new code. Your profile rebuilt completely: 4 $5K attempts, 3 blown, 20 trades (5W/15L), gains $373.50, losses $15,439.75, net −$15,066.25. That equals your net realized profit. Your legacy $50K practice account (+$362.50, 4 trades) stayed separate. Nothing was written: SaveSequence was still 815 afterwards, and the leaderboard snapshot was unchanged.
- **Live Studio sandbox:** tested with real clicks on the Stats nav, scope tabs, period tabs and Restart, and real server requests. Stats updated within about 1 s after opens, a partial close, closes, a forced crash with a two-fill liquidation, and a restart. Lifetime vs current attempt values were correct, and repeated Retry requests didn't change any value.
- **Persisted restart / reconnect:** tested on a separate isolated world key. After trades, a blown attempt and a restart, Stop/Play restored identical stats (7 trades, −$9,700, 1 blown). The blown notice did not reopen. The isolated key was then deleted.
- **Layout:** `tools/ValidateStatsUI.luau` checked 80 views at 1920×1022 down to 320×568 and 844×390 (six scope/period variants plus the loading, error, empty and zero-trade states). No overflow, off-screen, overlap or touch-target issues. The workspace audit including Stats found no Stats issues. Two items it reports come from existing screens: the guided-tour Skip button (88×26) and the Activity empty text at 1024×600.
- **Previews:** `design-previews/stats-desktop.jpg`, `stats-phone.jpg`, `stats-phone-breakdown.jpg` and `stats-landscape.jpg`.
- Studio source matches `src/` for all 36 scripts. Temporary fixtures (sandbox config, isolated world key, crash command, validation clones) were removed.

## Notes

- **Save the place:** press Ctrl+S (File → Save to Roblox) in Studio. The tools can't trigger a save. The local `Get Funded!.rbxl` file is older than the open session.
- On first run the live build migrates the saved world as described above. Checkpoint v3 is unchanged, but an older server build would keep trading without updating stats. The next new-build restore repairs that drift and labels anything it can't match. Use the usual Shut Down All Servers when publishing.
- Not tested: physical devices, and multiple live servers.
