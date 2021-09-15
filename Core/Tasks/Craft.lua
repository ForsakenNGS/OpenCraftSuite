-- WoW auctionhouse source
local _, OCS = ...
local TaskCraft = OCS.Tasks:Add("Craft")

function TaskCraft:OnInitialize()
  self.source = OCS:GetModule("Source", "Crafting")
end

function TaskCraft:Create(skillString, skillCrafts, craftChars)
  local recipeList = {}
  local itemsRequired = {}
  local itemsProduced = {}
  for skillId, skillCount in pairs(skillCrafts) do
    -- Find recipe
    local recipeData = nil
    for i, charName in ipairs(craftChars) do
      recipeData = self.source:GetRecipeDataById(skillString, skillId, charName)
      if recipeData then
        break
      end
    end
    if not recipeData then
      return nil
    end
    -- Get items required
    for reagentId, reagentCount in pairs(recipeData.reagents) do
      if itemsRequired[reagentId] then
        itemsRequired[reagentId] = itemsRequired[reagentId] + reagentCount * skillCount
      else
        itemsRequired[reagentId] = reagentCount * skillCount
      end
    end
    -- Get items produced
    local _, itemId = OCS.Utils:ParseItemLink(recipeData.itemLink)
    if itemId then
      if itemsProduced[itemId] then
        itemsProduced[itemId] = itemsProduced[itemId] + skillCount * (recipeData.itemCount or 1)
      else
        itemsProduced[itemId] = skillCount * (recipeData.itemCount or 1)
      end
    end
  end
  local task = self:CreateBase(craftChars, false, itemsRequired, itemsProduced)
  task.skillString = skillString
  task.skillCrafts = skillCrafts
  return task
end

function TaskCraft:CreateTaskFrame(taskData, taskLevel)
  local taskFrame = OCS.TaskBase.CreateTaskFrame(self, taskData, taskLevel)
  taskFrame:SetLayout("Flow")
  for skillId, skillCount in pairs(taskData.skillCrafts) do
    local recipeData = self.source:GetRecipeDataById(taskData.skillString, skillId)
    local craftRow = OCS.GUI:CreateWidget("SimpleGroup")
    craftRow:SetFullWidth(true)
    craftRow:SetLayout("Flow")
    local craftIcon = OCS.GUI:CreateWidget("Label")
    if recipeData.skillIcon then
      craftIcon:SetImage(recipeData.skillIcon)
    elseif recipeData.itemLink then
      local itemIcon = GetItemIcon(recipeData.itemLink)
      if itemIcon then
        craftIcon:SetImage(recipeData.skillIcon)
      end
    end
    craftIcon:SetImageSize(18, 18)
    craftIcon:SetHeight(20)
    craftIcon:SetWidth(20)
    local craftLabel = OCS.GUI:CreateWidget("Label")
    local craftText = "???"
    if recipeData.itemLink then
      local itemName = GetItemInfo(recipeData.itemLink)
      if itemName then
        craftText = itemName
      else
        -- Item data not available, queue update
        OCS.Tasks:UpdateLazy()
      end
    else
      local skillName = GetSpellInfo(recipeData.skillLink)
      if skillName then
        craftText = skillName
      else
        -- Spell data not available, queue update
        OCS.Tasks:UpdateLazy()
      end
    end
    craftLabel:SetText(skillCount.."x "..craftText)
    craftRow:AddChild(craftIcon)
    craftRow:AddChild(craftLabel)
    taskFrame:AddChild(craftRow)
  end
  return taskFrame
end

function TaskCraft:CanMerge(taskA, taskB)
  if (taskA.moduleName ~= self.moduleName) or (taskA.moduleName ~= self.moduleName) then
    -- Tasks are not both crafted, can't merge!
    return false
  end
  if not OCS.Utils:ArraysEqual(taskA.characters, taskB.characters) then
    -- Selected characters do not match, can't merge!
    return false
  end
  if taskA.skillString ~= taskB.skillString then
    -- Selected professions do not match, can't merge!
    return false
  end
  return true
end

function TaskCraft:MergeTasks(taskA, taskB)
  if not self:CanMerge(taskA, taskB) then
    return nil
  end
  local craftsMerged = {}
  for skillId, skillCount in pairs(taskA.skillCrafts) do
    if craftsMerged[skillId] then
      craftsMerged[skillId] = craftsMerged[skillId] + skillCount
    else
      craftsMerged[skillId] = skillCount
    end
  end
  for skillId, skillCount in pairs(taskB.skillCrafts) do
    if craftsMerged[skillId] then
      craftsMerged[skillId] = craftsMerged[skillId] + skillCount
    else
      craftsMerged[skillId] = skillCount
    end
  end
  return OCS.Tasks:Create("Craft", taskA.skillString, craftsMerged, taskA.characters)
end
