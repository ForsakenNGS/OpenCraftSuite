-- Bag inventory
local _, OCS = ...
local InventoryBag = OCS.Inventory:Add("Bag")

function InventoryBag:OnInitialize()
  OCS.InventoryBase.OnInitialize(self)
  self.bagItems = {}
  self.bagItemCounts = {}
  self.bagSlotCounts = {}
  self:RegisterEvent("BAG_UPDATE", "OnBagUpdate")
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
  self:Log("Init done!", "debug")
end

function InventoryBag:GetBagItems()
  return self.bagItems
end

function InventoryBag:UpdateBag(bagId)
  self:Log("Updating contents of bag #"..bagId, "debug")
  self.bagItems[bagId] = {}
  self.bagItemCounts[bagId] = {}
  self.bagSlotCounts[bagId] = GetContainerNumSlots(bagId)
  for slot = 1, self.bagSlotCounts[bagId] do
    local itemId = GetContainerItemID(bagId, slot)
    if itemId then
      local texture, itemCount, locked, quality, readable, lootable, itemLink = GetContainerItemInfo(bagId, slot)
      if self.bagItemCounts[bagId][itemId] then
        self.bagItemCounts[bagId][itemId] = self.bagItemCounts[bagId][itemId] + itemCount
      else
        self.bagItemCounts[bagId][itemId] = itemCount
      end
      self.bagItems[bagId][slot] = { id = itemId, count = itemCount, link = itemLink }
    else
      self.bagItems[bagId][slot] = nil
    end
  end
end

function InventoryBag:UpdateBags()
  for bagId = 0, NUM_BAG_SLOTS do
    self:UpdateBag(bagId)
  end
  self:UpdateItemCounts()
end


function InventoryBag:UpdateItemsOnHand()
  self.itemsOnHand = {}
  for bagId, bagItems in pairs(self.bagItemCounts) do
    for itemId, itemCount in pairs(bagItems) do
      if self.itemsOnHand[itemId] then
        self.itemsOnHand[itemId] = self.itemsOnHand[itemId] + itemCount
      else
        self.itemsOnHand[itemId] = itemCount
      end
    end
  end
end

function InventoryBag:OnBagUpdate(_, bagId)
  if (bagId >= 0) and (bagId <= NUM_BAG_SLOTS) then
    self:UpdateBag(bagId)
    self:UpdateItemCounts()
    self:UpdateLazy()
  end
end

function InventoryBag:OnPlayerEnteringWorld()
  self:UpdateBags()
end
