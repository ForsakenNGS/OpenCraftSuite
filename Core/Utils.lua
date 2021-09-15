-- Source framework
local _, OCS = ...
local priceCurrencies = { "c", "s", "g" }
local priceColors = { "ffeda55f", "ffc7c7cf", "ffffd70a" }
local lazyUpdates = {}

OCS.Utils = {}

function OCS.Utils:LazyUpdate(ident, callback, timeout)
  timeout = timeout or 1
  lazyUpdates[ident] = {
    timeTarget = GetTime() + floor(timeout),
    callback = callback
  }
  C_Timer.After(timeout, function()
    if lazyUpdates[ident] and GetTime() > lazyUpdates[ident].timeTarget then
      -- Not overwritten
      lazyUpdates[ident].callback()
      lazyUpdates[ident] = nil
    end
  end)
end

function OCS.Utils:CloneList(list)
  local listCopy = {}
  for i, v in ipairs(list) do
    tinsert(listCopy, v)
  end
  return listCopy
end

function OCS.Utils:CloneTable(table, recurse, recurseLimit)
  local tableCopy = {}
  for k, v in pairs(table) do
    if not recurse or type(obj) ~= 'table' then
      tableCopy[k] = v
    else
      if not recurseLimit then
        recurseLimit = 10
      end
      tableCopy[k] = self:CloneTable(v, true, recurseLimit - 1)
    end
  end
  return setmetatable(tableCopy, getmetatable(table))
end

function OCS.Utils:ArraysEqual(...)
  local arrays = { ... }
  -- Count each value in each array
  local counts = {}
  for i, ar in ipairs(arrays) do
    for j, value in ipairs(ar) do
      if not counts[value] then
        counts[value] = 1
      else
        counts[value] = counts[value] + 1
      end
    end
  end
  -- Check if every key found is present in every array
  local expected = #(arrays)
  for value, found in pairs(counts) do
    if found < expected then
      return false
    end
  end
  return true
end

function OCS.Utils:ParseItemLink(link)
  if not link then
    return nil
  end
  local _, _, Color = string.find(link, "|c(%x*).*|r");
  local _, _, Type, Id, Name = string.find(link, "|H(.-):(%d+).-|h%[(.-)%]|h");
  if Id then
    local IdTyped = Type..Id;
    return IdTyped, tonumber(Id), Name, Type, Color;
  else
    return nil
  end
end

function OCS.Utils:ParseItemLinks(text)
  local results = {}
  local posStart, posEnd, linkType, linkId, linkName
  repeat
    posStart, posEnd, linkType, linkId, linkName = string.find(text, "|H(.-):(%d+).-|h%[(.-)%]|h", posEnd);
    if linkType and linkId then
      tinsert(results, { type = linkType, id = tonumber(linkId), name = linkName })
    end
  until not posEnd
  return results
end

function OCS.Utils:FormatCharacterName(charName)
  return charName
end

function OCS.Utils:FormatMoney(moneyCoppers)
  if moneyCoppers < 0 then
    return "|cffff0000-"..self:FormatMoney(moneyCoppers * -1).."|r"
  end
  local result = ""
  local currencyIndex = 3
  local currencyFactor = 10000
  local currencyDisplay = false
  while (currencyIndex > 0) do
    if (moneyCoppers > currencyFactor) or currencyDisplay then
      local currencyValue = floor(moneyCoppers / currencyFactor)
      result = result..currencyValue.."|c"..priceColors[currencyIndex]..priceCurrencies[currencyIndex].."|r "
      moneyCoppers = moneyCoppers - currencyValue * currencyFactor
      currencyDisplay = true
    end
    currencyFactor = currencyFactor / 100
    currencyIndex = currencyIndex - 1
  end
  return trim(result)
end

function OCS.Utils:DumpVariable(var, indent, returnResult)
  if (not indent) then
    indent = "";
  end
  local dumped = {};
  if (type(var) == "table") then
    local values = {};
    for i in pairs(var) do
      local value = strtrim(self:DumpVariable(var[i], indent.."  ", true));
      tinsert(values, indent.."  "..i.." = "..value);
    end
    if (#(values) > 0) then
      tinsert(dumped, indent.."(table) {");
      tinsert(dumped, strjoin("\n", unpack(values)))
      tinsert(dumped, indent.."}");
    else
      tinsert(dumped, indent.."(table) { }");
    end
  elseif (type(var) == "boolean") then
    if (var) then
      tinsert(dumped, indent.."(bool)true");
    else
      tinsert(dumped, indent.."(bool)false");
    end
  elseif (type(var) == "number") then
    tinsert(dumped, indent.."(num)"..var);
  elseif (type(var) == "string") then
    tinsert(dumped, indent.."(str)"..var);
  elseif (type(var) == "function") then
    tinsert(dumped, indent.."(function)");
  end
  if (returnResult) then
    return strjoin("\n", unpack(dumped));
  else
    local text = strjoin("\n", unpack(dumped));
    local lines = { strsplit("\n", text) };
    for i in ipairs(lines) do
      print(lines[i]);
    end
  end
end
