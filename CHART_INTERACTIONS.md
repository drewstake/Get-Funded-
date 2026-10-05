# Chart interactions

The candlestick chart now lives in `src/ChartView.luau` (painting, input, drawing tools). It uses `ChartViewport.luau` (navigation maths), `ChartTools.luau` (drawings, magnet, undo) and `ChartPaintPool.luau` (object reuse). `TerminalUI.luau` mounts it. Everything is presentation only: the chart never changes prices, candles or accounts. The one exception is the existing stop/target drag, which sends the same `AmendProtection` request as before.

## What caused the glitchy candles

Measured in Studio Play before the change: **35% of wicks were off-centre from their body and 5% did not span it**. The error moved as you panned. The causes:

1. **Integer GUI offsets.** `UDim` offsets are integers, so Roblox truncates fractional positions. Body left edge, body width and wick X were each computed from fractional values and truncated separately. As the view moved, each one rounded differently, so wicks shifted and bodies changed height by a pixel.
2. **Objects reused by slot, each with its own tween.** Candle frames were reused by draw order, and each object ran its own 80 ms tween. Auto-fit rescaled the price axis on every quote, so bodies and wicks were mid-animation almost constantly.
3. **Hollow bodies drawn with an outer `UIStroke`.** The stroke adds pixels outside the frame, so bearish bodies were wider than bullish ones and not centred on their wick.
4. **Fixed-position grid.** Grid lines stayed at fixed screen positions while their labels changed, so grid and prices looked misaligned during vertical drags.
5. **Doji.** A doji (`Close == Open`) was treated as bullish. Colour now comes from exact tick counts, so float noise can never flip it.

No evidence was found of completed candles' data changing. The client merge and the server only update the last candle. A new Studio audit checks this continuously (see Verification).

## How it's fixed

- One transform maps time and price to pixels, rounded once per coordinate. Candles, wicks, volume, grid, labels, levels, drawings and the crosshair all use it.
- Candles sit in a strip. While the scale is unchanged, a pan moves only the strip, so every mark moves rigidly with no per-candle rounding shimmer.
- Each candle owns its objects, keyed by candle time, so a candle can never inherit another candle's paint. There are no per-object tweens. Auto-fit smoothing eases the view range instead, so everything stays aligned.
- Hollow bearish bodies are an inset fill: pixel-exact and centred.
- Colour: up (close > open) is filled green, down is hollow red, doji is a flat muted line. It is computed from each candle's own open and close in ticks, never from the viewport.

## Navigation

| Action | Desktop | Touch |
| --- | --- | --- |
| Pan | Drag (middle-drag always pans) | One-finger drag |
| Zoom | Wheel, anchored to the cursor | Pinch, anchored to the midpoint |
| Price scale | Drag the price axis (up = taller candles) | Drag the price axis |
| Auto-fit | Double-click the price axis, or **Auto** | Double-tap the axis, or **Auto** |
| Follow live | **Live** | **Live** |
| Defaults | **Reset** | **Reset** |

- Zoom range: 10 bars in, out to whichever comes first of 2 px per candle (about 630 bars at 1920 px) and the available history.
- History is now **720 candles per series** (was 120). `MarketConfig.MaxCandles` sets it, and restored worlds adopt the new limit. It only affects chart history, never matching. Older worlds grow into it as new candles form.
- Following live means the latest candle is in view. New candles then scroll the chart by exactly one bar. If you pan into history, the viewport stays still when new candles arrive.
- A manual price scale persists through pans, zooms and live updates until you use Auto, double-click the axis or Reset. With auto-fit on, dragging pans time only. With a manual scale, it pans price too.

## Drawing tools

Toolbar (desktop): Select/pan, Crosshair, Trend, Horizontal line, **Rectangle**, then **Magnet**, **Undo**, **Redo**, Clear. On phones these are in the chart's **···** sheet, with Delete, Reset, Auto and Live.

- **Rectangle:** drag to draw (or click, then click again), with a live preview. The rectangle is stored in time and price coordinates. After drawing, it is selected and the tool returns to Select.
- **Select, move, resize:** click a drawing's edge (or inside a selected rectangle) to select and drag it. Drag a corner handle to resize. Handles and hit areas are larger on touch. Clicking inside an unselected rectangle selects it, but dragging there still pans the chart.
- **Style bar** (while selected): border colour, fill colour, fill opacity (8/15/25/40%) and Delete. It uses the UI Kit palette: violet, green, rose, muted.
- **Magnet:** snaps to the nearest candle open, high, low or close within 14 px (24 px on touch), with a small ring on the target. The toolbar toggle is persistent. Holding **Ctrl** enables it temporarily, and releasing restores your setting. It only applies while placing or editing drawings, never while panning.
- **Keys:** Delete/Backspace deletes the selected drawing (ignored while a text field is focused). Ctrl+Z undoes; Ctrl+Y or Ctrl+Shift+Z redoes. There are 100 undo steps, covering create, move, resize, style, delete and clear.
- **Cancel:** Esc (where the game receives it), right-click, window focus loss, or opening the Roblox menu. An edit is restored and a placement discarded. In a published Roblox game, Esc opens the system menu and is never delivered to the game, so Esc cancels by way of the menu opening.
- **Crosshair:** follows the pointer and snaps to the nearest candle. It shows price and time tags on the axes and colours the OHLC readout by candle direction. Cursors change for pan, grab, scale, move and resize.

## Verification (Studio, September 28, 2026)

- Unit tests (Studio and local Luau): viewport 35/35, drawing tools 24/24, paint pool 10/10.
- Live Play, 541 frames with a live market, a drag and wheel zoom: **0 of 38,614** candle samples had an off-centre wick or a wick short of its body. Body widths were uniform in every frame. No completed candle changed colour. The audit showed `CompletedCandleMutations = 0` and `CandleColorMismatches = 0`.
- Deep zoom-out stopped at the history-based limit. Axis drag up gave a manual scale that survived pans and live updates. Double-click on the axis restored auto-fit, with all 132 visible candles inside the range. Reset, Auto and Live buttons worked. A detached view stayed exactly still through a new candle. Following scrolled by one bar.
- Rectangle: placement preview, commit, selection handles, style bar (fill green, border red, 25% opacity), move by edge, corner resize with the opposite corner fixed. Ctrl+Z / Ctrl+Y undo and redo stepped back through resize and move correctly. Delete and Backspace deleted; Backspace while a text box was focused did not.
- Ctrl held: magnet activated and showed the snap ring on a candle's close. Release: magnet off, persistent setting unchanged.
- Edit preview (Studio saved GUI) regenerated: 31 candles, 17 hollow, 0 colour mismatches.

- Second session (after Studio reconnected):
  - 720-candle history, 632 candles on screen: pan repaint 0.8 ms median, 1.3 ms worst (script time), 0 wrong colours.
  - Ctrl magnet placement snapped the corner exactly to a candle high (time and price). The same placement without Ctrl did not snap.
  - Right-click mid-placement cancelled with nothing created.
  - Window focus loss mid-move with Ctrl held restored the rectangle and cleared Ctrl.
  - Persistent magnet toggle worked from the phone tools sheet.
  - Phone portrait 390×844 and landscape 844×390: no chart buttons outside the chart. Rectangle placement and the fill chip worked.
  - Resizing back to desktop kept drawings within 0.5 px of their time/price anchors.
  - Live audit over 609 paints: 0 completed-candle changes, 0 colour mismatches.
- Found and fixed in testing: on phones the two-row style bar covered the small plot and the view controls. It is now one row over the timeframe bar, with a tap-to-cycle fill chip.

## Remaining / known limits

- Esc: Roblox reserves it for the system menu in live games. Opening the menu is wired to cancel. That path runs the same handler as focus loss (verified), but the real menu signal can't be triggered from test code.
- Not tested on physical touch devices, and pinch was not injected (covered by viewport unit tests only). Phone sizes were emulated by resizing the workspace.
- Roblox has no native tooltips, so toolbar buttons carry a `Tooltip` attribute but show no hover text.
- Drawings stay per contract and timeframe, and are not saved between sessions (as before).
- Studio's virtual mouse sometimes releases buttons between calls, so a few test runs were discarded and repeated.

## Optional additions (not built)

- Show drawings on every timeframe of the same contract (anchors are already time based).
- Save drawings with the player profile.
- Drag the time axis to zoom horizontally, and add keyboard arrows to pan.
- Hover tooltips for toolbar buttons.
- More drawing types (Fibonacci, text notes, price range).

## Backups

`backups/src.before-chart-interactions/` and `backups/Get Funded!.before-chart-interactions.rbxl`.
