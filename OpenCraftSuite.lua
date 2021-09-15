-- Central lua file
local addonName, OCS = ...
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

OCS.ADDON_NAME = addonName
OCS.ADDON_VERSION = GetAddOnMetadata(addonName, "Version")
OCS.AceAddon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceComm-3.0", "AceConsole-3.0", "AceEvent-3.0")
OCS.AceMessageCallback = function(message, ...)
  OCS.Events:OnMessage(message, ...)
end

function OCS.AceAddon:OnInitialize()
  local modules = OCS:GetModulesAll()
  for modType in pairs(modules) do
    for modName in pairs(modules[modType]) do
      local module = modules[modType][modName]
      module:OnInitialize()
    end
  end
  AceConfig:RegisterOptionsTable(addonName, self:GetAceOptions(), self:GetAceOptionsSlash())
  OCS.ConfigFrame = AceConfigDialog:AddToBlizOptions(addonName, OCS.L["OCS"])
  OCS.Debug:Log("OpenCraftSuite initialized.", "Core", "debug")
  OCS.Events:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    -- Startup tasks etc.
    OCS.Tasks:ReadTasks()
  end)
end

function OCS.AceAddon:GetAceOptionsSlash()
  return { "ocs" }
end

function OCS.AceAddon:GetAceOptions()
  local options = {
    name = OCS.L["OCS"],
    handler = OCS.AceAddon,
    type = 'group',
    args = {}
  };
  local modules = OCS:GetModulesAll()
  for modType in pairs(modules) do
    local modTypeOptions = {
      name = OCS.L["MODULE_TYPE_"..strupper(modType)],
      type = "group",
      args = {}
    }
    local modTypeOptionsPresent = false
    for modName in pairs(modules[modType]) do
      local module = modules[modType][modName]
      local modOptions = module:GetAceOptions()
      if modOptions then
        modTypeOptions.args[module.moduleName] = {
          name = module.moduleName,
          type = "group",
          args = modOptions
        }
        modTypeOptionsPresent = true
      end
    end
    if modTypeOptionsPresent then
      options.args[modType] = modTypeOptions
    end
  end
  return options
end
