-- Inventory framework
local _, OCS = ...

OCS.TaskBase = OCS.ModuleBase:Inherit()

function OCS.TaskBase:New(name, module)
  -- Parent class
  module = OCS.ModuleBase:New("Task", name, module)
  module.isHovered = false
  module.isReady = false
  -- Inheritance
  module = module or {}
  setmetatable(module, self)
  self.__index = self
  return module
end

function OCS.TaskBase:CreateBase(characters, isDynamic, itemsRequired, itemsProduced)
  return {
    id = OCS.Tasks:CreateTaskId(), parents = {}, children = {},
    moduleName = self.moduleName,
    isDynamic = isDynamic,
    characters = characters or {},
    characterChosen = nil,
    itemsRequired = itemsRequired or {},
    itemsProduced = itemsProduced or {}
  }
end

-- Check whether this task is fixed or dynamically created
function OCS.TaskBase:CanMerge(taskA, taskB)
  return false
end

function OCS.TaskBase:MergeTasks(taskA, taskB)
  return nil
end

-- Check whether this task is fixed or dynamically created
function OCS.TaskBase:IsDynamicTask(taskData)
  return taskData.isDynamic or false
end

function OCS.TaskBase:CreateTaskFrame(taskData, taskLevel)
  -- interface/questframe/ui-questlogtitlehighlight.blp
  local taskFrame = OCS.GUI:CreateWidget("InlineGroup")
  taskFrame:SetTitle(OCS.Tasks:GetTitle(taskData))
  taskFrame:SetFullWidth(true)
  taskFrame.frame:EnableMouse(true)
  taskFrame.frame:SetScript("OnMouseUp", function(frame, ...) self:OnTaskFrameMouseUp(taskFrame, taskData, ...) end)
  taskFrame.frame:SetScript("OnEnter", function(frame) self:OnTaskFrameEnter(taskFrame, taskData) end)
  taskFrame.frame:SetScript("OnLeave", function(frame) self:OnTaskFrameLeave(taskFrame, taskData) end)
  taskFrame:SetCallback("OnEnter", function(widget)
    if widget.frame:GetScript("OnEnter") then widget.frame:GetScript("OnEnter")(widget.frame) end
  end)
  taskFrame:SetCallback("OnLeave", function(widget)
    if widget.frame:GetScript("OnLeave") then widget.frame:GetScript("OnLeave")(widget.frame) end
  end)
  -- Highlight texture
  if not taskFrame.TaskListHighlight then
    taskFrame.TaskListHighlight = taskFrame.frame:CreateTexture()
    -- Ensure highlight is hidden when widget is released
    OCS.GUI:HookAceRelease(taskFrame, function(self, ...)
      self.TaskListHighlight:Hide()
      self.TaskListHighlight:ClearAllPoints()
    end)
  end
  local backdrop = OCS.GUI:GetAceBackdrop(taskFrame)
  taskFrame.TaskListHighlight:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
  taskFrame.TaskListHighlight:SetVertexColor(1, 1, 1, 0.5)
  if backdrop then
    taskFrame.TaskListHighlight:SetAllPoints(backdrop)
  else
    taskFrame.TaskListHighlight:SetPoint("TOPLEFT")
    taskFrame.TaskListHighlight:SetPoint("BOTTOMRIGHT")
  end
  taskFrame.TaskListHighlight:Hide()
  return taskFrame
end

-- Get a descriptive name for the task
function OCS.TaskBase:GetTitle(taskData)
  local title = OCS.L["MODULE_TASK_"..strupper(taskData.moduleName).."_TITLE"]
  if taskData.characterChosen then
    title = title.." - "..OCS.Utils:FormatCharacterName(taskData.characterChosen)
  end
  return title
end

-- Sets whether this task is fixed or dynamically created
function OCS.TaskBase:SetDynamic(taskData, isDynamic)
  self.isDynamic = isDynamic
end

function OCS.TaskBase:UpdateTaskFrames()
  if OCS.Tasks:HasTasks() then
    local taskList, taskById = OCS.Tasks:GetTasks()
    for _, taskData in pairs(taskList) do
      if taskData.moduleName == self.moduleName then
        local taskFrame = OCS.Tasks:GetTaskFrame(taskData.id)
        if taskFrame then
          self:OnTaskFrameUpdate(taskFrame, taskData)
        end
      end
    end
  end
end

function OCS.TaskBase:OnTaskFrameClick(taskWidget, taskData, button, ...)
  OCS.Events:SendMessage("OCS_TASK_FRAME_CLICK", taskWidget, taskData, button, self, ...)
end

function OCS.TaskBase:OnTaskFrameMouseUp(taskWidget, taskData, button, ...)
  if button == "RightButton" then
    OCS.Tasks:RemoveTask(taskData.id)
  else
    self:OnTaskFrameClick(taskWidget, taskData, button, ...)
  end
end

function OCS.TaskBase:OnTaskFrameEnter(taskWidget, taskData)
  self.isHovered = true
  OCS.Events:SendMessage("OCS_TASK_FRAME_ENTER", taskWidget, taskData, self)
  self:OnTaskFrameUpdate(taskWidget, taskData)
end

function OCS.TaskBase:OnTaskFrameLeave(taskWidget, taskData)
  self.isHovered = false
  OCS.Events:SendMessage("OCS_TASK_FRAME_LEAVE", taskWidget, taskData, self)
  self:OnTaskFrameUpdate(taskWidget, taskData)
end

function OCS.TaskBase:OnTaskFrameUpdate(taskWidget, taskData)
  if self.isReady then
    taskWidget.TaskListHighlight:Show()
    if self.isHovered then
      taskWidget.TaskListHighlight:SetVertexColor(0, 1, 0, 0.7)
    else
      taskWidget.TaskListHighlight:SetVertexColor(0, 0.6, 0, 0.7)
    end
  else
    if self.isHovered then
      taskWidget.TaskListHighlight:Show()
      taskWidget.TaskListHighlight:SetVertexColor(1, 1, 1, 0.7)
    else
      taskWidget.TaskListHighlight:Hide()
    end
  end
  OCS.Events:SendMessage("OCS_TASK_FRAME_UPDATE", taskWidget, taskData, self)
end
