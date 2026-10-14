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

-- Retail 12.x moved GetCoinTextureString into C_CurrencyInfo; Classic still has the global.
local GetCoinTextureStringCompat = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString

local function coin(amount)
    amount = amount or 0

    if GetCoinTextureStringCompat then
        return GetCoinTextureStringCompat(amount)
    end

    local gold = math.floor(amount / 10000)
    local silver = math.floor(amount / 100) % 100
    local copper = amount % 100
    return string.format("%dg %ds %dc", gold, silver, copper)
end

-- =====================
-- Core
-- =====================
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")

-- UseContainerItem only sells while a vendor is open; elsewhere it would equip/use the item.
local merchantOpen = false

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

-- Retail 12.x removed the global GetItemInfo; Classic clients may lack C_Item.GetItemInfo.
local GetItemInfoCompat = (C_Item and C_Item.GetItemInfo) or GetItemInfo

local function sellGreys()
    local totalSell = 0
    local soldAny = false

    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)

        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)

            -- Poor / grey quality is 0. Container info is available instantly, no item cache needed.
            if info and info.quality == 0 and not info.hasNoValue and not info.isLocked then
                local count = info.stackCount or 1
                local sellPrice = select(11, GetItemInfoCompat(info.itemID or info.hyperlink))

                C_Container.UseContainerItem(bag, slot)
                soldAny = true
                totalSell = totalSell + ((sellPrice or 0) * count)
            end
        end
    end

    if totalSell > 0 then
        PrintOK("Sold greys for " .. coin(totalSell))
    elseif soldAny then
        PrintOK("Sold greys.")
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
        merchantOpen = true
        ensureDefaults()
        repairItemsIfEnabled()
        sellGreys()
        return
    end

    if event == "MERCHANT_CLOSED" then
        merchantOpen = false
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
        if not merchantOpen then
            PrintWarn("Open a vendor first.")
            return
        end

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
