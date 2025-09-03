local addonName = ...
local frame = CreateFrame("Frame")

frame:RegisterEvent("MERCHANT_SHOW")

frame:SetScript("OnEvent", function()
    -- Auto Repair
    if CanMerchantRepair() then
        local cost, canRepair = GetRepairAllCost()
        if canRepair and cost > 0 then
            if GetMoney() >= cost then
                RepairAllItems()
                print("|cff00ff00Greys Be Gone: Repaired items for|r " .. GetCoinTextureString(cost))
            else
                print("|cffff0000Greys Be Gone: Not enough money to repair.|r")
            end
        end
    end

    -- Auto Sell Greys
    local totalSell = 0
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if itemInfo and itemInfo.hyperlink then
                local itemLink = itemInfo.hyperlink
                local itemCount = itemInfo.stackCount or 1
                local itemID = itemInfo.itemID
                local _, _, itemRarity, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(itemLink)

                if itemRarity == 0 and itemSellPrice and itemSellPrice > 0 then
                    C_Container.UseContainerItem(bag, slot)
                    totalSell = totalSell + (itemSellPrice * itemCount)
                end
            end
        end
    end

    if totalSell > 0 then
        print("|cff00ff00Greys Be Gone: Sold greys for|r " .. GetCoinTextureString(totalSell))
    end
end)
