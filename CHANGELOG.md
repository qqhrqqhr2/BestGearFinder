# Changelog - Best Gear Finder

## 1.0.4
- Toy-like items that are not weapons or armor (e.g. novelty "ranged" items) are no longer listed.
- Faster item loading: requests are sent 3x faster and items in your level range are requested first.
- Items with no level requirement are now listed, placed by item level (shown as "No req").
- Ability-teaching relics (rune items with a use effect, e.g. druid idols) are no longer listed as gear.
- Items that never load are given up on after 3 requests, so the "loading" count reaches zero and the list stops changing.

## 1.0.3
- Status line reworded: shows the number of items found in the game; items that never load are reported as "not in this game skipped". Hover the status line for details.
- New filter option "Known sources only" (hides unknown-source [New] items and low-chance world drops).
- Within each slot, items with a known source are listed before [New] items.
- Built-in Forever sources: dungeon/zone drops, quest rewards, vendors and crafting sources for many items that are not in the 1.12 data, so [New] items can show where they come from.
- Click a slot title to collapse / expand it.
- Drag the bottom-right corner to resize the window height (saved).
- Tooltips on the top buttons.

## 1.0.2
- Fixed the status line showing a wrong maximum required level.

## 1.0.1
- Language dropdown (Auto / 한국어 / English) and `/bgf lang ko|en|auto`; the window rebuilds immediately, no /reload needed.
- Per-slot count is now a dropdown (2-10).
- Support button moved to the top right of the window.
- Filter and dropdown menus now have an opaque background.
- Fixed overlapping labels in the English UI; slot and spec names are translated correctly.

## 1.0.0
- Recommends best-in-slot style gear for your class and level from one data source (CMaNGOS classic-db 1.12.x).
- Dungeon/raid drops, crafted items and quest rewards, with source and drop rate in the tooltip.
- DPS / Tank / Heal columns side by side.
- Numeric required-level range with Search button, "Upgrades only", quality filter, world-drop toggle.
- Finds new Forever items missing from the 1.12 database in the game client (marked [New], source unknown).
- Draggable on-screen launcher icon (position is saved).
- English and Korean UI (follows the game client language).
