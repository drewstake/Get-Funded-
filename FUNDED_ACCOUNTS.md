# Funded accounts, onboarding and copy trading

Get Funded! now plays as a simulated prop firm: **Start → Trade → Earn → Unlock → Choose whether to copy → Scale.** Everything is server-authoritative and runs through the existing matching engine. All capital, prices and profits are virtual.

## Player journey

| Player | Lands on | What they see |
| --- | --- | --- |
| First-time | Welcome | "Start with $5,000. Prove your skills. Build your funded portfolio.", the ladder, one **Start a Funded Account** button and a simulation notice. No account exists until they press it. |
| Just started | Trading workspace | $5K account selected and a skippable 5-step guided first trade: pick an instrument, set size, place, close, then the **first profit milestone** and the next objective. |
| Returning | Funded accounts dashboard | Prominent **Continue Trading** (resumes the last account), capital vs. realized profit, next-unlock progress, the ladder, copy trading and legacy accounts. |
| Pre-ladder player (migrated) | Dashboard | Their old practice account(s) kept exactly as they were, **Continue Trading** into them, and **Start $5K** to begin the ladder. |

The workspace keeps the After Hours layout. Desktop adds a fourth tile for the next objective (click to open the dashboard) and an **Accounts** item in the rail. Phones show the account and objective in the header with a thin progress line, and **Accounts** in the bottom bar. Unlocks and the first profit get a short animated notification; unlocks include **Activate**.

## Ladder rules (`ReplicatedStorage.MarketReign.ProgressionConfig`)

| Tier | Capital | Unlocks at (lifetime net realized) | Loss limit | Max contracts |
| --- | --- | --- | --- | --- |
| $5K | $5,000 | Start | $5,000 | 5 |
| $10K | $10,000 | $3,000 | $10,000 | 10 |
| $25K | $25,000 | $8,000 | $25,000 | 20 |
| $50K | $50,000 | $18,000 | $50,000 | 30 |
| $100K | $100,000 | $38,000 | $100,000 | 40 |

Stage goals are $3,000 / $5,000 / $10,000 / $20,000 / $40,000. Top-tier completion occurs at $78,000 cumulative profit. The UI displays progress within the current stage. Existing unlocks receive separate one-time credit preserving progress from the earlier ladder; actual realized profit is unchanged. See [the current update and verification report](PROGRESSION_EMINI_UPDATE.md).

- Progress is net realized profit across the player's funded accounts. Starting balances, open P&L, legacy practice accounts and **blown-account losses** never count: when an attempt is blown (or replaced by a restart) and flat, its losses are written off for unlock progress, so the next attempt starts at the beginning of the current stage (e.g. $0 / $3,000). Lifetime net realized, Stats and the leaderboard still include every attempt. See [TRADING_IMPROVEMENTS_UPDATE.md](TRADING_IMPROVEMENTS_UPDATE.md).
- An unlock is recorded once, saved, and announced once. Losses after an unlock don't take it away.
- Unlocked accounts are activated by the player; activation never switches the traded account silently. Accounts are kept and can be switched at any time; switching never pauses or closes the others.
- An **account depleted** at equity zero or below can restart with fresh capital once it is flat. The player sees an **Account Blown** notice once per depletion, a persistent blown status and a **Restart Account** action; see [ACCOUNT_BLOWN_UPDATE.md](ACCOUNT_BLOWN_UPDATE.md). The earlier realized loss and retained history stay in the ledger and in Stats, but not in unlock progress. Positive-equity margin liquidation does not fail an account or enable a restart; daily/trailing loss thresholds do not apply.
- Tiers, sizes, thresholds, loss limits, contract caps, margin use, restarts and copy defaults are all in the config. `Funded.Validate` stops the server on a malformed ladder (non-ascending sizes or thresholds, a second free tier, bad ids).

## Copy trading

Introduced when the second funded account is activated; **off until the player turns it on**. The player picks one lead and any followers, plus sizing (same quantity, or scaled by account size).

- Only orders placed on the lead are copied: market/limit entries with their SL/TP, closes, limit cancels and SL/TP moves or cancels.
- Each copy is a normal `MarketEngine` call on the follower's own account, so its E-mini multiplier, margin, contract cap, equity, depletion state and order limits apply. Linked limit orders carry the lead order id so cancels follow.
- Every copied order returns a copy report (copied / skipped / rejected with the engine's reason), shown as a card and summarized on the dashboard.
- Turning copying off changes settings only. Positions, stops and orders stay exactly where they are and each account trades independently.
- A player's accounts never trade against each other: same-player self-trade prevention cancels the older quote, exactly as the engine already does within one account.

## Persistence and migration

- Profiles (onboarding state, tiers, ledger, active account, copy settings) are saved inside the existing checkpoint, so balances and unlocks always restore together. No second DataStore.
- The checkpoint format is **version 4** (armed stop entry orders), reading versions 1–4. Existing practice accounts retain their balances and history and remain excluded from unlocks and funded capital. Micro positions retain their original exposure and protection; unfilled micro entries are cancelled. Selectable new trades use ES, NQ, RTY and YM. The [migration report](PROGRESSION_EMINI_UPDATE.md) describes profile credit, retained micro books and positive-equity account restoration.
- Older server builds cannot read version 3 and fail closed rather than saving over the migrated world.
- New players get no implicit account. Repeated or duplicated Start requests return the existing starter account.

## Protocol

New `OrderRequest` actions: `Start`, `Activate {Tier}`, `Account {Key}` (tier id or `L50000`), `Restart {Tier}`, `Copy {Enabled, Leader, Followers, Sizing}`, `Flag {Stage}`. `MarketUpdate` adds `Portfolio` (sent on change, on full refresh and once per second), `Events` (unlock / first profit) and `AccountKey`; replies add `Kind` and `Copies`. Players without an account receive status-and-portfolio packets only.

## Files

| New | Purpose |
| --- | --- |
| `src/ProgressionConfig.luau` | Configurable ladder and copy defaults (ReplicatedStorage) |
| `src/FundedAccounts.luau` | Profiles, lifecycle, unlocks, migration, copy plan/mirror (ServerScriptService) |
| `src/FundedTests.luau` | 11-case regression suite |

Runtime source and preview helpers are in `src/` and `tools/`. `ProgressionTests` adds 10 boundary, E-mini, loss and migration regressions. Current changes and backups are recorded in [PROGRESSION_EMINI_UPDATE.md](PROGRESSION_EMINI_UPDATE.md).

## Studio diagnostics (server context, Play)

```lua
local d = game.ServerScriptService.MarketReign.StudioDiagnostics
print(d:Invoke("FundedTests"))           -- 11 funded / copy / migration cases
print(d:Invoke("Profiles"))              -- saved profile + client view per player
d:Invoke("SetUnlock", "F10K", 20)        -- playtest aid: lower one threshold for this session only (never saved)
```

## Earlier funded-ladder verification (before the E-mini update)

The following records the earlier micro-contract build. Current results are in [PROGRESSION_EMINI_UPDATE.md](PROGRESSION_EMINI_UPDATE.md) and `emini-progression-validation-results.json`.

- Studio Play: engine 11/11 (seed 73521 replay hash still **1610557394**, 1,259 executions), continuity 6/6, funded 11/11 including checkpoint v2 round trip and v1 migration.
- Live flow on a separate saved test world: Welcome → Start → full guided tour → first profit (+$25) → unlock celebration → activate $10K → copy intro → copy on (lead $10K) → 3 MNQ copy **rejected for margin** and reported → 1 MES copied → copy off with both positions and stops intact → independent close → account switching → Stop/Play: returning player landed on the dashboard with everything restored and no repeated celebration.
- Server guards via the real remote: duplicate Start created nothing, locked activation and invalid account/copy requests were rejected.
- Real saved Studio world: your existing $50K practice account migrated intact ($50,362.50, realized +$362.50) and excluded from progress; Start $5K then worked alongside it.
- Layout audit: 35 screen/viewport combinations (welcome, starter, tour, full ladder dashboard and workspace at 1920×1022 → 320×568 and 844×390) with no text overflow, off-screen elements or text overlapping card buttons. Original workspace interactions (BUY payload, close confirmation, mobile SELL) unchanged.
- Not tested: physical-device touch, live-scope multi-server behavior after publishing.

## Publishing notes

The changes are in the open Studio session and in `src/`. This update has not been published. For a future deployment, use **Shut Down All Servers** (or Migrate to Latest Update) so no older server build tries to own the exchange: an old build would fail closed on the version 3 checkpoint (no data loss, but trading pauses until the old servers are gone).
