# Leaderboard

The desktop sidebar, mobile navigation and first-join welcome screen open the native Global / This Server leaderboard. It uses the existing Fredoka typography, outlined text, navy surfaces, cyan borders, purple selected tabs and glossy controls. The list scrolls independently of the pinned Your standing row. Top-three rows have gold, silver and bronze accents; your row has a cyan outline.

## Authoritative scoring

- `FundedAccounts:Earned` is the sole profit calculation. It adds each unique funded account's `Realized` once, including retired attempts and copy-trading followers. It excludes legacy practice accounts, starting capital, progression migration credits, unrealized P&L and activation capital.
- The engine persists `CompletedTrades` when an execution reduces a position, including partial and break-even closes. Returning accounts also qualify from saved close history or a nonzero saved realized result. No profit is reconstructed from the bounded display history.
- Existing profiles, balances, positions, saved histories and restarts remain intact. No leaderboard migration resets or rewrites profits.
- Values are compared in integer cents, descending, with ascending numeric Roblox user ID breaking ties. Ranks are ordinal (1, 2, 3). Highest tier includes unlocked tiers that have not yet been activated.

## Persistence and consistency

This game already stores every funded profile in one shared exchange checkpoint and routes follower servers to its leased owner. The leaderboard exploits that complete authoritative dataset: each save captures the full top 100, and only a successful checkpoint commit exposes that projection to the publisher. A separate `GetFunded_Leaderboard_v1` DataStore atomically stores the entire top-100 snapshot under `top100`.

This avoids independent ordered-score and metadata writes, ambiguous ties at the 100th-place cutoff, and stale winners after losses. Every snapshot contains the stable exchange WorldId and monotonically increasing SaveSequence. `UpdateAsync` rejects an older/equal sequence and fails closed on a different world identity. Only the current shared exchange owner can originate a new durable projection. Do not manually reset the exchange store without also intentionally migrating its leaderboard namespace.

The publisher coalesces saves and writes at most once per 45 seconds after success. Failed writes retain the latest pending projection and back off from 5 to 45 seconds. Reads are cached for 45 seconds, with one read in flight and a 10-second error retry floor. There are no per-row DataStore requests. Missing historical names use a batched Roblox UserService lookup with cached results; avatars use Roblox headshot thumbnails.

Global clients refresh only while visible, every 45 seconds; This Server refreshes every 10 seconds and includes only currently connected players. The read-only RemoteFunction accepts only a tab name and has its own per-player two-second limit. It accepts no scores, account IDs or profit submissions and does not consume trading request capacity.

The pinned global rank is exact only when a fresh, successfully read/published snapshot contains that player with matching profit. Otherwise eligible players see **Outside top 100**, and players without a completed funded trade see **Complete a trade to join**. Reads/writes that fail, snapshots older than 120 seconds, and expired client caches suppress exact ranks. Saved results remain available with a Retry state. Loading, empty and cold-error states are explicit.

Leaderboard capture, storage and name lookup failures are isolated from matching and saving. Shutdown commits the exchange before making a best-effort final leaderboard publish; the next owner reconstructs any missed projection from the durable exchange. Existing exchange-save safety rules continue to apply independently.

Studio uses the `Studio` scope; published game servers use `Live`. Studio test rankings never enter production. No test-mode source overrides or temporary fixture objects remain installed.

## Verification

See `leaderboard-validation-results.json` for the evidence. Fifty-one isolated engine, funded-account, progression, continuity and leaderboard regression checks passed. These cover negative and break-even profits, copied trades, restarts, legacy exclusions, duplicate IDs, the tie cutoff, stale writers and delayed responses, saved records, reconnects, outage recovery and continued trading during leaderboard failures.

An actual isolated Studio trade closed at **-$12.50**. Both tabs and an independent cloud-store reader returned the same amount. It survived two full Studio restarts with one retained account. A fake client score was ignored. A temporary failed read endpoint verified cold-error, cached-error/rank suppression and Retry recovery, then was removed. Both temporary cloud keys were removed after the writer stopped.

`tools/ValidateLeaderboardUI.luau` mounts and destroys isolated native UI fixtures, checking seven sizes: 1440×900, 1000×600, 390×720, 360×582, 750×304, 680×262 and 834×1100. Each fits at least one complete scrolling row plus the pinned row without overlap. It also covers all four UI states and expired-cache rank suppression. Native screenshots and actual input verified desktop and iPhone 17 Pro portrait/landscape. The existing Sensor orientation and CoreUISafeInsets were preserved.

### Source locations

- Server: `LeaderboardRanking`, `LeaderboardService`, `LeaderboardTests`, and integrations in `MarketServer`, `WorldService`, `FundedAccounts`, `MarketEngine`.
- Shared presentation: `LeaderboardClient`, `LeaderboardView`, and navigation integration in `TerminalUI`.
- Studio regression invocation: `ServerScriptService.MarketReign.StudioDiagnostics:Invoke("LeaderboardTests")` in Play, or require a fresh cloned server module in Edit.
- Refresh the normal authored preview with `tools/RefreshStudioPreview.luau` after installing source updates.
