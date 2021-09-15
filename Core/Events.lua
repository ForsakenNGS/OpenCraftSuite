-- Source framework
local _, OCS = ...
local eventHandlers = {}
local messageHandlers = {}

OCS.Events = {}

function OCS.Events:Init()
  self.frame = CreateFrame("Frame")
  self.frame:SetScript("OnEvent", function(frame, ...)
    self:OnEvent(...)
  end);
end

function OCS.Events:RegisterMessage(message, callback)
  if not messageHandlers[message] then
    OCS.AceAddon:RegisterMessage(message, OCS.AceMessageCallback)
    messageHandlers[message] = {}
  end
  if not tContains(messageHandlers[message], callback) then
    tinsert(messageHandlers[message], callback)
  end
end

function OCS.Events:UnregisterMessage(message, callback)
  if messageHandlers[message] then
    if not callback then
      -- Unregister all callbacks
      messageHandlers[message] = nil
      OCS.AceAddon:UnregisterMessage(message)
    else
      for i in ipairs(messageHandlers[message]) do
        if messageHandlers[message][i] == callback then
          tremove(messageHandlers[message], i);
          break;
        end
      end
      if #(messageHandlers[message]) == 0 then
        messageHandlers[message] = nil
        OCS.AceAddon:UnregisterMessage(message)
      end
    end
  end
end

function OCS.Events:OnMessage(message, ...)
  if messageHandlers[message] then
    for i in ipairs(messageHandlers[message]) do
      messageHandlers[message][i](message, ...)
    end
  end
end

function OCS.Events:SendMessage(message, ...)
  OCS.AceAddon:SendMessage(message, ...)
end

function OCS.Events:OnEvent(event, ...)
  if eventHandlers[event] then
    for i in ipairs(eventHandlers[event]) do
      eventHandlers[event][i](event, ...)
    end
  end
end

function OCS.Events:RegisterEvent(event, callback)
  if not eventHandlers[event] then
    self.frame:RegisterEvent(event)
    eventHandlers[event] = {}
  end
  if not tContains(eventHandlers[event], callback) then
    tinsert(eventHandlers[event], callback)
  end
end

function OCS.Events:UnregisterEvent(event, callback)
  if eventHandlers[event] then
    if not callback then
      -- Unregister all callbacks
      eventHandlers[event] = nil
      self.frame:UnregisterEvent(event)
    else
      for i in ipairs(eventHandlers[event]) do
        if eventHandlers[event][i] == callback then
          tremove(eventHandlers[event], i);
          break;
        end
      end
      if #(eventHandlers[event]) == 0 then
        eventHandlers[event] = nil
        self.frame:UnregisterEvent(event)
      end
    end
  end
end

function OCS.Events:OnEvent(event, ...)
  if eventHandlers[event] then
    for i in ipairs(eventHandlers[event]) do
      eventHandlers[event][i](event, ...)
    end
  end
end

-- Kickstart event handler
OCS.Events:Init()
