# After Hours UI

Applied the `03-after-hours.png` visual direction to the native Roblox interface in `src/TerminalUI.luau`.

- Charcoal/violet palette, rounded layered cards, fine violet borders and native line icons.
- Left navigation, three account tiles, a separate order ticket, and a full-width activity table on desktop.
- Portrait and landscape phone layouts, with condensed controls on smaller screens.
- Green BUY, rose SELL, filled up candles, hollow down candles, input focus borders, pressed-button feedback and close confirmation.
- Roblox Builder Sans and Roboto Mono provide native typography without external assets.

Existing MES, MNQ, M2K and MYM contracts, virtual balances, matching, saved accounts, chart navigation, drawings and draggable protection remain connected to the existing modules. Stop and target fields explicitly show the game's tick distances; they are not the illustrative prices from the design board. Review and Learn connect to the existing history and walkthrough.

Press Play in Studio to use the interface. The saved Edit preview is a static snapshot from the existing exchange. Run `tools/RefreshStudioPreview.luau` after source edits to rebuild it.

## Verification

Studio Play checks passed: 11 engine cases, 8 chart viewport cases and 7 chart paint pool cases. Seven layouts from 320×568 through 1920×1022 were checked for panel overflow and text fit. Desktop and mobile order controls, confirmation, limit cancellation, instrument/timeframe selection, chart pan/Go live and connection states were exercised using `tools/AfterHoursUIFixture.luau`. The fixture runs only in Studio's client and sends no remote orders. Clean it up through its Diagnostics bindable before saving; it is not installed in the game.

Detailed results: `after-hours-validation-results.json`. Physical-device touch has not been tested.

## Backups

- `backups/TerminalUI.before-after-hours.luau`
- `backups/Get Funded!.before-after-hours.rbxl`

The source and local place are updated. Publishing to the live Roblox experience is a separate step.
