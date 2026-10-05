# Progress UI implementation

Installed in the connected **Get Funded!** Studio place on October 1, 2026.

- `src/ProgressView.luau` owns the responsive progress page.
- `src/TerminalUI.luau` mounts it and retains the existing restart action and navigation.
- `icons/progress/` contains three original transparent PNGs made with the built-in ImageGen tool: milestone badge, lock, and earned checkmark. `manifest.json` records their Roblox asset IDs and exact prompts (prefix + individual prompt + suffix).
- Cash and rank trophy icons reuse the game's existing assets. Cards, text, dividers, numbers, and progress bars remain native editable Roblox GUI objects.

The page keeps the server's award rules, including the balance AND lifetime-profit requirements of later milestones. Negative lifetime profit has an explanatory recovery note. All permanent and legacy titles remain visible. The page never scrolls. Desktop uses compact, fixed-height sections; small screens use Overview, Upcoming, and Earned tabs. Long title collections use page arrows, with selection preserved across refreshes.

Validation: 63 viewport/state combinations, including 320-pixel portrait widths and phone landscape safe areas. All tabs and all title pages were checked for text fit, horizontal and vertical bounds, progress-bar overlap, and title reachability. No scrolling containers are used. Live desktop and iPhone landscape views were inspected; real clicks on the Earned tab and Next page button worked, and pagination survived a full UI refresh. Results are in validation.json.

The standard Edit preview was refreshed; temporary fixtures were removed and device simulation reset to default. The changed modules are installed in Studio and saved as source on disk. **A full .rbxl save was not completed:** the native save controls were unavailable while Studio was minimized or receiving user input. Save the open place in Studio to persist these edits in the place file. Nothing was published to the live experience.

`Progress UI Modules.rbxmx` is an additional native export of the two modules, verified against the source files. If restoring into another copy of this game, import its two ModuleScripts into `ReplicatedStorage.MarketReign`, replacing the same-named modules. The remaining game modules are dependencies and must already exist.

Original source backups: `backups/progress-redesign-20261001/`.
