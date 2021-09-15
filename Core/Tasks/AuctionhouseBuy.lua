-- WoW auctionhouse source
local _, OCS = ...
local TaskAuctionhouseBuy = OCS.Tasks:Add("AuctionhouseBuy")

function TaskAuctionhouseBuy:OnInitialize()
  self.source = OCS:GetModule("Sources", "Auctionhouse")
end

function TaskAuctionhouseBuy:Create(fetchItems, charName)
  if not charName then
    charName = UnitName("player")
  end
  return self:CreateBase({ charName }, true, nil, fetchItems)
end

function TaskAuctionhouseBuy:CreateTaskFrame(taskData, taskLevel)
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
