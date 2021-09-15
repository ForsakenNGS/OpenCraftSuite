-- WoW auctionhouse source
local _, OCS = ...
local TaskMailSend = OCS.Tasks:Add("MailSend")
local sendMailTask = nil

function TaskMailSend:Create(charTo, charFrom, itemsProvided)
  if not charFrom then
    charFrom = UnitName("player")
  end
  local taskData = self:CreateBase({ charFrom }, true, itemsProvided, itemsProvided)
  taskData.mailTarget = charTo
  return taskData
end

function TaskMailSend:OnInitialize()
  self.source = OCS:GetModule("Inventory", "Mail")
  self:RegisterEvent("MAIL_SEND_SUCCESS", "OnMailSendSuccess")
  self:RegisterEvent("MAIL_SHOW", "OnMailShow")
  self:RegisterEvent("MAIL_CLOSED", "OnMailClosed")
end

function TaskMailSend:CreateTaskFrame(taskData, taskLevel)
  local taskFrame = OCS.TaskBase.CreateTaskFrame(self, taskData, taskLevel)
  taskFrame:SetLayout("List")
  for itemId, itemCount in pairs(taskData.itemsProduced) do
    local itemIconImage = GetItemIcon(itemId)
    local itemName = GetItemInfo(itemId) or "???"
    local itemRow = OCS.GUI:CreateWidget("SimpleGroup")
    itemRow:SetFullWidth(true)
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

-- Get a descriptive name for the task
function TaskMailSend:GetTitle(taskData)
  local title = OCS.L["MODULE_TASK_MAILSEND_TITLE"]
  if taskData.characterChosen then
    title = title..": "..OCS.Utils:FormatCharacterName(taskData.characterChosen)
  end
  if taskData.mailTarget then
    title = title.." -> "..OCS.Utils:FormatCharacterName(taskData.mailTarget)
  end
  return title
end

function TaskMailSend:OnTaskFrameClick(taskWidget, taskData, button, ...)
  -- Move items
  if self.isReady then
    if GetCursorInfo() then
      -- Something on the cursor! Cancel move!
      self:Log(OCS.L["ERROR_CLEAR_CURSOR"], "error")
      return
    end
    ClearSendMail()
    local itemsMissing = OCS.Utils:CloneTable(taskData.itemsProduced)
    local inventoryBag = OCS:GetModule("Inventory", "Bag")
    if not inventoryBag then
      self:Log("Inventory module 'Bag' not found!")
      return
    end
    local itemsBag = inventoryBag:GetBagItems()
    local bagSession, targetBag, targetSlot = OCS.Inventory:GetFreeBagSlotSession()
    local bagItemsAdd = {}
    local bagItemsLocked = {}
    for bagId, bagItems in pairs(itemsBag) do
      for slot, slotItem in pairs(bagItems) do
        if slotItem and itemsMissing[slotItem.id] and itemsMissing[slotItem.id] > 0 then
          local countTake = min(itemsMissing[slotItem.id], slotItem.count)
          itemsMissing[slotItem.id] = itemsMissing[slotItem.id] - countTake
          if countTake == slotItem.count then
            -- Add whole stack to mail
            tinsert(bagItemsAdd, { bag = bagId, slot = slot })
          else
            -- Split before attach
            bagSession, targetBag, targetSlot = OCS.Inventory:GetFreeBagSlotSession(bagSession, 0)
            if not targetSlot then
              ClearSendMail()
              self:Log(OCS.L["ERROR_INVENTORY_FULL"], "error")
              return
            end
            SplitContainerItem(bagId, slot, countTake)
            PickupContainerItem(targetBag, targetSlot)
            tinsert(bagItemsAdd, { bag = targetBag, slot = targetSlot })
            tinsert(bagItemsLocked, { bag = bagId, slot = slot })
            tinsert(bagItemsLocked, { bag = targetBag, slot = targetSlot })
          end
        end
      end
    end
    inventoryBag:CreateItemUnlockCallback(function()
      self:Log("Sending mail...")
      local mailSlot = 1
      for i, bagItem in ipairs(bagItemsAdd) do
        PickupContainerItem(bagItem.bag, bagItem.slot)
        ClickSendMailItemButton(mailSlot)
        mailSlot = mailSlot + 1
      end
      SendMail(taskData.mailTarget, "OCS Mailer", "OCS Mailer items")
      sendMailTask = taskData
      OCS.Tasks:UpdateLazy()
    end, bagItemsLocked)
  end
end

function TaskMailSend:OnMailSendSuccess()
  if sendMailTask ~= nil then
    -- TODO: Create fetch mail task for receiving character
    sendMailTask = nil
  end
end

function TaskMailSend:OnMailShow()
  self.isReady = true
  self:UpdateTaskFrames()
end

function TaskMailSend:OnMailClosed()
  self.isReady = false
  sendMailTask = nil
  self:UpdateTaskFrames()
end
