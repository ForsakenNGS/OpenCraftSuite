-- Mail inventory
local _, OCS = ...
local InventoryMail = OCS.Inventory:Add("Mail")

function InventoryMail:OnInitialize()
  OCS.InventoryBase.OnInitialize(self)
  self.mailItems = {}
  self.mailItemCounts = {}
  self.itemCounts = {}
  self:RegisterEvent("MAIL_INBOX_UPDATE", "OnMailInboxUpdate")
  self:RegisterEvent("UPDATE_PENDING_MAIL", "OnUpdatePendingMail")
  self:Log("Init done!", "debug")
end

function InventoryMail:ObtainItems(itemsRequired)
  local bankTask = OCS.Tasks:Create("MailFetch")
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

function InventoryMail:GetItemsSendable(itemsProvided, target, ...)
  -- TODO: Filter foreign characters?
  -- TODO: Filter items to be sent to guild(bank)s?
  -- TODO: Filter soulbound items? do it ealrier?
  return itemsProvided
end

function InventoryMail:SendItems(itemsProvided, target, source, ...)
  local mailTask = OCS.Tasks:Create("MailSend", target, source)
  if mailTask then
    if source then
      mailTask.characterChosen = source
    end
    local mailTasks = {}
    local mailItemSlots = ATTACHMENTS_MAX_SEND
    for itemId, itemCount in pairs(itemsProvided) do
      local _, _, _, _, _, _, _, itemStackCount = GetItemInfo(itemId)
      local obtainableCount = min(itemCount, OCS.Inventory:GetItemsOnHand(itemId))
      local currentCount = 0
      while (obtainableCount > 0) do
        if obtainableCount > itemStackCount then
          -- Add full stack
          currentCount = currentCount + itemStackCount
          obtainableCount = obtainableCount - itemStackCount
        else
          -- Add partial stack
          currentCount = currentCount + obtainableCount
          obtainableCount = obtainableCount - obtainableCount
        end
        mailItemSlots = mailItemSlots - 1
        if mailItemSlots == 0 then
          -- Item limit reached! Finish current mail
          if currentCount > 0 then
            mailTask.itemsProduced[itemId] = currentCount
            mailTask.itemsRequired[itemId] = currentCount
          end
          tinsert(mailTasks, mailTask)
          -- Create new mail
          mailTask = OCS.Tasks:Create("MailSend", target, source)
          if source then
            mailTask.characterChosen = source
          end
          -- Reset counters
          mailItemSlots = ATTACHMENTS_MAX_SEND
          currentCount = 0
        end
      end
      if currentCount > 0 then
        mailTask.itemsProduced[itemId] = currentCount
        mailTask.itemsRequired[itemId] = currentCount
      end
    end
    tinsert(mailTasks, mailTask)
    return mailTasks
  end
  return {}
end

function InventoryMail:UpdateMailInbox()
  self:Log("Updating contents of the mail inbox", "debug")
  self.mailItems = {}
  self.mailItemCounts = {}
  local inboxCount = GetInboxNumItems()
  --self:Log("Found "..inboxCount.." mails in the inbox", "debug")
  for i = 1, inboxCount do
    self.mailItems[i] = {}
    self.mailItemCounts[i] = {}
    for j = 1, ATTACHMENTS_MAX_RECEIVE do
      local name, itemId, itemTexture, count, quality, canUse = GetInboxItem(i, j)
      if itemId then
        --self:Log("Mail #"..i.." contains "..count.." x Item #"..itemId, "debug")
        if self.mailItemCounts[i][itemId] then
          self.mailItemCounts[i][itemId] = self.mailItemCounts[i][itemId] + count
        else
          self.mailItemCounts[i][itemId] = count
        end
        self.mailItems[i][j] = { id = itemId, count = itemCount, link = itemLink }
      else
        self.mailItems[i][j] = nil
      end
    end
  end
  self:UpdateItemCounts()
end

function InventoryMail:UpdateItemsObtainable()
  self.itemsObtainable = {}
  for mailId in pairs(self.mailItemCounts) do
    for itemId in pairs(self.mailItemCounts[mailId]) do
      if self.itemsObtainable[itemId] then
        self.itemsObtainable[itemId] = self.itemsObtainable[itemId] + self.mailItemCounts[mailId][itemId]
      else
        self.itemsObtainable[itemId] = self.mailItemCounts[mailId][itemId]
      end
    end
  end
end

function InventoryMail:OnMailInboxUpdate(_, mouseButton)
  self:UpdateMailInbox()
end

function InventoryMail:OnUpdatePendingMail()
  -- TODO: Task the user with checking the mail
end
