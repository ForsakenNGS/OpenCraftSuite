-- Inventory framework
local _, OCS = ...

OCS.SourceBase = OCS.ModuleBase:Inherit()

function OCS.SourceBase:New(name, module)
  -- Parent class
  module = OCS.ModuleBase:New("Source", name, module)
  -- Inheritance
  module = module or {}
  setmetatable(module, self)
  self.__index = self
  return module
end

function OCS.SourceBase:GetPrice(itemId, type, quantity, ...)
  return nil
end

function OCS.SourceBase:GetVendorPrice(itemId, quantity, ...)
  return nil
end

function OCS.SourceBase:GetPriceTypes()
  return { "default" }
end

-- If the module is able to buy items (e.g. from vendor/auctionhouse)
function OCS.SourceBase:GetItemsBuyable(itemsRequired)
  return {}
end

-- Create task(s) for buying the given items
function OCS.SourceBase:BuyItems(itemsRequired)
  return {}
end
