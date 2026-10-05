# Security fixes — Get Funded!, 2026-09-30

Fixes for the findings in `output/security-audit-2026-09-30/SECURITY_AUDIT.md`. Only local source files in `src/` were changed. The open Studio place, saved `.rbxl` files, published experience, live remotes and DataStores were not touched. The audit fixtures in `output/security-audit-2026-09-30/` are unchanged; they now fail at the point where the exploit used to succeed.

## What changed

| Finding | Fix | Files |
| --- | --- | --- |
| F1 — unlimited free-reset accounts | A saved per-profile reset budget (token bucket) plus a 30 s cooldown for resetting a healthy $5K account. A per-profile ceiling on saved records. Exchange-wide capacity for new accounts. Compaction folds finished attempts into one archive record per tier. Every check runs before anything is cancelled, settled, retired or created. | `FundedAccounts.luau`, `TradeStats.luau`, `MarketEngine.luau`, `ProgressionConfig.luau`, `MarketServer.server.luau` |
| F1 — checkpoint writer/reader mismatch | The writer now refuses raw JSON above the reader's own bound (32,000,000) before compressing. It also applies the reader's header check before committing, and measures the whole stored DataStore value (lease fields + checkpoint + headroom). | `WorldCheckpoint.luau`, `WorldService.luau`, `WorldConfig.luau` |
| F2 — completed-purchase replays pause and save the exchange | A replay of a receipt that is already in a successful commit is answered from memory: no debit, account, write or TransactionBusy pause. A receipt created on this server stays "uncommitted" until a save that captured it succeeds. New purchases get a saved per-profile budget and a 2 s exchange-wide spacing. An unexpected error during a purchase can no longer leave the exchange frozen. | `WorldService.luau`, `FundedAccounts.luau`, `WorldConfig.luau` |
| F3 — unbounded replies for clients that never subscribe | New `ReplyBuffer` module: at most 64 queued replies per connection, each for at most 30 s. Every reply path (accepted, rejected, queue-full, paused) goes through it. A drop forces a full authoritative resync on the next packet and reports `RepliesDropped`. | `ReplyBuffer.luau` (new), `MarketServer.server.luau`, `WorldConfig.luau` |
| S1 — crossed fallback quote (conditional) | `Engine:_touch` still falls back to the last trade when a side is empty, but clamped. A buy never fills below the best bid, and a sell never above the best ask. | `MarketEngine.luau` |
| Tests | New maintained suite with 20 scenarios; registered as the `SecurityTests` diagnostics command. | `SecurityTests.luau` (new), `MarketServer.server.luau` |

Line endings of untouched lines were preserved, so each diff contains only real changes.

## New configuration and its gameplay effect

Times are real seconds of live exchange time. They are stored on the saved market clock (`Engine.Time` ÷ `SimulationSpeed`), which is restored with the checkpoint, never runs backwards across servers, and does not advance while the exchange is paused. Setting `Burst`, `CooldownSeconds` or `CompactAbove` to 0 disables that limit.

| Setting (file) | Default | Effect on players |
| --- | --- | --- |
| `ResetLimits.CooldownSeconds` (ProgressionConfig) | 30 | Voluntarily resetting a *healthy* free $5K account needs 30 s since the previous one. A restart after a blown account has no cooldown. |
| `ResetLimits.Burst` / `RefillSeconds` | 5 / 720 | Up to 5 free resets/restarts back to back, then 1 more every 12 minutes (5/hour sustained). Healthy resets and blown restarts share this budget. A rejection names the wait, e.g. "Next free reset in 9 min. Nothing was changed." |
| `PurchaseLimits.Burst` / `RefillSeconds` | 3 / 60 | Up to 3 new Shop purchases back to back, then 1 per minute. Replays of an existing receipt are free and instant. |
| `AccountLimits.MaxRetained` | 64 | Maximum saved funded records per player, archives included. One slot per still-unclaimed tier is always reserved, so earned activations are never blocked. In practice this caps usable accounts at roughly 50–60. |
| `AccountLimits.CompactAbove` / `KeepFinished` | 16 / 4 | Once a player has more than 16 records, finished attempts beyond the newest 4 are folded into a per-tier archive. The Accounts screen shows the 4 newest finished cards. Tier rows (`Owned`/`Blown`) and Stats still count every attempt; `Portfolio.Archived` summarises the folded ones. |
| `AccountLimits.ArchiveRecent` | 20 | Summary rows kept for the most recently folded attempts. |
| `AccountLimits.MaxExchangeAccounts` | 20,000 | Secondary cap on all funded records in the shared checkpoint. |
| `CapacityFraction` / `NewAccountCapacityFraction` (WorldConfig) | 0.8 / 0.9 | Resets and purchases pause at 80% of either checkpoint size limit. A first Start and earned activations continue up to 90%. Existing accounts always keep trading. |
| `MaxEncodedBytes` / `RecordHeadroomBytes` | 3,600,000 / 4,096 | Hard limit for the whole stored value (Roblox allows 4,194,304 characters). It sits above the old 3,500,000 checkpoint-only check, so no save the previous build accepted becomes unsavable. |
| `PurchaseSpacingSeconds` | 2 | Two different players' *new* purchases on one server are at least 2 s apart ("The Shop is busy…"). |
| `MaxQueuedReplies` / `ReplyMaxAgeSeconds` | 64 / 30 | Only affects clients that do not read their updates. Normal clients flush replies every 0.1 s. |

**What compaction keeps.** It never deletes accounting totals. The archive holds exact sums of Base, Balance, Realized and CashFlow, so `Engine:Audit` cash, P&L and inventory still reconcile. It also keeps merged lifetime stats (trades, wins/losses, gains/losses, best/worst, day buckets), attempt/blown/breached counts, and the sum of wallet high-water marks, so no folded profit can be re-earned. The newest 60 history rows and 40 fills are kept. What is lost is the per-attempt display history older than those rows.

**What is never folded:**

- the active account
- copy-trading members
- the account each tier entitlement points to
- accounts with a pending liquidation item
- accounts with an undelivered depletion notice

Purchase receipts are never modified, and folded instance keys cannot be reset again.

## Evidence (isolated Lune runtime, fake stores)

"Before" is the original sources and "after" is the fixed sources. Both runs used the audit's own fixtures plus `fix-verification.luau`.

| Check | Before | After |
| --- | --- | --- |
| Audit reset loop (200 immediate resets) | 200 accepted, 201 records, raw 137,053 → 301,511 B, portfolio 96,683 B | 1 accepted, 199 rejected with no change, 2 records, raw 137,949 B, portfolio 2,828 B |
| Sustained attacker, 1 h at 6 req/s, reconnecting every 100 s | unbounded | 21,600 requests → 9 accepted; max 10 records |
| Rate limits off, 1,000 resets (compaction alone) | unbounded | records steady at 11; raw ~148.8 KB and portfolio ~6.6 KB flat from reset 250 to 1,000; 1,001 lifetime attempts; Audit passes |
| Purchase + 10 replays | 10 extra writes, 10 global pauses | 0 extra writes, 0 pauses, 11 identical receipts, one $2,000 debit, bystander traded 10/10 |
| Codec fixture, 32,000,020 raw bytes | writer accepted, reader refused | writer refuses before compressing; exactly 32,000,000 saves and decodes; 32,000,001 refused |
| Non-subscribing client: 601 accepted, 600 rejected, 2,000 queue-full | 601 replies retained, growing | never more than 64; 1,744 queue-full replies also bounded; 0 after the 30 s age limit; the later Subscribe got one full packet with portfolio and `RepliesDropped` |
| Crossed fallback fixture, 10 round trips | +$625 realized and wallet | long $0, short $0; wallet $0 |

**Regression suites.** All 11 suites pass: 141 named scenarios and 166 assertions, 0 failures. That is the 121 pre-existing scenarios, 166 TradeAmendment assertions, and 20 new SecurityTests scenarios; ReearnTests also passes. See `regression-results.json`.

**New tests detect the original bugs.** Run against the original modules, 18 of the 20 new tests fail. The two that still pass are the ReplyBuffer unit test and the fail-closed restore test, which was already correct.

**Server script.** `server-reply-harness.luau` runs the current `MarketServer.server.luau` source against mocked Players, remotes and clock, the same technique as the audit harness. It also re-checks the audit's ownership, finite-number, ID and field-length protections: all pass. Results are in `server-reply-results.json`.

**S1 reachability — not demonstrated live.** The profitable round trip was only ever shown in a server-built fixture, and players cannot submit participant orders. Normal simulation over 3 seeds × 8,000 steps found no one-sided crossed book states, matching the audit; the fixed engine also produced 0 crossed effective quotes. The fix makes crossing impossible by construction, whether or not the state is reachable. It also covers limit-order marketability, closes, and liquidation with no liquidity, all tested.

An independent adversarial review found three real problems in an earlier draft. All three are fixed and have regression tests:

- A save accepted by the old writer could have become unopenable after deployment. The limits were re-based as described above.
- An error during a purchase could freeze the exchange permanently. The purchase call is now protected, and the transaction flag is cleared whenever the engine is reloaded.
- A compaction error could have left inconsistent account lists. Folds are now all-or-nothing, and compaction is limited to 4 profiles per maintenance tick.

## Compatibility and migration

- **No checkpoint version bump.** The record format is unchanged, and new profile fields (`Limits`) and archive fields are additive. Existing saves need no migration. Old profiles start with a full reset/purchase budget, which is saved as soon as it is spent.
- **Existing saves stay openable.** Every save that restores today can be re-saved: the raw limit equals the reader's, and the stored limit covers the old writer's maximum. A save the reader cannot decode still fails closed and is never overwritten (tested).
- **Already-bloated profiles are compacted on the maintenance tick,** up to 4 profiles per second. Compaction preserves lifetime statistics exactly; tests compare compacted and uncompacted play, including checkpoint round trips.
- **Rollback.** An older build can read the new saves. It would show an archive as one blown account card, and count it as a single attempt on the Stats page. Accounting and the wallet stay correct.
- **Client.** No client code changed. `Portfolio.Limits`, `Portfolio.Archived` and `RepliesDropped` are new, optional fields.

## Remaining risks

1. **Storage capacity (main risk, architectural).** The whole game still lives in one DataStore key.
   - A heavily active player at steady state measured about 143 KB raw.
   - At that size, resets and purchases pause after roughly 150–180 such players, sooner with less-compressible real data.
   - Before this fix, the same growth was unbounded and ended in an exchange-wide save failure. Now new accounts pause while existing players keep trading.
   - Real scaling needs per-player storage (profiles and ledgers in their own keys), which is out of scope here.
   - The live checkpoint size is unknown; check `LastRawBytes` / `LastStoredBytes` after deploying.
2. **Still unbounded (slowly):**
   - purchase receipts (bounded by earned wallet and the purchase budget)
   - one daily-stats row per record per trading day
   - `TradeStats` day buckets in archives
3. **Client.** The client does not act on `RepliesDropped`. A non-subscribing client whose Start reply expires would keep showing "Opening your account…" until its portfolio arrives. Normal clients are unaffected.
4. **Pre-existing, not changed.** `TradeStats.MarkDepletion` labels a healthy-reset attempt as an "earlier loss-limit breach" whenever stats are reconciled (every save builds a fresh Funded view). Compaction keeps that existing classification. Fixing it is a product decision.
5. **Future ladder `Version` bump.** `Funded:Migrate` would re-run and reset receipts and wallet history for every profile; this was already true before. Archive records are now kept intact if that happens.

## Deployment steps

1. In Studio, sync the 8 modified sources into their existing scripts under ServerScriptService.MarketReign / ReplicatedStorage.MarketReign (`ProgressionConfig` lives in ReplicatedStorage).
2. Create two new ModuleScripts in ServerScriptService.MarketReign: `ReplyBuffer` and `SecurityTests`.
3. In Edit mode, run `output/security-fix-verification-2026-09-30/run-regressions.luau` in the command bar. Optionally also run `fix-verification.luau`. Expect 0 failures.
4. Test in a private/test experience before publishing. Check the StudioDiagnostics performance output and the saved checkpoint size.
5. Publish.

## Not verified

- Real Roblox runtime: all runs used Lune with a Roblox API shim. Its JSON, compression and hash behaviour are close to Roblox's but not identical, so byte counts differ slightly.
- Real DataStore behaviour, sizes and latency.
- The live checkpoint's current size.
- Network transport.
- Studio command-bar execution of the new suite.
- Performance under production load.
- The client chart tests (ChartToolsTests / ChartViewportTests / ChartPaintPoolTests), which touch no changed code.
