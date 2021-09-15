-- Inventory framework
local _, OCS = ...

OCS.FrameBase = OCS.ModuleBase:Inherit()

function OCS.FrameBase:New(name, module)
  -- Parent class
  module = OCS.ModuleBase:New("Frame", name, module)
  -- Inheritance
  setmetatable(module, self)
  self.__index = self
  return module
end

function OCS.FrameBase:Create(name, title)
  if self.widget then
    self:CreateContents()
    return self.widget, false
  end
  self.name = name or self.name
  self.title = title or self.title or ""
  self.widget = OCS.GUI:CreateFrame(self.name, self.widgetType or "Window")
  self.frame = self.widget.frame or nil
  self.widget:SetTitle(self.title)
  self:CreateContents()
  return self.widget, true
end

function OCS.FrameBase:CreateContents()
  -- TODO: Create your content widgets here
end

function OCS.FrameBase:SaveLocation()
  local playerName = GetUnitName("player")
  local frameStatus = self:GetCharacterStorage(playerName, "FrameStatus", self.widget.status or {})
  self.widget:SetStatusTable(frameStatus)
end

function OCS.FrameBase:Show()
  if self.widget then
    self.widget:Show()
  end
end

function OCS.FrameBase:Hide()
  if self.widget then
    self.widget:Hide()
  end
end
