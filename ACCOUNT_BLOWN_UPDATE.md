# Account Blown recovery flow — September 28, 2026

> **Updated September 29, 2026:** a blown attempt's losses no longer count toward unlocks. The notice now says the loss stays in your Stats and shows unlock progress (e.g. $0 / $3,000). See [TRADING_IMPROVEMENTS_UPDATE.md](TRADING_IMPROVEMENTS_UPDATE.md).

When the server confirms a funded account is depleted (the engine latched it at **$0 equity or below**), the player now gets a clear **Account Blown** notice, a persistent blown status, and a server-validated **Restart Account** action. Negative open P&L with positive equity never triggers any of it.

## What the player sees

- **Notice (once per depletion event).** Pink "Account Blown" dialog naming the account, attempt and copy role (e.g. `$5K FUNDED · ATTEMPT 2 · COPY FOLLOWER`). It says equity reached $0 and positions were liquidated, shows equity/final balance, this attempt's result and net realized profit, and explains what restarting does: opens the next attempt with the tier's starting capital, keeps this attempt's result and trade history (net realized profit still counts toward unlocks), and leaves other accounts, positions and copy settings unchanged. *Nothing restarts automatically.*
- **Closing state.** While liquidation still has open contracts, the notice shows "Closing remaining positions…" (contracts and orders left) and the restart button reads "Closing positions…" and is disabled. It switches live to "All positions closed · ready to restart" when the server reports the account flat.
- **Persistent status.** After dismissal: a dashboard banner per blown account with Restart Account, a BLOWN / CLOSING tier card with the same action, a workspace tile replacing the objective tile on desktop and a banner above the chart on phones, blown labels in the account switcher, account details and mobile header. Tapping the status reopens the notice on demand; refreshes, navigation, reconnecting and account switching never reopen it automatically.
- **Copy trading.** A blown follower is identified as such; the lead and every other account keep their positions. New lead orders report the follower as *Skipped: Account blown… Restart it to resume copying.* After restart the follower resumes copying with unchanged settings.
- **Restart.** One request in flight ("Restarting…"), 0.6 s debounce, server confirmation closes the notice and, for the active account, returns to the workspace showing the restored balance.

## How it works

- `FundedAccounts:Depletion(entry)` is the single authoritative rule (engine `Locked`, open positions/orders → Closing, `AllowRestart` and flat → CanRestart). `Restart` uses the same rule; a duplicate in the same step is rejected ("already restarted").
- `TakeEvents` emits one `Depleted` event per account attempt (`F5K:1`, `F5K:2`, …). The marker `DepletionNotice` is saved with the profile in the existing checkpoint, so the notice survives reconnects/restores without repeating. Profiles saved before this update announce an already-depleted account once.
- `View` rows add `Depleted`, `Closing`, `CanRestart`, `DepletionEvent`, `OpenContracts` and `PriorRealized`.
- `MarketClient` buffers events that arrive before the UI listens (`Session:OnEvent`), so a depletion that happened while away is still announced once on join.
- No protocol or checkpoint version change; server validation, rate limits and request-id de-duplication are unchanged.

Files: `src/FundedAccounts.luau`, `src/MarketClient.luau`, `src/TerminalUI.luau`, `src/MarketServer.server.luau` (diagnostic command), new `src/DepletionTests.luau`. Backup: `backups/account-blown-before-20260928/`.

## Verification

See `account-blown-validation-results.json`.

- Regression suites (fresh Studio Play VM): DepletionTests 7/7, FundedTests 11/11, ProgressionTests 10/10, TradeLimitsTests 27/27, MarketTests 11/11; WorldTests 6/6 and LeaderboardTests 13/13 (isolated Edit clones).
- Live, isolated local sandbox (persistence disabled, nothing saved) with real clicks through the UI and real server requests: see the results file for each step.
- Layout audit: 30 views (320×568, 390×844, 844×390, 1280×720, 1920×1080 × trade/dashboard/notice × closing/ready) with no text overflow, off-screen dialog, overlapping controls, and the restart action in view on every size.
- Saved Studio world untouched: SaveSequence 718, checkpoint digest `1cda630c…be269` before and after.

Studio source matches `src/` for all 33 scripts; all temporary fixtures were removed. Edit preview regenerated (30 candles, seed 73521). Not published.
