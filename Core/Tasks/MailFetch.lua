-- WoW auctionhouse source
local _, OCS = ...
local TaskMailFetch = OCS.Tasks:Add("MailFetch")

function TaskMailFetch:Create(itemsFetch)
  if not charFrom then
    charFrom = UnitName("player")
  end
  local taskData = self:CreateBase({ charFrom }, true, nil, itemsFetch)
  return taskData
end

function TaskMailFetch:OnInitialize()
  self.source = OCS:GetModule("Inventory", "Mail")
  self:RegisterEvent("MAIL_SEND_SUCCESS", "OnMailSendSuccess")
  self:RegisterEvent("MAIL_SHOW", "OnMailShow")
  self:RegisterEvent("MAIL_CLOSED", "OnMailClosed")
end

function TaskMailFetch:CreateTaskFrame(taskData, taskLevel)
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

function TaskMailFetch:OnMailShow()
  self.isReady = true
  self:UpdateTaskFrames()
end

function TaskMailFetch:OnMailClosed()
  self.isReady = false
  sendMailTask = nil
  self:UpdateTaskFrames()
end

function TaskMailFetch:OnMailSendSuccess(event, ...)
  self:Log(event, "debug", { ... })
end
