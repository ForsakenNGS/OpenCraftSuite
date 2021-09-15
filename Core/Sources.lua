-- Source framework
local _, OCS = ...

OCS.Sources = {}

function OCS.Sources:Add(name, module)
  return OCS.SourceBase:New(name, module)
end

function OCS.Sources:GetPrice(itemId, quantity, ...)
  local result = {}
  local sourceModules = OCS:GetModulesByType("Source")
  for name in pairs(sourceModules) do
    local itemTypes = sourceModules[name]:GetPriceTypes()
    result[name] = {}
    for i in ipairs(itemTypes) do
      local itemType = itemTypes[i]
      result[name][itemType] = sourceModules[name]:GetPrice(itemId, itemType, quantity, ...)
    end
  end
  return result
end

function OCS.Sources:GetPriceMin(itemId, quantity, ...)
  local result = nil
  local sourceModules = OCS:GetModulesByType("Source")
  for name in pairs(sourceModules) do
    local itemTypes = sourceModules[name]:GetPriceTypes()
    for i in ipairs(itemTypes) do
      local itemPrice = sourceModules[name]:GetPrice(itemId, itemTypes[i], quantity, ...)
      if result == nil or itemPrice < result then
        result = itemPrice
      end
    end
  end
  return result
end

function OCS.Sources:GetPriceMax(itemId, quantity, ...)
  local result = nil
  local sourceModules = OCS:GetModulesByType("Source")
  for name in pairs(sourceModules) do
    local itemTypes = sourceModules[name]:GetPriceTypes()
    for i in ipairs(itemTypes) do
      local itemPrice = sourceModules[name]:GetPrice(itemId, itemTypes[i], quantity, ...)
      if result == nil or itemPrice > result then
        result = itemPrice
      end
    end
  end
  return result
end

function OCS.Sources:GetVendorPrice(itemId, quantity, ...)
  local sourceModules = OCS:GetModulesByType("Source")
  for name in pairs(sourceModules) do
    local vendorPrice = sourceModules[name]:GetVendorPrice(itemId, quantity or 1, ...)
    if vendorPrice then
      return vendorPrice
    end
  end
  return nil
end

function OCS.Sources:BuyItems(itemsRequired, modulePriority)
  local sourceModules = OCS:GetModulesByType("Source")
  if not modulePriority then
    modulePriority = {}
    for modName in pairs(sourceModules) do
      tinsert(modulePriority, modName)
    end
  end
  -- Group by module
  itemsRequired = OCS.Utils:CloneTable(itemsRequired) -- Prevent manipulation of input table
  local buyByModule = {}
  for _, modName in ipairs(modulePriority) do
    local module = sourceModules[modName]
    local itemsBuyable = module:GetItemsBuyable(itemsRequired)
    for itemId, itemCount in pairs(itemsRequired) do
      if itemsBuyable[itemId] then
        local countUsed = min(itemCount, itemsBuyable[itemId])
        itemsRequired[itemId] = itemCount - countUsed
        if not buyByModule[modName] then
          buyByModule[modName] = {}
        end
        if buyByModule[modName][itemId] then
          buyByModule[modName][itemId] = buyByModule[modName][itemId] + countUsed
        else
          buyByModule[modName][itemId] = countUsed
        end
      end
    end
  end
  -- Create tasks per module
  local buyTasks = {}
  for modName, modItems in pairs(buyByModule) do
    local module = sourceModules[modName]
    local modTasks = module:BuyItems(modItems)
    for _, modTask in ipairs(modTasks) do
      tinsert(buyTasks, modTask)
    end
  end
  return buyTasks
end
