-- WoW auctionhouse source
local _, OCS = ...
local TaskListFrame = OCS.Frames:Add("TaskList")

function TaskListFrame:OnInitialize()
  self.title = OCS.L["MODULE_TASK_LIST"]
  self.name = "OCS_TaskListFrame"
  self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnPlayerRegenDisabled")
  self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnPlayerRegenEnabled")
  self:RegisterMessage("OCS_TASK_LIST_UPDATE", "OnTaskListUpdate")
  self:RegisterMessage("OCS_TASK_FRAME_ENTER", "OnTaskFrameEnter")
  self:RegisterMessage("OCS_TASK_FRAME_LEAVE", "OnTaskFrameLeave")
end

function TaskListFrame:Create(name, title)
  local widget, created = OCS.FrameBase.Create(self, name, title)
  if created then
    self.frame:SetFrameStrata("MEDIUM")
    widget:SetCallback("OnClose", function()
      -- Nothing yet
    end)
    widget:SetLayout("List")
    self:SaveLocation()
  end
end

function TaskListFrame:CreateContents()
  if not self.hoverText then
    self.hoverText = self.widget.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallRight")
    self.hoverText:SetText("|cffff8080"..OCS.L["MODULE_TASK_LIST_HOVER_DESC"].."|r")
    self.hoverText:Hide()
  end
  self.widget:ReleaseChildren()
  -- Add tasks
  local taskList, taskById = OCS.Tasks:GetTasks()
  local taskGroup = nil
  local taskParents = {}
  for i, taskData in ipairs(taskList) do
    while #(taskParents) > 0 and not tContains(taskData.parents, taskParents[1]) do
      tremove(taskParents, 1)
    end
    local taskLevel = #(taskParents)
    local taskWidget = self:CreateTaskFrame(taskData, taskLevel)
    if taskLevel > 0 then
      if not taskGroup then
        taskGroup = OCS.GUI:CreatePaddedGroup("SimpleGroup", 16, 0, 0, 0)
        taskGroup:SetLayout("List")
        taskGroup:SetFullWidth(true)
      end
      taskGroup:AddChild(taskWidget)
    else
      if taskGroup then
        self.widget:AddChild(taskGroup)
        taskGroup = nil
      end
      self.widget:AddChild(taskWidget)
    end
    tinsert(taskParents, 1, taskData.id)
  end
  if taskGroup then
    self.widget:AddChild(taskGroup)
    taskGroup = nil
  end
  -- Hover text
  self.hoverLabel = OCS.GUI:CreateWidget("Label")
  self.widget:AddChild(self.hoverLabel)
end

function TaskListFrame:CreateTaskFrame(taskData, taskLevel)
  return OCS.Tasks:CreateTaskFrame(taskData, taskLevel)
end

function TaskListFrame:OnTaskListUpdate()
  if OCS.Tasks:HasTasks() then
    self:Create()
    self:Show()
  else
    self:Hide()
  end
end

function TaskListFrame:OnTaskFrameEnter(_, taskWidget, taskData)
  if self.hoverText then
    self.hoverText:SetParent(taskWidget.content)
    self.hoverText:ClearAllPoints()
    self.hoverText:SetPoint("BOTTOMLEFT", taskWidget.content, "BOTTOMLEFT", 0, -10)
    self.hoverText:SetPoint("BOTTOMRIGHT", taskWidget.content, "BOTTOMRIGHT", 0, -10)
    self.hoverText:Show()
  end
end

function TaskListFrame:OnTaskFrameLeave(_, taskWidget, taskData)
  taskWidget.TaskListHighlight:Hide()
  if self.hoverText then
    self.hoverText:SetParent(self.widget.content)
    self.hoverText:ClearAllPoints()
    self.hoverText:Hide()
  end
end

function TaskListFrame:OnPlayerRegenDisabled()
  self:Hide()
end

function TaskListFrame:OnPlayerRegenEnabled()
  if OCS.Tasks:HasTasks() then
    self:Create()
    self:Show()
  else
    self:Hide()
  end
end
