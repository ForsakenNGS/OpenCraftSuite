-- Debugging framework
local _, OCS = ...
local modules = {}

OCS.ModuleBase = {};

function OCS:GetModulesAll()
  return modules
end

function OCS:GetModulesByType(type)
  return modules[type] or {}
end

function OCS:IsModulePresent(type, name)
  if modules[type] and modules[type][name] then
    return true
  end
  return false
end

function OCS:GetModule(type, name)
  if modules[type] and modules[type][name] then
    return modules[type][name]
  end
  return nil
end

function OCS:GetModuleAbbr(type, name)
  if modules[type] and modules[type][name] then
    return modules[type][name].moduleNameAbbr or name
  end
  return name
end

function OCS.ModuleBase:Inherit(module)
  -- Inheritance
  module = module or {}
  setmetatable(module, self)
  self.__index = self
  return module
end

function OCS.ModuleBase:New(type, name, module)
  module = self:Inherit(module)
  -- Private variables
  module.moduleType = type
  module.moduleName = name
  module.moduleNameAbbr = module.moduleNameAbbr or name
  module.eventCallbacks = {}
  module.messageCallbacks = {}
  module.configIdent = module.configIdent or type.."_"..name
  module.storageIdent = module.storageIdent or type.."_"..name
  module.logPrefix = module.logPrefix or type.."/"..name
  -- Register module
  if not modules[type] then
    modules[type] = {}
  end
  if not modules[type][name] then
    modules[type][name] = module
  else
    -- TODO: Error / Warning for duplicate module? Replace existing module?
  end
  -- Return
  return module
end

function OCS.ModuleBase:OnInitialize()
  -- Nothing by default
end

function OCS.ModuleBase:GetAceOptions()
  return nil
end

-- Get priority for the module
function OCS.ModuleBase:GetPriority()
  return 10
end

function OCS.ModuleBase:GetName()
  return self.moduleName
end

function OCS.ModuleBase:Log(message, level, payload)
  OCS.Debug:Log(message, self.logPrefix, level, payload)
end

function OCS.ModuleBase:RegisterMessage(message, callbackName)
  if not self.messageCallbacks[message] then
    self.messageCallbacks[message] = {}
  end
  if not self.messageCallbacks[message][callbackName] then
    self.messageCallbacks[message][callbackName] = function(...)
      xpcall(self[callbackName], CallErrorHandler, self, ...)
    end
    OCS.Events:RegisterMessage(message, self.messageCallbacks[message][callbackName])
  end
end

function OCS.ModuleBase:UnregisterMessage(message, callbackName)
  if self.messageCallbacks[event] then
    if not callbackName then
      -- Remove all callbacks
      for callbackName in pairs(self.messageCallbacks[event]) do
        OCS.Events:UnregisterMessage(event, self.messageCallbacks[event][callbackName])
      end
      self.messageCallbacks[event] = nil
    else
      -- Remove specific callback
      if self.messageCallbacks[event][callbackName] then
        OCS.Events:UnregisterMessage(event, self.messageCallbacks[event][callbackName])
      end
    end
  end
end

function OCS.ModuleBase:SendMessage(message, ...)
  OCS.Events:SendMessage(message, ...)
end

function OCS.ModuleBase:RegisterEvent(event, callbackName)
  if not self.eventCallbacks[event] then
    self.eventCallbacks[event] = {}
  end
  if not self.eventCallbacks[event][callbackName] then
    self.eventCallbacks[event][callbackName] = function(...)
      if self[callbackName] then
        xpcall(self[callbackName], CallErrorHandler, self, ...)
      else
        self:Log("Callback '"..callbackName.."' not found for event '"..event.."' (Module "..self.moduleName..")", "error")
      end
    end
    OCS.Events:RegisterEvent(event, self.eventCallbacks[event][callbackName])
  end
end

function OCS.ModuleBase:UnregisterEvent(event, callbackName)
  if self.eventCallbacks[event] then
    if not callbackName then
      -- Remove all callbacks
      for callbackName in pairs(self.eventCallbacks[event]) do
        OCS.Events:UnregisterEvent(event, self.eventCallbacks[event][callbackName])
      end
      self.eventCallbacks[event] = nil
    else
      -- Remove specific callback
      if self.eventCallbacks[event][callbackName] then
        OCS.Events:UnregisterEvent(event, self.eventCallbacks[event][callbackName])
      end
    end
  end
end

function OCS.ModuleBase:SetStorageValue(name, value)
  if not OpenCraftSuiteDB then
    OpenCraftSuiteDB = {}
  end
  if not OpenCraftSuiteDB["modules"] then
    OpenCraftSuiteDB["modules"] = {}
  end
  if not OpenCraftSuiteDB["modules"][self.storageIdent] then
    OpenCraftSuiteDB["modules"][self.storageIdent] = {}
  end
  OpenCraftSuiteDB["modules"][self.storageIdent][name] = value
end

function OCS.ModuleBase:GetStorageValue(name, default)
  if not OpenCraftSuiteDB then
    OpenCraftSuiteDB = {}
  end
  if not OpenCraftSuiteDB["modules"] then
    OpenCraftSuiteDB["modules"] = {}
  end
  if not OpenCraftSuiteDB["modules"][self.storageIdent] then
    OpenCraftSuiteDB["modules"][self.storageIdent] = {}
  end
  if OpenCraftSuiteDB["modules"][self.storageIdent][name] == nil then
    OpenCraftSuiteDB["modules"][self.storageIdent][name] = default
  end
  return OpenCraftSuiteDB["modules"][self.storageIdent][name]
end

function OCS.ModuleBase:GetRealmFactionStorage(suffix)
  local realm = GetRealmName()
  local faction = UnitFactionGroup("player")
  if suffix then
    suffix = " - "..suffix
  else
    suffix = ""
  end
  return self:GetStorageValue(realm.." - "..faction..suffix, {})
end

function OCS.ModuleBase:GetCharactersStored()
  local result = {}
  if not realmFactionStorage.charStorage then
    for charName, charStorage in pairs(realmFactionStorage.charStorage) do
      tinsert(result, charName)
    end
  end
  return result
end

function OCS.ModuleBase:GetCharacterStorage(charName, suffix, default)
  local realmFactionStorage = self:GetRealmFactionStorage(suffix)
  if not realmFactionStorage.charStorage then
    realmFactionStorage.charStorage = {}
  end
  if charName then
    if not realmFactionStorage.charStorage[charName] then
      realmFactionStorage.charStorage[charName] = default or {}
    end
    return realmFactionStorage.charStorage[charName]
  else
    return realmFactionStorage.charStorage
  end
end

function OCS.ModuleBase:SetCharacterStorage(characterData, charName, suffix)
  local realmFactionStorage = self:GetRealmFactionStorage(suffix)
  if charName then
    realmFactionStorage.charStorage[charName] = characterData
  else
    realmFactionStorage.charStorage = characterData
  end
end

function OCS.ModuleBase:GetGuildStorage(guildName, suffix)
  local realmFactionStorage = self:GetRealmFactionStorage(suffix)
  if not realmFactionStorage.guildStorage then
    realmFactionStorage.guildStorage = {}
  end
  if guildName then
    if not realmFactionStorage.guildStorage[guildName] then
      realmFactionStorage.guildStorage[guildName] = {}
    end
    return realmFactionStorage.guildStorage[guildName]
  else
    return realmFactionStorage.guildStorage
  end
end

function OCS.ModuleBase:SetGuildStorage(guildData, suffix)
  local realmFactionStorage = self:GetRealmFactionStorage(suffix)
  realmFactionStorage.guildStorage = guildData
end
