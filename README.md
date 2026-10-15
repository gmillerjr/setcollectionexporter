# ESO Set Collection Exporter

A PC/Mac add-on for The Elder Scrolls Online with a standalone HTML dashboard. Export your sticker-book collection and your current character's crafting research, then explore the results in your browser.

## What it does

- Shows collected and missing pieces for each set, with totals and completion percentages.
- Searches and groups sets by name, source, or type, including dungeons and trials.
- Filters incomplete sets or missing pieces, with expandable piece details.
- Displays set bonuses and links to ESO-Hub.
- Checks crafted-set research eligibility for the exported character.

The dashboard imports native Lua SavedVariables locally, without a server or conversion tool. Collection status means sticker-book unlocks, not items currently in your inventory. Unlocks are shared across the account/server; research belongs to the exported character. Only the latest export is retained.

## Dependencies

- **The Elder Scrolls Online for PC/Mac.** The manifest targets API 101051.
- **A modern web browser** for the dashboard.
- **[LibSets](https://www.esoui.com/downloads/info2241-LibSets.html)** is optional for basic exports, but needed for full dungeon/trial classification and crafted-set trait requirements. Install any dependencies listed by LibSets; the library is not bundled here.

Without matching LibSets data, some types and crafting requirements appear as unclassified or unknown. Crafting eligibility checks research counts only; materials, styles, station access, and crafting skill still apply.

## Installation

1. Extract the ZIP.
2. Copy the **SetCollectionExporter** folder into your ESO AddOns directory. On Windows, this is normally:

   `Documents/Elder Scrolls Online/live/AddOns/`

   Documents may be redirected to OneDrive. On Mac, use your ESO user-data directory's `live/AddOns/` folder.
3. Check that `SetCollectionExporter.txt` and `SetCollectionExporter.lua` sit directly inside `AddOns/SetCollectionExporter/`, without an extra folder level.
4. Install LibSets if you want the additional classification and crafting features.
5. Start ESO and enable **Set Collection Exporter** in the Add-Ons menu. After updating an existing installation, run `/reloadui`. A new installation may require restarting the game.
6. Keep **dashboard.html** anywhere convenient on your computer. It does not need to be in AddOns. The `tests` folder is optional and can be deleted.

## How to use it

1. Log in to the character whose crafting research you want to export.
2. Open **Collections → Set Items** in keyboard mode and click **Export Set Collection** above the filters at the upper right, or type **`/setexport`** in chat. Use the command in gamepad mode.
3. Wait for **Ready**, then run **`/reloadui`** or log out normally to write the export to disk.
4. Double-click **dashboard.html** to open it in your browser.
5. Click **Import ESO SavedVariables** and select:

   `Documents/Elder Scrolls Online/live/SavedVariables/SetCollectionExporter.lua`

   Choose the file in **SavedVariables**, not the add-on source file in **AddOns**.
6. Use search, grouping, filters, and expandable sets to explore your collection. **Missing Sets Only** includes partially collected sets; **Missing Pieces Only** also hides their unlocked pieces. Both missing filters exclude crafted sets.

To refresh your data, repeat export → wait for Ready → reload or log out → re-import. Check the displayed account, server, character, and timestamp. **Try sample export** lets you preview the dashboard without ESO.

To keep a separate character export, copy the written SavedVariables file elsewhere and rename the copy, for example `CharacterName-setcollectionexport.lua`. The dashboard accepts renamed copies.

If the button is missing, use `/setexport`; `/setexportstatus` provides version and button diagnostics. If data looks old, repeat the export and reload steps before importing again.
