-- Inventory framework
local _, OCS = ...

OCS.Inventory = {}

function OCS.Inventory:Add(name, module)
  return OCS.InventoryBase:New(name, module)
end

function OCS.Inventory:MergeItemCounts(adddedItems, existingItems)
  if not existingItems then
    existingItems = {}
  end
  return existingItems
end

function OCS.Inventory:GetItemsOverall(itemId)
  return self:GetItemsOnHand(itemId) + self:GetItemsObtainable(itemId)
end

function OCS.Inventory:GetItemsObtainable(itemId, ignoredModules)
  local inventoryModules = OCS:GetModulesByType("Inventory")
  if not itemId then
    -- All items on character
    local result = {}
    for name in pairs(inventoryModules) do
      if not ignoredModules or not tContains(ignoredModules, name) then
        local moduleItems = inventoryModules[name]:GetItemsObtainable()
        for itemId, itemCount in pairs(moduleItems) do
          if result[itemId] then
            result[itemId] = result[itemId] + itemCount
          else
            result[itemId] = itemCount
          end
        end
      end
    end
    return result
  else
    -- For specific item
    local result = 0
    for name in pairs(inventoryModules) do
      if not ignoredModules or not tContains(ignoredModules, name) then
        result = result + inventoryModules[name]:GetItemsObtainable(itemId)
      end
    end
    return result
  end
end

function OCS.Inventory:GetItemsOnHand(itemId, ignoredModules)
  local inventoryModules = OCS:GetModulesByType("Inventory")
  if not itemId then
    -- All items on character
    local result = {}
    for name in pairs(inventoryModules) do
      if not ignoredModules or not tContains(ignoredModules, name) then
        local moduleItems = inventoryModules[name]:GetItemsOnHand()
        for itemId, itemCount in pairs(moduleItems) do
          if result[itemId] then
            result[itemId] = result[itemId] + itemCount
          else
            result[itemId] = itemCount
          end
        end
      end
    end
    return result
  else
    -- For specific item
    local result = 0
    for name in pairs(inventoryModules) do
      if not ignoredModules or not tContains(ignoredModules, name) then
        result = result + inventoryModules[name]:GetItemsOnHand(itemId)
      end
    end
    return result
  end
end

function OCS.Inventory:GetFreeBagSlotSession(session, bagType)
  if not session then
    session = { slotsTaken = {}, slotOffsets = {} }
  end
  if bagType == nil then
    return session
  end
  if not session.slotOffsets[bagType] then
    session.slotOffsets[bagType] = {}
  end
  local slotOffsets = session.slotOffsets[bagType]
  while true do
    slotOffsets.bag, slotOffsets.slot = self:GetFreeBagSlot(slotOffsets.bag, slotOffsets.slot, bagType)
    if not slotOffsets.bag then
      -- No free slot found!
      return session
    elseif not session.slotsTaken[slotOffsets.bag] or not session.slotsTaken[slotOffsets.bag][slotOffsets.slot] then
      -- Mark slot as taken
      if not session.slotsTaken[slotOffsets.bag] then
        session.slotsTaken[slotOffsets.bag] = {}
      end
      session.slotsTaken[slotOffsets.bag][slotOffsets.slot] = true
      -- Return slot
      return session, slotOffsets.bag, slotOffsets.slot
    end
    -- Next free slot already taken, search ahead
  end
end

function OCS.Inventory:GetFreeBagSlot(offsetBag, offsetSlot, bagType)
  local bag = offsetBag or 0
  local slot = (offsetSlot or 0) + 1
  local bagType = bagType or 0
  while bag <= NUM_BAG_SLOTS do
    local bagContentMatch = true
    if bag > 0 then
      local invId = ContainerIDToInventoryID(bag)
      local bagItemId = GetInventoryItemID("player", invId)
      local bagContentType = GetItemFamily(bagItemId)
      bagContentMatch = (bagContentType == 0) or (bit.band(bagType, bagContentType) > 0)
    end
    local bagFree = GetContainerNumFreeSlots(bag)
    if bagFree > 0 and bagContentMatch then
      local bagSize = GetContainerNumSlots(bag)
      while slot <= bagSize do
        itemId = GetContainerItemID(bag, slot)
        -- TODO: Allow stacking items
        if itemId == nil then
          -- Found free slot
          return bag, slot
        end
        slot = slot + 1
      end
      -- End of bag reached!
      bag = bag + 1
    else
      bag = bag + 1
    end
  end
  return nil, nil
end

function OCS.Inventory:GetCharacters()
  local result = {}
  local inventoryModules = OCS:GetModulesByType("Inventory")
  for modName, module in pairs(inventoryModules) do
    for charName in ipairs(module:GetCharacters()) do
      if not tContains(result, charName) then
        tinsert(result, charName)
      end
    end
  end
  return result
end

function OCS.Inventory:GetGuilds()
  local result = {}
  local inventoryModules = OCS:GetModulesByType("Inventory")
  for modName, module in pairs(inventoryModules) do
    for _, guildName in ipairs(module:GetGuilds()) do
      if not tContains(result, guildName) then
        tinsert(result, guildName)
      end
    end
  end
  return result
end

function OCS.Inventory:GetItemsOnGuild(itemId, guildName, ignoredModules)
  local inventoryModules = OCS:GetModulesByType("Inventory")
  if not itemId then
    -- All items on character
    local result = {}
    for name in pairs(inventoryModules) do
      if not ignoredModules or not tContains(ignoredModules, name) then
        local moduleItems = inventoryModules[name]:GetItemsOnGuild(itemId, guildName)
        for itemId, itemCount in pairs(moduleItems) do
          if result[itemId] then
            result[itemId] = result[itemId] + itemCount
          else
            result[itemId] = itemCount
          end
        end
      end
    end
    return result
  else
    -- For specific item
    local result = 0
    for name in pairs(inventoryModules) do
      if not ignoredModules or not tContains(ignoredModules, name) then
        result = result + inventoryModules[name]:GetItemsOnGuild(itemId, guildName)
      end
    end
    return result
  end
end

function OCS.Inventory:GetItemsOnCharacter(itemId, characterName, ignoredModules)
  local inventoryModules = OCS:GetModulesByType("Inventory")
  if not itemId then
    -- All items on character
    local result = {}
    for name in pairs(inventoryModules) do
      if not ignoredModules or not tContains(ignoredModules, name) then
        local moduleItems = inventoryModules[name]:GetItemsOnCharacter(itemId, characterName)
        for itemId, itemCount in pairs(moduleItems) do
          if result[itemId] then
            result[itemId] = result[itemId] + itemCount
          else
            result[itemId] = itemCount
          end
        end
      end
    end
    return result
  else
    -- For specific item
    local result = 0
    for name in pairs(inventoryModules) do
      if not ignoredModules or not tContains(ignoredModules, name) then
        result = result + inventoryModules[name]:GetItemsOnCharacter(itemId, characterName)
      end
    end
    return result
  end
end

function OCS.Inventory:GetItemsPerCharacter(itemId, ignoredModules)
  local itemCountGlobal = 0
  local itemCountsOverall = {}
  local inventoryModules = OCS:GetModulesByType("Inventory")
  for name in pairs(inventoryModules) do
    if not ignoredModules or not tContains(ignoredModules, name) then
      local module = inventoryModules[name]
      local itemCounts = module:GetItemsPerCharacter(itemId)
      for characterName in pairs(itemCounts) do
        if not itemCountsOverall[characterName] then
          itemCountsOverall[characterName] = {}
        end
        itemCountsOverall[characterName][module.moduleName] = itemCounts[characterName]
        itemCountGlobal = itemCountGlobal + itemCounts[characterName]
      end
    end
  end
  return itemCountsOverall, itemCountGlobal
end

function OCS.Inventory:SendItems(itemsProvided, target, source, ...)
  local inventoryModules = OCS:GetModulesByType("Inventory")
  if not modulePriority then
    modulePriority = {}
    for modName in pairs(inventoryModules) do
      tinsert(modulePriority, modName)
    end
  end
  -- Clone available items counts into new table to not change the input table
  local itemsAvailable = {}
  for itemId, itemCount in pairs(itemsProvided) do
    itemsAvailable[itemId] = itemCount
  end
  -- Group by module
  itemsProvided = OCS.Utils:CloneTable(itemsProvided) -- Prevent manipulation of input table
  local sendByModule = {}
  for _, modName in ipairs(modulePriority) do
    local module = inventoryModules[modName]
    local itemsSendable = module:GetItemsSendable(itemsAvailable, target, source, ...)
    for itemId, itemCount in pairs(itemsAvailable) do
      if itemsSendable[itemId] then
        local countSend = min(itemCount, itemsSendable[itemId])
        itemsAvailable[itemId] = itemCount - countSend
        if not sendByModule[modName] then
          sendByModule[modName] = {}
        end
        if sendByModule[modName][itemId] then
          sendByModule[modName][itemId] = sendByModule[modName][itemId] + countSend
        else
          sendByModule[modName][itemId] = countSend
        end
      end
    end
  end
  -- Create tasks per module
  local sendTasks = {}
  for modName, modItems in pairs(sendByModule) do
    local module = inventoryModules[modName]
    local modTasks = module:SendItems(modItems, target, source, ...)
    for _, modTask in ipairs(modTasks) do
      tinsert(sendTasks, modTask)
    end
  end
  return sendTasks
end

function OCS.Inventory:ObtainItems(itemsRequired, modulePriority)
  local inventoryModules = OCS:GetModulesByType("Inventory")
  if not modulePriority then
    modulePriority = {}
    for modName in pairs(inventoryModules) do
      tinsert(modulePriority, modName)
    end
  end
  -- Group by module
  itemsRequired = OCS.Utils:CloneTable(itemsRequired) -- Prevent manipulation of input table
  local obtainByModule = {}
  for _, modName in ipairs(modulePriority) do
    local module = inventoryModules[modName]
    local itemsObtainable = module:GetItemsObtainable()
    for itemId, itemCount in pairs(itemsRequired) do
      if itemsObtainable[itemId] then
        local countUsed = min(itemCount, itemsObtainable[itemId])
        itemsRequired[itemId] = itemCount - countUsed
        if not obtainByModule[modName] then
          obtainByModule[modName] = {}
        end
        if obtainByModule[modName][itemId] then
          obtainByModule[modName][itemId] = obtainByModule[modName][itemId] + countUsed
        else
          obtainByModule[modName][itemId] = countUsed
        end
      end
    end
  end
  -- Create tasks per module
  local obtainTasks = {}
  for modName, modItems in pairs(obtainByModule) do
    local module = inventoryModules[modName]
    local modTasks = module:ObtainItems(modItems)
    for _, modTask in ipairs(modTasks) do
      tinsert(obtainTasks, modTask)
    end
  end
  return obtainTasks
end
