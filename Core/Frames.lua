-- Source framework
local _, OCS = ...

OCS.Frames = {}

function OCS.Frames:Add(name, module)
  return OCS.FrameBase:New(name, module)
end

function OCS.Frames:Get(name)
  return OCS:GetModule("Frame", name)
end

function OCS.Frames:Show(name)
  local frame = self:Get(name)
  if frame then
    frame:Create()
    frame:Show()
  end
  return frame
end

function OCS.Frames:Hide(name)
  local frame = self:Get(name)
  if frame then
    frame:Hide()
  end
  return frame
end
