-- WoW auctionhouse source
local _, OCS = ...
local ItemGroupsFrame = OCS.Frames:Add("ItemGroups")

function ItemGroupsFrame:OnInitialize()
  self.title = OCS.L["MODULE_INTERNAL_ITEMGROUPS"]
  self.name = "OCS_ItemGroupsFrame"
  self.groupSelected = nil
  self:RegisterMessage("OCS_ITEMGROUPS_UPDATE", "OnUpdateItemGroups")
end

function ItemGroupsFrame:GetAceOptions()
  local options = {
    Show = {
      name = OCS.L["MODULE_INTERNAL_ITEMGROUPS_SHOW_FRAME"],
      type = "execute",
      order = 200,
      func = function() OCS.Frames:Show("ItemGroups") end
    }
  }
  return options
end

function ItemGroupsFrame:Create(name, title)
  local frame, created = OCS.FrameBase.Create(self, name, title)
  if created then
    self.widget:SetLayout("Manual")
    self:SaveLocation()
  end
end

function ItemGroupsFrame:CreateContents()
  self.widget:ReleaseChildren()
  self.frame:SetMinResize(680, 440)
  -- Item-Group tree
  self.itemGroupList = OCS.GUI:CreateWidget("TreeGroup")
  self.itemGroupList:SetLayout("Manual")
  self.itemGroupList:SetTree(self:GetItemGroupsTree())
  self.itemGroupList:SetFullWidth(true)
  self.itemGroupList:SetCallback("OnGroupSelected", function(widget, _, groupPathStr)
    self:OnGroupSelected({ strsplit("\001", groupPathStr) })
  end)
  -- Group-Level actions
  self.groupActions = OCS.GUI:CreateWidget("SimpleGroup")
  self.groupActions:SetLayout("Flow")
  self.groupActions:SetFullWidth(true)
  self.groupName = OCS.GUI:CreateWidget("EditBox")
  self.groupName:DisableButton(true)
  self.groupActions:AddChild(self.groupName)
  self.groupAddRoot = OCS.GUI:CreateWidget("Button")
  self.groupAddRoot:SetAutoWidth(true)
  self.groupAddRoot:SetText(OCS.L["MODULE_INTERNAL_ITEMGROUPS_BTN_ADD_ROOT"])
  self.groupAddRoot:SetCallback("OnClick", function()
    self:OnGroupAddRoot( self.groupName:GetText() )
  end)
  self.groupActions:AddChild(self.groupAddRoot)
  self.groupAddChild = OCS.GUI:CreateWidget("Button")
  self.groupAddChild:SetAutoWidth(true)
  self.groupAddChild:SetDisabled(true)
  self.groupAddChild:SetText(OCS.L["MODULE_INTERNAL_ITEMGROUPS_BTN_ADD_CHILD"])
  self.groupAddChild:SetCallback("OnClick", function()
    self:OnGroupAddChild( self.groupName:GetText() )
  end)
  self.groupActions:AddChild(self.groupAddChild)
  self.groupRename = OCS.GUI:CreateWidget("Button")
  self.groupRename:SetAutoWidth(true)
  self.groupRename:SetDisabled(true)
  self.groupRename:SetText(OCS.L["MODULE_INTERNAL_ITEMGROUPS_BTN_RENAME"])
  self.groupRename:SetCallback("OnClick", function()
    self:OnGroupRename( self.groupSelected, self.groupName:GetText() )
  end)
  self.groupActions:AddChild(self.groupRename)
  self.groupDelete = OCS.GUI:CreateWidget("Button")
  self.groupDelete:SetAutoWidth(true)
  self.groupDelete:SetDisabled(true)
  self.groupDelete:SetText(OCS.L["MODULE_INTERNAL_ITEMGROUPS_BTN_DELETE"])
  self.groupDelete:SetCallback("OnClick", function()
    self:OnGroupDelete( self.groupSelected )
  end)
  self.groupActions:AddChild(self.groupDelete)
  self.widget:AddChild(self.itemGroupList)
  self.widget:AddChild(self.groupActions)
  -- Position elements
  self.groupActions.frame:ClearAllPoints()
  self.groupActions.frame:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 16, 16)
  self.groupActions.frame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -16, 16)
  self.itemGroupList.frame:ClearAllPoints()
  self.itemGroupList.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 16, -32)
  self.itemGroupList.frame:SetPoint("BOTTOMRIGHT", self.groupActions.frame, "TOPRIGHT")
  -- Init group details
  self:CreateGroupDetails()
end

function ItemGroupsFrame:CreateGroupDetails()
  self.itemGroupList:ReleaseChildren()
  self.itemGroupList:SetLayout("Manual")
  if not self.groupSelected then
    return
  end
  self.itemActions = OCS.GUI:CreateWidget("SimpleGroup")
  self.itemActions:SetLayout("Flow")
  self.itemActions:SetFullWidth(true)
  self.itemNames = OCS.GUI:CreateWidget("EditBox")
  self.itemNames:DisableButton(true)
  self.itemActions:AddChild(self.itemNames)
  self.itemAdd = OCS.GUI:CreateWidget("Button")
  self.itemAdd:SetAutoWidth(true)
  self.itemAdd:SetText(OCS.L["MODULE_INTERNAL_ITEMGROUPS_BTN_ADD_ITEMS"])
  self.itemAdd:SetCallback("OnClick", function()
    self:OnGroupAddItems( self.groupSelected, self.itemNames:GetText() )
  end)
  self.itemActions:AddChild(self.itemAdd)
  self.itemRem = OCS.GUI:CreateWidget("Button")
  self.itemRem:SetAutoWidth(true)
  self.itemRem:SetText(OCS.L["MODULE_INTERNAL_ITEMGROUPS_BTN_REM_ITEM"])
  self.itemRem:SetCallback("OnClick", function()
    self:OnGroupRemItem( self.itemSelected.groupPath or self.groupSelected, self.itemSelected.id )
  end)
  self.itemActions:AddChild(self.itemRem)
  self.itemGroupList:AddChild(self.itemActions)
  -- Item table
  local tableData = {}
  self.itemGroupContents = OCS.GUI:CreateWidget("Table")
  self.itemGroupContents.GetCellType = function(widget, colIndex)
    if (colIndex == 1) then
      return "ItemRow"
    else
      return "InteractiveLabel"
    end
  end
  self.itemGroupContents:SetCallback("OnTableCellCreated", function(widget, _, cell, colIndex, rowIndex)
    -- Modify cell element
    if (colIndex == 1) then
      cell:SetFullWidth(true)
      cell:SetImageSize(19, 19)
      cell:SetJustifyV("LEFT")
    else
      cell.label:SetHeight(19)
      cell:SetJustifyV("MIDDLE")
    end
  end)
  self.itemGroupContents:SetCallback("OnTableRowUpdate", function(widget, _, cells, rowIndex)
    -- Update cell content
    local itemData = tableData[rowIndex]
    if itemData then
      cells[1]:SetImage(itemData.icon)
      cells[1]:SetText(itemData.name)
      cells[2]:SetText(itemData.group)
    end
  end)
  self.itemGroupContents:SetCallback("OnUpdateData", function(widget)
    -- Update available data
    tableData = OCS.ItemGroups:GetItems(self.groupSelected)
    widget:SetRowCount(#(tableData))
  end)
  self.itemGroupContents:SetCallback("OnTableRowEnter", function(widget, _, cells, rowIndex)
    if tableData[rowIndex] then
      GameTooltip:ClearAllPoints()
      GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
      GameTooltip:SetHyperlink(tableData[rowIndex].link)
      GameTooltip:Show()
    end
  end)
  self.itemGroupContents:SetCallback("OnTableRowLeave", function(widget, _, cells, rowIndex)
    GameTooltip:Hide()
  end)
  self.itemGroupContents:SetCallback("OnTableSel", function(widget, _, rowIndex)
    if rowIndex then
      self:OnItemSelected(tableData[rowIndex])
    else
      self.itemSelected = nil
    end
  end)
  self.itemGroupContents:SetRowHeight(19)
  self.itemGroupContents:SetColumnLabels({ "Name", "Group" }, { 2, 1 })
  self.itemGroupContents:UpdateData()
  self.itemGroupList:AddChild(self.itemGroupContents)
  -- Position elements
  self.itemActions.frame:ClearAllPoints()
  self.itemActions.frame:SetPoint("BOTTOMLEFT", self.itemGroupList.content, "BOTTOMLEFT")
  self.itemActions.frame:SetPoint("BOTTOMRIGHT", self.itemGroupList.content, "BOTTOMRIGHT")
  self.itemGroupContents.frame:ClearAllPoints()
  self.itemGroupContents.frame:SetPoint("TOPLEFT", self.itemGroupList.content, "TOPLEFT")
  self.itemGroupContents.frame:SetPoint("BOTTOMRIGHT", self.itemActions.frame, "TOPRIGHT")
end

function ItemGroupsFrame:GetItemGroupsTree(groupList, childTree)
  if not groupList then
    groupList = OCS.ItemGroups:GetGroups()
  end
  if not childTree then
    childTree = {}
  end
  for i, groupData in ipairs(groupList) do
    local treeNode = {
      value = groupData.name, text = groupData.name
    }
    local treeChildren = {}
    self:GetItemGroupsTree(groupData.children, treeChildren)
    if #(treeChildren) > 0 then
      treeNode.children = treeChildren
    end
    tinsert(childTree, treeNode)
  end
  return childTree
end

function ItemGroupsFrame:OnGroupAddRoot(groupName)
  OCS.ItemGroups:CreateGroup(groupName)
  self.groupName:SetText("")
end

function ItemGroupsFrame:OnGroupAddChild(groupName)
  OCS.ItemGroups:CreateGroup(groupName, self.groupSelected)
  self.groupName:SetText("")
end

function ItemGroupsFrame:OnGroupRename(groupPath, groupNameNew)
  local groupPathOld = OCS.Utils:CloneList(groupPath)
  local groupNameOld = groupPath[ #(groupPath) ]
  groupPath[ #(groupPath) ] = groupNameNew -- Update input path to match the new name
  if not OCS.ItemGroups:RenameGroup(groupPathOld, groupNameNew) then
    groupPath[ #(groupPath) ] = groupNameOld -- Revert input path in case of failure
  end
end

function ItemGroupsFrame:OnGroupDelete(groupPath)
  OCS.ItemGroups:DeleteGroup(groupPath)
end

function ItemGroupsFrame:OnItemSelected(itemData)
  self.itemSelected = itemData
end

function ItemGroupsFrame:OnGroupSelected(groupPath)
  local groupData = OCS.ItemGroups:GetGroupByPath(groupPath)
  local groupTextCurrent = self.groupName:GetText()
  if self.groupSelected then
    local groupDataPrev = OCS.ItemGroups:GetGroupByPath(self.groupSelected)
    if groupTextCurrent == groupDataPrev.name then
      groupTextCurrent = ""
    end
  end
  if groupTextCurrent == "" then
    self.groupName:SetText(groupData.name)
  end
  self.groupSelected = groupPath
  if self.groupAddChild and self.groupDelete then
    if self.groupSelected then
      self.groupAddChild:SetDisabled(false)
      self.groupRename:SetDisabled(false)
      self.groupDelete:SetDisabled(false)
    else
      self.groupAddChild:SetDisabled(true)
      self.groupRename:SetDisabled(true)
      self.groupDelete:SetDisabled(true)
    end
  end
  self:CreateGroupDetails()
end

function ItemGroupsFrame:OnGroupAddItems(groupPath, itemsStr)
  local itemIds = {}
  local links = OCS.Utils:ParseItemLinks(itemsStr)
  if #(links) > 0 then
    for i, linkData in ipairs(links) do
      if linkData.type == "item" then
        tinsert(itemIds, linkData.id)
      end
    end
  else
    local itemName, itemLink = GetItemInfo(itemsStr)
    local _, itemId = OCS.Utils:ParseItemLink(itemLink)
    if itemId then
      tinsert(itemIds, itemId)
    end
  end
  OCS.ItemGroups:AddGroupItem(groupPath, unpack(itemIds))
  self.itemNames:SetText("")
  self.itemGroupContents:UpdateData()
end

function ItemGroupsFrame:OnGroupRemItem(groupPath, itemId)
  OCS.ItemGroups:RemGroupItem(groupPath, itemId)
  self.itemNames:SetText("")
  self.itemGroupContents:UpdateData()
end

function ItemGroupsFrame:OnUpdateItemGroups()
  if self.itemGroupList then
    self.itemGroupList:SetTree(self:GetItemGroupsTree())
    if self.groupSelected then
      self.itemGroupList:SelectByPath(unpack(self.groupSelected))
    end
  end
end
