-- Set Collection Exporter: reads your set collection and stores it in SavedVariables for dashboard.html.
-- This file never writes to disk itself. ESO saves SetCollectionExporterSaved on /reloadui or logout.

-- Names and settings you might want to change
local ADDON = "SetCollectionExporter"
local VERSION = "1.2.0"
local SCHEMA_VERSION = 2
local PIECE_FIELD_SEPARATOR = "|"
local SCAN_UPDATE = ADDON .. "Scan"
local BUTTON_UPDATE = ADDON .. "ButtonInit"
local SCAN_INTERVAL_MS = 20       -- pause between scan batches
local SETS_PER_BATCH = 8          -- sets read per batch; lower it if the game stutters during a scan
local BUTTON_RETRY_MS = 500       -- how often to look for the Set Items panel until it exists
local MAX_COLLECTION_SETS = 10000 -- stop if the set list never ends

-- ESO functions the scan needs. If any is missing, /setexport stops and says which one.
local REQUIRED_APIS = {
    "GetNextItemSetCollectionId",
    "GetNumItemSetCollectionPieces",
    "GetItemSetCollectionPieceInfo",
    "GetItemSetCollectionPieceItemLink",
    "IsItemSetCollectionSlotUnlocked",
    "GetItemSetName",
    "GetItemSetType",
    "GetItemSetInfo",
    "GetItemSetBonusInfo",
    "GetItemSetCollectionCategoryId",
    "GetItemSetCollectionCategoryName",
    "GetItemSetCollectionCategoryParentId",
    "GetNumSmithingResearchLines",
    "GetSmithingResearchLineInfo",
    "GetSmithingResearchLineTraitInfo",
	"GetSmithingResearchLineTraitTimes",
}

-- True while a scan is running, so a second one can't start
local isScanning = false

-- Small helpers: chat messages, text cleanup, and safe calls into LibSets (optional)

local function printMessage(message)
    d("[Set Export] " .. tostring(message))
end

local function cleanText(value)
    local text = tostring(value or "")
    return (text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%^%a+", ""))
end

local function callLibSets(name, ...)
    if not LibSets or type(LibSets[name]) ~= "function" then
        return nil
    end

    local ok, result = pcall(LibSets[name], ...)
    if ok then
        return result
    end
    return nil
end

-- Set info: type (dungeon, trial, other, crafted), source and bonuses

-- Works out a set's type and where it comes from. LibSets gives better answers when it's installed.
local function getSetMetadata(id)
    local category, names, seen = GetItemSetCollectionCategoryId(id), {}, {}
    while category and category ~= 0 and not seen[category] do
        seen[category] = true
        table.insert(names, 1, cleanText(GetItemSetCollectionCategoryName(category)))
        category = GetItemSetCollectionCategoryParentId(category)
    end
    local nativeType, libraryType = GetItemSetType(id), callLibSets("GetSetType", id)
    local kind, confidence = "other", "native"
    if libraryType and LIBSETS_SETTYPE_TRIAL and libraryType == LIBSETS_SETTYPE_TRIAL then
        kind, confidence = "trial", "LibSets"
    elseif libraryType and ((LIBSETS_SETTYPE_DUNGEON and libraryType == LIBSETS_SETTYPE_DUNGEON)
        or (LIBSETS_SETTYPE_MONSTER and libraryType == LIBSETS_SETTYPE_MONSTER)) then
        kind, confidence = "dungeon", "LibSets"
    elseif nativeType == ITEM_SET_TYPE_MONSTER then
        kind = "dungeon"
    elseif nativeType == ITEM_SET_TYPE_DUNGEON then
        kind, confidence = "other", "unclassified instance set: install/update LibSets to distinguish dungeon/trial"
    elseif nativeType == ITEM_SET_TYPE_CRAFTED then
        kind = "crafted"
    elseif not libraryType then
        confidence = "trial classification unavailable without LibSets"
    end
    local source = table.concat(names, " / ")
    local zones = callLibSets("GetZoneIds", id)
    if type(zones) == "table" then
        local zoneNames, used = {}, {}
        for _, zone in pairs(zones) do
            local name = GetZoneNameById(zone)
            if name and name ~= "" and not used[name] then
                zoneNames[#zoneNames + 1] = cleanText(name)
                used[name] = true
            end
        end
        table.sort(zoneNames)
        if #zoneNames > 0 then
            source = table.concat(zoneNames, ", ")
        end
    end
    return kind, source ~= "" and source or "Source unavailable", confidence
end

local function collectSetBonuses(id)
    local result = {}
    local _, _, count = GetItemSetInfo(id)
    for i = 1, count or 0 do
        local required, description = GetItemSetBonusInfo(id, i)
        local text = cleanText(description)
        -- ESO's own text often starts with "(2 items)" already; only add the count when it doesn't.
        if text:sub(1, 1) ~= "(" then
            text = "(" .. tostring(required) .. ") " .. text
        end
        result[#result + 1] = text
    end
    return result
end

-- Trait research for the currently logged in toon

local function collectResearch()
    local result = {}
    local craftingTypes = {
        CRAFTING_TYPE_BLACKSMITHING,
        CRAFTING_TYPE_CLOTHIER,
        CRAFTING_TYPE_WOODWORKING,
        CRAFTING_TYPE_JEWELRYCRAFTING,
    }

    for _, craft in ipairs(craftingTypes) do
        for line = 1, GetNumSmithingResearchLines(craft) do
            local name, _, total = GetSmithingResearchLineInfo(craft, line)
            local known = 0
            local traits = {}

            for trait = 1, total do
                local traitType, _, learned =
                    GetSmithingResearchLineTraitInfo(craft, line, trait)

                local _, remaining =
                    GetSmithingResearchLineTraitTimes(craft, line, trait)

                local status = "missing"

                if learned then
                    status = "researched"
                    known = known + 1
                elseif remaining ~= nil then
                    status = "researching"
                end

                traits[#traits + 1] = {
                    id = traitType,
                    name = cleanText(GetString("SI_ITEMTRAITTYPE", traitType)),
                    status = status,
                    remaining = remaining,
                }
            end

            result[#result + 1] = {
                craft = craft,
                craftName = cleanText(GetString("SI_TRADESKILLTYPE", craft)),
                line = line,
                name = cleanText(name),
                known = known,
                total = total,
                traits = traits,
            }
        end
    end

    return result
end



-- Saves the in-game name for an armor/weapon/slot type once per export instead of once per piece.
local function recordLabel(labels, prefix, value)
    if labels[value] == nil then
        labels[value] = cleanText(GetString(prefix, value))
    end
end

-- "pieceId|unlocked(0 or 1)|armorType|weaponType|equipType|name". dashboard.html reads this format.
local function encodePiece(pieceId, unlocked, armorType, weaponType, equipType, name)
    return table.concat({
        pieceId, unlocked and 1 or 0, armorType, weaponType, equipType, name,
    }, PIECE_FIELD_SEPARATOR)
end

-- Reads one set and all its pieces. Returns the set, its piece count and how many are unlocked.
local function collectSet(id, labels)
    local kind, source, confidence = getSetMetadata(id)
    local set = {
        id = id,
        name = cleanText(GetItemSetName(id)),
        hubName = callLibSets("GetSetName", id, "en"),
        type = kind,
        source = source,
        classification = confidence,
        pieces = {},
        bonuses = collectSetBonuses(id),
    }
    local unlockedCount = 0
    local count = GetNumItemSetCollectionPieces(id)
    for index = 1, count do
        local pieceId, slot = GetItemSetCollectionPieceInfo(id, index)
        local link = GetItemSetCollectionPieceItemLink(pieceId, LINK_STYLE_DEFAULT, ITEM_TRAIT_TYPE_NONE)
        local unlocked = IsItemSetCollectionSlotUnlocked(id, slot)
        local armorType = GetItemLinkArmorType(link)
        local weaponType = GetItemLinkWeaponType(link)
        local equipType = GetItemLinkEquipType(link)
        recordLabel(labels.armor, "SI_ARMORTYPE", armorType)
        recordLabel(labels.weapon, "SI_WEAPONTYPE", weaponType)
        recordLabel(labels.equip, "SI_EQUIPTYPE", equipType)
        set.pieces[#set.pieces + 1] = encodePiece(
            pieceId, unlocked, armorType, weaponType, equipType, cleanText(GetItemLinkName(link)))
        if unlocked then
            unlockedCount = unlockedCount + 1
        end
    end
    return set, count, unlockedCount
end

-- Crafted sets are listed on their own and don't count toward sticker-book totals

local function collectCraftedSets(snapshot)
    local crafted = callLibSets("GetSetTypeSetsData", LIBSETS_SETTYPE_CRAFTED)
    local craftedIds = {}
    if type(crafted) == "table" then
        for id in pairs(crafted) do
            craftedIds[id] = true
        end
    end
    if GetNumConsolidatedSmithingSets and GetConsolidatedSmithingItemSetIdByIndex then
        for i = 1, GetNumConsolidatedSmithingSets() do
            local id = GetConsolidatedSmithingItemSetIdByIndex(i)
            if id and id > 0 then
                craftedIds[id] = true
            end
        end
    end
    for id in pairs(craftedIds) do
        local _, source = getSetMetadata(id)
        local needed = callLibSets("GetTraitsNeeded", id)
        snapshot.craftedSets[#snapshot.craftedSets + 1] = {
            id = id,
            name = cleanText(GetItemSetName(id)),
            hubName = callLibSets("GetSetName", id, "en"),
            type = "crafted",
            source = source,
            traitsNeeded = needed,
            bonuses = collectSetBonuses(id),
        }
    end
    table.sort(snapshot.craftedSets, function(a, b)
        return a.id < b.id
    end)
    if not LibSets then
        snapshot.warnings[#snapshot.warnings + 1] =
            "LibSets absent: trial classification and crafted trait requirements unavailable."
    end
    if #snapshot.craftedSets == 0 then
        snapshot.warnings[#snapshot.warnings + 1] =
            "Crafted catalog unavailable on this client. Install/update LibSets."
    end
end


-- Saving: only runs after a scan finishes, so a failed scan keeps the last good export

local function commitSnapshot(snapshot)
    snapshot.percent = snapshot.total > 0 and 100 * snapshot.unlocked / snapshot.total or 0
    SetCollectionExporterSaved = SetCollectionExporterSaved or {}
    -- Older versions saved a copy per character. Clear it so it doesn't stay in the file.
    SetCollectionExporterSaved.characters = nil
    SetCollectionExporterSaved.latest = snapshot
    EVENT_MANAGER:UnregisterForUpdate(SCAN_UPDATE)
    isScanning = false
    printMessage("Ready: " .. snapshot.unlocked .. "/" .. snapshot.total .. " pieces unlocked. Use /reloadui or logout to write SavedVariables, then import the .lua file.")
end


-- this exports the sets to the file

-- Runs from /setexport and the Export button.
local function startExport()
    if isScanning then
        printMessage("Scan already running.")
        return
    end

    for _, name in ipairs(REQUIRED_APIS) do
        if type(_G[name]) ~= "function" then
            printMessage("Unsupported client: missing " .. name .. ". Previous export kept.")
            return
        end
    end

    isScanning = true
    local snapshot = {
        schemaVersion = SCHEMA_VERSION,
        labels = { armor = {}, weapon = {}, equip = {} },
        timestamp = GetTimeStamp(),
        apiVersion = GetAPIVersion(),
        account = GetDisplayName(),
        world = GetWorldName(),
        character = cleanText(GetUnitName("player")),
        characterId = tostring(GetCurrentCharacterId()),
        sets = {},
        craftedSets = {},
        warnings = {},
        total = 0,
        unlocked = 0,
    }
    local ids, seen, last = {}, {}, nil
    local ok, err = pcall(function()
        while true do
            local id = GetNextItemSetCollectionId(last)
            if not id or id == 0 then
                break
            end
            if seen[id] then
                error("Collection iterator repeated a set ID")
            end
            ids[#ids + 1] = id
            seen[id] = true
            last = id
            if #ids > MAX_COLLECTION_SETS then
                error("Collection iterator exceeded safety limit")
            end
        end
        snapshot.research = collectResearch()
    end)
    if not ok then
        isScanning = false
        printMessage(err)
        return
    end

    local index = 1
    printMessage("Scanning " .. #ids .. " sets...")
    EVENT_MANAGER:RegisterForUpdate(SCAN_UPDATE, SCAN_INTERVAL_MS, function()
        local success, reason = pcall(function()
            for _ = 1, SETS_PER_BATCH do
                local id = ids[index]
                if not id then
                    break
                end
                local set, setTotal, setUnlocked = collectSet(id, snapshot.labels)
                snapshot.sets[#snapshot.sets + 1] = set
                snapshot.total = snapshot.total + setTotal
                snapshot.unlocked = snapshot.unlocked + setUnlocked
                index = index + 1
            end
            if index > #ids then
                collectCraftedSets(snapshot)
                commitSnapshot(snapshot)
            end
        end)
        if not success then
            EVENT_MANAGER:UnregisterForUpdate(SCAN_UPDATE)
            isScanning = false
            printMessage("Scan failed; previous export kept: " .. tostring(reason))
        end
    end)
end

-- The Export button in Collections Set Items, and the /setexportstatus check

local exportButton, buttonError

local function getSetItemsPanel()
    return ZO_ItemSetsBook_Keyboard_TopLevel
        or (ITEM_SET_COLLECTIONS_BOOK_KEYBOARD and ITEM_SET_COLLECTIONS_BOOK_KEYBOARD.control)
end

local function attachExportButton()
    -- Size and position are set a few lines down (SetDimensions / SetAnchor).
    if exportButton then
        return true
    end
    local panel = getSetItemsPanel()
    if not panel then
        return false
    end

    local button = WINDOW_MANAGER:CreateControlFromVirtual("SetCollectionExporterButton", panel, "ZO_DefaultButton")
    button:SetDimensions(220, 32)
    button:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -20, 0)
    button:SetText("Export Set Collection")
    button:SetDrawTier(DT_HIGH)
    button:SetDrawLayer(DL_OVERLAY)
    button:SetMouseEnabled(true)
    button:SetHidden(false)
    button:SetHandler("OnClicked", startExport)
    exportButton = button
    buttonError = nil
    return true
end

local function initializeButton()
    local function attempt()
        local ok, attached = pcall(attachExportButton)
        if not ok or attached then
            EVENT_MANAGER:UnregisterForUpdate(BUTTON_UPDATE)
            if not ok then
                buttonError = tostring(attached)
                printMessage("Collections button unavailable; use /setexport. " .. buttonError)
            end
        end
        return ok and attached
    end
    -- check to make sure th button loads
    EVENT_MANAGER:RegisterForUpdate(BUTTON_UPDATE, BUTTON_RETRY_MS, attempt)
    attempt()
end

local function printStatus()
    local panel = getSetItemsPanel()
    printMessage("v" .. VERSION .. " | API " .. tostring(GetAPIVersion())
        .. " | keyboard panel=" .. tostring(panel ~= nil)
        .. " | panel hidden=" .. tostring(panel and panel:IsControlHidden())
        .. " | button=" .. tostring(exportButton ~= nil)
        .. " | button hidden=" .. tostring(exportButton and exportButton:IsControlHidden())
        .. " | gamepad=" .. tostring(IsInGamepadPreferredMode and IsInGamepadPreferredMode() or false))
    if buttonError then
        printMessage("Button error: " .. buttonError)
    end
end

-- Startup: register the slash commands and add the button once the add-on has loaded

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= ADDON then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
    SLASH_COMMANDS["/setexport"] = startExport
    SLASH_COMMANDS["/setexportstatus"] = printStatus
    initializeButton()
end)
