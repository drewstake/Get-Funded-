# FPS and chart updates

Roblox's Windows player supports a maximum framerate of 240 FPS. Choose **Esc > Settings > Maximum Framerate > 240 FPS** in the Roblox player. This is a player setting, not a game script setting. A higher limit does not guarantee the hardware can sustain it. Use Shift+F5 in the player to measure actual FPS; Studio adds its own overhead.

The development session measured 59.99 FPS before optimization and 60.01 FPS afterward. This is consistent with a 60 FPS limit; 240 FPS has not been measured. Sources: [Roblox announcement](https://devforum.roblox.com/t/introducing-the-maximum-framerate-setting/2995965/1) and [performance diagnostics](https://create.roblox.com/docs/performance-optimization/identify).

## Changes

- Pointer movement now updates a separate pool of crosshair labels, drawing previews, and magnet indicators. Candles and grid only repaint when market data, navigation, or scale easing changes.
- Network changes take priority over pending pointer updates. Full paints update both pools from the same chart geometry.
- The OHLC readout no longer clears its text before every assignment, allowing unchanged text to stay cached.
- Rendering still follows the display's RenderStepped event; no 60 Hz limiter was added. Market simulation, matching, and broadcast timing are unchanged.

## Verification (September 28, 2026)

A deterministic 720-candle fixture, 577 visible, with 240 pointer updates measured mean script time of **1.439 ms before / 0.078 ms after** (94.5% lower). The pointer updates performed 240 full chart paints before and zero after, with zero new GUI objects in both runs. This benchmark uses a hidden GUI and measures script execution, not GPU render performance.

All 12 fixture checks passed: crosshair selection/alignment, OHLC readout, market and navigation invalidation, magnet snapping, rectangle preview and cancellation, pointer exit, unchanged market step, and candle data/color integrity. Existing chart tests passed: viewport 35, drawing tools 24, paint pool 10.

Live mouse movement was verified in Studio with incoming market updates. The subsequent 180-frame sample measured 60.01 FPS, 17.98 ms p95 frame interval, no chart errors, no completed candle mutations, and no color mismatches. Pointer updates outnumbered full paints (1,330 overlay paints vs. 834 full paints at the sample). Detailed values are in `fps-optimization-results.json`; the repeatable fixture is `tools/ValidateChartPerformance.luau`.

Applied to the open Studio place and saved as `Get Funded!.rbxl`. Not published. Original files are in `backups/src.before-fps-optimization/` and `backups/Get Funded!.before-fps-optimization.rbxl`.
