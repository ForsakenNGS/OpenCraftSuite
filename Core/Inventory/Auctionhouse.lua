-- Mail inventory
local _, OCS = ...
local InventoryAuctionhouse = OCS.Inventory:Add("Auctionhouse", { moduleNameAbbr = "AH" })

function InventoryAuctionhouse:OnInitialize()
  OCS.InventoryBase.OnInitialize(self)
  self.ahItems = {}
  self.ahItemCounts = {}
  self.updateStatus = {}
  self:RegisterEvent("AUCTION_OWNED_LIST_UPDATE", "OnAuctionOwnedListUpdate")
  self:Log("Init done!", "debug")
end

function InventoryAuctionhouse:GetNumOwnedAuctions()
	return GetNumAuctionItems("owner")
end

function InventoryAuctionhouse:GetAuctionItems()
  return self.ahItems
end

function InventoryAuctionhouse:GetAuctionInfo(auctionType, index)
	local name, texture, stackSize, quality, _, _, _, minBid, _, buyout, bid, highBidder, _, _, _, saleStatus = GetAuctionItemInfo(auctionType, index)
	local link = name and name ~= "" and GetAuctionItemLink(auctionType, index)
	if not link then
		return
	end
	local duration = GetAuctionItemTimeLeft(auctionType, index)
	return index, link, name, texture, stackSize, quality, minBid, buyout, bid, highBidder, saleStatus, duration
end

function InventoryAuctionhouse:IsScanAllowed()
	return true
end

function InventoryAuctionhouse:UpdateOwnedAuctions()
  wipe(self.updateStatus)
  local ownedAuctions = self:GetNumOwnedAuctions()
  for i = 1, ownedAuctions do
    self.updateStatus[i] = "pending"
  end
end

function InventoryAuctionhouse:UpdateOwnedQueue()
  if not self:IsScanAllowed() then
    return
  end
  local itemsUpdated = 0
  local itemsPending = 0
  for index in pairs(self.updateStatus) do
    local auctionStatus = self.updateStatus[index]
    if auctionStatus == "pending" then
  		local auctionId, link, name, texture, stackSize, quality, minBid, buyoutPrice, bid, highBidder, saleStatus, duration = self:GetAuctionInfo("owner", index)
      if auctionId then
        local _, itemId = OCS.Utils:ParseItemLink(link)
        local buyoutPricePerItem = nil
        local minBidPerItem = nil
        if buyoutPrice and buyoutPrice > 0 then
          buyoutPricePerItem = buyoutPrice / stackSize
        end
        if minBid and minBid > 0 then
          minBidPerItem = minBid / stackSize
        end
        self.ahItems[auctionId] = {
          itemId = itemId, name = name, link = link, saleStatus = saleStatus,
          stackSize = stackSize, duration = duration,
          buyoutPrice = buyoutPrice, buyoutPricePerItem = buyoutPricePerItem,
          minBid = minBid, minBidPerItem = minBidPerItem
        }
        self.updateStatus[index] = "done"
        itemsUpdated = itemsUpdated + 1
        -- self:Log("Auction #"..auctionId..": "..link, "debug", { name, texture, stackSize, quality, minBid, buyout, bid, highBidder, saleStatus, duration })
      else
        itemsPending = itemsPending + 1
      end
    end
  end
  if itemsUpdated > 0 then
    self:Log("Updated "..itemsUpdated.." own auctions", "debug")
    self:UpdateItemCounts()
  end
  if itemsPending > 0 then
    self:Log(itemsUpdated.." own auctions pending for update...", "debug")
    C_Timer.After(0.5, function()
      self:UpdateOwnedQueue()
    end);
  end
end

function InventoryAuctionhouse:UpdateItemsObtainable()
  self.itemsObtainable = {}
  for auctionId in pairs(self.ahItems) do
    local itemId = self.ahItems[auctionId].itemId
    if self.itemsObtainable[itemId] then
      self.itemsObtainable[itemId] = self.itemsObtainable[itemId] + self.ahItems[auctionId].stackSize
    else
      self.itemsObtainable[itemId] = self.ahItems[auctionId].stackSize
    end
  end
end

function InventoryAuctionhouse:OnAuctionOwnedListUpdate()
  self:UpdateOwnedAuctions()
  self:UpdateOwnedQueue()
end
