-- WoW auctionhouse source
local _, OCS = ...
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
local DesignFrame = OCS.Frames:Add("Design")

local BackdropMinimal = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	tile = true, tileSize = 2, edgeSize = 1,
	insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

local BackdropNone = {
	bgFile = nil,
	edgeFile = nil,
	tile = true, tileSize = 0, edgeSize = 0,
	insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

local PaneBackdrop  = {
  bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 3, right = 3, top = 5, bottom = 3 }
}

function DesignFrame:OnInitialize()
  self.title = OCS.L["MODULE_FRAME_DESIGN"]
  self.name = "OCS_DesignFrame"
  self:RegisterMessage("OCS_GUI_CREATE_FRAME", "OnGuiCreateFrame")
  self:RegisterMessage("OCS_GUI_CREATE_WIDGET", "OnGuiCreateWidget")
end

function DesignFrame:GetAceOptions()
  local options = {
    Preset = {
      name = OCS.L["MODULE_FRAME_DESIGN_SHOW_FRAME"],
      type = "select",
      order = 100,
      values = {
        ["Default"] = "Default design",
        ["Minimal"] = "Minimalistic design",
      },
      sorting = { "Default", "Minimal" },
      width = "full",
      set = function(info, val) DesignFrame:SetDesignPreset(val) end,
      get = function(info) return DesignFrame:GetDesignPreset() end
    },
    Show = {
      name = OCS.L["MODULE_FRAME_DESIGN_SHOW_FRAME"],
      type = "execute",
      order = 200,
      func = function() OCS.Frames:Show("Design") end
    }
  }
  return options
end

function DesignFrame:GetDesignPreset()
  return self:GetStorageValue("DesignPreset", "Default")
end

function DesignFrame:SetDesignPreset(presetName)
  self:SetStorageValue("DesignPreset", presetName)
end

function DesignFrame:GetAceFrameElements(widget)
  local _, _, _, _, _, _, _, _, _, titlebg, titlebg_l, titlebg_r, line1, line2 = widget.frame:GetRegions()
  print("Debug", titlebg:GetObjectType(), titlebg_l:GetObjectType(), titlebg_r:GetObjectType())
  local close, statusbg, title, sizer_se, sizer_s, sizer_e = widget.frame:GetChildren()
  local titletext = title:GetRegions()
  local statustext = title:GetRegions()
  return
    titletext, titlebg, statustext, statusbg, close, title, titlebg_l, titlebg_r,
    sizer_se, sizer_s, sizer_e, line1, line2
end

function DesignFrame:GetAceWindowElements(widget)
  local titlebg, dialogbg, topleft, topright, top, bottomleft, bottomright, bottom, left, right, titletext, line1, line2 = widget.frame:GetRegions()
  local close, title, sizer_se, sizer_s, sizer_e = widget.frame:GetChildren()
  return
    titlebg, dialogbg, topleft, topright, top, bottomleft, bottomright, bottom,
    left, right, close, titletext, line1, line2, sizer_se, sizer_s, sizer_e
end

function DesignFrame:ApplyStyleBackdrop(widget, backdrop, backdropStyle)
  local backdrop, backdropResize = backdrop or OCS.GUI:GetAceBackdrop(widget)
  if backdrop then
    backdrop:SetBackdrop(backdropStyle)
    backdrop:SetBackdropColor(0.1, 0.1, 0.1, 0.7)
    backdrop:SetBackdropBorderColor(0.4, 0.64, 0.4)
    if backdropResize then
      backdrop:ClearAllPoints()
      backdrop:SetPoint("TOPLEFT", 4, -8)
      backdrop:SetPoint("BOTTOMRIGHT", -4, 4)
      backdrop:SetFrameStrata("BACKGROUND")
    end
  end
  return backdrop
end

function DesignFrame:ContentSizeFunctions(widget, horizontal, vertical, extraHeight)
	if extraHeight then
		widget.LayoutFinished = function(self, width, height)
			if self.noAutoHeight then return end
			self:SetHeight((height or 0) + extraHeight)
		end
	end
	if horizontal then
		widget.OnWidthSet = function(self, width)
			local content = self.content
			local contentwidth = width - horizontal
			if contentwidth < 0 then
				contentwidth = 0
			end
			content:SetWidth(contentwidth)
			content.width = contentwidth
		end
	end
	if vertical then
		widget.OnHeightSet = function(self, height)
			local content = self.content
			local contentheight = height - vertical
			if contentheight < 0 then
				contentheight = 0
			end
			content:SetHeight(contentheight)
			content.height = contentheight
		end
	end
end

function DesignFrame:OnAceAcquire(widget, widgetType)
  if self:GetDesignPreset() == "Minimal" then
    if widgetType == "Frame" then
      local titletext, titlebg, statustext, statusbg, close, title, titlebg_l, titlebg_r, sizer_se, sizer_s, sizer_e, line1, line2 = self:GetAceFrameElements(widget)
      -- Apply backdrop
      widget.content:ClearAllPoints()
      widget.content:SetPoint("TOPLEFT", 8, -26)
      widget.content:SetPoint("BOTTOMRIGHT", -8, 40)
      self:ApplyStyleBackdrop(widget, nil, BackdropMinimal)
      self:ApplyStyleBackdrop(widget, statusbg, BackdropMinimal)
      statusbg:ClearAllPoints()
      statusbg:SetPoint("BOTTOMLEFT", 8, 8)
      statusbg:SetPoint("BOTTOMRIGHT", -132, 8)
      close:ClearAllPoints()
      close:SetPoint("BOTTOMRIGHT", -8, 8)
      close:SetHeight(24)
      close:SetWidth(120)
      titlebg:Show()
      titlebg:SetColorTexture(0.0, 0.0, 0.0, 0.8)
      titlebg:ClearAllPoints()
      titlebg:SetPoint("TOPLEFT", 0, 0)
      titlebg:SetPoint("BOTTOMRIGHT", widget.frame, "TOPRIGHT", 0, -24)
      title:SetAllPoints(titlebg)
      titletext:SetPoint("TOP", titlebg, "TOP", 0, -6)
      -- Hide obsolete elements
      titlebg_l:Hide()
      titlebg_r:Hide()
      line1:Hide()
      line2:Hide()
    elseif widgetType == "Window" then
      local titlebg, dialogbg, topleft, topright, top, bottomleft, bottomright, bottom, left, right, close, titletext, line1, line2 = self:GetAceWindowElements(widget)
      -- Reuse existing elements
      titlebg:Show()
      titlebg:SetColorTexture(0.0, 0.0, 0.0, 0.8)
      titlebg:ClearAllPoints()
      titlebg:SetPoint("TOPLEFT", 8, -6)
      titlebg:SetPoint("BOTTOMRIGHT", widget.frame, "TOPRIGHT", -6, -24)
      close:Show()
      close:ClearAllPoints()
      close:SetPoint("TOPRIGHT", -6, -6)
      close:SetHeight(20)
      close:SetWidth(20)
      -- Hide obsolete elements
      dialogbg:Show()
      topleft:Hide()
      topright:Hide()
      top:Hide()
      bottomleft:Hide()
      bottomright:Hide()
      bottom:Hide()
      left:Hide()
      right:Hide()
      line1:Hide()
      line2:Hide()
    elseif widgetType == "InlineGroup" then
      local backdrop = self:ApplyStyleBackdrop(widget, nil, BackdropMinimal)
      backdrop:ClearAllPoints()
      backdrop:SetPoint("TOPLEFT", 4, -8)
      backdrop:SetPoint("BOTTOMRIGHT", -4, 4)
			self:ContentSizeFunctions(widget, 10, 12, 24)
      widget.content:ClearAllPoints()
      widget.content:SetPoint("TOPLEFT", 6, -8)
      widget.content:SetPoint("BOTTOMRIGHT", -6, 6)
      widget.titletext:SetParent(backdrop)
      widget.titletext:ClearAllPoints()
      widget.titletext:SetPoint("TOPLEFT", widget.content, "TOPLEFT", 24, 18)
      widget.titletext:SetPoint("TOPRIGHT", widget.content, "TOPRIGHT", -14, 18)
      widget.titletext:SetDrawLayer("OVERLAY")
    elseif widgetType == "EditBox" then
      widget.editbox.Left:Hide()
      widget.editbox.Right:Hide()
      widget.editbox.Middle:Show()
      widget.editbox.Middle:ClearAllPoints()
      widget.editbox.Middle:SetPoint("TOPLEFT", -8, -3)
      widget.editbox.Middle:SetPoint("BOTTOMRIGHT", 0, 3)
      widget.editbox.Middle:SetColorTexture(0.0, 0.0, 0.0, 0.7)
    elseif widgetType == "TreeGroup" then
      self:ApplyStyleBackdrop(widget, widget.treeframe, BackdropMinimal)
      self:ApplyStyleBackdrop(widget, widget.border, BackdropNone)
      widget.content:ClearAllPoints()
      widget.content:SetPoint("TOPLEFT", 8, 2)
      widget.content:SetPoint("BOTTOMRIGHT", 0, 0)
    elseif widgetType == "Table" then
      self:ApplyStyleBackdrop(widget, nil, BackdropMinimal)
      widget:SetHeaderButtonTextureSimple({
        file = 130696, -- "Interface\\AuctionFrame\\UI-AuctionFrame-FilterBg"
        sideWidths = 5, size = { canvas = { 256, 32 }, button = { 136, 19 } },
      })
    end
  elseif self:GetDesignPreset() == "Default" then
    if aceType == "Table" then
      widget:SetBackdrop(PaneBackdrop)
      widget:SetBackdropColor(0, 0, 0, 1)
      widget:SetHeaderButtonTextureSimple({
        file = 130696, -- "Interface\\AuctionFrame\\UI-AuctionFrame-FilterBg"
        sideWidths = 5, size = { canvas = { 256, 32 }, button = { 136, 19 } },
      })
    end
  end
  -- Reset on release
  OCS.GUI:HookAceRelease(widget, function(self, ...)
    DesignFrame:OnAceRelease(widget, widgetType)
  end)
end

function DesignFrame:OnAceRelease(widget, widgetType)
  if aceType == "Table" then
    widget:SetHeaderButtonTextureSimple({
      file = 130828, -- "Interface\\AuctionFrame\\UI-Panel-Button-Up"
      sideWidths = 12, size = { canvas = { 128, 32 }, button = { 80, 23 } },
    })
	elseif aceType == "InlineGroup" then
		local backdrop = self:ApplyStyleBackdrop(widget, nil, PaneBackdrop)
		widget.content:ClearAllPoints()
		widget.content:SetPoint("TOPLEFT", 10, -10)
		widget.content:SetPoint("BOTTOMRIGHT", -10, 10)
		widget.titletext:SetParent(widget.frame)
		widget.titletext:ClearAllPoints()
		widget.titletext:SetPoint("TOPLEFT", 14, 0)
		widget.titletext:SetPoint("TOPRIGHT", -14, 0)
		widget.titletext:SetJustifyH("LEFT")
		widget.titletext:SetHeight(18)
  end
  --self:Log("OnAceRelease", "debug", widgetType)
  AceGUI:Release(widget)
end

function DesignFrame:OnGuiCreateFrame(_, widget, widgetType)
  --self:Log("OnGuiCreateFrame", "debug", widgetType)
  self:OnAceAcquire(widget, widgetType)
end

function DesignFrame:OnGuiCreateWidget(_, widget, widgetType)
  --self:Log("OnGuiCreateWidget", "debug", widgetType)
  self:OnAceAcquire(widget, widgetType)
end

function DesignFrame:CreateContents()
  self.widget:ReleaseChildren()
  self.widget:SetLayout("Fill")
end
