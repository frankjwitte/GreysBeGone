-- GreysBeGone.lua – vendor janitor with /gbg toggle + status
-- NOTE: Add `## SavedVariables: GreysBeGoneDB` to your TOC if you haven't already.

local addonName = ...

-- =====================
-- SavedVariables & Defaults
-- =====================
GreysBeGoneDB = GreysBeGoneDB or nil
local DEFAULTS = {
    autoRepair = true,   -- toggle with /gbg toggle
}

local function deepcopy(tbl)
    local t = {}
    for k, v in pairs(tbl) do
        t[k] = (type(v) == "table") and deepcopy(v) or v
    end
    return t
end

local function ensureDefaults()
    if not GreysBeGoneDB then
        GreysBeGoneDB = deepcopy(DEFAULTS)
        return
    end
    for k, v in pairs(DEFAULTS) do
        if GreysBeGoneDB[k] == nil then
            GreysBeGoneDB[k] = deepcopy(v)
        end
    end
end

-- =====================
-- Utilities
-- =====================
local PREFIX_OK   = "|cff00ff00GreysBeGone|r: "
local PREFIX_WARN = "|cffffff00GreysBeGone|r: "
local PREFIX_ERR  = "|cffff0000GreysBeGone|r: "

local function PrintOK(msg)  print(PREFIX_OK .. msg)  end
local function PrintWarn(msg) print(PREFIX_WARN .. msg) end
local function PrintErr(msg)  print(PREFIX_ERR .. msg)  end

local function coin(amount)
    return GetCoinTextureString(amount or 0)
end

-- =====================
-- Core
-- =====================
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MERCHANT_SHOW")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        ensureDefaults()
        -- Optional: announce on first load only
        -- PrintOK("Loaded. /gbg for options.")
        return
    end

    if event == "MERCHANT_SHOW" then
        -- Auto Repair (if enabled)
        if GreysBeGoneDB and GreysBeGoneDB.autoRepair and CanMerchantRepair() then
            local cost, canRepair = GetRepairAllCost()
            if canRepair and cost and cost > 0 then
                if GetMoney() >= cost then
                    RepairAllItems()
                    PrintOK("Repaired items for " .. coin(cost))
                else
                    PrintErr("Not enough money to repair.")
                end
            end
        end

        -- Auto Sell Greys
        local totalSell = 0
        for bag = 0, NUM_BAG_SLOTS do
            local numSlots = C_Container.GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.hyperlink then
                    local _, _, quality, _, _, _, _, _, _, _, sellPrice = GetItemInfo(info.hyperlink)
                    local count = info.stackCount or 1
                    if quality == 0 and sellPrice and sellPrice > 0 then
                        C_Container.UseContainerItem(bag, slot)
                        totalSell = totalSell + (sellPrice * count)
                    end
                end
            end
        end

        if totalSell > 0 then
            PrintOK("Sold greys for " .. coin(totalSell))
        else
            PrintWarn("No greys to sell.")
        end
    end
end)

-- =====================
-- Slash Commands
-- =====================
SLASH_GREYSBEGONE1 = "/gbg"
SlashCmdList["GREYSBEGONE"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "toggle" then
        GreysBeGoneDB.autoRepair = not GreysBeGoneDB.autoRepair
        if GreysBeGoneDB.autoRepair then
            PrintOK("Auto-repair is |cff00ff00ENABLED|r.")
        else
            PrintWarn("Auto-repair is |cffff0000DISABLED|r.")
        end
        return
    elseif msg == "status" or msg == "" then
        local ar = GreysBeGoneDB.autoRepair and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
        PrintOK("Status → Auto-repair: " .. ar)
        return
    end

    PrintWarn("Commands: /gbg status, /gbg toggle")
end
