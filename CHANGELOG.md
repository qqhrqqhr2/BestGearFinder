# Changelog - Best Gear Finder

## 1.0.10
- Faster item search: prioritize search requests, reuse cached information and show known items before new-item discovery finishes. Pending requests no longer cause the search to end early.
- Item search runs automatically when opened or when filters change; stopping or closing it cancels queued search work.
- Recommendation scores are reused; item-info events invalidate only the affected item's cached stats and score.
- Fixed cloth gear being excluded for druids, negative stat-difference rounding, delayed item information and class/source search filters.
- Recommendations now default to score order; level 30 BiS priority remains optional. A BiS marker no longer falsely marks a lower-scoring item as an upgrade.
- Two-handed weapons compare against the total score of the equipped main-hand and off-hand. Switching to a one-handed setup is marked for a weapon-combination check.
- Updated recommendation and search windows with clearer cards separating item names, comparison scores and sources.
- Scores and displayed percentage changes are estimates; first-time discovery may still take time. Search results remain limited to 150 items.

## 1.0.9
- Item search: searching again no longer drops items whose info had not arrived yet (they were wrongly given up on).
- Many more gear sources: quest rewards (with faction), dungeon drops, vendors, rares, world drops and PvP sets collected from the guide pages. Korean names for quests, bosses and vendors.
- Updated dungeon drops, level 30 BiS lists and Forever item data.

## 1.0.8
- New: Sort dropdown with checkboxes (armor, DPS, strength, agility, stamina, intellect, spirit, spell power, healing, attack power, mp5, defense); several checked = sorted by their total.
- New: Item tooltips everywhere (bags, character, chat links, comparison, quest, vendor, loot and other addons' windows) show this addon's sources and BiS mark. Crafted items list their reagents and where the recipe is learned.
- New: Items with no known source get a likely source from nearby item IDs (marked as an estimate). Not shown for non-gear or when ATT knows the item.
- New: Sources of gear you loot, get from quests or see at vendors are recorded automatically and shown as "(seen by you)"; /bgf export lists them.
- Boss, mob and zone names in sources are shown in Korean when the addon language is Korean; quest titles follow the language setting.
- Dungeon quest rewards follow faction/class rules (no other-faction quest for the same reward).
- The Best Gear Finder window's item tooltip now matches other windows, plus the comparison with your equipped item.
- Minimum window width so the top buttons no longer overlap for classes with 2-3 roles.

## 1.0.7
- Dungeon data now covers 18 dungeons (Deadmines, Shadowfang Keep, Stockade, Razorfen Downs, Scarlet Monastery, Uldaman, Ragefire Chasm, Hall of Thanes, Dalaran and more): boss drops and dungeon quest rewards.
- Level 30 BiS lists updated for all classes.
- Crafted items updated for all professions (629 more items), with the skill needed to learn them and whether a recipe is required.
- New Forever zones: vendor gear, zone quest rewards and rare mob drops added; Forever quest rewards and world drops updated.
- Korean dungeon names for Dalaran, Hall of Thanes, Ruins of Lordaeron and Excavation Site.

## 1.0.6
- New: Item search window ("Item search" button / `/bgf find <name>`): filter all items by name or boss, required level, quality, source and an auction-house style category tree (weapon, armor, shield, libram/idol/totem, back, neck, ring, trinket). Shows a progress bar while loading.
- New: "My character" dropdown to view the recommendations of any other class (view only, no comparison with your gear).
- New: Dungeon boss drops and quest rewards for the new Forever dungeons were added or updated.
- New: Background opacity sliders for the main and search windows.
- Items with no level requirement are only listed when their item level is close to the top of your range (fewer too-low items).
- The search window follows the language setting.

## 1.0.5
- New: [BiS] marker for the top pick on the level 30 BiS list (PvE). BiS items are listed first in each slot, and an unworn BiS top pick is always shown.
- Scores now include equip effects read from tooltips (spell power, healing, attack power, mana per 5 sec, defense) and weapon DPS for feral druids.
- Tooltips show "Compared to equipped" with the biggest stat differences.
- Off-hand items are always listed (they were hidden while wielding a two-hander).
- Items with no level requirement are listed for any level range (capped by item level) and shown as "No req".
- Ability-teaching rune relics and toy-like non-gear items are no longer listed.
- Quest rewards are shown whether or not you have completed the quest.
- Items that never load are given up on after 3 requests; faster item loading with your level range first; progress bar at the bottom while loading.
- Fixed the list not scrolling to the bottom after raising the per-slot count (scroll range is recalculated).

## 1.0.4
- Progress bar at the bottom while item data is loading; the indexing message is gone.
- Quest rewards are now shown whether or not you have already completed the quest.
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
