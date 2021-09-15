-- Debugging framework
local _, OCS = ...

OCS.Debug = {};

function OCS.Debug:Add(name, module)
  return OCS.DebugBase:New(name, module)
end

function OCS.Debug:GetLevelInt(levelString)
  if (levelString == "debug") then
    return 0
  elseif (levelString == "info") then
    return 1
  elseif (levelString == "warning") then
    return 2
  elseif (levelString == "error") then
    return 3
  end
  return 100
end

-- Log a debugging message with an optional payload
function OCS.Debug:Log(message, module, level, payload)
  if not module then
    module = "Unknown Module"
  end
  if not level then
    level = "info"
  end
  local debugModules = OCS:GetModulesByType("Debug")
  for name in pairs(debugModules) do
    debugModules[name]:Log(message, module, level, payload)
  end
end
