-- WoW auctionhouse source
local _, OCS = ...
local AuctionhouseFrame = OCS.Frames:Add("Auctionhouse")

function AuctionhouseFrame:OnInitialize()
  self.title = OCS.L["MODULE_FRAME_AUCTIONHOUSE"]
  self.name = "OCS_AuctionhouseFrame"
  self:RegisterEvent("AUCTION_HOUSE_SHOW", "OnAuctionHouseShow")
  self:RegisterEvent("AUCTION_HOUSE_CLOSED", "OnAuctionHouseClose")
end

function AuctionhouseFrame:GetAceOptions()
  local options = {
    Show = {
      name = OCS.L["MODULE_FRAME_AUCTIONHOUSE_SHOW"],
      type = "execute",
      order = 200,
      func = function() OCS.Frames:Show("Auctionhouse") end
    }
  }
  return options
end

function AuctionhouseFrame:CreateContents()
  self.widget:ReleaseChildren()
  self.widget:SetLayout("Fill")
  -- Item-Group tree
  self.sectionTree = OCS.GUI:CreateWidget("TreeGroup")
  self.sectionTree:SetTree(self:GetSections())
  self.sectionTree:SetFullWidth(true)
  self.sectionTree:SetCallback("OnGroupSelected", function(widget, _, groupPathStr)
    self:OnSectionSelected({ strsplit("\001", groupPathStr) })
  end)
	self.widget:AddChild(self.sectionTree)
end

function AuctionhouseFrame:CreateSection_Buy_Search()
	self.sectionTree:ReleaseChildren()
  self.sectionTree:SetLayout("Manual")
  local tableWidget = nil
	-- Update data function
	local ah = OCS:GetModule("Source", "Auctionhouse")
	local crafting = OCS:GetModule("Source", "Crafting")
	local tsm = OCS:GetModule("Source", "TSM")
  local tableData = {}
  local filterText = ""
	local function updateList()
    local searchFilter = ah:ParseFilterString(filterText)
    self:Log("Auction search: "..filterText, "debug", searchFilter)
    local searchQuery = ah.SearchQuery:Create(searchFilter)
		-- Obtain the prices for the reagents
    searchQuery:Progress(function(_, current, maximum)
      self:UpdateProgress(current, maximum)
    end)
    searchQuery:After(function(query)
      tableData = {}
      for i, auctionData in ipairs(query:GetResultList()) do
        tinsert(tableData, auctionData)
      end
      self:Log("Auction results: "..#(tableData))
      sort(tableData, function(a, b)
        return a.buyoutPricePerItem < b.buyoutPricePerItem
      end)
      tableWidget:UpdateData()
    end)
    searchQuery:QueryResults()
	end
  -- Search bar
  local searchBar = OCS.GUI:CreateWidget("EditBox")
  searchBar:DisableButton(true)
  searchBar:SetCallback("OnTextChanged", function(widget, _, text)
    filterText = text
  end)
  searchBar:SetCallback("OnEnterPressed", function(widget, _, text)
    filterText = text
    updateList()
  end)
  self.sectionTree:AddChild(searchBar)
  -- Result table
  tableWidget = OCS.GUI:CreateWidget("Table")
  tableWidget:SetCallback("OnTableRowUpdate", function(widget, _, cells, rowIndex)
    -- Update cell content
    local itemData = tableData[rowIndex]
    if itemData then
      cells[1]:SetText(itemData.name)
      cells[2]:SetText(itemData.owner)
      cells[3]:SetText(OCS.Utils:FormatMoney(itemData.minBidPerItem))
      cells[4]:SetText(OCS.Utils:FormatMoney(itemData.buyoutPricePerItem))
    end
  end)
  tableWidget:SetCallback("OnUpdateData", function(widget)
    widget:SetRowCount(#(tableData))
  end)
  tableWidget:SetCallback("OnTableRowEnter", function(widget, _, cells, rowIndex)
    -- TODO
  end)
  tableWidget:SetCallback("OnTableRowLeave", function(widget, _, cells, rowIndex)
    -- TODO
  end)
  tableWidget:SetCallback("OnTableSel", function(widget, _, rowIndex)
    -- TODO
  end)
  tableWidget:SetRowHeight(19)
  tableWidget:SetColumnLabels({ "Name", "Seller", "Bid", "Buyout" }, { 3, 1, 1, 1 })
  self.sectionTree:AddChild(tableWidget)
  -- Positioning
  searchBar.frame:SetPoint("TOPLEFT")
  searchBar.frame:SetPoint("TOPRIGHT")
  tableWidget.frame:SetPoint("TOPLEFT", searchBar.frame, "BOTTOMLEFT")
  tableWidget.frame:SetPoint("BOTTOMRIGHT")
end

function AuctionhouseFrame:CreateSection_Sell_Cancel()
	self.sectionTree:ReleaseChildren()
  self.sectionTree:SetLayout("Manual")
  local tableWidget = nil
	-- Update data function
	local ahInventory = OCS:GetModule("Inventory", "Auctionhouse")
	local ahSource = OCS:GetModule("Source", "Auctionhouse")
  local tableData = {}
  local filterText = ""
	local function updateList()
    local activeAuctions = ahInventory:GetAuctionItems()
    local activeItemBatch = ahSource.SearchItemBatch:Create()
    for auctionId, auctionData in pairs(activeAuctions) do
      if auctionData.saleStatus == 0 then
        activeItemBatch:AddItemQuery(auctionData.itemId, auctionData.name)
      end
    end
    activeItemBatch:Progress(function(_, current, maximum)
      self:UpdateProgress(current, maximum)
    end)
    activeItemBatch:AfterItems(function(_, itemPrices)
      tableData = {}
      for auctionId, auctionData in pairs(activeAuctions) do
        if auctionData.saleStatus == 0 and itemPrices[auctionData.itemId] and itemPrices[auctionData.itemId].priceMin < auctionData.buyoutPricePerItem then
          auctionData.undercutPlayer = itemPrices[auctionData.itemId].priceMinOwner
          auctionData.undercutPricePerItem = itemPrices[auctionData.itemId].priceMin
          tinsert(tableData, auctionData)
        else
          auctionData.undercutPlayer = nil
          auctionData.undercutPricePerItem = nil
        end
      end
      self:Log("Auction results: "..#(tableData))
      tableWidget:UpdateData()
    end)
    activeItemBatch:QueryResults()
	end
  -- Search bar
  local searchBar = OCS.GUI:CreateWidget("EditBox")
  searchBar:DisableButton(true)
  searchBar:SetCallback("OnTextChanged", function(widget, _, text)
    filterText = text
  end)
  searchBar:SetCallback("OnEnterPressed", function(widget, _, text)
    filterText = text
    updateList()
  end)
  self.sectionTree:AddChild(searchBar)
  -- Result table
  tableWidget = OCS.GUI:CreateWidget("Table")
  tableWidget:SetCallback("OnTableRowUpdate", function(widget, _, cells, rowIndex)
    -- Update cell content
    local ownData = tableData[rowIndex]
    if ownData then
      cells[1]:SetText(ownData.name)
      cells[2]:SetText(ownData.undercutPlayer)
      cells[3]:SetText(OCS.Utils:FormatMoney(ownData.undercutPricePerItem))
      cells[4]:SetText(OCS.Utils:FormatMoney(ownData.buyoutPricePerItem))
    end
  end)
  tableWidget:SetCallback("OnUpdateData", function(widget)
    widget:SetRowCount(#(tableData))
  end)
  tableWidget:SetCallback("OnTableRowEnter", function(widget, _, cells, rowIndex)
    -- TODO
  end)
  tableWidget:SetCallback("OnTableRowLeave", function(widget, _, cells, rowIndex)
    -- TODO
  end)
  tableWidget:SetCallback("OnTableSel", function(widget, _, rowIndex)
    -- TODO
  end)
  tableWidget:SetRowHeight(19)
  tableWidget:SetColumnLabels({ "Item", "Undercut by", "Undercut price", "Your price" }, { 3, 1, 1, 1 })
  self.sectionTree:AddChild(tableWidget)
  -- Positioning
  searchBar.frame:SetPoint("TOPLEFT")
  searchBar.frame:SetPoint("TOPRIGHT")
  tableWidget.frame:SetPoint("TOPLEFT", searchBar.frame, "BOTTOMLEFT")
  tableWidget.frame:SetPoint("BOTTOMRIGHT")
  -- Initial update
  updateList()
end

function AuctionhouseFrame:CreateSection_Crafting_FindProfitable()
	self.sectionTree:ReleaseChildren()
  self.sectionTree:SetLayout("Manual")
  local tableWidget = nil
	-- Update data function
	local ah = OCS:GetModule("Source", "Auctionhouse")
	local crafting = OCS:GetModule("Source", "Crafting")
	local tsm = OCS:GetModule("Source", "TSM")
  local tableData = {}
	local function updateList()
    local professions = crafting:GetProfessions()
    local craftingItemBatch = ah.SearchItemBatch:Create()
    local recipeList = {}
    local vendorPrices = {}
		-- Gather recipes that are sold sufficiently
		for _, skillString in ipairs(professions) do
			local recipes = crafting:GetRecipeData(skillString)
			for _, recipeData in ipairs(recipes) do
				-- Check if item is being bought sufficiently
				if recipeData.itemId then
					local saleRatio = tsm:GetItemProperty(recipeData.itemId, "regionSoldPerDay") or 0
					if saleRatio > 1000 then
            tinsert(recipeList, recipeData)
            craftingItemBatch:AddItemQuery(recipeData.itemId)
						for reqId, reqCount in pairs(recipeData.reagents) do
              if not vendorPrices[reqId] then
                local vendorPrice = OCS.Sources:GetVendorPrice(reqId)
                if vendorPrice then
                  vendorPrices[reqId] = vendorPrice
                else
                  craftingItemBatch:AddItemQuery(reqId)
  							end
              end
						end
					end
				end
			end
		end
		-- Obtain the prices for the reagents
    craftingItemBatch:Progress(function(_, current, maximum)
      self:UpdateProgress(current, maximum)
    end)
    craftingItemBatch:AfterItems(function(_, itemPrices)
      for itemId, itemPrice in pairs(vendorPrices) do
        itemPrices[itemId] = {
          itemId = itemId, itemName = GetItemInfo(itemId),
          priceMin = itemPrice, priceMinOwner = "VENDOR",
          priceMax = itemPrice, priceMaxOwner = "VENDOR",
          auctions = {}
        }
      end
      self:Log("Gathering prices for "..#(recipeList).." recipes", "debug")
      tableData = {}
			for i, recipeData in ipairs(recipeList) do
        local recipeReagentPrice = 0
        for reqId, reqCount in pairs(recipeData.reagents) do
          recipeReagentPrice = recipeReagentPrice + (itemPrices[reqId].priceMin or 0) * reqCount
        end
        local recipeSellPrice = itemPrices[recipeData.itemId].priceMin or OCS.Sources:GetPriceMin(recipeData.itemId, 1)
        if recipeSellPrice > 0 then
          local recipeProfit = recipeSellPrice - recipeReagentPrice
          tinsert(tableData, {
            itemId = recipeData.itemId, itemName = GetItemInfo(recipeData.itemId),
            reagentPrice = recipeReagentPrice, sellPrice = recipeSellPrice, profit = recipeProfit
          })
        end
      end
      sort(tableData, function(a, b)
        return a.profit > b.profit
      end)
      tableWidget:UpdateData()
    end)
    craftingItemBatch:QueryResults()
	end
  -- Result table
  tableWidget = OCS.GUI:CreateWidget("Table")
  tableWidget:SetCallback("OnTableRowUpdate", function(widget, _, cells, rowIndex)
    -- Update cell content
    local itemData = tableData[rowIndex]
    if itemData then
      cells[1]:SetText(itemData.itemName or itemData.itemId)
      cells[2]:SetText(OCS.Utils:FormatMoney(itemData.reagentPrice))
      cells[3]:SetText(OCS.Utils:FormatMoney(itemData.profit))
    end
  end)
  tableWidget:SetCallback("OnUpdateData", function(widget)
    widget:SetRowCount(#(tableData))
  end)
  tableWidget:SetCallback("OnTableRowEnter", function(widget, _, cells, rowIndex)
    -- TODO
  end)
  tableWidget:SetCallback("OnTableRowLeave", function(widget, _, cells, rowIndex)
    -- TODO
  end)
  tableWidget:SetCallback("OnTableSel", function(widget, _, rowIndex)
    -- TODO
  end)
  tableWidget:SetRowHeight(19)
  tableWidget:SetColumnLabels({ "Name", "Craft Cost", "Profit" }, { 2, 1, 1 })
  self.sectionTree:AddChild(tableWidget)
  -- Positioning
  tableWidget.frame:SetPoint("TOPLEFT")
  tableWidget.frame:SetPoint("BOTTOMRIGHT")
  -- Initial update
  updateList()
end

function AuctionhouseFrame:UpdateProgress(current, maximum)
  if current < maximum then
    self.widget:SetTitle(self.title.." ("..current.." / "..maximum..")")
  else
    self.widget:SetTitle(self.title)
  end
end

function AuctionhouseFrame:GetSections()
	local sections = {}
	local sectionsByIdent = {}
	-- Buy
  local sectionBuy = {
    value = "Buy", text = OCS.L["MODULE_FRAME_AUCTIONHOUSE_BUY"],
		children = {
      { value = "Search", text = OCS.L["MODULE_FRAME_AUCTIONHOUSE_BUY_SEARCH"] },
      { value = "AdvancedSearch", text = OCS.L["MODULE_FRAME_AUCTIONHOUSE_BUY_ADVANCED_SEARCH"] },
      { value = "Groups", text = OCS.L["MODULE_FRAME_AUCTIONHOUSE_BUY_GROUPS"] }
    }
  }
	tinsert(sections, sectionBuy)
	sectionsByIdent[sectionBuy.value] = sectionBuy
	-- Sell
  local sectionSell = {
    value = "Sell", text = OCS.L["MODULE_FRAME_AUCTIONHOUSE_SELL"],
		children = {
      { value = "Post", text = OCS.L["MODULE_FRAME_AUCTIONHOUSE_SELL_POST"] },
      { value = "Cancel", text = OCS.L["MODULE_FRAME_AUCTIONHOUSE_SELL_CANCEL"] }
    }
  }
	tinsert(sections, sectionSell)
	sectionsByIdent[sectionSell.value] = sectionSell
	-- Crafting
	if OCS:GetModule("Source", "Crafting") then
	  local sectionCrafting = {
	    value = "Crafting", text = OCS.L["MODULE_FRAME_AUCTIONHOUSE_CRAFTING"],
			children = {
				{ value = "FindProfitable", text = OCS.L["MODULE_FRAME_AUCTIONHOUSE_CRAFTING_FIND_PROFITABLE"] }
			}
	  }
		tinsert(sections, sectionCrafting)
		sectionsByIdent[sectionCrafting.value] = sectionCrafting
	end
	-- Settings
  local sectionSettings = {
    value = "Settings", text = OCS.L["MODULE_FRAME_AUCTIONHOUSE_SETTINGS"],
		children = {}
  }
	tinsert(sections, sectionSettings)
	sectionsByIdent[sectionSettings.value] = sectionSettings
	-- Fire event to allow outside extensions
  self:SendMessage("OCS_AUCTIONHOUSE_FRAME_SECTIONS", sections, sectionsByIdent)
	return sections
end

function AuctionhouseFrame:OnSectionSelected(sectionPath)
	local methodName = "CreateSection_"..strjoin("_", unpack(sectionPath))
	if type(self[methodName]) == "function" then
		-- Call method matching the selected section
		self[methodName](self)
	else
		-- No builting function for the selected section, send message to inject the desired content
  	self:SendMessage("OCS_AUCTIONHOUSE_FRAME_SECTION_CREATE", sectionPath, self.sectionTree)
	end
end

function AuctionhouseFrame:OnAuctionHouseShow()
	OCS.Frames:Show("Auctionhouse")
end

function AuctionhouseFrame:OnAuctionHouseClose()
	self:Hide()
end
