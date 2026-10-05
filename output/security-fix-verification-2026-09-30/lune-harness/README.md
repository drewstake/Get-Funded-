# Lune harness used for the isolated verification

A minimal Roblox API shim (`roblox.luau`) so the server modules and test suites run under
[Lune](https://github.com/lune-org/lune) (a standalone Luau runtime) with no Roblox services, DataStores or network.
It provides HttpService JSON (strict, Roblox-like, exact number round trips), EncodingService (zstd via Lune,
SHA-256, base64), a ModuleScript tree for `game.ServerScriptService.MarketReign` / `game.ReplicatedStorage.MarketReign`,
and `task` from Lune.

    lune run run.luau <path to src> suites:PermanentShopTests,WorldTests,...,SecurityTests [out.json]
    lune run run.luau <path to src> <script.luau> [out.json]

`build_server_harness.py <MarketServer.server.luau> <out.luau>` regenerates `server-reply-harness.luau` from the audit's
`server-boundary-harness.luau` prefix (paths inside it point at the sandbox copy; adjust before reuse).
Differences from Roblox: JSON number formatting and `GetDecompressedBufferSize` are emulated, so byte counts differ
slightly from Studio.
