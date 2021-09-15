-- Chat debugging output
local _, OCS = ...
local DebugChat = OCS.Debug:Add("Chat")
local debugEnabled = true

function DebugChat:Log(message, moduleName, level, payload)
  local levelInt = OCS.Debug:GetLevelInt(level)
  local levelMinInt = OCS.Debug:GetLevelInt( self:GetLogLevel() )
  if (levelInt < levelMinInt) then
    return
  end
  if (level == "debug") then
    level = "|cff8080ff<"..level..">|r"
  elseif (level == "info") then
    level = "|cff80ff80<"..level..">|r"
  elseif (level == "warning") then
    level = "|cffa0a080<"..level..">|r"
  elseif (level == "error") then
    level = "|cffff8080<"..level..">|r"
  end
  OCS.AceAddon:Print(level.." |cffffc000"..moduleName.."|r", message)
  if payload then
    OCS.AceAddon:Print(OCS.Utils:DumpVariable(payload, "", true))
  end
end

function DebugChat:GetLogLevel()
  return self:GetStorageValue("logLevel", "warning")
end

function DebugChat:SetLogLevel(level)
  self:SetStorageValue("logLevel", level)
end

function DebugChat:GetAceOptions()
  return {
    logLevel = {
      name = OCS.L["LOG_LEVEL_LABEL"],
      desc = OCS.L["LOG_LEVEL_DESCRIPTION"],
      type = "select",
      values = {
        ["debug"] = OCS.L["LOG_LEVEL_DEBUG"],
        ["info"] = OCS.L["LOG_LEVEL_INFO"],
        ["warning"] = OCS.L["LOG_LEVEL_WARNING"],
        ["error"] = OCS.L["LOG_LEVEL_ERROR"]
      },
      sorting = { "debug", "info", "warning", "error" },
      style = "dropdown",
      set = function(info, val) DebugChat:SetLogLevel(val) end,
      get = function(info) return DebugChat:GetLogLevel() end
    }
  }
end
