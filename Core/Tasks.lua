-- Source framework
local _, OCS = ...
local taskList = {}
local taskById = {}
local taskUserData = {}
local taskIdNext = time()

OCS.Tasks = {}

function OCS.Tasks:Add(name, module)
  return OCS.TaskBase:New(name, module)
end

function OCS.Tasks:GetModuleForTask(taskData)
  local moduleType = taskData.moduleName
  local taskModules = OCS:GetModulesByType("Task")
  return taskModules[moduleType] or nil
end

function OCS.Tasks:Create(type, ...)
  local taskModules = OCS:GetModulesByType("Task")
  if taskModules[type] and taskModules[type].Create then
    local taskData = taskModules[type]:Create(...)
    tinsert(taskList, taskData)
    taskById[taskData.id] = taskData
    return taskData
  end
  return nil
end

function OCS.Tasks:CreateTaskId()
  local newId = taskIdNext
  taskIdNext = taskIdNext + 1
  return newId
end

function OCS.Tasks:RemoveTask(taskId)
  local taskIndex = nil
  for i, taskData in ipairs(taskList) do
    if taskData.id == taskId then
      taskIndex = i
      break
    end
  end
  if taskIndex then
    tremove(taskList, taskIndex)
    taskById[taskId] = nil
    self:UpdateTasks()
  end
end

function OCS.Tasks:ClearDynamic()
  for i = #(taskList), 1, -1 do
    local taskData = taskList[i]
    if taskData.isDynamic then
      tremove(taskList, i)
    end
  end
  taskById = {}
  for i, taskData in ipairs(taskList) do
    taskById[taskData.id] = taskData
  end
end

function OCS.Tasks:HasTasks()
  return #(taskList) > 0
end

function OCS.Tasks:GetTasks()
  return taskList, taskById
end

function OCS.Tasks:GetTaskById(id)
  return taskById[id] or nil
end

function OCS.Tasks:GetUserData(id, default)
  if not taskUserData[id] and default then
    taskUserData[id] = default
  end
  return taskUserData[id]
end

function OCS.Tasks:SetUserData(id, data)
  taskUserData[id] = data
end

function OCS.Tasks:GetTitle(taskData)
  local module = self:GetModuleForTask(taskData)
  if module then
    return module:GetTitle(taskData) or "???"
  end
  return "???"
end

function OCS.Tasks:CreateTaskFrame(taskData, taskLevel)
  local module = self:GetModuleForTask(taskData)
  local taskFrame = nil
  if module then
    taskFrame = module:CreateTaskFrame(taskData, taskLevel) or "???"
  else
    taskFrame = OCS.TaskBase:CreateTaskFrame(taskData, taskLevel)
  end
  local taskUserData = self:GetUserData(taskData.id, {})
  taskUserData.taskListFrame = taskFrame
  return taskFrame
end

function OCS.Tasks:GetTaskFrame(taskId)
  local taskUserData = self:GetUserData(taskId)
  if taskUserData and taskUserData.taskListFrame then
    return taskUserData.taskListFrame
  else
    return nil
  end
end

function OCS.Tasks:ReadTasks()
  if OpenCraftSuiteDB["tasks"] then
    taskList = OpenCraftSuiteDB["tasks"]
    taskById = {}
    -- Update auto increment
    for i, taskData in ipairs(taskList) do
      taskById[taskData.id] = taskData
      taskIdNext = max(taskIdNext, taskData.id + 1)
    end
    -- Update dynamic tasks
    self:UpdateLazy()
  end
end

function OCS.Tasks:WriteTasks()
  OpenCraftSuiteDB["tasks"] = taskList
end

function OCS.Tasks:UpdateLazy(timeout)
  OCS.Utils:LazyUpdate("TasksUpdateLazy", function()
    self:UpdateTasks()
  end, timeout)
end

-- Solve tasks by input
function OCS.Tasks:UpdateTasks()
  self:ClearDynamic()
  taskList, taskById = OCS.TaskSolver:SolveTasks(taskList, taskById)
  taskUserData = {}
  self:WriteTasks()
  OCS.Events:SendMessage("OCS_TASK_LIST_UPDATE")
end
