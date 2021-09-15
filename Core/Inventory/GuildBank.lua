-- Bank inventory
local _, OCS = ...
local InventoryGuildBank = OCS.Inventory:Add("GuildBank")

function InventoryGuildBank:OnInitialize()
  OCS.InventoryBase.OnInitialize(self)
  self.bankItems = {}
  self.bankItemCounts = {}
  self:RegisterEvent("GUILDBANK_UPDATE_TABS", "OnGuildBankUpdateTabs")
  self:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED", "OnGuildBankBagSlotsChanged")
  self:RegisterEvent("GUILDBANKFRAME_OPENED", "OnGuildBankFrameOpened")
  self:Log("Init done!", "debug")
end

function InventoryGuildBank:UpdateGuildBank()
  for i = 1, GetNumGuildBankTabs() do
    self:UpdateGuildBankTab(i)
  end
  self:UpdateItemCounts()
end

function InventoryGuildBank:LoadFromStorage()
  local guildName = GetGuildInfo("player") or "No Guild"
  local charData, guildData = OCS.InventoryBase.LoadFromStorage(self)
  if guildData[guildName] then
    self.bankItems = guildData[guildName].bankItems or self.bankItems
    self.bankItemCounts = guildData[guildName].bankItemCounts or self.bankItemCounts
  end
end

function InventoryGuildBank:WriteToStorage()
  local guildName = GetGuildInfo("player") or "No Guild"
  local playerData, guildData = OCS.InventoryBase.WriteToStorage(self)
  if not guildData[guildName] then
    guildData[guildName] = {}
  end
  guildData[guildName].bankItems = self.bankItems
  guildData[guildName].bankItemCounts = self.bankItemCounts
end

-- Get the tabs/slot with their items for the currently active guildbank
function InventoryGuildBank:GetActiveGuildItems()
  return self.bankItems or {}
end

function InventoryGuildBank:ObtainItems(itemsRequired)
  local bankTask = OCS.Tasks:Create("GuildBankFetch")
  if bankTask then
    for itemId, itemCount in pairs(itemsRequired) do
      local obtainableCount = min(itemCount, self:GetItemsObtainable(itemId))
      if obtainableCount > 0 then
        bankTask.itemsProduced[itemId] = obtainableCount
      end
    end
    -- TODO: Create task(s) to obtain the given items
    return { bankTask }
  end
  return {}
end

function InventoryGuildBank:UpdateGuildBankTab(tabIndex)
  self:Log("Updating contents of guild bank tab #"..tabIndex, "debug")
  self.bankItems[tabIndex] = {}
  self.bankItemCounts[tabIndex] = {}
  for i = 1, 98 do
    local itemLink = GetGuildBankItemLink(tabIndex, i)
    local _, itemId = OCS.Utils:ParseItemLink(itemLink)
    if itemId then
      local texture, itemCount, locked, isFiltered, quality = GetGuildBankItemInfo(tabIndex, i)
      if self.bankItemCounts[tabIndex][itemId] then
        self.bankItemCounts[tabIndex][itemId] = self.bankItemCounts[tabIndex][itemId] + itemCount
      else
        self.bankItemCounts[tabIndex][itemId] = itemCount
      end
      self.bankItems[tabIndex][i] = { id = itemId, count = itemCount, link = itemLink }
    end
  end
end

function InventoryGuildBank:UpdateItemsObtainable()
  local playerGuildName = GetGuildInfo("player") or "No Guild"
  self.itemsObtainable = {}
  for guildName, guildStorage in pairs(self.itemsGuilds) do
    if (guildName ~= playerGuildName) then
      -- Get guild items of alt
      for itemId, itemCount in pairs(guildStorage.itemCounts or {}) do
        if self.itemsObtainable[itemId] then
          self.itemsObtainable[itemId] = self.itemsObtainable[itemId] + itemCount
        else
          self.itemsObtainable[itemId] = itemCount
        end
      end
    end
  end
  -- Current characters guild
  for bagId, bagItems in pairs(self.bankItemCounts) do
    for itemId, itemCount in pairs(bagItems) do
      if self.itemsObtainable[itemId] then
        self.itemsObtainable[itemId] = self.itemsObtainable[itemId] + itemCount
      else
        self.itemsObtainable[itemId] = itemCount
      end
    end
  end
end

function InventoryGuildBank:UpdateItemsGuilds()
  local guildName = GetGuildInfo("player") or "No Guild"
  if not self.itemsGuilds[guildName] then
    self.itemsGuilds[guildName] = {}
  end
  self.itemsGuilds[guildName].itemCounts = {}
  for bagId, bagItems in pairs(self.bankItemCounts) do
    for itemId, itemCount in pairs(bagItems) do
      if self.itemsGuilds[guildName].itemCounts[itemId] then
        self.itemsGuilds[guildName].itemCounts[itemId] = self.itemsGuilds[guildName].itemCounts[itemId] + itemCount
      else
        self.itemsGuilds[guildName].itemCounts[itemId] = itemCount
      end
    end
  end
end

function InventoryGuildBank:OnGuildBankUpdateTabs(...)
  self:UpdateGuildBank()
end

function InventoryGuildBank:OnGuildBankBagSlotsChanged(...)
  self:UpdateGuildBankTab(GetCurrentGuildBankTab())
  self:UpdateItemCounts()
  self:UpdateLazy()
end

function InventoryGuildBank:OnGuildBankFrameOpened()
  self:UpdateGuildBank()
end
