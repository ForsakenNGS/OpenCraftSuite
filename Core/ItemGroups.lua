-- Source framework
local _, OCS = ...

OCS.ItemGroups = OCS.ModuleBase:New("Internal", "ItemGroups")

function OCS.ItemGroups:OnInitialize()
  self.itemGroups = self:GetStorageValue("List", {})
end

function OCS.ItemGroups:CreateGroup(name, parentPath, items, children)
  local parentData, groupList = self:GetGroupByPath(parentPath)
  if parentData then
    -- Add child element
    local groupData = self:CreateGroupData(name, items, children)
    tinsert(parentData.children, groupData)
    self:SortGroups(parentData.children)
    self:OnGroupsChanged()
    return groupData
  elseif groupList then
    -- Add root element
    local groupData = self:CreateGroupData(name, items, children)
    tinsert(groupList, groupData)
    self:SortGroups(groupList)
    self:OnGroupsChanged()
    return groupData
  else
    -- Failed to find parent!
    self:Log("Failed to create item group! Parent not found!", "error", parentPath)
  end
  return nil, nil
end

function OCS.ItemGroups:CreateGroupData(name, items, children)
  return {
    name = name,
    items = items or {},
    children = children or {}
  }
end

function OCS.ItemGroups:RenameGroup(groupPath, newName)
  local elementData, groupList, elementIndex = self:GetGroupByPath(groupPath)
  if elementData and groupList and elementIndex then
    for i, neighbourData in ipairs(groupList) do
      if neighbourData.name == newName then
        self:Log("Failed to rename item group! A group with that name ("..newName..") already exists!", "error", groupPath)
        return false
      end
    end
    groupList[elementIndex].name = newName
    self:SortGroups(groupList)
    self:OnGroupsChanged()
    return true
  else
    self:Log("Failed to rename item group! Element not found!", "error", groupPath)
    return false
  end
end

function OCS.ItemGroups:DeleteGroup(groupPath)
  local elementData, groupList, elementIndex = self:GetGroupByPath(groupPath)
  if elementData and groupList and elementIndex then
    tremove(groupList, elementIndex)
    self:OnGroupsChanged()
    return true
  else
    self:Log("Failed to delete item group! Element not found!", "error", groupPath)
    return false
  end
end

function OCS.ItemGroups:AddGroupItem(groupPath, ...)
  local elementData, groupList, elementIndex = self:GetGroupByPath(groupPath)
  if elementData and groupList and elementIndex then
    local itemIds = { ... }
    for i, itemId in ipairs(itemIds) do
      if not tContains(elementData.items, itemId) then
        tinsert(elementData.items, itemId)
      end
    end
    self:OnGroupItemsChanged(groupPath)
    return true
  else
    self:Log("Failed to add item to group! Element not found!", "error", groupPath)
    return false
  end
end

function OCS.ItemGroups:RemGroupItem(groupPath, ...)
  local elementData, groupList, elementIndex = self:GetGroupByPath(groupPath)
  if elementData and groupList and elementIndex then
    local itemIds = { ... }
    for i = #(elementData.items), 1, -1 do
      if tContains(itemIds, elementData.items[i]) then
        tremove(elementData.items, i)
      end
    end
    self:OnGroupItemsChanged(groupPath)
    return true
  else
    self:Log("Failed to remove item from group! Element not found!", "error", groupPath)
    return false
  end
end

function OCS.ItemGroups:GetGroups()
  return self.itemGroups
end

function OCS.ItemGroups:GetGroupByPath(groupPath, groupList, parents)
  if not groupList then
    groupList = self.itemGroups
    if groupPath then
      -- Clone to not modify the input variable
      groupPath = OCS.Utils:CloneList(groupPath)
    end
  end
  if not groupPath then
    -- Root element
    return nil, groupList, nil, nil
  end
  if not parents then
    parents = {}
  end
  -- Find next element
  local elementName = tremove(groupPath, 1)
  local elementData, elementIndex = self:GetGroupByName(elementName, groupList)
  if elementData then
    -- Element found!
    if #(groupPath) > 0 then
      -- More path left, move down one level
      tinsert(parents, elementData)
      return self:GetGroupByPath(groupPath, elementData.children, parents)
    else
      -- End of path reached, return result
      return elementData, groupList, elementIndex, parents
    end
  else
    -- Parent not found! Failure!
    return nil, nil, nil, nil
  end
end

function OCS.ItemGroups:GetGroupByName(name, groupList)
  if not groupList then
    groupList = self.itemGroups
  end
  for i, groupData in ipairs(groupList) do
    if groupData.name == name then
      return groupData, i
    end
  end
  return nil, nil
end

function OCS.ItemGroups:GetItems(groupPath)
  local result = {}
  local elementData, groupList, elementIndex, parents = self:GetGroupByPath(groupPath)
  if elementData and groupList and elementIndex then
    local itemIds = {}
    for i, itemId in pairs(elementData.items) do
      if not tContains(itemIds, itemId) then
        local name, link, _, _, _, _, _, _, _, icon = GetItemInfo(itemId)
        tinsert(itemIds, itemId)
        tinsert(result, { id = itemId, name = name, link = link, icon = icon, group = elementData.name, groupPath = groupPath })
      end
    end
    local parentPath = {}
    for j, parentData in pairs(parents) do
      tinsert(parentPath, parentData.name)
      for i, itemId in pairs(parentData.items) do
        if not tContains(itemIds, itemId) then
          local name, link, _, _, _, _, _, _, _, icon = GetItemInfo(itemId)
          tinsert(itemIds, itemId)
          tinsert(result, { id = itemId, name = name, link = link, icon = icon, group = parentData.name, groupPath = parentPath })
        end
      end
      parentPath = OCS.Utils:CloneList(parentPath)
    end
  end
  return result
end

function OCS.ItemGroups:SortGroups(groupList)
  if groupList then
    sort(groupList, function(a, b)
      return a.name < b.name
    end)
  end
  return groupList
end

function OCS.ItemGroups:OnGroupsChanged()
  self:SendMessage("OCS_ITEMGROUPS_UPDATE")
end

function OCS.ItemGroups:OnGroupItemsChanged(groupPath)
  self:SendMessage("OCS_ITEMGROUP_ITEMS_UPDATE", groupPath)
end
