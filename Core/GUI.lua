-- Source framework
local _, OCS = ...
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
local guiFrames = {}

OCS.GUI = {}

function OCS.GUI:CreateFrame(name, widgetType)
  widgetType = widgetType or "Frame"
  guiFrames[name] = AceGUI:Create(widgetType)
  OCS.Events:SendMessage("OCS_GUI_CREATE_FRAME", guiFrames[name], widgetType)
  return guiFrames[name]
end

function OCS.GUI:CreateWidget(widgetType)
  widgetType = widgetType or "Button"
  local widget = AceGUI:Create(widgetType)
  OCS.Events:SendMessage("OCS_GUI_CREATE_WIDGET", widget, widgetType)
  return widget
end

function OCS.GUI:CreatePaddedGroup(widgetType, padLeft, padTop, padRight, padBottom)
  if padRight == nil then
    padRight = padLeft
  end
  if padBottom == nil then
    padBottom = padTop
  end
  local group = self:CreateWidget(widgetType or "SimpleGroup")
  group.content:ClearAllPoints()
	group.content:SetPoint("TOPLEFT", padLeft or 0, padTop or 0)
	group.content:SetPoint("BOTTOMRIGHT", padRight or 0, padBottom or 0)
  -- Reset on release
  OCS.GUI:HookAceRelease(group, function(self, ...)
    self.content:ClearAllPoints()
  	self.content:SetPoint("TOPLEFT")
  	self.content:SetPoint("BOTTOMRIGHT")
  end)
  return group
end

-- Hook the ACE GUI release function securely
function OCS.GUI:HookAceRelease(widget, callback)
  local orgCallback = widget.Release
  widget.Release = function(self, ...)
    callback(self, ...)
    self.Release = orgCallback
    if self.Release then
      self:Release(...)
    end
  end
  return widget
end

-- Auto size the parent frame of an ACE widget depending on the content
function OCS.GUI:HookAceAutosize(widget, callback)
  local orgCallback = widget.Release
  widget.Release = function(self, ...)
    callback(self, ...)
    self.Release = orgCallback
    if self.Release then
      self:Release(...)
    end
  end
  return widget
end

function OCS.GUI:GetAceBackdrop(widget)
  if widget.frame.SetBackdrop then
    return widget.frame, false
  end
  local children = { widget.frame:GetChildren() }
  for i, childFrame in ipairs(children) do
    if childFrame.SetBackdrop then
      return childFrame, true
    end
  end
  return nil
end

function OCS.GUI:GetFrame(name)
  return guiFrames[name]
end

function OCS.GUI:ShowFrame(name)
  if guiFrames[name] then
    guiFrames[name]:Show()
  end
end

function OCS.GUI:HideFrame(name)
  if guiFrames[name] then
    guiFrames[name]:Hide()
  end
end
