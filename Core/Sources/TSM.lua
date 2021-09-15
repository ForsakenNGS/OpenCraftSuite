-- TSM price sources
local _, OCS = ...
local SourceTsm = OCS.Sources:Add("TSM")
local TsmData = {}
local TsmRegion = {}
local TsmRealm = {}

function SourceTsm:GetPrice(itemId, type, quantity)
  if not type then
    type = "dbmarketvalue"
  end
  if not quantity then
    quantity = 1
  end
  if TsmRealm[itemId] then
    if (type == "dbmarketvalue") and (TsmRealm[itemId].marketValue) then
      return TsmRealm[itemId].marketValue * quantity
    elseif (type == "dbminbuyout") and (TsmRealm[itemId].minBuyout) then
      return TsmRealm[itemId].minBuyout * quantity
    else
      local customValue = TSM_API.GetCustomPriceValue(type, "i:"..itemId)
      if customValue then
        return customValue * quantity
      else
        return nil
      end
    end
  end
  return nil
end

function SourceTsm:GetVendorPrice(itemId, quantity, ...)
  local vendorPrice = self:GetItemProperty(itemid, "vendorbuy")
  if vendorPrice then
    return vendorPrice * quantity
  end
  return nil
end

function SourceTsm:GetItemProperty(itemId, property)
  if TsmRealm[itemId] and TsmRealm[itemId][property] then
    return TsmRealm[itemId][property]
  elseif TsmRegion[itemId] and TsmRegion[itemId][property] then
    return TsmRegion[itemId][property]
  else
    return nil
  end
end

function SourceTsm:GetPriceTypes()
  return { "dbmarketvalue", "dbminbuyout", "vendorbuy" }
end

function SourceTsm:GetClientRegion()
  return "BCC-"..GetCVar("Portal")
end

function SourceTsm:IsCurrentRealm(realm)
	local currentRealm = GetRealmName().."-"..UnitFactionGroup("player")
	return strlower(realm) == strlower(currentRealm)
end

function SourceTsm:LoadData(tag, data)
  if not data then
    return
  end
  local ClientRegion = SourceTsm:GetClientRegion()
  for _, info in ipairs(data) do
    local realm, data = unpack(info)
    if realm == ClientRegion or gsub(realm, "Classic-%-([A-Z]+)", "%1-Classic") == ClientRegion or gsub(realm, "BCC-%-([A-Z]+)", "%1-BCC") == ClientRegion then
      self:LoadRegionData(loadstring(data)())
    elseif self:IsCurrentRealm(realm) then
      self:LoadRealmData(loadstring(data)())
    end
  end
end

function SourceTsm:LoadRegionData(data)
  self:Log("Loading "..#(data.data).." datasets into TSM region data", "debug")
  for i in ipairs(data.data) do
    local dataRow = {}
    for j, v in ipairs(data.data[i]) do
      dataRow[ data.fields[j] ] = v
    end
    TsmRegion[ dataRow.itemString ] = dataRow
  end
end

function SourceTsm:LoadRealmData(data)
  self:Log("Loading "..#(data.data).." datasets into TSM realm data", "debug")
  for i in ipairs(data.data) do
    local dataRow = {}
    for j, v in ipairs(data.data[i]) do
      dataRow[ data.fields[j] ] = v
    end
    TsmRealm[ dataRow.itemString ] = dataRow
  end
end

-- Hook into TSM
local FetchDataOriginal = TSMAPI.AppHelper.FetchData
TSMAPI.AppHelper.FetchData = function(self, tag)
  local data = FetchDataOriginal(self, tag)
  SourceTsm:LoadData(tag, data)
  return data
end
