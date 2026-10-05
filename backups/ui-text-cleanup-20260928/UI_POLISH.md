# UI polish: Play-mode chart, feedback, sounds, theme (Sept 28, 2026)

## Chart in Play mode
I couldn't reproduce a hard failure. The chart painted and updated in every Play flow tested: returning player on the shared saved world, a new player in a local sandbox, orders, contract and timeframe switching, pan/zoom, drawings, stop/target drag, and seven viewport sizes. The console showed no errors.

I did find and fix three ways the chart can stop:
- **Dropped subscriptions.** The server's request rate limit (20 burst, 6/s) silently drops a `Subscribe`. After fast contract or timeframe switching, the server kept streaming the old series and the new chart stayed on "Loading" indefinitely. `MarketClient` now re-subscribes when packets arrive for a different series for more than 1.5 s. Tested: 80 rapid switches recovered in 1.8 s.
- **Paint errors could poison the UI.** If `ChartView:Paint` threw, the pooled painter stayed installed, so every later GUI object went into the chart pool. Paint now runs inside `xpcall`. On an error it resets the painter, warns once and rebuilds. The whole render is guarded the same way (`ChartError` / `RenderError` attributes appear in Studio).
- **Frozen under popups.** The chart stopped repainting whenever a popup or sheet was open. It now stays live; chart input is still blocked while a popup is open.

Both candle directions have filled bodies: 0 hollow, 0 colour mismatches.

## Interaction feedback (`src/UIFeedback.luau`, ReplicatedStorage)
- **Buttons:** hover lift plus a light sheen, a squish on press, and a Back-ease bounce on release. Buttons are centred for scaling, and effects are sized to the control (big tiles move less).
- **Surviving rebuilds:** the GUI is rebuilt on refresh, so hover, press and selection state is remembered by path. A rebuilt control carries on with its animation.
- **Selection pop:** tabs, segments, nav, markets, timeframes, contracts, lead/follow and toggles. Steppers bump their value when it changes.
- **Popups:** open with a scale pop and a backdrop fade. Closing fades out from a non-interactive CanvasGroup "ghost". The mobile sheet slides up and toasts drop in.
- **Duplicate actions:** every button is debounced (steppers 0.05 s). BUY/SELL lock and show **SENDING…** while an order is in flight. Close position shows **Closing…**. A triple-click sends one order.
- **Order results:** success feedback (sound, pulse and green/pink ring) only plays on the server reply. Rejections shake the control and play the error sound.
- **Cleanup:** looping tweens (loading dots, coach highlight, pending shine) stop before every rebuild.

## Sounds (official Roblox GUI assets)
| Event | Asset |
| --- | --- |
| Click | Roblox GUI - Select 17208396156 |
| Stepper tick (quieter, faster) | Roblox GUI - Select 17208396156 |
| Tab / toggle | Bubble 17208204604 |
| Popup open | Swipe 17208405682 |
| Order sent | Send 17208399163 |
| Server-confirmed success | Purchase 17208380755 |
| Unlock / first profit | Notification High 17208361335 |
| Error / rejection | Negative 17208353912 |

All sounds play through the `GetFundedUI` SoundGroup, with per-sound and global rate limits. Volume is Low, Medium or High (default Medium, 0.65).

The on/off toggle is in **Settings** and in the desktop status bar (**SOUND ON/OFF**); on phones, Settings is reached from the ··· menu. The preference lasts for the session only; it is not saved to the profile.

## Theme
Restyled to the colorful reference:
- **Popups:** contracts, timeframes, chart tools, menu, switch account, copy intro, settings, help, guide and close confirmation. They share the purple header, icon, outlined title, red X and glossy buttons.
- **Screens:** welcome, loading and the dashboard (coloured KPI tiles, gold next-unlock card, ladder cards per state, copy trading, legacy).
- **Smaller pieces:** coach card, toasts (info/success/error), unlock celebration, copy report, activity table header and actions, the mobile header, dock, sheet and ··· buttons, the chart's waiting state, active tool, style bar and the protection-popup close button.

Numeric tables keep the monospace font.

## Verification
- Chart unit tests: 35 viewport, 10 paint pool and 24 tools cases.
- Server tests: engine 11/11, continuity 6/6, funded 11/11.
- Layout audit (`tools/AuditColorfulUI.luau`): 94 screen/popup/size combinations from 1920×1022 down to 320×568 and 844×390. It checks text overflow, off-screen objects, clipped buttons and touch targets under 32×28. The one issue it found (Close popup note at 320 px) is fixed.
- Order tests ran only in a **local sandbox** (`WorldConfig.Enabled=false`, restored to `true` afterwards). Your shared saved world was opened read-only and was unchanged ($5K Funded at $4,991.50).
- The Edit preview was regenerated: 31 filled candles, no sounds or effect layers saved.
- Not tested: physical touch devices and hearing the audio. Sound playback was verified by play counters.

Studio helpers: the root `UIDiagnostics` BindableFunction (Studio only) and `SoundPlayed<Name>` attributes.
Backup of the previous sources: `backups/src.before-play-fix-polish/`.
