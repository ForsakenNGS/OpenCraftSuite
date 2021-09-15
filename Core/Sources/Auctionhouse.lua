-- WoW auctionhouse source
local _, OCS = ...
local SourceAuctionhouse = OCS.Sources:Add("Auctionhouse")

local itemAuctions = {}
local queryActive = nil

function SourceAuctionhouse:OnInitialize()
  OCS.SourceBase.OnInitialize(self)
  self.ahItems = {}
  self.ahItemCounts = {}
  self.updateStatus = {}
  self:RegisterEvent("AUCTION_ITEM_LIST_UPDATE", "OnAuctionItemListUpdate")
  self:Log("Init done!", "debug")
end

function SourceAuctionhouse:GetPrice(itemId, type, quantity)
  if not type then
    type = "buyout"
  end
  if not quantity then
    quantity = 1
  end
  -- TODO: Read item price from cache or update if possible?
  return nil
end

function SourceAuctionhouse:GetItemsBuyable(itemsRequired)
  -- Assume we can buy everything for now
  return OCS.Utils:CloneTable(itemsRequired)
end

-- Create task(s) for buying the given items
function SourceAuctionhouse:BuyItems(itemsRequired)
  local taskBuy = OCS.Tasks:Create("AuctionhouseBuy", itemsRequired)
  if taskBuy then
    return { taskBuy }
  end
  return {}
end

function SourceAuctionhouse:ParseFilterQuality(filterPart)
	for i = 0, 7 do
		if strlower(str) == strlower(_G["ITEM_QUALITY"..i.."_DESC"]) then
			return i
		end
	end
  return nil
end

function SourceAuctionhouse:ParseFilterString(filterStr)
  local filterTable = {}
  local filterParts = { strsplit("/", strtrim(filterStr)) }
  local filterPrev = "START"
  local filterDataIndices = {}
  for i, part in ipairs(filterParts) do
    if i == 1 then
      -- first part
      filterTable.name = part
      filterPrev = "NAME"
    else
      local categoryMatch = false
      if filterPrev == "NAME" then
        for i, catData in ipairs(AuctionCategories) do
          if part == catData.name then
            filterDataIndices.classIndex = i
            filterPrev = "CLASS_FIRST"
            categoryMatch = true
            break
          end
        end
      elseif filterPrev == "CLASS_FIRST" then
        for i, catData in ipairs(AuctionCategories[filterDataIndices.classIndex].subCategories) do
          if part == catData.name then
            filterDataIndices.subClassIndex = i
            filterPrev = "CLASS_SECOND"
            categoryMatch = true
            break
          end
        end
      elseif filterPrev == "CLASS_SECOND" then
        for i, catData in ipairs(AuctionCategories[filterDataIndices.classIndex].subCategories[filterDataIndices.subClassIndex].subCategories) do
          if part == catData.name then
            filterDataIndices.invtypeIndex = i
            filterPrev = "CLASS_THIRD"
            categoryMatch = true
            break
          end
        end
      end
      if categoryMatch or part == "" then
        -- Do not try to match this part (again)
      elseif part == "exact" then
        filterTable.exactMatch = true
      elseif self:ParseFilterQuality(part) then
        filterTable.qualityIndex = self:ParseFilterQuality(part)
        filterPrev = "QUALITY_INDEX"
      elseif tonumber(part) then
        if filterPrev ~= "MIN_LEVEL" then
          filterTable.minLevel = tonumber(part)
          filterPrev = "MIN_LEVEL"
        else
          filterTable.maxLevel = tonumber(part)
          filterPrev = "MAX_LEVEL"
        end
      end
    end
  end
	if filterDataIndices.classIndex and filterDataIndices.subClassIndex and filterDataIndices.invtypeIndex then
		filterTable.filterData = AuctionCategories[filterDataIndices.classIndex].subCategories[filterDataIndices.subClassIndex].subCategories[filterDataIndices.invtypeIndex].filters;
	elseif filterDataIndices.classIndex and subCategoryIndex then
		filterTable.filterData = AuctionCategories[filterDataIndices.classIndex].subCategories[filterDataIndices.subClassIndex].filters;
	elseif filterDataIndices.classIndex then
		filterTable.filterData = AuctionCategories[filterDataIndices.classIndex].filters;
  end
  return filterTable
end

-- Create task(s) for buying the given items
function SourceAuctionhouse:OnAuctionItemListUpdate()
  if queryActive then
    queryActive:FetchResults()
  end
end

SourceAuctionhouse.SearchQuery = {}

function SourceAuctionhouse.SearchQuery:Create(parameters, module)
  -- Inheritance
  module = module or {}
  setmetatable(module, self)
  self.__index = self
  -- Private variables
  module.parameters = parameters or { getAll = true }
  module.page = 0
  module.resultList = nil
  module.resultBatch = nil
  module.resultCount = nil
  module.callbacksAfter = {}
  module.callbacksProgress = {}
  return module
end

function SourceAuctionhouse.SearchQuery:QueryResults(retry)
  local canQuery, canQueryAll = CanSendAuctionQuery()
  if (not self.parameters.getAll and canQuery) or (self.parameters.getAll and canQueryAll) then
    queryActive = self
    if self.page == 0 then
      self.resultList = {}
    end
    QueryAuctionItems(
      self.parameters.name or "", self.parameters.minLevel, self.parameters.maxLevel,
      self.page, self.parameters.isUsable or false, self.parameters.qualityIndex or 0,
      self.parameters.getAll, self.parameters.exactMatch, self.parameters.filterData
    )
    return true
  elseif (retry == nil) or (retry == true) then
    C_Timer.After(0.3, function()
      self:QueryResults(true)
    end)
  end
  return false
end

function SourceAuctionhouse.SearchQuery:GetResultList()
  return self.resultList
end

function SourceAuctionhouse.SearchQuery:FetchResults()
  self.resultBatch, self.resultCount = GetNumAuctionItems("list")
  local isIncomplete = false
  for i = 1, self.resultBatch do
    local name, texture, count, quality, canUse, level, levelColHeader, minBid,
      minIncrement, buyoutPrice, bidAmount, highBidder, bidderFullName, owner,
      ownerFullName, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo("list", i)
    local buyoutPricePerItem = nil
    local minBidPerItem = nil
    if buyoutPrice and buyoutPrice > 0 then
      buyoutPricePerItem = buyoutPrice / count
    end
    if minBid and minBid > 0 then
      minBidPerItem = minBid / count
    end
    tinsert(self.resultList, {
      ahIndex = i, ahPage = self.page, ahParams = self.parameters,
      name = name, texture = texture, count = count, quality = quality,
      canUse = canUse, level = level, levelColHeader = levelColHeader,
      minBid = minBid, minIncrement = minIncrement,
      buyoutPrice = buyoutPrice, buyoutPricePerItem = buyoutPricePerItem,
      bidAmount = bidAmount, minBidPerItem = minBidPerItem,
      highBidder = highBidder, bidderFullName = bidderFullName,
      owner = owner, ownerFullName = ownerFullName, saleStatus = saleStatus,
      itemId = itemId, hasAllInfo = hasAllInfo
    })
    if not hasAllInfo then
      isIncomplete = true
    end
  end
  if self.resultBatch < 50 then
    -- Query done
    queryActive = nil
    self.page = 0
    self:OnProgress(self.resultCount, self.resultCount)
    self:OnQueryDone()
  elseif not isIncomplete then
    -- Query next page
    queryActive = nil
    self.page = self.page + 1
    self:OnProgress(#(self.resultList), self.resultCount)
    self:QueryResults()
  end
end

function SourceAuctionhouse.SearchQuery:After(callback)
  tinsert(self.callbacksAfter, callback)
end

function SourceAuctionhouse.SearchQuery:Progress(callback)
  tinsert(self.callbacksProgress, callback)
end

function SourceAuctionhouse.SearchQuery:OnProgress(current, maximum)
  for i = #(self.callbacksProgress), 1, -1 do
    self.callbacksProgress[i](self, current, maximum)
  end
end

function SourceAuctionhouse.SearchQuery:OnQueryDone()
  for i = #(self.callbacksAfter), 1, -1 do
    self.callbacksAfter[i](self)
    tremove(self.callbacksAfter, i)
  end
  wipe(self.callbacksAfter)
end

SourceAuctionhouse.SearchBatch = {}

function SourceAuctionhouse.SearchBatch:Create(module)
  -- Inheritance
  module = module or {}
  setmetatable(module, self)
  self.__index = self
  -- Private variables
  module.queries = {}
  module.callbacksAfter = {}
  module.callbacksProgress = {}
  return module
end

function SourceAuctionhouse.SearchBatch:AddQuery(query)
  tinsert(self.queries, query)
end

function SourceAuctionhouse.SearchBatch:QueryResults()
  local queryCount = #(self.queries)
  for i = queryCount, 1, -1 do
    if i == queryCount then
      -- Callback after last query
      self.queries[i]:After(function()
        self:OnProgress(i, queryCount)
        self:OnQueryDone()
      end)
    end
    if i > 1 then
      -- Chain queries together
      self.queries[i-1]:After(function()
        self:OnProgress(i-1, queryCount)
        self.queries[i]:QueryResults()
      end)
    else
      -- Start first query
      self:OnProgress(0, queryCount)
      self.queries[i]:QueryResults()
    end
  end
  return true
end

function SourceAuctionhouse.SearchBatch:After(callback)
  tinsert(self.callbacksAfter, callback)
end

function SourceAuctionhouse.SearchBatch:Progress(callback)
  tinsert(self.callbacksProgress, callback)
end

function SourceAuctionhouse.SearchBatch:OnProgress(current, maximum)
  for i = #(self.callbacksProgress), 1, -1 do
    self.callbacksProgress[i](self, current, maximum)
  end
end

function SourceAuctionhouse.SearchBatch:OnQueryDone()
  for i = #(self.callbacksAfter), 1, -1 do
    self.callbacksAfter[i](self, self.queries)
    tremove(self.callbacksAfter, i)
  end
end

SourceAuctionhouse.SearchItemBatch = SourceAuctionhouse.SearchBatch:Create()

function SourceAuctionhouse.SearchItemBatch:Create(module)
  -- Inheritance
  module = SourceAuctionhouse.SearchBatch:Create(module)
  setmetatable(module, self)
  self.__index = self
  -- Callback for items
  module.itemIds = {}
  module.itemPrices = {}
  module.callbacksItems = {}
  return module
end

function SourceAuctionhouse.SearchItemBatch:AddItemQuery(itemId, itemName)
  if tContains(self.itemIds, itemId) then
    return -- Item already queued
  end
  if not itemName then
    itemName = GetItemInfo(itemId)
  end
  local itemQuery = SourceAuctionhouse.SearchQuery:Create({ name = itemName, exactMatch = true })
  tinsert(self.queries, itemQuery)
  tinsert(self.itemIds, itemId)
  self.itemPrices[itemId] = {
    itemId = itemId, itemName = itemName,
    priceMin = nil, priceMinOwner = nil,
    priceMax = nil, priceMaxOwner = nil,
    auctions = nil
  }
end

function SourceAuctionhouse.SearchItemBatch:OnItemsDone()
  for i = #(self.callbacksItems), 1, -1 do
    self.callbacksItems[i](self, self.itemPrices)
    tremove(self.callbacksItems, i)
  end
end

function SourceAuctionhouse.SearchItemBatch:AfterItems(callback)
  tinsert(self.callbacksItems, callback)
end

function SourceAuctionhouse.SearchItemBatch:QueryResults()
  self:After(function(_, queries)
    for i, query in pairs(queries) do
      local itemId = self.itemIds[i]
      local itemResults = self.itemPrices[itemId]
      -- Reset result entry
      itemResults.priceMin = nil
      itemResults.priceMinOwner = nil
      itemResults.priceMax = nil
      itemResults.priceMaxOwner = nil
      -- Iterate results and determine the min and max price
      itemResults.auctions = query:GetResultList()
      for j, auctionData in ipairs(itemResults.auctions) do
        if auctionData.buyoutPrice > 0 then
          if itemResults.priceMin == nil or auctionData.buyoutPricePerItem < itemResults.priceMin then
            itemResults.priceMin = auctionData.buyoutPricePerItem
            itemResults.priceMinOwner = auctionData.owner
          end
          if itemResults.priceMax == nil or auctionData.buyoutPricePerItem > itemResults.priceMax then
            itemResults.priceMax = auctionData.buyoutPricePerItem
            itemResults.priceMaxOwner = auctionData.owner
          end
        end
      end
    end
    self:OnItemsDone()
  end)
  return SourceAuctionhouse.SearchBatch.QueryResults(self)
end
