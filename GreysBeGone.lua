-- GreysBeGone.lua – vendor janitor with /gbg toggle + status

local addonName = ...

-- =====================
-- SavedVariables & Defaults
-- =====================
GreysBeGoneDB = GreysBeGoneDB or nil

local DEFAULTS = {
    autoRepair = true,      -- toggle with /gbg toggle
    verboseNoGreys = true, -- toggle with /gbg chatty
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
            GreysBeGoneDB[k] = (type(v) == "table") and deepcopy(v) or v
        end
    end
end

-- =====================
-- Utilities
-- =====================
local PREFIX_OK   = "|cff00ff00GreysBeGone|r: "
local PREFIX_WARN = "|cffffff00GreysBeGone|r: "
local PREFIX_ERR  = "|cffff0000GreysBeGone|r: "

local function PrintOK(msg)    print(PREFIX_OK .. msg)    end
local function PrintWarn(msg)  print(PREFIX_WARN .. msg)  end
local function PrintErr(msg)   print(PREFIX_ERR .. msg)   end

local function coin(amount)
    return GetCoinTextureString(amount or 0)
end

-- =====================
-- Core
-- =====================
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MERCHANT_SHOW")

local function repairItemsIfEnabled()
    if not GreysBeGoneDB or not GreysBeGoneDB.autoRepair then
        return
    end

    if not CanMerchantRepair() then
        return
    end

    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then
        return
    end

    if GetMoney() >= cost then
        RepairAllItems()
        PrintOK("Repaired items for " .. coin(cost))
    else
        PrintErr("Not enough money to repair.")
    end
end

local function sellGreys()
    local totalSell = 0

    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)

        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)

            if info and info.hyperlink and not info.isLocked then
                local _, _, quality, _, _, _, _, _, _, _, sellPrice = GetItemInfo(info.hyperlink)
                local count = info.stackCount or 1

                -- Poor / grey quality is 0.
                if quality == 0 and sellPrice and sellPrice > 0 then
                    C_Container.UseContainerItem(bag, slot)
                    totalSell = totalSell + (sellPrice * count)
                end
            end
        end
    end

    if totalSell > 0 then
        PrintOK("Sold greys for " .. coin(totalSell))
    elseif GreysBeGoneDB and GreysBeGoneDB.verboseNoGreys then
        PrintWarn("No greys to sell.")
    end
end

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        ensureDefaults()
        return
    end

    if event == "MERCHANT_SHOW" then
        ensureDefaults()
        repairItemsIfEnabled()
        sellGreys()
    end
end)

-- =====================
-- Slash Commands
-- =====================
SLASH_GREYSBEGONE1 = "/gbg"

SlashCmdList["GREYSBEGONE"] = function(msg)
    ensureDefaults()

    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "toggle" then
        GreysBeGoneDB.autoRepair = not GreysBeGoneDB.autoRepair

        if GreysBeGoneDB.autoRepair then
            PrintOK("Auto-repair is |cff00ff00ENABLED|r.")
        else
            PrintWarn("Auto-repair is |cffff0000DISABLED|r.")
        end

        return
    end

    if msg == "chatty" then
        GreysBeGoneDB.verboseNoGreys = not GreysBeGoneDB.verboseNoGreys

        if GreysBeGoneDB.verboseNoGreys then
            PrintOK("No-grey message is |cff00ff00ENABLED|r.")
        else
            PrintWarn("No-grey message is |cffff0000DISABLED|r.")
        end

        return
    end

    if msg == "sell" then
        sellGreys()
        return
    end

    if msg == "status" or msg == "" then
        local ar = GreysBeGoneDB.autoRepair and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
        local ng = GreysBeGoneDB.verboseNoGreys and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"

        PrintOK("Status → Auto-repair: " .. ar .. " | No-grey message: " .. ng)
        return
    end

    PrintWarn("Commands: /gbg status, /gbg toggle, /gbg chatty, /gbg sell")
end
