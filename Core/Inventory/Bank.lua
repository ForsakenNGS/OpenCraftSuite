-- Bank inventory
local _, OCS = ...
local InventoryBank = OCS.Inventory:Add("Bank")

function InventoryBank:OnInitialize()
  OCS.InventoryBase.OnInitialize(self)
  self.bankItems = {}
  self.bankItemCounts = {}
  self.bankSlotCounts = {}
  self:RegisterEvent("BAG_UPDATE", "OnBagUpdate")
  self:RegisterEvent("PLAYERBANKSLOTS_CHANGED", "OnPlayerBankSlotsChanged")
  self:RegisterEvent("BANKFRAME_OPENED", "OnBankFrameOpened")
  self:Log("Init done!", "debug")
end

function InventoryBank:LoadFromStorage()
  local charData, guildData = OCS.InventoryBase.LoadFromStorage(self)
  self.bankItems = charData.bankItems or self.bankItems
  self.bankItemCounts = charData.bankItemCounts or self.bankItemCounts
  self.bankSlotCounts = charData.bankSlotCounts or self.bankSlotCounts
end

function InventoryBank:WriteToStorage()
  local playerData = OCS.InventoryBase.WriteToStorage(self)
  playerData.bankItems = self.bankItems
  playerData.bankItemCounts = self.bankItemCounts
  playerData.bankSlotCounts = self.bankSlotCounts
end

-- Get the tabs/slot with their items for the currently active guildbank
function InventoryBank:GetActiveBankItems()
  return self.bankItems or {}
end

function InventoryBank:ObtainItems(itemsRequired)
  local bankTask = OCS.Tasks:Create("BankFetch")
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

function InventoryBank:UpdateBag(bagId)
  local _, bagType = GetContainerNumFreeSlots(-1);
  if (bagType == nil) then
    -- Bank not open, prevent update!
    return false
  end
  --self:Log("Updating contents of bank slot #"..bagId, "debug")
  self.bankItems[bagId] = {}
  self.bankItemCounts[bagId] = {}
  self.bankSlotCounts[bagId] = GetContainerNumSlots(bagId)
  for slot = 1, self.bankSlotCounts[bagId] do
    local itemId = GetContainerItemID(bagId, slot)
    self.bankItems[bagId][slot] = itemId
    if itemId then
      local texture, itemCount, locked, quality, readable, lootable, itemLink = GetContainerItemInfo(bagId, slot)
      if self.bankItemCounts[bagId][itemId] then
        self.bankItemCounts[bagId][itemId] = self.bankItemCounts[bagId][itemId] + itemCount
      else
        self.bankItemCounts[bagId][itemId] = itemCount
      end
      self.bankItems[bagId][slot] = { id = itemId, count = itemCount, link = itemLink }
    else
      self.bankItems[bagId][slot] = nil
    end
  end
  return true
end

function InventoryBank:UpdateBags()
  self:UpdateBag(BANK_CONTAINER)
  for bagId = NUM_BAG_SLOTS+1, NUM_BAG_SLOTS+NUM_BANKBAGSLOTS do
    self:UpdateBag(bagId)
  end
  self:UpdateItemCounts()
end

function InventoryBank:UpdateItemsObtainable()
  self.itemsObtainable = {}
  for bagId in pairs(self.bankItemCounts) do
    for itemId in pairs(self.bankItemCounts[bagId]) do
      if self.itemsObtainable[itemId] then
        self.itemsObtainable[itemId] = self.itemsObtainable[itemId] + self.bankItemCounts[bagId][itemId]
      else
        self.itemsObtainable[itemId] = self.bankItemCounts[bagId][itemId]
      end
    end
  end
end

function InventoryBank:OnBagUpdate(_, bagId)
  if (bagId == BANK_CONTAINER) or ((bagId >= NUM_BAG_SLOTS+1) and (bagId <= NUM_BAG_SLOTS+NUM_BANKBAGSLOTS)) then
    if self:UpdateBag(bagId) then
      self:UpdateItemCounts()
      self:UpdateLazy()
    end
  end
end

function InventoryBank:OnPlayerBankSlotsChanged(_, bankSlot)
  if bankSlot <= NUM_BANKGENERIC_SLOTS then
    if self:UpdateBag(BANK_CONTAINER) then
      self:UpdateItemCounts()
      self:UpdateLazy()
    end
  end
end

function InventoryBank:OnBankFrameOpened()
  self:UpdateBags()
end
