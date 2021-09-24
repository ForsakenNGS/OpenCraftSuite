-- Bag inventory
local _, OCS = ...
local SourceTooltip = OCS.Sources:Add("Tooltip")

function SourceTooltip:OnInitialize()
  self:Log("Init done!", "debug")
end

function SourceTooltip:InjectTooltip(tooltipType, tooltip, extra1, extra2, extra3, extra4)
  if tooltipType == "item" then
    local itemName, itemLink = tooltip:GetItem()
    local _, itemId = OCS.Utils:ParseItemLink(itemLink)
    local sourceText = {}
    local sourceCount = 0
    local itemPrices = OCS.Sources:GetPrice(itemId)
    for moduleName in pairs(itemPrices) do
      for itemPriceType in pairs(itemPrices[moduleName]) do
        local itemPrice = itemPrices[moduleName][itemPriceType]
        if itemPrice then
          sourceCount = sourceCount + 1
          tinsert(sourceText, { moduleName.." "..itemPriceType, itemPrice })
        end
      end
    end
    if sourceCount > 0 then
      tooltip:AddLine("OCS Price")
      for i in ipairs(sourceText) do
        local itemPriceType, itemPrice = unpack(sourceText[i])
        local itemQuantity = 1
        local itemSuffix = ""
        if (type(extra3) == "number") and (type(extra4) == "number") then
          local _, itemCount = GetContainerItemInfo(extra3, extra4)
          itemQuantity = itemCount or 1
        end
        if IsShiftKeyDown() and (itemQuantity > 1) then
          itemSuffix = " x"..itemQuantity
          itemPrice = itemPrice * itemQuantity
        end
        tooltip:AddDoubleLine("  |cff8080ff"..itemPriceType..itemSuffix.."|r", OCS.Utils:FormatMoney(itemPrice))
      end
      tooltip:Show()
    end
  end
end
