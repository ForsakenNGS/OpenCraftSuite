-- WoW auctionhouse source
local _, OCS = ...
local CraftingFrame = OCS.Frames:Add("Crafting")

function CraftingFrame:OnInitialize()
  self.source = OCS:GetModule("Source", "Crafting")
  self.title = OCS.L["MODULE_SOURCE_CRAFTING"]
  self.name = "OCS_CraftingFrame"
  self.professionList = nil
  self:RegisterEvent("CRAFT_SHOW", "OnCraftShow");
  self:RegisterEvent("CRAFT_CLOSE", "OnCraftClose");
  self:RegisterEvent("TRADE_SKILL_SHOW", "OnTradeSkillShow")
  self:RegisterEvent("TRADE_SKILL_CLOSE", "OnTradeSkillClose")
end

function CraftingFrame:GetAceOptions()
  local options = {
    ReplaceCrafting = {
      name = OCS.L["MODULE_SOURCE_CRAFTING_REPLACE"],
      desc = OCS.L["MODULE_SOURCE_CRAFTING_REPLACE_DESCRIPTION"],
      type = "toggle",
      order = 100,
      width = "full",
      set = function(info, val) CraftingFrame:SetReplaceCrafting(val) end,
      get = function(info) return CraftingFrame:GetReplaceCrafting() end
    },
    Show = {
      name = OCS.L["MODULE_SOURCE_CRAFTING_SHOW_FRAME"],
      type = "execute",
      order = 200,
      func = function() OCS.Frames:Show("Crafting") end
    }
  }
  return options
end

function CraftingFrame:Create(name, title)
  local frame, created = OCS.FrameBase.Create(self, name, title)
  if created then
    self.widget:SetCallback("OnClose", function()
      self:OnClose()
    end)
    self.widget:SetLayout("Fill")
    self:SaveLocation()
  end
end

function CraftingFrame:CreateContents()
  self.widget:ReleaseChildren()
  self.frame:SetMinResize(680, 440)
  -- Profession / Character tree
  self.professionList = OCS.GUI:CreateWidget("TreeGroup")
  self.professionList:SetLayout("Manual")
  self.professionList:SetTree(self:GetProfessionTree())
  self.professionList:SetFullHeight(true)
  self.professionList:SetFullWidth(true)
  self.professionList:SetCallback("OnGroupSelected", function(widget, _, groupIdent)
    local skillString, charName = strsplit("\001", groupIdent)
    self:UpdateRecipiesTable(skillString, charName)
  end)
  self.widget:AddChild(self.professionList)
  -- Profession recipe table
  self.recipeTable = nil
  self.searchBar = nil
  self.recipeDetails = nil
end

function CraftingFrame:UpdateRecipiesTable(skillString, charName)
  local searchBar = self:CreateRecipiesSearchbar()
  local recipeTable = self:CreateRecipiesTable()
  local recipeDetails = self:CreateRecipieDetails()
  local tableData = self.source:GetRecipeData(skillString, charName) or {}
  local recipeExtra = {}
  local function getRecipeExtra(recipeData)
    if not recipeExtra[recipeData.skillId] then
      local name, _, icon = GetSpellInfo(recipeData.skillId)
      local extra = {
        name = name, icon = icon,
        countMin = nil, countMax = nil
      }
      -- Calculate count craftable
      local reagentMin, reagentMax
      for reagentId, reagentCount in pairs(recipeData.reagents) do
        local countOnHand = OCS.Inventory:GetItemsOnHand(reagentId)
        local countOverall = OCS.Inventory:GetItemsOverall(reagentId)
        local craftsOnHand = floor(countOnHand / reagentCount)
        local craftsOverall = floor(countOverall / reagentCount)
        if (extra.countMin == nil) or (craftsOnHand < extra.countMin) then
          extra.countMin = craftsOnHand
        end
        if (extra.countMax == nil) or (craftsOverall < extra.countMax) then
          extra.countMax = craftsOverall
        end
      end
      -- Write into cache
      recipeExtra[recipeData.skillId] = extra
    end
    return recipeExtra[recipeData.skillId]
  end
  -- Poistioning
  searchBar:ClearAllPoints()
  searchBar:SetPoint("TOPLEFT")
  searchBar:SetPoint("TOPRIGHT")
  recipeTable:ClearAllPoints()
  recipeTable:SetPoint("TOPLEFT", searchBar.frame, "BOTTOMLEFT")
  recipeTable:SetPoint("TOPRIGHT", searchBar.frame, "BOTTOMRIGHT")
  recipeTable:SetPoint("BOTTOMRIGHT")
  recipeDetails:ClearAllPoints()
  recipeDetails:SetPoint("BOTTOMLEFT")
  recipeDetails:SetPoint("BOTTOMRIGHT")
  -- Search bar
  searchBar:SetCallback("OnTextChanged", function(widget, _, text)
    tableData = self.source:GetRecipeDataFiltered(skillString, charName, text)
    recipeTable:UpdateData()
  end)
  searchBar:SetCallback("OnEnterPressed", function(widget, _, text)
    tableData = self.source:GetRecipeDataFiltered(skillString, charName, text)
    recipeTable:UpdateData()
  end)
  -- Recipe table
  recipeTable:SetCallback("OnTableRowUpdate", function(widget, _, cells, rowIndex)
    -- Update cell content
    local searchText = searchBar:GetText()
    local recipeData = tableData[rowIndex]
    if recipeData then
      local recipeExtra = getRecipeExtra(recipeData)
      if recipeExtra.countMax == 0 then
        cells[1]:SetText("|cffff0000"..recipeExtra.countMin.."|r")
      elseif recipeExtra.countMin ~= recipeExtra.countMax then
        cells[1]:SetText("|cffffff00"..recipeExtra.countMin.."-"..recipeExtra.countMax.."|r")
      else
        cells[1]:SetText("|cff00ff00"..recipeExtra.countMin.."|r")
      end
      cells[2]:SetImage(recipeData.skillIcon or recipeExtra.icon)
      cells[2]:SetText(recipeExtra.name)
      cells[3]:SetText("???")
    end
  end)
  recipeTable:SetCallback("OnUpdateData", function(widget)
    -- Update available data
    local searchText = searchBar:GetText()
    local recipeCount = #(tableData)
    self:Log("Update data count: "..recipeCount, "debug")
    widget:SetRowCount(recipeCount);
  end)
  recipeTable:SetCallback("OnTableRowEnter", function(widget, _, cells, rowIndex)
    if tableData[rowIndex] then
      GameTooltip:ClearAllPoints()
      GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
      GameTooltip:SetHyperlink(tableData[rowIndex].skillLink or tableData[rowIndex].itemLink)
      GameTooltip:Show()
    end
  end)
  recipeTable:SetCallback("OnTableRowLeave", function(widget, _, cells, rowIndex)
    GameTooltip:Hide()
  end)
  recipeTable:SetCallback("OnTableSel", function(widget, _, rowIndex)
    if rowIndex then
      if IsShiftKeyDown() then
        local recipeLink = tableData[rowIndex].skillLink or tableData[rowIndex].itemLink
        SetItemRef(recipeLink, recipeLink, "LeftButton")
      end
      self:CreateRecipieDetails(tableData[rowIndex], skillString)
    else
      self:HideRecipieDetails()
    end
  end)
  recipeTable:UpdateData()
  self:HideRecipieDetails()
end

function CraftingFrame:CreateRecipiesSearchbar()
  if self.searchBar then
    return self.searchBar
  end
  -- Search bar
  self.searchBar = OCS.GUI:CreateWidget("EditBox")
  self.searchBar:DisableButton(true)
  self.professionList:AddChild(self.searchBar)
  return self.searchBar
end

function CraftingFrame:CreateRecipiesTable()
  if self.recipeTable then
    return self.recipeTable
  end
  self.recipeTable = OCS.GUI:CreateWidget("Table")
  self.recipeTable:SetFullHeight(true)
  self.recipeTable:SetFullWidth(true)
  self.recipeTable:SetRowHeight(19)
  self.recipeTable.GetCellType = function(widget, colIndex)
    if (colIndex == 2) then
      return "ItemRow"
    else
      return "InteractiveLabel"
    end
  end
  self.recipeTable:SetCallback("OnTableCellCreated", function(widget, _, cell, colIndex, rowIndex)
    -- Modify cell element
    if (colIndex == 2) then
      cell:SetFullWidth(true)
      cell:SetImageSize(19, 19)
      cell:SetJustifyV("LEFT")
    else
      cell.label:SetHeight(19)
      cell:SetJustifyV("MIDDLE")
    end
  end)
  self.recipeTable:SetColumnLabels({ "#", "Name", "Cost" }, { 54, 1, 96 })
  self.professionList:AddChild(self.recipeTable)
  return self.recipeTable
end

function CraftingFrame:GetHideTooltipFunc()
  if not self.hideTooltipFunc then
    self.hideTooltipFunc = function()
      GameTooltip:Hide()
    end
  end
  return self.hideTooltipFunc
end

function CraftingFrame:GetReagentTooltipFunc(itemLink)
  local typedId, id = OCS.Utils:ParseItemLink(itemLink)
  if not typedId then
    return nil
  end
  if not self.reagentTooltipFunc then
    self.reagentTooltipFunc = {}
  end
  if not self.reagentTooltipFunc[typedId] then
    self.reagentTooltipFunc[typedId] = function()
      GameTooltip:ClearAllPoints()
      GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
      GameTooltip:SetHyperlink(itemLink)
      GameTooltip:Show()
    end
  end
  return self.reagentTooltipFunc[typedId]
end

function CraftingFrame:CreateRecipieRow(reagentId, reagentCount, reagentTooltip, tooltipHide)
  local reagentIcon = OCS.GUI:CreateWidget("InteractiveLabel")
  reagentIcon:SetImageSize(16, 16)
  reagentIcon:SetHeight(20)
  reagentIcon:SetWidth(20)
  reagentIcon:SetCallback("OnEnter", reagentTooltip)
  reagentIcon:SetCallback("OnLeave", tooltipHide)
  local reagentLabel = OCS.GUI:CreateWidget("InteractiveLabel")
  reagentLabel.label:SetJustifyV("MIDDLE")
  reagentLabel.label:SetHeight(19)
  reagentLabel:SetHeight(19)
  reagentLabel:SetText("0 / "..reagentCount.." x ???")
  reagentLabel:SetCallback("OnEnter", reagentTooltip)
  reagentLabel:SetCallback("OnLeave", tooltipHide)
  local reagentCost = OCS.GUI:CreateWidget("Label")
  reagentCost.label:SetJustifyH("RIGHT")
  reagentCost.label:SetJustifyV("MIDDLE")
  reagentCost.label:SetHeight(19)
  reagentCost:SetText("???")
  return {
    id = reagentId, count = reagentCount,
    icon = reagentIcon, label = reagentLabel, cost = reagentCost
  }
end

function CraftingFrame:UpdateRecipieRow(recipeRow, quantity)
  local itemIcon = GetItemIcon(recipeRow.id)
  local itemName, itemLink, _, _, _, _, _, _, _, _, itemSellPrice = GetItemInfo(recipeRow.id)
  local reagentCount = recipeRow.count * quantity
  local reagentCountOnHand = min(reagentCount, OCS.Inventory:GetItemsOnHand(recipeRow.id))
  local reagentItemCost = self.source:GetItemPrice(recipeRow.id, reagentCount)
  if recipeRow.icon and itemIcon then
    recipeRow.icon:SetImage(itemIcon)
  end
  local reagentCountText = reagentCountOnHand.." / "..reagentCount
  if (reagentCountOnHand == 0) then
    reagentCountText = "|cffff8080"..reagentCountText.."|r"
  elseif (reagentCountOnHand < reagentCount) then
    reagentCountText = "|cffffff80"..reagentCountText.."|r"
  else
    reagentCountText = "|cff80ff80"..reagentCountText.."|r"
  end
  if recipeRow.label and itemName then
    recipeRow.label:SetText(reagentCountText.." x "..itemName)
  else
    recipeRow.label:SetText(reagentCountText.." x ???")
  end
  if recipeRow.cost and reagentItemCost then
    recipeRow.cost:SetText(OCS.Utils:FormatMoney(reagentItemCost))
  else
    recipeRow.cost:SetText("???")
  end
  return reagentItemCost or 0
end

function CraftingFrame:CreateRecipieDetails(recipeData, skillProf)
  if not self.recipeDetails then
    self.recipeDetails = OCS.GUI:CreateWidget("InlineGroup")
    self.professionList:AddChild(self.recipeDetails)
  else
    self.recipeDetails:ReleaseChildren()
  end
  if recipeData and skillProf then
    local recipeLink = recipeData.itemLink or recipeData.skillLink
    --self:Log("Recipe Details: "..skillProf, "debug", recipeData)
    self.recipeDetails:SetLayout("Manual")
    -- Recipe icon
    local recipeIcon = OCS.GUI:CreateWidget("InteractiveLabel")
    local name, _, icon = GetSpellInfo(recipeData.skillId)
    recipeIcon:SetImage(recipeData.skillIcon or icon)
    recipeIcon:SetImageSize(48, 48)
    recipeIcon:SetCallback("OnEnter", self:GetReagentTooltipFunc(recipeLink))
    recipeIcon:SetCallback("OnLeave", self:GetHideTooltipFunc())
    recipeIcon:SetCallback("OnClick", function()
      SetItemRef(recipeData.skillLink, recipeData.skillLink, "LeftButton")
    end)
    recipeIcon:SetWidth(48)
    self.recipeDetails:AddChild(recipeIcon)
    -- Recipe label
    local recipeLabel = OCS.GUI:CreateWidget("InteractiveLabel")
    recipeLabel:SetFontObject(GameFontHighlightLarge)
    recipeLabel:SetText(name)
    recipeLabel:SetCallback("OnEnter", self:GetReagentTooltipFunc(recipeLink))
    recipeLabel:SetCallback("OnLeave", self:GetHideTooltipFunc())
    self.recipeDetails:AddChild(recipeLabel)
    --Recipe reagents
    local tableData = { columns = { 20, 9, 100 }, space = 2, align = "TOPLEFT" }
    local recipeReagents = OCS.GUI:CreateWidget("SimpleGroup")
    recipeReagents:SetLayout("Table")
    recipeReagents:PauseLayout()
    recipeReagents:SetUserData("table", tableData)
    local reagentWidgets = {}
    for reagentId, reagentCount in pairs(recipeData.reagents) do
      local reagentWidgetRow = self:CreateRecipieRow(reagentId, reagentCount);
      local _, reagentLink = GetItemInfo(reagentId)
      if not reagentLink then
        reagentLink = recipeData.skillLink
      end
      reagentWidgetRow.icon:SetCallback("OnEnter", self:GetReagentTooltipFunc(reagentLink))
      reagentWidgetRow.icon:SetCallback("OnLeave", self:GetHideTooltipFunc())
      reagentWidgetRow.icon:SetCallback("OnClick", function()
        SetItemRef(reagentLink, reagentLink, "LeftButton")
      end)
      reagentWidgetRow.label:SetCallback("OnEnter", self:GetReagentTooltipFunc(reagentLink))
      reagentWidgetRow.label:SetCallback("OnLeave", self:GetHideTooltipFunc())
      recipeReagents:AddChild(reagentWidgetRow.icon)
      recipeReagents:AddChild(reagentWidgetRow.label)
      recipeReagents:AddChild(reagentWidgetRow.cost)
      tinsert(reagentWidgets, reagentWidgetRow)
    end
    local reagentWidgetsOverall = self:CreateRecipieRow("overall", 1);
    reagentWidgetsOverall.icon:SetImage("Interface\\Icons\\inv_misc_coin_02")
    reagentWidgetsOverall.label:SetText(OCS.L["MODULE_SOURCE_CRAFTING_PRICE_TOTAL"])
    recipeReagents:AddChild(reagentWidgetsOverall.icon)
    recipeReagents:AddChild(reagentWidgetsOverall.label)
    recipeReagents:AddChild(reagentWidgetsOverall.cost)
    self.recipeDetails:AddChild(recipeReagents)
    -- Actions / Queue
    local recipeActions = OCS.GUI:CreateWidget("SimpleGroup")
    recipeActions:SetFullWidth(true)
    recipeActions:SetLayout("Flow")
    local recipeActionLess = OCS.GUI:CreateWidget("Button")
    recipeActionLess:SetAutoWidth(true)
    recipeActionLess:SetText(OCS.L["MODULE_SOURCE_CRAFTING_BTN_LESS"])
    recipeActions:AddChild(recipeActionLess)
    local recipeActionQuantity = OCS.GUI:CreateWidget("EditBox")
    recipeActionQuantity:DisableButton(true)
    recipeActionQuantity:SetWidth(80)
    recipeActionQuantity:SetText("1")
    recipeActions:AddChild(recipeActionQuantity)
    local recipeActionMore = OCS.GUI:CreateWidget("Button")
    recipeActionMore:SetAutoWidth(true)
    recipeActionMore:SetText(OCS.L["MODULE_SOURCE_CRAFTING_BTN_MORE"])
    recipeActions:AddChild(recipeActionMore)
    local recipeActionCraft = OCS.GUI:CreateWidget("Button")
    recipeActionCraft:SetAutoWidth(true)
    recipeActionCraft:SetText(OCS.L["MODULE_SOURCE_CRAFTING_BTN_CRAFT"])
    recipeActions:AddChild(recipeActionCraft)
    local recipeActionCraftAll = OCS.GUI:CreateWidget("Button")
    recipeActionCraftAll:SetAutoWidth(true)
    recipeActionCraftAll:SetText(OCS.L["MODULE_SOURCE_CRAFTING_BTN_CRAFT_ALL"])
    recipeActions:AddChild(recipeActionCraftAll)
    local recipeQueue = OCS.GUI:CreateWidget("SimpleGroup")
    recipeQueue:SetFullWidth(true)
    recipeQueue:SetLayout("Flow")
    local recipeQueueChar = OCS.GUI:CreateWidget("Dropdown")
    local recipeQueueCharAvailable = false
    local recipeQueueCharSelected = "__AUTO"
    local recipeQueueCharList = { ["__AUTO"] = OCS.L["MODULE_SOURCE_CRAFTING_CHARACTER_AUTO"] }
    local recipeQueueCharOrder = { "__AUTO" }
    for i, charName in ipairs(self.source:GetPlayerCrafters(skillProf, recipeData.skillId)) do
      recipeQueueCharList[charName] = charName
      tinsert(recipeQueueCharOrder, charName)
      recipeQueueCharAvailable = true
    end
    recipeQueueChar:SetWidth(180)
    recipeQueueChar:SetList(recipeQueueCharList, recipeQueueCharOrder)
    recipeQueueChar:SetValue("__AUTO")
    recipeQueueChar:SetText(OCS.L["MODULE_SOURCE_CRAFTING_BTN_QUEUE"])
    recipeQueue:AddChild(recipeQueueChar)
    local recipeQueueButton = OCS.GUI:CreateWidget("Button")
    recipeQueueButton:SetAutoWidth(true)
    recipeQueueButton:SetText(OCS.L["MODULE_SOURCE_CRAFTING_BTN_QUEUE"])
    recipeQueue:AddChild(recipeQueueButton)
    self.recipeDetails:AddChild(recipeActions)
    self.recipeDetails:AddChild(recipeQueue)
    -- Action / Queue scripts
    local recipeQuantity = 1
    local playerCraftIndex = self.source:CanPlayerCraft(skillProf, recipeData.skillId)
    local function reagentPriceUpdate()
      local overallItemCost = 0
      for i, reagentWidgetRow in ipairs(reagentWidgets) do
        overallItemCost = overallItemCost + self:UpdateRecipieRow(reagentWidgetRow, recipeQuantity)
      end
      if (overallItemCost > 0) then
        reagentWidgetsOverall.icon.frame:Show()
        reagentWidgetsOverall.label.frame:Show()
        reagentWidgetsOverall.cost.frame:Show()
        reagentWidgetsOverall.cost:SetText(OCS.Utils:FormatMoney(overallItemCost))
      else
        reagentWidgetsOverall.icon.frame:Hide()
        reagentWidgetsOverall.label.frame:Hide()
        reagentWidgetsOverall.cost.frame:Hide()
      end
    end
    if playerCraftIndex then
      recipeActionCraft:SetDisabled(false)
      recipeActionCraft:SetCallback("OnClick", function()
        if recipeData.skillType == "tradeskill" then
          local _, _, numAvailable = GetTradeSkillInfo(playerCraftIndex)
          DoTradeSkill(playerCraftIndex, min(numAvailable, recipeQuantity))
        end
      end)
      recipeActionCraftAll:SetDisabled(false)
      recipeActionCraftAll:SetCallback("OnClick", function()
        if recipeData.skillType == "tradeskill" then
          local _, _, numAvailable = GetTradeSkillInfo(playerCraftIndex)
          DoTradeSkill(playerCraftIndex, numAvailable)
        end
      end)
    else
      recipeActionCraft:SetDisabled(true)
      recipeActionCraftAll:SetDisabled(true)
    end
    if recipeQueueCharAvailable then
      recipeQueueChar:SetDisabled(false)
      recipeQueueChar:SetValue(recipeQueueCharSelected)
      recipeQueueChar:SetCallback("OnValueChanged", function(widget, _, char)
        recipeQueueCharSelected = char
      end)
      recipeQueueButton:SetDisabled(false)
      recipeQueueButton:SetCallback("OnClick", function()
        local craftChars = { recipeQueueCharSelected }
        if recipeQueueCharSelected == "__AUTO" then
          craftChars = self.source:GetPlayerCrafters(skillProf, recipeData.skillId)
        end
        self.source:QueueCraft(skillProf, recipeData.skillId, recipeQuantity, craftChars)
      end)
    else
      recipeQueueChar:SetDisabled(true)
      recipeQueueButton:SetDisabled(true)
      recipeQueueButton:SetCallback("OnClick", nil)
    end
    recipeActionLess:SetCallback("OnClick", function()
      if recipeQuantity > 1 then
        recipeQuantity = recipeQuantity - 1
        recipeActionQuantity:SetText(recipeQuantity)
        reagentPriceUpdate()
      end
    end)
    recipeActionMore:SetCallback("OnClick", function()
      if recipeQuantity < 1000 then
        recipeQuantity = recipeQuantity + 1
        recipeActionQuantity:SetText(recipeQuantity)
        reagentPriceUpdate()
      end
    end)
    recipeActionQuantity:SetCallback("OnTextChanged", function(widget, _, text)
      local newValue = tonumber(text)
      if newValue and newValue >= 1 then
        recipeQuantity = newValue
        reagentPriceUpdate()
      end
    end)
    -- Update reagent prices
    reagentPriceUpdate()
    -- Position frames
    self.recipeDetails.frame:Show()
    recipeIcon:ClearAllPoints()
    recipeIcon:SetPoint("TOPLEFT")
    recipeLabel:ClearAllPoints()
    recipeLabel:SetPoint("TOPLEFT", recipeIcon.frame, "TOPRIGHT", 8, 0)
    recipeLabel:SetPoint("TOPRIGHT")
    recipeLabel:SetHeight(20)
    recipeLabel:SetWidth(self.recipeDetails.content:GetWidth() - 160)
    recipeReagents:ClearAllPoints()
    recipeReagents:SetPoint("TOPLEFT", recipeLabel.frame, "BOTTOMLEFT", 0, -4)
    recipeReagents:SetWidth(self.recipeDetails.content:GetWidth() - 160)
    recipeReagents:ResumeLayout()
    recipeReagents:DoLayout()
    recipeQueue:ClearAllPoints()
    recipeQueue:SetPoint("BOTTOMLEFT")
    recipeQueue:SetPoint("BOTTOMRIGHT")
    recipeActions:ClearAllPoints()
    recipeActions:SetPoint("BOTTOMLEFT", recipeQueue.frame, "TOPLEFT")
    recipeActions:SetPoint("BOTTOMRIGHT", recipeQueue.frame, "TOPRIGHT")
    -- Limit recipe table
    self.recipeTable:ClearAllPoints()
    self.recipeTable:SetPoint("TOPLEFT", self.searchBar.frame, "BOTTOMLEFT")
    self.recipeTable:SetPoint("TOPRIGHT", self.searchBar.frame, "BOTTOMRIGHT")
    self.recipeTable:SetPoint("BOTTOMRIGHT", self.recipeDetails.frame, "TOPRIGHT")
    self.recipeDetails:ClearAllPoints()
    self.recipeDetails:SetPoint("BOTTOMLEFT", -10, -12)
    self.recipeDetails:SetPoint("BOTTOMRIGHT", 10, -12)
    -- Callbacks
    local function getRecipeHeight()
      return max(
        recipeIcon.frame:GetHeight() + recipeQueue.frame:GetHeight() + recipeActions.frame:GetHeight(),
        recipeLabel.frame:GetHeight() + recipeReagents.frame:GetHeight() + recipeQueue.frame:GetHeight() + recipeActions.frame:GetHeight()
      ) + 44
    end
    self.recipeDetails:SetHeight(getRecipeHeight())
    recipeReagents:DoLayout()
    -- Secure action buttons for crafting api
    if recipeData.skillType == "craft" then
      CraftFrame_SetSelection(playerCraftIndex)
			CraftCreateButton:SetParent(recipeActionCraft.frame)
			CraftCreateButton:ClearAllPoints()
			CraftCreateButton:SetAllPoints(recipeActionCraft.frame)
			CraftCreateButton:SetFrameLevel(200)
			CraftCreateButton:DisableDrawLayer("BACKGROUND")
			CraftCreateButton:DisableDrawLayer("ARTWORK")
			CraftCreateButton:SetHighlightTexture(nil)
			CraftCreateButton:Enable()
      recipeActionCraftAll:SetDisabled(true)
      recipeQueueButton:SetDisabled(true)
    else
      self:ResoreDefaultCraftButton()
    end
  end
  return self.recipeDetails
end

function CraftingFrame:ResoreDefaultCraftButton()
  CraftCreateButton:SetParent(CraftFrame)
  CraftCreateButton:ClearAllPoints()
  CraftCreateButton:SetPoint("CENTER", CraftFrame, "TOPLEFT", 224, -422)
  CraftCreateButton:SetFrameLevel(2)
  CraftCreateButton:EnableDrawLayer("BACKGROUND")
  CraftCreateButton:EnableDrawLayer("ARTWORK")
  CraftCreateButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
  CraftCreateButton:GetHighlightTexture():SetTexCoord(0, 0.625, 0, 0.6875)
end

function CraftingFrame:HideRecipieDetails()
  if self.recipeDetails then
    self.recipeDetails:SetHeight(0)
    self.recipeDetails:ReleaseChildren()
    self.recipeDetails.frame:Hide()
    self.recipeTable:SetPoint("TOPLEFT", self.searchBar.frame, "BOTTOMLEFT")
    self.recipeTable:SetPoint("TOPRIGHT", self.searchBar.frame, "BOTTOMRIGHT")
    self.recipeTable:SetPoint("BOTTOMRIGHT")
  end
end

function CraftingFrame:GetReplaceCrafting()
  return self:GetStorageValue("ReplaceCrafting", true)
end

function CraftingFrame:SetReplaceCrafting(doReplace)
  self:SetStorageValue("ReplaceCrafting", doReplace)
end

function CraftingFrame:GetProfessionTree()
  local charStorage = self.source:GetCharacterStorage()
  -- Group by skill instead of char
  local skillsGrouped = {}
  for charName, charSkills in pairs(charStorage) do
    for skillString in pairs(charSkills) do
      if not skillsGrouped[skillString] then
        skillsGrouped[skillString] = {}
      end
      tinsert(skillsGrouped[skillString], charName)
    end
  end
  -- Build tree
  local tree = {}
  for skillString in pairs(skillsGrouped) do
    local skillChars = skillsGrouped[skillString]
    local skillCharsTree = {}
    local skillId = self.source:GetTradeSkillId(skillString)
    local skillName, _, skillIcon = GetSpellInfo(skillId)
    for i in ipairs(skillChars) do
      local charName = skillChars[i]
      tinsert(skillCharsTree, {
        value = charName, text = OCS.Utils:FormatCharacterName(charName)
      })
    end
    tinsert(tree, {
      value = skillString, text = skillName, icon = skillIcon,
      children = skillCharsTree
    })
  end
  return tree
end

function CraftingFrame:OnClose()
  if self.craftingType == "Craft" then
    CloseCraft();
    self.craftingType = "None"
  elseif self.craftingType == "TradeSkill" then
    CloseTradeSkill();
    self.craftingType = "None"
  end
end

function CraftingFrame:OnCraftShow()
  self:Log("OnCraftShow", "debug")
  if self:GetReplaceCrafting() then
    -- Open crafting window
    local skillProf = self.source:GetTradeSkillString(GetCraftDisplaySkillLine());
    local playerName = GetUnitName("player")
    self:Log("Show Crafting Window!", "debug", { skillProf, playerName })
    OCS.Frames:Show("Crafting")
    self.craftingType = "Craft"
    self.professionList:SelectByPath(skillProf, playerName)
    CraftFrame:SetScript("OnHide", nil)
    HideUIPanel(CraftFrame);
  end
end

function CraftingFrame:OnCraftClose()
  self:Log("OnCraftClose", "debug")
  if self:GetReplaceCrafting() and (self.craftingType == "Craft") then
    -- Open crafting window
    self:Hide()
    self:ResoreDefaultCraftButton()
  end
end

function CraftingFrame:OnTradeSkillShow()
  self:Log("OnTradeSkillShow", "debug")
  if self:GetReplaceCrafting() then
    -- Open crafting window
    local skillProf = self.source:GetTradeSkillString(GetTradeSkillLine());
    local playerName = GetUnitName("player")
    self:Log("Show Crafting Window!", "debug", { skillProf, playerName })
    OCS.Frames:Show("Crafting")
    self.craftingType = "TradeSkill"
    self.professionList:SelectByPath(skillProf, playerName)
    if TradeSkillFrame then
      TradeSkillFrame:SetScript("OnHide", nil)
      HideUIPanel(TradeSkillFrame);
    end
  end
end

function CraftingFrame:OnTradeSkillClose()
  self:Log("OnTradeSkillClose", "debug")
  if self:GetReplaceCrafting() and (self.craftingType == "TradeSkill") then
    -- Open crafting window
    self:Hide()
  end
end
