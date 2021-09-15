-- Source framework
local _, OCS = ...
local TipHooker = LibStub:GetLibrary("LibTipHooker-1.1")

OCS.Tooltip = {}

function OCS.Tooltip:HookTooltip()
  TipHooker:Hook(function(...)
    OCS.Tooltip:InjectTooltip("item", ...)
  end, "item")
  TipHooker:Hook(function(...)
    OCS.Tooltip:InjectTooltip("buff", ...)
  end, "buff")
  TipHooker:Hook(function(...)
    OCS.Tooltip:InjectTooltip("spell", ...)
  end, "spell")
  TipHooker:Hook(function(...)
    OCS.Tooltip:InjectTooltip("talant", ...)
  end, "talant")
  TipHooker:Hook(function(...)
    OCS.Tooltip:InjectTooltip("unit", ...)
  end, "unit")
  TipHooker:Hook(function(...)
    OCS.Tooltip:InjectTooltip("action", ...)
  end, "action")
end

function OCS.Tooltip:InjectTooltip(type, tooltip, ...)
  local modules = OCS:GetModulesAll()
  for moduleType in pairs(modules) do
    for moduleName in pairs(modules[moduleType]) do
      if modules[moduleType][moduleName].InjectTooltip then
        modules[moduleType][moduleName]:InjectTooltip(type, tooltip, ...)
      end
    end
  end
end

-- Inject default tooltip
OCS.Tooltip:HookTooltip()
