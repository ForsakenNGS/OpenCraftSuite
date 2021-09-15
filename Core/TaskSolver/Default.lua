-- WoW auctionhouse source
local _, OCS = ...
local DefaultTaskSolver = OCS.TaskSolver:Add("Default")

function DefaultTaskSolver:Create()
  -- TODO: Create task for fetching an item from the bank
  return nil
end

function DefaultTaskSolver:GetSolveableTasks(taskList, tasksById)
  local solvableTasks = {}
  for i, taskData in ipairs(taskList) do
    tinsert(solvableTasks, taskData.id)
  end
  return solvableTasks
end

function DefaultTaskSolver:SolveTasks()
  local playerName = UnitName("player")
  local itemsCharacter = {}
  local itemsGuild = {}
  local itemsPlayerHand = {}
  local itemsPlayerObtainable = {}
  -- Clone tables to not interfere with source data
  for itemId, itemCount in pairs(OCS.Inventory:GetItemsOnHand()) do
    itemsPlayerHand[itemId] = itemCount
  end
  for itemId, itemCount in pairs(OCS.Inventory:GetItemsObtainable()) do
    itemsPlayerObtainable[itemId] = itemCount
  end
  local mailItemsTo = {}
  local mailItems = false
  local obtainGuild = {}
  local obtainGuildFlag = false
  local obtainItems = {}
  local obtainItemsFlag = false
  local buyItems = {}
  local buyItemsFlag = false
  local tasksRelog = {}
  local tasksRelogFlag = false
  for i, taskData in ipairs(self.taskList) do
    if taskData.characterChosen then
      local charName = taskData.characterChosen
      -- Check for items available locally
      if not itemsCharacter[charName] then
        if charName ~= playerName then
          itemsCharacter[charName] = OCS.Inventory:GetItemsOnCharacter(nil, charName)
        else
          itemsCharacter[charName] = itemsPlayerHand
        end
      end
      local itemsRequired = self.itemsPendingByTask[taskData.id]
      local itemsAvailable = true
      for reqId, reqCount in pairs(itemsRequired) do
        if reqCount > 0 and itemsCharacter[charName][reqId] and itemsCharacter[charName][reqId] > 0 then
          local itemsUsed = min(reqCount, itemsCharacter[charName][reqId])
          reqCount = reqCount - itemsUsed
          itemsCharacter[charName][reqId] = itemsCharacter[charName][reqId] - itemsUsed
          itemsRequired[reqId] = reqCount
        end
        if reqCount > 0 then
          itemsAvailable = false
        end
      end
      if itemsAvailable then
        -- All items available at the target char. Task to relog
        self:Log("Relog due to "..charName)
        tasksRelog[taskData.id] = charName
        tasksRelogFlag = true
      else
        -- Check for items obtainable on current character, that are required for the task
        if charName ~= playerName then
          for reqId, reqCount in pairs(itemsRequired) do
            if reqCount > 0 and itemsPlayerHand[reqId] and itemsPlayerHand[reqId] > 0 then
              local itemsUsed = min(reqCount, itemsPlayerHand[reqId])
              reqCount = reqCount - itemsUsed
              itemsPlayerHand[reqId] = itemsPlayerHand[reqId] - itemsUsed
              itemsRequired[reqId] = reqCount
              -- Mail to crafter
              mailItems = true
              if not mailItemsTo[charName] then
                mailItemsTo[charName] = {}
              end
              if mailItemsTo[charName][reqId] then
                mailItemsTo[charName][reqId] = mailItemsTo[charName][reqId] + itemsUsed
              else
                mailItemsTo[charName][reqId] = itemsUsed
              end
            end
          end
        end
        -- Check for obtainable items
        for reqId, reqCount in pairs(itemsRequired) do
          if reqCount > 0 and itemsPlayerObtainable[reqId] and itemsPlayerObtainable[reqId] > 0 then
            local itemsUsed = min(reqCount, itemsPlayerObtainable[reqId])
            reqCount = reqCount - itemsUsed
            itemsPlayerObtainable[reqId] = itemsPlayerObtainable[reqId] - itemsUsed
            itemsRequired[reqId] = reqCount
            -- Obtain items
            obtainItemsFlag = true
            if obtainItems[reqId] then
              obtainItems[reqId] = obtainItems[reqId] + itemsUsed
            else
              obtainItems[reqId] = itemsUsed
            end
          end
        end
        -- Buy all remaining items
        for reqId, reqCount in pairs(itemsRequired) do
          if reqCount > 0 then
            buyItemsFlag = true
            buyItems[reqId] = reqCount
            itemsRequired[reqId] = 0
          end
        end
      end
    end
  end
  -- Create tasks based on collected information
  --self:Log("Solution: ", "debug", { mailItemsTo, obtainGuild, obtainItems, buyItems, relogTask })
  local tasksNew = {}
  if mailItems then
    -- Create mail task(s)
    for charName, mailItems in pairs(mailItemsTo) do
      local mailTasks = OCS.Inventory:SendItems(mailItems, charName, playerName)
      for _, taskData in ipairs(mailTasks) do
        tinsert(tasksNew, taskData)
      end
    end
  end
  if obtainItemsFlag then
    -- Obtain items task(s)
    local obtainTasks = OCS.Inventory:ObtainItems(obtainItems)
    for _, taskData in ipairs(obtainTasks) do
      tinsert(tasksNew, taskData)
    end
  end
  if buyItemsFlag then
    -- Buy items task(s)
    local buyTasks = OCS.Sources:BuyItems(buyItems)
    for _, taskData in ipairs(buyTasks) do
      tinsert(tasksNew, taskData)
    end
  end
  -- Add new tasks
  for _, taskData in ipairs(tasksNew) do
    tinsert(self.taskList, taskData)
    self.taskById[taskData.id] = taskData
  end
  -- Refresh dependencies to include the newly added tasks
  self:SolveDependencies()
  -- Add relog tasks after child dependencies are solved
  if tasksRelogFlag then
    for taskId, charTarget in pairs(tasksRelog) do
      local relogTask = OCS.Tasks:Create("Relog", charTarget)
      tinsert(self.taskList, relogTask)
      self.taskById[relogTask.id] = relogTask
      self:AddChildRequirement(taskId, relogTask.id)
    end
  end
end
