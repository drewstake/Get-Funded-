# Copy trading UI and account names — 2026-10-01

## Trade execution overlays removed — follow-up

Removed the detailed Copy Report popup and the successful Place-order toast (filled price, slippage, and copied-count text). Successful replies still clear pending orders, update positions, and trigger existing button/sound feedback. Failed-order messages and unrelated notifications remain available. Trading and copy execution code is unchanged.

Applied to local `src/TerminalUI.luau` and native Studio, with matching normalized source checksums. Disposable native fixtures at 1440 × 900 and 390 × 844 confirmed successful placement creates a position and clears pending state without a toast; copy replies create neither overlay; rejected placement retains the error. The preview was refreshed and the updated `Get Funded!.rbxl` saved locally. Backups: `backups/trade-overlay-removal-20261001/`. No publish was performed.

## Funded account labels and checkbox assets — latest update

This section supersedes the historical layout, label, and save-status notes below.

- Both copy editors now use **LEADER** and **FOLLOWER(S)**. Checked followers use the transparent ImageGen asset `rbxassetid://87249253289841`, with the original checkbox selection and draft/save behavior intact. The asset renders at 22 px on compact layouts and 26 px on desktop; native renderings were inspected at those sizes.
- Account labels consistently use **$5K FUNDED ACCOUNT**, **$10K FUNDED ACCOUNT**, and the corresponding tier amount. Instance numbers remain hidden. Wrapped names, wider title areas, and separate role/badge rows accommodate the longer labels. The mobile summary card is now 110 px tall to retain two complete rows.
- Place a Trade no longer displays copy-destination status in its subtitle or mobile hint.
- Usable owned-account cards no longer have Trade Account or Trading now buttons/indicators. Cards are shorter and spacing is rebalanced. Reset and activation actions remain available where applicable; account switching still uses the existing switcher.
- Native Studio scripts and the normal StarterGui preview were updated. Temporary test fixtures were removed and normal scripts restored. The updated place was exported and saved to `Get Funded!.rbxl`, with a second copy in `output/ui-account-labels-20261001/`. No live publish was performed.

Verification: **1,598 UI checks, 72 layouts, 0 issues**, across eight viewport sizes from 1920 × 1080 to 320 × 568. Includes long tier names, overflowing follower lists, hidden instance numbers, image loading, owned-card spacing, and copy setup/edit/save/stop flows. Eight native regression suites passed **266 checks with no failures**. Play-mode mouse input passed in both copy editors on desktop and mobile, including deselection by clicking directly on the checkmark image and preventing premature requests.

Results: `output/ui-account-labels-20261001/validation.json`. Asset and complete built-in ImageGen prompt: `icons/copy-trading/follower-checkmark.png` and `follower-checkmark.json`. Original sources and place: `backups/ui-account-labels-20261001/`. Studio server modules received only the relevant naming changes; unrelated differences between local source and Studio were preserved.

## Accounts card and popup polish — previous update

This supersedes the click behaviour described in the sections below.

- **Whole card opens Copy Trading.** The Accounts card is one button. Rows, empty list space, the header and the padding all open the popup. Nothing on the card switches the trading account. The small copy button in the header is gone. Switching stays in the sidebar/header account switcher (Switch account popup).
- **Accounts card styling.** Rows use one flat surface with a single rim and no shine strip. The selected row keeps its purple fill with a purple rim, not the old near-white one. Rows sit inset inside the scrolling list so their rims never clip, and they don't grow on hover inside the clip. The list shows whole rows only: 3 on desktop and 2 on phones, and the rest scroll. Padding is consistent: header and rows line up at 14 px on desktop and 7 px on phones. Leader/Follower badges are wider, so "Follower" is readable on phones. On phones, non-trading rows use an outlined marker instead of an 8 px cash icon. Small desktop windows (card under 250 px of row width) use tighter spacing so the names still fit. The phone summary row is 8–10 px taller (68, or 64 on short/landscape phones) so two full rows fit, and the Equity/P&L values are centred in it.
- **Copy Trading popup.** The header is clean, with no decorative dots, concentric corners and an evenly inset close button. The ON/OFF status pill (with a dot) follows the title. On narrow phones the title shrinks instead of wrapping. Rows, the source dropdown and the actions share one corner radius (14, or 12 when compact). Every rim is 2 px, with no shine or lower-edge strips. Name and balance are vertically centred. The Change chevron no longer touches its label. The info button is a real circle (a duplicate UICorner made it square before). Spacing is wider between rows and before the action. The follower list keeps a margin so rims and hover growth never clip. When height-limited it shows whole rows only, so no sliver of the next row shows. The primary action always stays in view. Copy From/To, status, checkboxes and Start/Save/Stop are unchanged. Copy Size stays removed.

Verification:

- Validator: **994 checks, 32 layouts, 0 issues** at 8 sizes plus overflow. Flows at 1440×900, 390×844 and 320×568.
- Live Play-mode clicks with real mouse input on 7 card targets (desktop): all opened the popup, and the trading account stayed the same.
- Hit-test grids over the whole card at 7 sizes: every point inside the rounded card reaches the card, a row or the list hit area.
- Studio regression suites: 14 suites, 379 cases, 0 failures.

Results are in `output/accounts-card-polish-validation.json`. Screenshots are in `design-previews/accounts-card-polish-2026-09-30/`. Backups are in `backups/accounts-card-polish-20260930/`. Studio's `TerminalUI` matches local `src`, and the StarterGui preview was regenerated. **The place still needs to be saved in Studio.** The approved mockup image wasn't available in this session, so the polish follows the written spec and the surrounding UI.

## Implemented reference redesign — later update

The image-approved redesign supersedes the earlier layout and interaction notes below.

- **Accounts summary card:** three generous desktop rows, purple selected state with green dot, dark-blue alternatives with cash icons, count badge, and overflow scrolling. While copying is active, participating accounts show a gold Leader or cyan Follower badge instead of the right-side checkmark/chevron. Nonparticipating accounts retain the icons. Clicking a row switches the trading account using the existing Account request. The small copy icon in the header opens copy setup. Phones use compact scrolling rows.
- **Account labels:** plain names such as `$5K Account` throughout both selection lists, including duplicate sizes. No instance numbers are displayed; internal keys still identify each account independently.
- **Copy editor:** `COPY FROM` / `COPY TO`, a compact ON/OFF badge, selectable source dropdown, checkboxes, selected count, and a bounded follower list. The primary action stays visible as followers scroll. Both the popup and Accounts tab use the same editor.
- **Actions:** Start Copying when off, Stop Copying when the saved setup is on, Save Changes for an edited live setup. A small Stop action remains available during edits, including incomplete drafts. Edits stay local until saved; pending requests block duplicate submission. Stopping retains the saved selection for restarting and never closes positions.
- **Less text:** Copy Size, Clear/Remove Leader, explanatory paragraphs, and the unsaved banner are removed. Detailed rules are available from the hover/tap info control. Only “Only new trades are copied.” remains under the action.
- **Sizing:** existing saved sizing is preserved; new setups retain the server's Same default. No sizing or server logic was changed.

Validation: **410 checks, 32 layouts, zero issues**, across eight viewports from 1920×1080 to 320×568, plus overflowing follower lists at all eight sizes. Desktop/phone flows cover account switching, fresh setup, draft discard, save, source changes, stopping an incomplete draft, restart, request guards, and synchronization between entry points. Role badges replace the icons only for participating accounts and clear when copying stops. Names contain no instance numbers. Existing proportional sizing and free account activation also passed. Native desktop and phone renderings were visually inspected. Results: `output/accounts-role-labels-validation.json`; validator: `tools/ValidateCopyTradingUI.luau`.

Applied to local `src/TerminalUI.luau` and the open Studio place; regenerated the normal starter-account preview and removed temporary fixtures. **The place still needs to be saved in Studio.** No publish or live-server test was performed. Prior source and validator are in `backups/accounts-copy-redesign-20260930/`.

## Earlier implementation history

## What changed

1. **No sequence numbers in names.** `FundedAccounts:InstanceName` now returns `"$10K Account"` (tier short name + "Account"). The same name appears in the header, sidebar switcher, order ticket, account cards, copy UI, copy reports and server messages (for example "Now trading $10K Account."). Instance keys (`F10K:1`, `F10K:2`) and account ids are unchanged, so two accounts of the same size stay separate. Two wording fixes avoid "account account" (quantity-limit popup, coach step 2).
2. **Trade tab account list.** The Accounts summary tile is now a list of usable accounts. Each row shows a **Leader** (gold) or **Follower** (cyan) pill, taken from the saved copy setup and shown only while copying is on. The trading account is purple with a green dot. Clicking a row (or the tile) opens the copy setup popup. It doesn't switch accounts or change any settings. On phones the tile is wider and scrolls when there are more than two accounts.
3. **Simplified copy trading editor.** The Accounts tab card and the Trade tab popup use the same `copyPanel` and the same draft:
   - **Leader** at the top. It shows the current leader, with a **Change/Choose** selector (a one-of list) and **Remove leader · stop copying** (turns copying off; positions are never closed).
   - **Followers** below. Each other usable account is its own row with a checkbox on the right. The leader is never listed, so an account can't follow itself.
   - Copy size (Same / Scale by account size) and the rules text are kept.
   - Edits stay a draft until **Start copying** or **Save changes**. Opening either entry point (or the Accounts tab) resets the draft to the saved setup. The "Set up copying" intro now opens this popup directly.
4. **Permanent Tier Access removed from the Accounts tab.** The section and its cards are gone. The subtitle now reads "N usable accounts", and account cards say "Funded account". Tier ownership, unlocks and Shop purchases are unchanged. That section was the only place in the Accounts tab to claim a free first account for an earned tier. To keep that working, a **Ready to activate** card appears only while such an account is waiting.

## Files

- `src/FundedAccounts.luau`: `InstanceName` only.
- `src/TerminalUI.luau`: names, `copyRole`, account list tile, `copyPanel` + Copy popup, Accounts tab, reply handling (`PendingCopy`).
- `src/DepletionTests.luau`: expects `"$5K Account"`.
- `tools/ValidateCopyTradingUI.luau` (new): Studio Edit-mode validator.
- Backups: `backups/copy-trading-ui-before-20260930/`. Screenshots: `design-previews/copy-trading-ui-2026-09-30/`.

## Verification

- **UI validator, Studio:** 305 checks, 0 issues.
  - Sizes: 8, from 1920×1080 to 320×568.
  - Coverage: Trade, Copy popup and Accounts at each size, and text-fit and "#digit" audits.
  - Full flows at 1440×900 and 390×844: discard a draft, save a follower, change the leader, sync with the Accounts tab, remove the leader, start copying with the second $10K, switch between the two $10K accounts, and claim a free activation.
- **Regression suites:**
  - Local `src` under Lune: 12 suites, 151 scenarios + 166 assertions, 0 failures.
  - Open Studio place: 11 suites, 131 + 166, 0 failures.
- **Studio sync:** Studio `TerminalUI` matches local `src` (ignoring blank lines). Results are in `output/copy-trading-ui-validation.json`.

## Notes and limitations

- Studio has the changes but the place isn't saved. Save it in Studio to keep them.
- Studio's server modules are still the pre-security-fix versions. Only `InstanceName` and the one test line were patched there; the earlier security-fix sync is still pending.
- No Play-mode or live-server test was run. The flows used real engine and account modules with the network send stubbed. Test in a private server before publishing.
- Turning copying off keeps the old leader/followers in the saved profile, as before. The UI treats "off" as "no leader", so they're never shown or reused automatically.
- Same-size accounts have identical names. They are told apart by position, balance and the trading marker.
- The reference image wasn't attached, so the layout follows the written description.
