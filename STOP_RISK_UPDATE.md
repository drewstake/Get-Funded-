# Stop placement and funded liquidation — September 28, 2026

Stops may now represent a loss larger than the funded account's equity. Both initial stop settings and later chart drags use this policy; copy trading uses the same server checks for each follower.

The engine no longer uses estimated stop risk to reduce order capacity or reject a stop amendment. Contract limits, existing/pending exposure, actual-equity buying power, valid ticks, price bands, ownership, and stale-request checks still apply.

Funded positions liquidate when **equity reaches $0 or below**, including unrealized P&L. Positive-equity maintenance-margin exits are disabled for player accounts. Bot maintenance-margin behavior is unchanged. Liquidation latches on each execution, cancels pending entries, and retries remaining close quantity when liquidity is unavailable or partial. The account's loss history and depleted state remain intact.

Updated the in-game explanation to match this behavior. Chart styling and the earlier grid removal remain unchanged.

Source is synchronized to Roblox Studio, the Studio draft is saved to Roblox, and the preview is regenerated. The latest local place is `Get Funded!.rbxl`, also exported as `output/Get Funded! Wide Stops.rbxl`. No live release was published.

## Verification

All **78 isolated server scenarios passed**: MarketTests 11, TradeLimitsTests 27, ProgressionTests 10, FundedTests 11, WorldTests 6, and LeaderboardTests 13.

Eight new scenarios cover ES, NQ, RTY, and YM, long and short: initial stops above equity, farther stop amendments, stale-drag rejection, survival below maintenance margin while equity is positive, reduced buying power for new entries, exact-zero/negative-equity liquidation, pending-order cancellation, empty-book retries, partial liquidation, and preserved realized losses/history. Copy tests cover wide initial and amended stops on lead and follower accounts. Existing account-size limits and persistence regressions also passed.

Tests used cloned modules and in-memory accounts in Studio Edit mode. No saved player DataStore records were modified. Test clones were destroyed. Detailed results are in `stop-risk-validation-results.json`; the pre-change source/place backup is in `backups/stop-risk-before-20260928/`.
