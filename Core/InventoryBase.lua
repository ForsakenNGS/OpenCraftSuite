-- Inventory framework
local _, OCS = ...
local itemUnlockCallbacks = {}

OCS.InventoryBase = OCS.ModuleBase:Inherit()

function OCS.InventoryBase:New(name, module)
  -- Parent class
  module = OCS.ModuleBase:New("Inventory", name, module)
  -- Private variables
  module.itemsOnHand = {}
  module.itemsObtainable = {}
  module.itemsCombined = {}
  module.itemsGuilds = {}
  -- Inheritance
  setmetatable(module, self)
  self.__index = self
  return module
end

function OCS.InventoryBase:CreateItemUnlockCallback(callback, slots)
  local callbackData = { callback = callback, slots = slots }
  if self:CheckItemUnlockCallback(callbackData) then
    callbackData.callback()
  else
    tinsert(itemUnlockCallbacks, callbackData)
  end
  return callbackData
end

function OCS.InventoryBase:CheckItemUnlockCallback(callbackData)
  local done = true
  for i, slotData in pairs(callbackData.slots) do
    local _, _, locked = GetContainerItemInfo(slotData.bag, slotData.slot);
    done = done and not locked
  end
  return done
end

function OCS.InventoryBase:OnInitialize()
  self:LoadFromStorage()
  self:RegisterEvent("ITEM_UNLOCKED", "OnItemUnlocked")
end

function OCS.InventoryBase:OnItemUnlocked(_, bagId, slotId)
  local callbackCount = #(itemUnlockCallbacks)
  if callbackCount > 0 then
    for i = callbackCount, 1, -1 do
      local callbackData = itemUnlockCallbacks[i]
      if self:CheckItemUnlockCallback(callbackData) then
        -- All locks cleared! Invoke callback and remove from list
        tremove(itemUnlockCallbacks, i)
        callbackData.callback()
      end
    end
  end
end

function OCS.InventoryBase:GetCharacters()
  return self:GetCharactersStored()
end

function OCS.InventoryBase:GetGuilds()
  local result = {}
  for guildName, guildStorage in pairs(self.itemsGuilds) do
    tinsert(result, guildName)
  end
  return result
end

function OCS.InventoryBase:GetItemsObtainable(itemId)
  if itemId then
    return self.itemsObtainable[itemId] or 0
  else
    return self.itemsObtainable
  end
end

function OCS.InventoryBase:GetItemsSendable(itemsProvided, target, source, ...)
  return {}
end

function OCS.InventoryBase:GetItemsOverall(itemId)
  local result = 0
  local charStorage = self:GetCharacterStorage()
  for charName, charData in pairs(charStorage) do
    if charData and charData.itemsCombined[itemId] then
      result = result + charData.itemsCombined[itemId]
    end
  end
  return result
end

function OCS.InventoryBase:GetItemsOnHand(itemId)
  if itemId then
    return self.itemsOnHand[itemId] or 0
  else
    return self.itemsOnHand
  end
end

function OCS.InventoryBase:GetItemsCombined(itemId)
  if itemId then
    return self.itemsCombined[itemId] or 0
  else
    return self.itemsCombined
  end
end

function OCS.InventoryBase:GetItemsOnGuild(itemId, guildName)
  if not self.itemsGuilds[guildName] then
    if itemId then
      return 0
    else
      return {}
    end
  end
  if itemId then
    return self.itemsGuilds[guildName].itemCounts[itemId] or 0
  else
    return self.itemsGuilds[guildName].itemCounts or {}
  end
end

function OCS.InventoryBase:GetItemsOnCharacter(itemId, charName)
  local playerName = GetUnitName("player")
  local charData = self:GetCharacterStorage(charName)
  if charData then
    if itemId then
      if charData.itemsCombined and charData.itemsCombined[itemId] then
        return charData.itemsCombined[itemId]
      end
    elseif charData.itemsCombined then
      return charData.itemsCombined
    end
  end
  if itemId then
    return 0
  else
    return {}
  end
end

function OCS.InventoryBase:GetItemsPerCharacter(itemId)
  local result = {}
  local charStorage = self:GetCharacterStorage()
  for charName, charData in pairs(charStorage) do
    if itemId then
      if charData.itemsCombined and charData.itemsCombined[itemId] then
        result[charName] = charData.itemsCombined[itemId]
      else
        result[charName] = 0
      end
    elseif charData.itemsCombined then
      for itemId, itemCount in pairs(charData.itemsCombined) do
        if not result[charName] then
          result[charName] = {}
        end
        result[charName][itemId] = itemCount
      end
    end
  end
  return result
end

function OCS.InventoryBase:ObtainItems(itemsRequired)
  -- TODO: Create task(s) to obtain the given items
  return {}
end

function OCS.InventoryBase:SendItems(itemsProvided, target, source, ...)
  -- TODO: Create task(s) to send the given items
  return {}
end

function OCS.InventoryBase:LoadFromStorage()
  local charData, guildData = self:ReadFromStorage()
  self.itemsOnHand = charData.itemsOnHand or self.itemsOnHand
  self.itemsObtainable = charData.itemsObtainable or self.itemsOnHand
  self.itemsCombined = charData.itemsCombined or self.itemsOnHand
  self.itemsGuilds = guildData or self.itemsGuilds
  return charData, guildData
end

function OCS.InventoryBase:ReadFromStorage()
  local playerName = GetUnitName("player")
  return self:GetCharacterStorage(playerName), self:GetGuildStorage()
end

function OCS.InventoryBase:WriteToStorage()
  local playerName = GetUnitName("player")
  local playerData = self:GetCharacterStorage(playerName)
  playerData.itemsObtainable = self.itemsObtainable
  playerData.itemsOnHand = self.itemsOnHand
  playerData.itemsCombined = self.itemsCombined
  -- Write guild data
  self:SetGuildStorage(self.itemsGuilds)
  -- Return for easy chaining
  return playerData, self.itemsGuilds
end

function OCS.InventoryBase:UpdateItemsOnHand()
  self.itemsOnHand = {}
  -- TODO: Add items on hand
end

function OCS.InventoryBase:UpdateItemsObtainable()
  self.itemsObtainable = {}
  -- TODO: Add items obtainable
end

function OCS.InventoryBase:UpdateItemsGuilds()
  self.itemsGuilds = {}
  -- TODO: Add items obtainable
end

function OCS.InventoryBase:UpdateItemCounts()
  self:UpdateItemsOnHand()
  self:UpdateItemsObtainable()
  self:UpdateItemsGuilds()
  self.itemsCombined = {}
  for itemId, itemCount in pairs(self.itemsOnHand) do
    if not self.itemsCombined[itemId] then
      self.itemsCombined[itemId] = itemCount
    else
      self.itemsCombined[itemId] = self.itemsCombined[itemId] + itemCount
    end
  end
  for itemId, itemCount in pairs(self.itemsObtainable) do
    if not self.itemsCombined[itemId] then
      self.itemsCombined[itemId] = itemCount
    else
      self.itemsCombined[itemId] = self.itemsCombined[itemId] + itemCount
    end
  end
  self:WriteToStorage()
  OCS.Tasks:UpdateLazy()
end

function OCS.InventoryBase:UpdateLazy(timeout)
  OCS.Utils:LazyUpdate("Inventory_"..self.moduleName.."_UpdateLazy", function()
    self:UpdateItemCounts()
  end, timeout)
end
