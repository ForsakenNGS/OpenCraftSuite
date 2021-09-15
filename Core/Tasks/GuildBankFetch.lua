-- WoW auctionhouse source
local _, OCS = ...
local TaskGuildBankFetch = OCS.Tasks:Add("GuildBankFetch")

function TaskGuildBankFetch:OnInitialize()
  self.source = OCS:GetModule("Inventory", "GuildBank")
  self:RegisterEvent("GUILDBANKFRAME_OPENED", "OnGuildBankFrameOpened")
  self:RegisterEvent("GUILDBANKFRAME_CLOSED", "OnGuildBankFrameClosed")
end

function TaskGuildBankFetch:Create(fetchItems, charName)
  if not charName then
    charName = UnitName("player")
  end
  return self:CreateBase({ charName }, true, nil, fetchItems)
end

function TaskGuildBankFetch:CreateTaskFrame(taskData, taskLevel)
  local taskFrame = OCS.TaskBase.CreateTaskFrame(self, taskData, taskLevel)
  taskFrame:SetLayout("List")
  for itemId, itemCount in pairs(taskData.itemsProduced) do
    local itemIconImage = GetItemIcon(itemId)
    local itemName = GetItemInfo(itemId) or "???"
    local itemRow = OCS.GUI:CreateWidget("SimpleGroup")
    itemRow:SetLayout("Flow")
    local itemIcon = OCS.GUI:CreateWidget("Label")
    if itemIconImage then
      itemIcon:SetImage(itemIconImage)
    end
    itemIcon:SetImageSize(18, 18)
    itemIcon:SetHeight(20)
    itemIcon:SetWidth(20)
    local itemLabel = OCS.GUI:CreateWidget("Label")
    itemLabel:SetText(itemCount.."x "..itemName)
    itemRow:AddChild(itemIcon)
    itemRow:AddChild(itemLabel)
    taskFrame:AddChild(itemRow)
  end
  self:OnTaskFrameUpdate(taskFrame, taskData)
  return taskFrame
end

function TaskGuildBankFetch:OnTaskFrameClick(taskWidget, taskData, button, ...)
  -- Move items
  if self.isReady then
    if GetCursorInfo() then
      -- Something on the cursor! Cancel move!
      self:Log(OCS.L["ERROR_CLEAR_CURSOR"], "error")
      return
    end
    -- TODO: Error if item on cursor
    local itemsMissing = OCS.Utils:CloneTable(taskData.itemsProduced)
    local itemsBank = self.source:GetActiveGuildItems()
    -- Build item move order
    local itemsTake = {}
    local bagSession, targetBag, targetSlot = OCS.Inventory:GetFreeBagSlotSession()
    for bankTab, bankTabItems in pairs(itemsBank) do
      for bankSlot = 98, 1, -1 do
        local bankSlotItem = bankTabItems[bankSlot]
        if bankSlotItem and itemsMissing[bankSlotItem.id] and itemsMissing[bankSlotItem.id] > 0 then
          local itemBagType = GetItemFamily(bankSlotItem.id)
          bagSession, targetBag, targetSlot = OCS.Inventory:GetFreeBagSlotSession(bagSession, itemBagType)
          if not targetSlot then
            self:Log(OCS.L["ERROR_INVENTORY_FULL"], "error")
            return {}
          end
          local countTake = min(itemsMissing[bankSlotItem.id], bankSlotItem.count)
          itemsMissing[bankSlotItem.id] = itemsMissing[bankSlotItem.id] - countTake
          tinsert(itemsTake, {
            id = bankSlotItem.id, tab = bankTab, slot = bankSlot,
            count = bankSlotItem.count, take = countTake,
            targetBag = targetBag, targetSlot = targetSlot
          })
        end
      end
    end
    -- Move items
    for _, itemTake in ipairs(itemsTake) do
      if itemTake.targetBag and itemTake.targetSlot then
        -- Pickup from guildbank
        if itemTake.take < itemTake.count then
          SplitGuildBankItem(itemTake.tab, itemTake.slot, itemTake.take)
        else
          PickupGuildBankItem(itemTake.tab, itemTake.slot)
        end
        -- Put into bag
        PickupContainerItem(itemTake.targetBag, itemTake.targetSlot)
      end
    end
    OCS.Tasks:UpdateLazy()
  end
end

function TaskGuildBankFetch:OnGuildBankFrameOpened()
  self.isReady = true
  self:UpdateTaskFrames()
end

function TaskGuildBankFetch:OnGuildBankFrameClosed()
  self.isReady = false
  self:UpdateTaskFrames()
end
