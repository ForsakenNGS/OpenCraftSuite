-- WoW auctionhouse source
local _, OCS = ...
local SourceCrafting = OCS.Sources:Add("Crafting")

function SourceCrafting:OnInitialize()
  self:RegisterEvent("CRAFT_SHOW", "OnCraftShow");
  self:RegisterEvent("TRADE_SKILL_UPDATE", "OnTradeSkillUpdate")
  self.frameCrafting = nil
  self.frameCraftingType = "None"
  self.frameProfessionList = nil
  self.frameProfessionTable = nil
  self.frameProfessionSearch = nil
  self.frameProfessionRecipe = nil
end

function SourceCrafting:DestroyCraftingFrame()
  if self.frameCrafting then
    self.frameCrafting.frame:SetMinResize(0, 0)
    self.frameCrafting:Release()
    self.frameCrafting = nil
    self.frameCraftingType = "None"
    self.frameProfessionList = nil
    self.frameProfessionTable = nil
    self.frameProfessionSearch = nil
    self.frameProfessionRecipe = nil
  end
end

function SourceCrafting:GetAceOptions()
  local options = {}
  if OCS:IsModulePresent("Frame", "Crafting") then
    options.ShowCrafting = {
      name = OCS.L["MODULE_SOURCE_CRAFTING_SHOW_FRAME"],
      type = "execute",
      order = 100,
      func = function() OCS.Frames:Show("Crafting") end
    }
  end
  if OCS:IsModulePresent("Frame", "TaskList") then
    options.ShowTaskList = {
      name = OCS.L["MODULE_TASKS_SHOW_FRAME"],
      type = "execute",
      order = 200,
      func = function() OCS.Frames:Show("TaskList") end
    }
  end
  return options
end

function SourceCrafting:QueueCraft(skillProf, skillId, quantity, craftChars)
  local task = OCS.Tasks:Create("Craft", skillProf, { [skillId] = quantity }, craftChars)
  OCS.Tasks:UpdateTasks()
end

function SourceCrafting:CheckSearchText(recipeData, searchText)
  if searchText == "" then
    -- No search filter
    return true
  end
  local _, searchItemId = OCS.Utils:ParseItemLink(searchText)
  if searchItemId then
    self:Log("Item Search: "..searchItemId)
    -- Search by required/produced items
    local _, recipeItemId = OCS.Utils:ParseItemLink(recipeData.itemLink)
    if (recipeItemId ~= searchItemId) and not recipeData.reagents[searchItemId] then
      return false
    end
  else
    -- Search by name
    local name = strlower(GetSpellInfo(recipeData.skillId))
    local searchWords = { strsplit(" ", searchText) }
    for i, searchWord in ipairs(searchWords) do
      if not strfind(name, strlower(searchWord)) then
        return false
      end
    end
  end
  return true
end

function SourceCrafting:CanPlayerCraft(skillString, skillId, charName)
  if not charName then
    charName = GetUnitName("player")
  end
  local charSkills = self:GetCharacterStorage(charName)
  if charSkills[skillString] then
    for i, recipeData in ipairs(charSkills[skillString]) do
      if (skillId == recipeData.skillId) then
        return recipeData.skillIndex
      end
    end
  end
  return nil
end

function SourceCrafting:GetPlayerCrafters(skillString, skillId)
  local result = {}
  local charStorage = self:GetCharacterStorage()
  for charName, charSkills in pairs(charStorage) do
    if charSkills[skillString] then
      for i, recipeData in ipairs(charSkills[skillString]) do
        if (skillId == recipeData.skillId) then
          tinsert(result, charName)
          break
        end
      end
    end
  end
  return result
end

function SourceCrafting:GetItemPrice(itemId, quantity)
  quantity = quantity or 1
  local priceResults = OCS.Sources:GetPrice(itemId, quantity)
  local priceLowest = nil
  for moduleName, moduleResults in pairs(priceResults) do
    for priceType, priceValue in pairs(moduleResults) do
      if priceValue and (not priceLowest or priceValue < priceLowest) then
        priceLowest = priceValue
      end
    end
  end
  return priceLowest
end

function SourceCrafting:GetRecipeCountFiltered(skillString, charName, searchText)
  local count = 0
  if charName then
    -- Filter recipes of an individual character
    local recipeResultUnfiltered = self:GetRecipeData(skillString, charName)
    for i, recipeData in ipairs(recipeResultUnfiltered) do
      if self:CheckSearchText(recipeData, searchText) then
        count = count + 1
      end
    end
  else
    -- Filter all recipes for the given profession
    local charStorage = self:GetCharacterStorage()
    local recipeIds = {}
    for charName, charSkills in pairs(charStorage) do
      if (charSkills[skillString]) then
        for i, recipeData in ipairs(charSkills[skillString]) do
          if not tContains(recipeIds, recipeData.skillId) and self:CheckSearchText(recipeData, searchText) then
            tinsert(recipeIds, recipeData.skillId)
            count = count + 1
          end
        end
      end
    end
  end
  return count
end

function SourceCrafting:GetRecipeDataFiltered(skillString, charName, searchText)
  local recipeResult = {}
  -- Filter recipes of an individual character
  local recipeResultUnfiltered = self:GetRecipeData(skillString, charName)
  for i, recipeData in ipairs(recipeResultUnfiltered) do
    if self:CheckSearchText(recipeData, searchText) then
      tinsert(recipeResult, recipeData)
    end
  end
  return recipeResult
end

function SourceCrafting:GetRecipeDataById(skillString, skillId, charName)
  if not charName then
    local recipeData = nil
    local charStorage = self:GetCharacterStorage()
    for charName, charSkills in pairs(charStorage) do
      recipeData = recipeData or self:GetRecipeDataById(skillString, skillId, charName)
    end
    return recipeData
  else
    local charSkills = self:GetCharacterStorage(charName)
    if charSkills[skillString] then
      for i, recipeData in ipairs(charSkills[skillString]) do
        if recipeData.skillId == skillId then
          return recipeData
        end
      end
    end
    return nil
  end
end

function SourceCrafting:GetRecipeData(skillString, charName, recipeIndex)
  if charName then
    local charSkills = self:GetCharacterStorage(charName)
    if recipeIndex then
      return charSkills[skillString][recipeIndex]
    else
      return charSkills[skillString]
    end
  else
    local recipesByChar = {}
    local recipesList = {}
    local charsByRecipe = {}
    local charStorage = self:GetCharacterStorage()
    for charName, charSkills in pairs(charStorage) do
      if (charSkills[skillString]) then
        recipesByChar[charName] = charSkills[skillString]
        for i, recipeData in ipairs(charSkills[skillString]) do
          if not charsByRecipe[recipeData.skillId] then
            charsByRecipe[recipeData.skillId] = {}
            tinsert(recipesList, recipeData)
          end
          tinsert(charsByRecipe[recipeData.skillId], charName)
        end
      end
    end
    for charName, charRecipes in pairs(charsByRecipe) do
      if (charRecipes[skillString]) then
        for i, recipeData in ipairs(charRecipes[skillString]) do
          recipeData.characters = charsByRecipe[recipeData.skillId] or {}
        end
      end
    end
    return recipesList
  end
end

function SourceCrafting:GetRecipeCount(skillString, charName, searchText)
  if charName then
    -- Get recipe count for specific character
    local charSkills = self:GetCharacterStorage(charName)
    if charSkills[skillString] then
      return #(charSkills[skillString])
    else
      return 0
    end
  else
    -- Get count of unique recipes for the given profession accross all chars
    local recipeIds = {}
    local charStorage = self:GetCharacterStorage()
    for charName, charSkills in pairs(charStorage) do
      if (charSkills[skillString]) then
        for i, recipeData in ipairs(charSkills[skillString]) do
          if not tContains(recipeIds, recipeData.skillId) then
            tinsert(recipeIds, recipeData.skillId)
          end
        end
      end
    end
    return #(recipeIds)
  end
  return 0
end

function SourceCrafting:GetProfessions()
  local charStorage = self:GetCharacterStorage()
  local results = {}
  for charName, charSkills in pairs(charStorage) do
    for skillString in pairs(charSkills) do
      if not tContains(results, skillString) then
        tinsert(results, skillString)
      end
    end
  end
  return results
end

function SourceCrafting:GetProfessionTree()
  local charStorage = self:GetCharacterStorage()
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
    local skillId = self:GetTradeSkillId(skillString)
    local skillName, _, skillIcon = GetSpellInfo(skillId)
    for i in ipairs(skillChars) do
      local charName = skillChars[i]
      tinsert(skillCharsTree, {
        value = charName, text = charName
      })
    end
    tinsert(tree, {
      value = skillString, text = skillName, icon = skillIcon,
      children = skillCharsTree
    })
  end
  return tree
end

function SourceCrafting:GetTradeSkillId(skillString)
  if (skillString == "ALCHEMY") then
    return 28596
  elseif (skillString == "BLACKSMITHING") then
    return 29844
  elseif (skillString == "COOKING") then
    return 33359
  elseif (skillString == "ENCHANTING") then
    return 28029
  elseif (skillString == "ENGINEERING") then
    return 30350
  elseif (skillString == "FIRST_AID") then
    return 27028
  elseif (skillString == "FISHING") then
    return 33095
  elseif (skillString == "HERBALISM") then
    return 28695
  elseif (skillString == "JEWELCRAFTING") then
    return 28897
  elseif (skillString == "MINING") then
    return 29354
  elseif (skillString == "LEATHERWORKING") then
    return 32549
  elseif (skillString == "SKINNING") then
    return 32678
  elseif (skillString == "TAILORING") then
    return 26790
  end
end

function SourceCrafting:GetTradeSkillString(name)
  if (name == GetSpellInfo(self:GetTradeSkillId("ALCHEMY"))) then
    return "ALCHEMY"
  elseif (name == GetSpellInfo(self:GetTradeSkillId("BLACKSMITHING"))) then
    return "BLACKSMITHING"
  elseif (name == GetSpellInfo(self:GetTradeSkillId("COOKING"))) then
    return "COOKING"
  elseif (name == GetSpellInfo(self:GetTradeSkillId("ENCHANTING"))) then
    return "ENCHANTING"
  elseif (name == GetSpellInfo(self:GetTradeSkillId("ENGINEERING"))) then
    return "ENGINEERING"
  elseif (name == GetSpellInfo(self:GetTradeSkillId("FIRST_AID"))) then
    return "FIRST_AID"
  elseif (name == GetSpellInfo(self:GetTradeSkillId("FISHING"))) then
    return "FISHING"
  elseif (name == GetSpellInfo(self:GetTradeSkillId("HERBALISM"))) then
    return "HERBALISM"
  elseif (name == GetSpellInfo(self:GetTradeSkillId("JEWELCRAFTING"))) then
    return "JEWELCRAFTING"
  elseif (name == GetSpellInfo(self:GetTradeSkillId("MINING"))) then
    return "MINING"
  elseif (name == GetSpellInfo(self:GetTradeSkillId("LEATHERWORKING"))) then
    return "LEATHERWORKING"
  elseif (name == GetSpellInfo(self:GetTradeSkillId("SKINNING"))) then
    return "SKINNING"
  elseif (name == GetSpellInfo(self:GetTradeSkillId("TAILORING"))) then
    return "TAILORING"
  end
  return nil
end

function SourceCrafting:OnCraftShow()
  self:Log("OnCraftShow", "debug")
  local skillProf = self:GetTradeSkillString(GetCraftDisplaySkillLine());
  local skillCount = GetNumCrafts();
  local playerName = GetUnitName("player")
  local charSkills = self:GetCharacterStorage(playerName)
  self:Log("Craft Update: "..skillProf, "debug")
  charSkills[skillProf] = {}
  for i = 1, skillCount do
    local skillLink = GetCraftItemLink(i)
    if skillLink then
      local idTyped, id, name, type, color = OCS.Utils:ParseItemLink(skillLink)
      local reagentCount = GetCraftNumReagents(i)
      local reagents = {}
      for j = 1, reagentCount do
        local reagentName, reagentTexture, reagentCount = GetCraftReagentInfo(i, j);
        local reagentLink = GetCraftReagentItemLink(i, j)
        local _, reagentId = OCS.Utils:ParseItemLink(reagentLink)
        reagents[reagentId] = reagentCount
      end
      tinsert(charSkills[skillProf], {
        skillId = id, skillIndex = i, skillType = "craft", skillLink = skillLink, reagents = reagents
      })
    end
  end
end

function SourceCrafting:OnTradeSkillUpdate()
  local skillProf = self:GetTradeSkillString(GetTradeSkillLine());
  local skillCount = GetNumTradeSkills();
  local playerName = GetUnitName("player")
  local charSkills = self:GetCharacterStorage(playerName)
  self:Log("TradeSkill Update: "..skillProf, "debug")
  charSkills[skillProf] = {}
  for i = 1, skillCount do
    local skillLink = GetTradeSkillRecipeLink(i)
    if skillLink then
      local skillIcon = GetItemIcon(GetTradeSkillIcon(i) or 0)
      local skillItemLink = GetTradeSkillItemLink(i)
      local _, skillItemId = OCS.Utils:ParseItemLink(skillItemLink)
      if skillItemId then
        skillIcon = GetItemIcon(skillItemId) or skillIcon
      end
      local idTyped, id, name, type, color = OCS.Utils:ParseItemLink(skillLink)
      local reagentCount = GetTradeSkillNumReagents(i)
      local reagents = {}
      for j = 1, reagentCount do
        local reagentName, reagentTexture, reagentCount = GetTradeSkillReagentInfo(i, j);
        local reagentLink = GetTradeSkillReagentItemLink(i, j)
        local _, reagentId = OCS.Utils:ParseItemLink(reagentLink)
        reagents[reagentId] = reagentCount
      end
      tinsert(charSkills[skillProf], {
        skillId = id, skillIndex = i, skillType = "tradeskill",
        skillIcon = skillIcon, skillLink = skillLink,
        reagents = reagents,
        itemLink = skillItemLink, itemId = skillItemId, itemCount = GetTradeSkillNumMade(i)
      })
    end
  end
end
