# ESO Set Collection Exporter

A add-on for The Elder Scrolls Online with a standalone HTML dashboard displaying where you are in your sticker collection. Export your sticker-book collection and your current character's crafting research, then explore the results in your browser.

I created this because there were times where I'd watch builds, read about builds, and would wonder what I had already as I started to consider them.  Going in the game, and flipping between game and browser was getting old.

I also wanted to start dabbling in plugins for ESO and this seemed like an easy one to start with.

## What it does

- Shows collected and missing pieces for each set, with totals and completion percentages.
- Searches and groups sets by name, source, or type, including dungeons and trials.
- Filters incomplete sets or missing pieces.
- Displays set bonuses and links to ESO-Hub.
- Checks crafted-set research eligibility for the exported character.

The dashboard imports native Lua SavedVariables locally, without a server or conversion tool. Unlocks are shared across the account/server; research belongs to the exported character. Only the latest export is retained.

## Dependencies

- **[LibSets](https://www.esoui.com/downloads/info2241-LibSets.html)**

Without matching LibSets data, some types and crafting requirements appear as unclassified or unknown. Crafting eligibility checks research counts only; materials, styles, station access, and crafting skill still apply.

## Installation
This is currently beta and is not published in minion or anywhere.  Apologies for the manual install.

1. Extract the ZIP.
2. Copy the **SetCollectionExporter** folder into your ESO AddOns directory. On Windows, this is normally:

   `Documents/Elder Scrolls Online/live/AddOns/`

4. Install LibSets as you normally would.
5. Keep **dashboard.html** anywhere convenient on your computer. It does not need to be in AddOns.

## How to use it

1. Log in to the character whose item sets and research you want to export.
2. Open **Collections -> Set Items** click **Export Set Collection** above the filters at the upper right, or type **`/setexport`** in chat. Use the command in gamepad mode.
3. Wait for **Ready**, then run **`/reloadui`** or log out normally to write the export to disk.
4. Double-click **dashboard.html** to open it in your browser.
5. Click **Import ESO SavedVariables** and navigate to:

   `Documents/Elder Scrolls Online/live/SavedVariables/`

   Choose the file in **SetCollectionExporter.lua**.
6. Use search, grouping, filters, and expandable sets to explore your collection. **Missing Sets Only** includes partially collected sets; **Missing Pieces Only** also hides their unlocked pieces. Both missing filters exclude crafted sets.

To refresh your collection data, run a new export in ESO and wait for the Ready confirmation. Then use /reloadui or log out to save the updated data. Return to the dashboard and import the updated file.

Verify that the displayed account, server, character, and export timestamp are correct.

Want to explore the dashboard first? Click Try Sample Export to preview its features without launching ESO.

To keep a separate character export, copy the written SavedVariables file elsewhere and rename the copy, for example `CharacterName-setcollectionexport.lua`.

If the button is missing, use `/setexport`; `/setexportstatus` provides version and button diagnostics. If data looks old, repeat the export and reload steps before importing again.

## WIP

1. I'd like to get better detail on the research traits, ie nirnhoned, divines, etc rather than the extremely basic pull.

## AI Disclaimer
There is some generated code in this design.  While I speak HTML fluently and have a solid grasp on LUA, combining the two was new to me.  AI was used to bridget that gap and reviewed and tested by me.
