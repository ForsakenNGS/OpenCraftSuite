-- WoW auctionhouse source
local _, OCS = ...
local TaskRelog = OCS.Tasks:Add("Relog")
local logoutButtonsFree = {}

function TaskRelog:Create(charTo, charFrom)
  if not charFrom then
    charFrom = UnitName("player")
  end
  local taskData = self:CreateBase({ charFrom }, true, nil, nil)
  taskData.targetChar = charTo
  return taskData
end

function TaskRelog:OnInitialize()
  self.isReady = true
end

function TaskRelog:CreateTaskFrame(taskData, taskLevel)
  local taskFrame = OCS.TaskBase.CreateTaskFrame(self, taskData, taskLevel)
  taskFrame:SetLayout("List")
  local itemLabel = OCS.GUI:CreateWidget("Label")
  itemLabel:SetText(OCS.L["MODULE_TASK_RELOG_DESCRIPTION"])
  taskFrame:AddChild(itemLabel)
  local btnLogout = self:CreateLogoutButton()
  btnLogout:SetScript("OnEnter", function() taskFrame:Fire("OnEnter") end)
  btnLogout:SetScript("OnLeave", function() taskFrame:Fire("OnLeave") end)
  btnLogout:SetParent(taskFrame.frame)
  btnLogout:SetAllPoints(taskFrame.frame)
  btnLogout:Show()
  -- Release button when frame is released
  OCS.GUI:HookAceRelease(taskFrame, function()
    self:ReleaseLogoutButton(btnLogout)
  end)
  -- Initial update
  self:OnTaskFrameUpdate(taskFrame, taskData)
  return taskFrame
end

function TaskRelog:ReleaseLogoutButton(button)
  button:ClearAllPoints()
  button:SetParent(nil)
  tinsert(logoutButtonsFree, button)
end

function TaskRelog:CreateLogoutButton()
  if #(logoutButtonsFree) > 0 then
    -- Recycle existing button
    return tremove(logoutButtonsFree, 1)
  else
    local button = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", "/logout")
    return button
  end
end

-- Get a descriptive name for the task
function TaskRelog:GetTitle(taskData)
  local title = OCS.L["MODULE_TASK_RELOG_TITLE"]
  if taskData.characterChosen then
    title = title..": "..OCS.Utils:FormatCharacterName(taskData.characterChosen)
  end
  if taskData.targetChar then
    title = title.." -> "..OCS.Utils:FormatCharacterName(taskData.targetChar)
  end
  return title
end

function TaskRelog:OnTaskFrameClick(taskWidget, taskData, button, ...)
  Logout()
end
