-- Inventory framework
local _, OCS = ...

OCS.DebugBase = OCS.ModuleBase:Inherit()

function OCS.DebugBase:New(name, module)
  -- Parent class
  module = OCS.ModuleBase:New("Debug", name, module)
  -- Inheritance
  setmetatable(module, self)
  self.__index = self
  return module
end

function OCS.DebugBase:Log(message, moduleName, level, payload)
  -- Do nothing by default
end
