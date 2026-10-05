# Blox markets, manual TP/SL and UI cleanup — 2026-10-01

## What changed

1. **Moved TP/SL survive adding to a position.** Dragging an SL or TP on the chart marks that level as manual
   (`ManualStop` / `ManualTarget` on the position). When the same position grows, a manual level keeps its exact
   price; only levels that were never moved still follow the ticket distance from the new average entry. SL/TP
   are position-level, so they always cover the full updated quantity. Cancelling a level clears its manual flag.
   Copy-trading followers get the same behaviour because moves are copied through the same AmendProtection path.
2. **NEXT UNLOCK card keeps two lines on hover.** The goal name is split into two fixed lines
   ("$100K FUNDED" / "ACCOUNT") and its size is measured once (`fixText`), instead of TextScaled, which re-fitted
   the text onto one line when the card lifted. Same box, size and alignment at rest and on hover.
3. **Larger Copy Trading balances.** Balances under the leader/follower names are outlined like the names:
   16 px desktop, 14 px phones, 12 px compact (were 12/12/10). The leader picker balances grew from 11 to 13 px.
   Both entry points share `copyPanel`, so the popup and the Accounts tab match.
4. **"Only new trades are copied." removed** from both Copy Trading locations (the hint and the info tooltip).
   No behaviour change.
5. **Markets.** `BX` Blox 500 (was ES), `BT` BloxTech 100 (was NQ), new `BG` Blox Gold (tick 0.10, $100 per
   point, $10 per tick, 44 participants). RTY and YM are no longer offered. No "E-mini" text remains in the UI.
   - Saved worlds migrate on restore (checkpoint V7): ES/NQ books, positions, orders, history, fills, triggers
     and participants are renamed to BX/BT with prices, candles and volume intact. BG opens as a new book.
   - RTY and YM stay only as retired close-only books when a save already held them: open positions, their SL/TP
     and closing orders keep working; entry orders in those markets are cancelled on migration. They never
     appear in selectors.
   - Older builds refuse V7 saves (fail closed), so when publishing, shut down old servers.
6. **Usable owned-account cards** no longer show the OWNED chip or the "0 open · +$0 open P&L" row. The copy
   role chip sits beside the Balance label (desktop) or the name (phones). Cards are 190 px desktop / 128 px
   phones (+48 with Reset), with no empty bands.

## Verification

- Studio Play-mode suites: 11 server suites (128 scenarios + 140 assertions) and 3 chart suites (82 cases), 0
  failures. Local `src` under Lune (with SecurityTests): 12 suites, 148 scenarios + 140 assertions, 0 failures.
  New cases: manual SL/TP preserved on add (TradeAmendmentTests); E-mini era save migration and BG trading
  (ProgressionTests); BG tick rounding in TradeLimitsTests.
- **Live Play test (real mouse input):** opened BX long 1 @ 5,464.75 (SL 5,424.75 / TP 5,504.75), dragged the
  SL to 5,392.50 and the TP to 5,492.50, then bought 1 more @ 5,444.50. Result: Long 2 @ 5,454.625 with SL
  5,392.50 and TP 5,492.50 unchanged, both protective orders at quantity 2. Closed afterwards.
- `tools/ValidateCopyTradingUI.luau` (updated): 1,954 checks, 72 layouts, 8 viewports (1920×1080 to 320×568),
  including the two-line NEXT UNLOCK at rest and with a hover-scale probe, balance size/fit/clearance in both
  editors, and owned-card spacing. One audit note: a transient TextFits=false on the Copy popup header at
  320×568 during the open animation (header code unchanged; a direct probe reports it fits).
- Studio's Studio-scope exchange restored and migrated in Play (9 saved books → BX, BT, BG + retired books;
  history shows BX/BT).

## Files and state

- Local `src/` and the open Studio place match (normalised hashes) for all 42 scripts. The 9 server-module
  differences from before (pending security-fix sync) were preserved; only the relevant edits were applied.
- StarterGui preview regenerated (BX · Blox 500, two-line goal).
- **Studio place not saved yet.** Save it in Studio.
- Backups: `backups/blox-markets-20261001/` (local src, tools, Studio sources and the previous `Get Funded!.rbxl`).
- Scripts-only fallback place (previous rbxl with every updated script, old StarterGui preview):
  `output/blox-markets-20261001/Get Funded! Blox Markets (scripts only).rbxl`.
- Studio test data: the $10K follower account (F10K:2) realised −$2,112.50 from the live TP/SL tests.
