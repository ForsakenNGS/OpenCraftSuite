-- Inventory framework
local _, OCS = ...

OCS.TaskSolverBase = OCS.ModuleBase:Inherit()

function OCS.TaskSolverBase:New(name, module)
  -- Parent class
  module = OCS.ModuleBase:New("TaskSolver", name, module)
  -- Private variables
  module.taskList = module.taskList or {}
  module.taskById = module.taskById or {}
  module.itemsAvailable = module.itemsAvailable or {}
  module.itemsPendingByTask = module.itemsPendingByTask or {}
  module.itemsPendingOverall = module.itemsPendingOverall or {}
  module.childsRequired = module.childsRequired or {}
  module.parentsRequired = module.parentsRequired or {}
  -- Inheritance
  module = module or {}
  setmetatable(module, self)
  self.__index = self
  return module
end

function OCS.TaskSolverBase:AddChild(parentId, childId)
  local taskParent, taskChild = self.taskById[parentId], self.taskById[childId]
  if taskParent and taskChild then
    if not tContains(taskParent.children, childId) then
      tinsert(taskParent.children, childId)
    end
    if not tContains(taskChild.parents, parentId) then
      tinsert(taskChild.parents, parentId)
    end
  end
end

function OCS.TaskSolverBase:AddChildRequirement(parentId, childId)
  -- Remember child
  if not self.childsRequired[parentId] then
    self.childsRequired[parentId] = {}
  end
  if not tContains(self.childsRequired[parentId], childId) then
    tinsert(self.childsRequired[parentId], childId)
  end
  --  Remember parent
  if not self.parentsRequired[childId] then
    self.parentsRequired[childId] = {}
  end
  if not tContains(self.parentsRequired[childId], parentId) then
    tinsert(self.parentsRequired[childId], parentId)
  end
end

-- Solve tasks by input
function OCS.TaskSolverBase:FindChildTasks(taskParent)
  local result = {}
  for i, taskData in ipairs(self.taskList) do
    if (taskData.id ~= taskParent.id) and self:IsDependingOnTask(taskParent, taskData) == -1 then
      tinsert(result, taskData.id)
    end
  end
  return result
end

-- Check for item dependencies between the given Tasks
-- Return values: 0 = No dependencies, -1 = Task A depends on Task B, 1 = Task B depends on Task A
function OCS.TaskSolverBase:IsDependingOnTask(taskA, taskB)
  for itemReqId, itemReqCount in pairs(taskA.itemsRequired) do
    for itemProdId, itemProdCount in pairs(taskB.itemsProduced) do
      if itemReqId == itemProdId then
        -- Match! Task A requires somthing from Task B
        return -1
      end
    end
  end
  for itemReqId, itemReqCount in pairs(taskB.itemsRequired) do
    for itemProdId, itemProdCount in pairs(taskA.itemsProduced) do
      if itemReqId == itemProdId then
        -- Match! Task B requires somthing from Task A
        return 1
      end
    end
  end
  -- No dependencies on each other
  return 0
end

function OCS.TaskSolverBase:IsChildRecursive(parentId, childId, limit, level)
  if not level then
    level = 1
  end
  local childData = self.taskById[childId]
  for i, childRecurId in ipairs(childData.children) do
    if childRecurId == parentId then
      level = limit
      break
    else
      level = max(level, self:IsChildRecursive(parentId, childRecurId, limit, level + 1))
    end
  end
  return level
end

function OCS.TaskSolverBase:IsChildRequirementRecursive(parentId, childId, limit, level)
  if not level then
    level = 1
  end
  if self.childsRequired[childId] then
    for i, childRecurId in ipairs(self.childsRequired[childId]) do
      if childRecurId == parentId then
        level = limit
        break
      else
        level = max(level, self:IsChildRequirementRecursive(parentId, childRecurId, limit, level + 1))
      end
    end
  end
  local childData = self.taskById[childId]
  for i, childRecurId in ipairs(childData.children) do
    if childRecurId == parentId then
      level = limit
      break
    else
      level = max(level, self:IsChildRequirementRecursive(parentId, childRecurId, limit, level + 1))
    end
  end
  return level
end

function OCS.TaskSolverBase:GetTasks()
  return self.taskList, self.taskById
end

function OCS.TaskSolverBase:SetTasks(taskList, taskById)
  self.taskList = taskList
  if taskById then
    self.taskById = taskById
  else
    self.taskById = {}
    for i, taskData in ipairs(taskList) do
      self.taskById[taskData.id] = taskData
    end
  end
  self:SolveDependencies()
end


function OCS.TaskSolverBase:SolveDependencies()
  self.itemsAvailable = {}
  self.itemsPendingByTask = {}
  self.itemsPendingOverall = {}
  self.childsRequired = {}
  self.parentsRequired = {}
  -- Gather available items
  for i, taskData in ipairs(self.taskList) do
    for prodId, prodCount in pairs(taskData.itemsProduced) do
      if self.itemsAvailable[prodId] then
        self.itemsAvailable[prodId] = self.itemsAvailable[prodId] + prodCount
      else
        self.itemsAvailable[prodId] = prodCount
      end
    end
    self.itemsPendingByTask[taskData.id] = {}
    for reqId, reqCount in pairs(taskData.itemsRequired) do
      self.itemsPendingByTask[taskData.id][reqId] = reqCount
      if self.itemsPendingOverall[reqId] then
        self.itemsPendingOverall[reqId] = self.itemsPendingOverall[reqId] + reqCount
      else
        self.itemsPendingOverall[reqId] = reqCount
      end
    end
  end
  -- Gather pending items
  for i, taskData in ipairs(self.taskList) do
    local taskId = taskData.id
    local itemsPending = self.itemsPendingByTask[taskId]
    local childList = self:FindChildTasks(taskData)
    for _, childData in ipairs(self.taskList) do
      if tContains(childList, childData.id) and self:IsChildRequirementRecursive(taskId, childData.id, 5) < 5 then
        local childId = childData.id
        for reqId, reqCount in pairs(itemsPending) do
          if reqCount > 0 and self.itemsAvailable[reqId] and self.itemsAvailable[reqId] > 0 and childData.itemsProduced[reqId] then
            local itemsUsed = min(childData.itemsProduced[reqId], reqCount)
            itemsPending[reqId] = reqCount - itemsUsed
            self.itemsAvailable[reqId] = self.itemsAvailable[reqId] - itemsUsed
            self.itemsPendingOverall[reqId] = self.itemsPendingOverall[reqId] - itemsUsed
            self:AddChildRequirement(taskId, childId)
          end
        end
      end
    end
  end
end

function OCS.TaskSolverBase:UpdateDependencies()
  for i, taskData in ipairs(self.taskList) do
    if self.childsRequired[taskData.id] then
      taskData.children = self.childsRequired[taskData.id]
    else
      wipe(taskData.children)
    end
    if self.parentsRequired[taskData.id] then
      taskData.parents = self.parentsRequired[taskData.id]
    else
      wipe(taskData.parents)
    end
  end
end

-- Get a list of tasks that can be solved by this module
function OCS.TaskSolverBase:GetSolveableTasks(taskList, tasksById)
  return {}
end

function OCS.TaskSolverBase:TreeSortTasks(parentId, sortFunc, left)
  local overallChilds = 0
  if parentId then
    local taskParent = self.taskById[parentId]
    local tasksChilds = {}
    for _, taskId in ipairs(taskParent.children or {}) do
      tinsert(tasksChilds, self.taskById[taskId])
    end
    -- Sort child tasks
    if sortFunc then
      sort(tasksChilds, sortFunc)
    end
    -- Recurse children in order
    for i, taskData in ipairs(tasksChilds) do
      local childCount = self:TreeSortTasks(taskData.id, sortFunc, left + 1)
      taskData.nestedSet = {
        left = left,
        right = left + 1 + childCount * 2
      }
      left = taskData.nestedSet.right + 1
      overallChilds = overallChilds + childCount + 1
    end
  else
    left = 1
    -- Get root level tasks
    local tasksRoot = {}
    for i, taskData in ipairs(self.taskList) do
      tinsert(tasksRoot, taskData)
    end
    -- Sort root tasks
    if sortFunc then
      sort(tasksRoot, sortFunc)
    end
    -- Recurse children in order
    for i, taskData in ipairs(tasksRoot) do
      if not taskData.parents or #(taskData.parents) == 0 then
        local childCount = self:TreeSortTasks(taskData.id, sortFunc, left + 1)
        taskData.nestedSet = {
          left = left,
          right = left + 1 + childCount * 2
        }
        left = taskData.nestedSet.right + 1
        overallChilds = overallChilds + childCount + 1
      end
    end
    -- Final sort accross all tasks
    sort(self.taskList, function(a, b)
      return (a.nestedSet.left < b.nestedSet.left)
    end)
  end
  return overallChilds
end

function OCS.TaskSolverBase:SolveCharacters()
  local playerName = UnitName("player")
  for i, taskData in ipairs(self.taskList) do
    if #(taskData.characters) > 1 then
      if tContains(taskData.characters, playerName) then
        -- Prefer active character if possible
        taskData.characterChosen = playerName
      else
        -- TODO: Pick based on least relogs? Skill gains? etc.
        taskData.characterChosen = taskData.characters[1]
      end
    elseif #(taskData.characters) == 1 then
      -- Only one option, that it is.
      taskData.characterChosen = taskData.characters[1]
    else
      -- No character options, you're doing something wrong! :D
      taskData.characterChosen = nil
    end
  end
end

function OCS.TaskSolverBase:CleanupTasks()
  local orgList = self.taskList
  local orgById = self.taskById
  local orgCount = #(orgList)
  local taskPrev = nil
  local taskModules = OCS:GetModulesByType("Task")
  -- Merge tasks and create new list
  self.taskList = {}
  local i = 1
  while (i <= orgCount) do
    local taskData = orgList[i]
    local taskModule = taskModules[taskData.moduleName]
    -- Try to merge with following tasks
    for j = orgCount, i + 1, -1 do
      local taskMerged = taskModule:MergeTasks(taskData, orgList[j])
      if taskMerged then
        taskData = taskMerged
        tremove(orgList, j)
        orgCount = orgCount - 1
      end
    end
    -- Add the (optionally merged task) to the purged list
    tinsert(self.taskList, taskData)
    i = i + 1
  end
  -- Fill id lookup table
  self.taskById = {}
  for i, taskData in ipairs(self.taskList) do
    self.taskById[taskData.id] = taskData
  end
  -- Presort tasks by id
  sort(self.taskList, function(a, b)
    return a.id < b.id
  end)
end

function OCS.TaskSolverBase:SolveTasks()
  -- TODO Implement solving pending task dependencies
end

function OCS.TaskSolverBase:SortTasks()
  self:TreeSortTasks(nil, function(a, b)
    -- Compare assigned character
    local aPlayer = a.characterChosen and a.characterChosen == playerName
    local bPlayer = b.characterChosen and b.characterChosen == playerName
    if aPlayer and not bPlayer then
      return true
    else
      return a.id < b.id
    end
  end)
end

function OCS.TaskSolverBase:Solve()
  self:CleanupTasks()
  self:SolveCharacters()
  self:SolveDependencies()
  self:SolveTasks()
  self:UpdateDependencies()
  self:SortTasks()
  return self.taskList, self.taskById
end
