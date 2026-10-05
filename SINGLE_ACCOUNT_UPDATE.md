# Get Funded! single-account update — 2026-10-01

This document supersedes the account, wallet, shop, ladder and copy-trading behavior described in older update notes. The source and local place implement one active trading account per player. This update has not been published. Automated validation used isolated profiles only.

## Player flow

New players receive $5,000 in-game money automatically and land on Trade. Balance is starting capital plus closed trading results; open gain/loss changes equity until a trade closes. Equity is balance plus open gain/loss. The BX, BT and BG markets, market/limit orders, position sizing, stop loss, take profit, charts and amendments remain. The account uses the original starter cap of five contracts per market.

Trade highlights balance, open gain/loss and one next goal. Progress shows permanent titles and lifetime net profit. Stats separates This run, Lifetime and Dated history. The leaderboard ranks lifetime closed net trading profit, including failed runs. Help explains the rules and can replay the short guided trade; it follows an actual entry and close on the player's current account. Completing or skipping the guide creates no funds or rewards by itself.

Account selectors, the account shop, purchases, the separate earnings wallet, copy trading and leader/follower account roles were removed from both the client flow and server actions. The shared exchange's owner/follower **server** mechanism remains necessary for persistence and is unrelated to copy trading.

## Permanent progression

| Goal | Permanent title |
| --- | --- |
| First closing execution (including break-even) | Trader |
| First profitable closing execution | First Win |
| $500 lifetime net closed profit | Rising Trader |
| $10,000 closed balance and at least $5,000 lifetime net profit | Skilled Trader |
| $25,000 closed balance and at least $20,000 lifetime net profit | Market Pro |
| $50,000 closed balance and at least $45,000 lifetime net profit | Market Master |
| $100,000 closed balance and at least $95,000 lifetime net profit | Get Funded Legend |

All lifetime losses count. Starting money, carried capital, restart grants and open profit do not count as new trading profit. Milestone IDs are awarded once and persisted; losing and recovering money or restarting cannot re-award them. Rewards are titles only. The highest new milestone title stays as the rank after losses. Closing notifications include the result, new balance, next goal and any newly earned titles.

Equity at or below zero fails the account. The engine cancels orders and liquidates positions; a restart is available only after exposure is flat. A free restart grants a new $5,000 account identity and retains permanent rewards and lifetime results. The previous account token cannot authorize a new-run trade or duplicate restart. A persisted anti-spam allowance permits five immediate failed-run restarts, replenishing one per 12 minutes of active exchange time. Rejoining does not refill it.

Failed runs fold into a single accounting archive, keeping cash, realized results, counts and dated aggregates. Lifetime totals are retained; trade detail retains the existing 60-row bound and recent run summaries retain 32 entries. This is not an unlimited individual-trade log.

## Versioned save migration

The exchange uses checkpoint V8 and player profile V4. Restore performs migration in the isolated restored engine **before** the initial fenced commit and before admitting trades. V4 profiles are validated and reused, so retry/rejoin does not repeat settlement or grants. Future formats, missing ledger entries and invalid/corrupt/oversized checkpoints fail closed. Old binaries cannot read V8; rollback after a future deployment requires coordinated checkpoint recovery, not just reverting scripts.

For each old profile:

1. Recover every ledger account and any matching orphan player account. Keep the complete original profile in `LegacyProfile`, including tier ownership, purchases, completion, wallet and copy-link metadata. Preserve tier ownership as permanent `Legacy ... Trader` titles and old completion as `Legacy Top Tier Complete`.
2. Select the saved active usable account. If that cannot be used, select the last usable non-archive account in deterministic ledger order. Granted balances are never added together.
3. Record original balances, positions and orders in `Migration.Accounts`. Cancel all old orders and settle every old position through the ordinary reduce-only fill path at the restored current executable quote. The house receives the matching accounting entry. Clear old pending protection; no position, order or copy link transfers into the new run.
4. Archive and lock all old accounts. Their balances, net results, history and stats remain in the ledger, including settlement results. Archive flags prevent an old healthy account from being newly counted as a failed run.
5. Set the one new account's balance to **$5,000 + the selected account's realized net result after settlement**. That carry is new-run base capital with zero new-run realized profit, because its trading result already appears once in the old ledger. Example: an old $100,000 account with $2,500 net profit becomes $7,500, not $102,500.
6. If no usable account survives but old accounts exist, start failed at zero and offer the normal free restart. A carry producing a nonpositive balance also starts failed. A genuinely empty old profile starts at $5,000.

Other accounts' profits and losses remain in lifetime stats and progression but do not add spendable capital. Old wallet cents and purchases remain archived evidence; there is no wallet conversion, refund, second currency or spend endpoint. Migration can grant new title milestones supported by retained history; it does not mint trading-profit credit or replay cash rewards. On very large saves, retained migration evidence can exceed capacity; the exchange refuses the save and stays unavailable rather than trimming records.

## Backups and verification

The complete native Studio export is saved as `Get Funded!.rbxl`, with an identical delivery copy at `output/single-account-20261001/Get Funded - Single Account.rbxl`. `place-hashes.json` records both SHA-256 hashes. The export was read back without executing it and all 38 scripts matched the tested `src/` files; temporary fixtures and obsolete test modules were absent.

`backups/single-account-20261001/` contains the original local place, source, tools, place hash and the pre-edit Studio script snapshot. Local source already contained some security fixes absent from the open Studio copy; these were retained. `output/single-account-20261001/preexisting-source-differences.txt` records those differences.

Verification used disposable engines, fake storage and native Studio Edit-mode UI fixtures. No live player profile, production DataStore or real saved Studio exchange was read, traded on or reset. Studio remained out of Play.

- 65 gameplay, migration, restart, save/rejoin, world ownership, pricing and security scenarios passed; 140 order/protection amendment assertions passed.
- Eight tests of the actual server handler in an isolated mocked runtime passed: automatic join, removed actions, forged values, ownership, duplicate/stale restart requests, rejoin budgets, request validation and paused exchange protections.
- Native UI passed 72 screen states at 320×568, 390×844, 844×390, 1000×600, 1280×720 and 1920×1080, with no render/chart errors or unscaled text overflow. All six guided entry/close flows passed. Screens covered Trade, all five tutorial steps, Progress, lifetime/current Stats, Leaderboard, Help and failure.
- All 38 source files compile and match the installed Studio scripts. The saved native preview retains the original colorful style and a populated chart. The smallest-screen chart issue found during validation was fixed.

Reports: `output/single-account-20261001/regression-tests.json`, `server-boundary.json`, `studio-ui.json`, and `place-verification.json`. Active tests are in `src/SingleAccountTests.luau` and the retained regression suites. Tests for the retired multi-account model are archived in `tools/legacy-tests/pre-single-account/`.

Real cloud migration, live multiplayer/teleport continuity, and physical-device touch interaction have not been exercised. The retained checkpoint capacity and bounded-detail history limits still apply. Publishing remains a separate explicit request.
