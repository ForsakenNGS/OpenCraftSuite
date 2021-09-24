-- Bag inventory
local _, OCS = ...
local InventoryTooltip = OCS.Inventory:Add("Tooltip")

function InventoryTooltip:OnInitialize()
  OCS.InventoryBase.OnInitialize(self)
  self:Log("Init done!", "debug")
end

function InventoryTooltip:InjectTooltip(type, tooltip, ...)
  if type == "item" and self:GetTooltipEnabled() then
    local itemName, itemLink = tooltip:GetItem()
    local _, itemId = OCS.Utils:ParseItemLink(itemLink)
    local itemCountsOverall, itemCountGlobal = OCS.Inventory:GetItemsPerCharacter(itemId)
    --self:Log("Items found:", "debug", itemCountsOverall)
    if itemCountGlobal > 0 then
      tooltip:AddLine("OCS Inventory")
      for characterName in pairs(itemCountsOverall) do
        local characterText = {}
        local characterCount = 0
        for moduleName in pairs(itemCountsOverall[characterName]) do
          local moduleAbbr = OCS:GetModuleAbbr("Inventory", moduleName)
          characterCount = characterCount + itemCountsOverall[characterName][moduleName]
          tinsert(characterText, moduleAbbr..": |cffffffff"..itemCountsOverall[characterName][moduleName].."|r")
        end
        if characterCount > 0 then
          tooltip:AddDoubleLine("  "..characterName, "|cffffffff"..characterCount.."|r |cff8080ff("..strjoin(", ", unpack(characterText))..")|r")
        end
      end
      tooltip:Show()
    end
  end
end

function InventoryTooltip:GetTooltipEnabled()
  return self:GetStorageValue("tooltipEnabled", true)
end

function InventoryTooltip:SetTooltipEnabled(enabled)
  self:SetStorageValue("tooltipEnabled", enabled)
end

function InventoryTooltip:GetAceOptions()
  return {
    logLevel = {
      name = OCS.L["INVENTORY_TOOLTIP_LABEL"],
      desc = OCS.L["INVENTORY_TOOLTIP_DESCRIPTION"],
      type = "toggle",
      set = function(info, val) InventoryTooltip:SetTooltipEnabled(val) end,
      get = function(info) return InventoryTooltip:GetTooltipEnabled() end
    }
  }
end
