-- Source framework
local _, OCS = ...

OCS.TaskSolver = {}

function OCS.TaskSolver:Add(name, module)
  return OCS.TaskSolverBase:New(name, module)
end

function OCS.TaskSolver:SolveTasks(taskList, tasksById)
  local taskSolvers = {}
  local solverModules = OCS:GetModulesByType("TaskSolver")
  local solverModulesPrio = {}
  local solverMaxName = nil
  local solverMaxCount = nil
  -- Obtain solver  per taskId based on priority
  for modName, module in pairs(solverModules) do
    local modTasks = module:GetSolveableTasks(taskList, tasksById)
    for _, taskId in ipairs(modTasks) do
      if not taskSolvers[taskId] then
        taskSolvers[taskId] = modName
      else
        local modPrev = solverModules[taskSolvers[taskId]]
        if module:GetPriority() > modPrev:GetPriority() then
          taskSolvers[taskId] = modName
        end
      end
    end
    tinsert(solverModulesPrio, module)
  end
  -- Group tasks by solver
  local solverTasks = {}
  for taskId, modName in pairs(taskSolvers) do
    if not solverTasks[modName] then
      solverTasks[modName] = {}
    end
    tinsert(solverTasks[modName], taskId)
  end
  -- Sort solvers by priority
  sort(solverModulesPrio, function(a, b) return a:GetPriority() > b:GetPriority() end)
  -- Solve tasks by solver
  local tasksNew = {}
  local tasksNewById = {}
  for _, module in pairs(solverModulesPrio) do
    local modName = module:GetName()
    local modTasks = solverTasks[modName]
    if modTasks then
      local modTaskList = {}
      local modTasksById = {}
      for _, taskId in ipairs(modTasks) do
        modTasksById[taskId] = tasksById[taskId]
        tinsert(modTaskList, tasksById[taskId])
      end
      -- Solve tasks
      module:SetTasks(modTaskList, modTasksById)
      modTaskList, modTasksById = module:Solve()
      for _, taskData in ipairs(modTaskList) do
        tasksNewById[taskData.id] = taskData
        tinsert(tasksNew, taskData)
      end
    end
  end
  -- Return sorted list
  return tasksNew, tasksNewById
end
