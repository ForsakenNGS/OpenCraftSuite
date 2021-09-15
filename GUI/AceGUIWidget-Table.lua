--[[-----------------------------------------------------------------------------
Table Container
Plain container that scrolls its content and doesn't grow in height.
-------------------------------------------------------------------------------]]
local Type, Version = "Table", 26
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

-- Lua APIs
local pairs, assert, type = pairs, assert, type
local min, max, floor = math.min, math.max, math.floor

-- WoW APIs
local CreateFrame, UIParent = CreateFrame, UIParent

--[[-----------------------------------------------------------------------------
Support functions
-------------------------------------------------------------------------------]]

--fire an update after one frame to catch the scrollpane height
local function FirstFrameUpdate(frame)
	local self = frame.obj
	frame:SetScript("OnUpdate", nil)
	self:UpdateRows()
	self:ResizeRows()
end

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function Table_OnMouseWheel(frame, value)
	frame.obj:MoveScroll(value)
end

local function Table_OnSizeChanged(frame)
	frame:SetScript("OnUpdate", FirstFrameUpdate)
end

local function ScrollBar_OnScrollValueChanged(frame, value)
	frame.obj:SetScroll(value)
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
	["OnAcquire"] = function(self)
		self.tableCols = 0
		self.tableRowCount = 0
		self.tableRowHeight = 16
		self.tableDataVis = {}
		self.tableHeaders = {}
		self.tableHeaderType = "Button"
		self.tableCells = {}
		self.tableCellType = "InteractiveLabel"
		self.tableHoverIndex = nil
		self.tableSelIndex = nil
		self:SetScroll(0)
		self:SetBackdropInset(6)
		self.scrollframe:SetScript("OnUpdate", FirstFrameUpdate)
		-- Default callbacks
	  self:SetCallback("OnTableHeaderCreated", function(widget, _, header, colIndex, columnLabel)
			header:SetText(columnLabel)
	    header:SetFullWidth(true)
	  end)
	end,

	["OnRelease"] = function(self)
		self:ReleaseCleanup()
		self.status = nil
		for k in pairs(self.localstatus) do
			self.localstatus[k] = nil
		end
		self.scrollframe:SetPoint("BOTTOMRIGHT")
		self.scrollbar:Hide()
		self.scrollBarShown = nil
		self.content.height, self.content.width, self.content.original_width = nil, nil, nil
	end,

	["SetScroll"] = function(self, value)
		local status = self.status or self.localstatus
		local scrollRange = max(1, self:GetRowCount() - self:GetRowCountVisible())
		local scrollOffset = floor(value)
		self:SetRowOffset(scrollOffset)
		status.offset = scrollOffset
		status.scrollvalue = value
	end,

	["MoveScroll"] = function(self, value)
		local status = self.status or self.localstatus

		if self.scrollBarShown then
			local scrollRange = max(1, self:GetRowCount() - self:GetRowCountVisible())
			local delta = 1
			if value > 0 then
				delta = -1
			end
			local offsetNew = min(scrollRange, max(0, self:GetRowOffset() + delta))
			if (status.offset ~= offsetNew) then
				self:SetRowOffset(offsetNew)
				self.scrollbar:SetValue(offsetNew)
			end
		end
	end,

	["LayoutFinished"] = function(self, width, height)
		self.content:SetHeight(height or 0 + 20)
		-- schedule another update when everything has "settled"
		--self.scrollframe:SetScript("OnUpdate", FirstFrameUpdate)
	end,

	["SetStatusTable"] = function(self, status)
		assert(type(status) == "table")
		self.status = status
		if not status.scrollvalue then
			status.scrollvalue = 0
		end
	end,

	["OnWidthSet"] = function(self, width)
		local content = self.content
		content.width = width - (self.scrollBarShown and 20 or 0)
		content.original_width = width
	end,

	["OnHeightSet"] = function(self, height)
		local content = self.content
		content.height = height
	end,

	["GetRowOffset"] = function(self)
		return self.tableOffset
	end,

	["GetHeaderType"] = function(self, colIndex)
		return self.tableHeaderType
	end,

	["GetCellType"] = function(self, colIndex)
		return self.tableCellType
	end,

	["GetRowHeight"] = function(self)
		return self.tableRowHeight
	end,

	["GetRowCount"] = function(self)
		return self.tableRowCount
	end,

	["GetRowCountVisible"] = function(self, rowOffset)
		local height = self.scrollframe:GetHeight() or 0
		return max(floor(height / self.tableRowHeight) - 1, 0)
	end,

	["SetRowHeight"] = function(self, tableRowHeight)
		self.tableRowHeight = tableRowHeight
	end,

	["SetRowOffset"] = function(self, rowOffset)
		if (self.tableOffset ~= rowOffset) then
			if self.tableHoverIndex then
				self:Fire("OnTableRowLeave", self.tableCells[i], self.tableOffset + self.tableHoverIndex)
				self:Fire("OnTableRowEnter", self.tableCells[i], rowOffset + self.tableHoverIndex)
			end
			self.tableOffset = rowOffset
			self:UpdateRows()
		end
	end,

	["SetHeaderType"] = function(self, headerType)
		self.tableHeaderType = headerType
	end,

	["SetHeaderButtonTextureSimple"] = function(self, buttonTex, buttons)
		if not buttonTex then
			return
		end
		local texFile = buttonTex.file or 130696
		local sideWidths = buttonTex.sideWidths or 5
		local texCoordsX = buttonTex.texCoordsX or nil
		local texCoordsY = buttonTex.texCoordsY or nil
		if buttonTex.size and buttonTex.size.canvas and buttonTex.size.button then
			if not texCoordsX then
				local canvasWidth = buttonTex.size.canvas[1]
				local buttonWidth = buttonTex.size.button[1]
				texCoordsX = { 0, sideWidths / canvasWidth, (buttonWidth - sideWidths) / canvasWidth, buttonWidth / canvasWidth }
			end
			if not texCoordsY then
				local canvasHeight = buttonTex.size.canvas[2]
				local buttonHeight = buttonTex.size.button[2]
				texCoordsY = { 0, buttonHeight / canvasHeight }
			end
		end
		if not buttons then
			buttons = self.tableHeaders
		end
		for i, header in ipairs(buttons) do
			header.tableButtonHack = true
			header.frame:SetScript("OnMouseDown", nil)
			header.frame:SetScript("OnMouseUp", nil)
			header.frame:SetScript("OnShow", nil)
			header.frame:SetScript("OnDisable", nil)
			header.frame:SetScript("OnEnable", nil)
      header.frame.Left:ClearAllPoints()
			header.frame.Left:SetPoint("TOPLEFT", 0, 0)
			header.frame.Left:SetPoint("BOTTOMRIGHT", header.frame, "BOTTOMLEFT", sideWidths, 0)
      header.frame.Left:SetTexture(texFile)
      header.frame.Left:SetTexCoord(texCoordsX[1], texCoordsX[2], texCoordsY[1], texCoordsY[2])
      header.frame.Middle:ClearAllPoints()
			header.frame.Middle:SetPoint("TOPLEFT", sideWidths, 0)
			header.frame.Middle:SetPoint("BOTTOMRIGHT", sideWidths * -1, 0)
      header.frame.Middle:SetTexture(texFile)
      header.frame.Middle:SetTexCoord(texCoordsX[2], texCoordsX[3], texCoordsY[1], texCoordsY[2])
      header.frame.Right:ClearAllPoints()
			header.frame.Right:SetPoint("TOPLEFT", header.frame, "TOPRIGHT", sideWidths * -1, 0)
			header.frame.Right:SetPoint("BOTTOMRIGHT", 0, 0)
      header.frame.Right:SetTexture(texFile)
      header.frame.Right:SetTexCoord(texCoordsX[3], texCoordsX[4], texCoordsY[1], texCoordsY[2])
		end
		self.headerTexture = buttonTex
	end,

	["SetRowCount"] = function(self, rowCount)
		if (self.tableRowCount ~= rowCount) then
			self.tableRowCount = rowCount
			self:UpdateRows()
		end
	end,

	["SetRowSelected"] = function(self, selIndex)
		if (self.tableSelIndex ~= selIndex) then
			self.tableSelIndex = selIndex
			self:UpdateRows()
		end
	end,

	["SetColumnLabels"] = function(self, columns, columnWidths, space)
		assert(type(columns) == "table")
		-- Release existing headers and cells
		self:ReleaseCleanup()
		self:ReleaseChildren()
		self:PauseLayout()
		-- Create table containing the user data for the table layout and the header widgets
		local tableData = {
			columns = {},
			space = space or 0,
			align = "TOPLEFT"
		}
		self.tableCols = #(columns)
		self.tableOffset = 0
		self.tableRows = 0
		self.tableDataVis = {}
		self.tableHeaders = {}
		self.tableCells = {}
		for i = 1, #(columns) do
			local columnLabel = columns[i]
			local columnWidth = 9
			if columnWidths and columnWidths[i] then
				columnWidth = columnWidths[i]
			end
			local columnHeader = AceGUI:Create( self:GetHeaderType(i) )
			self:AddChild(columnHeader)
			self:SetHeaderButtonTextureSimple(self.headerTexture, { columnHeader })
			self:Fire("OnTableHeaderCreated", columnHeader, i, columnLabel)
			tinsert(tableData.columns, columnWidth)
			tinsert(self.tableHeaders, columnHeader)
		end
		self:SetLayout("Table")
		self:SetUserData("table", tableData)
		self:ResumeLayout()
	end,

	["SetRowDataVisible"] = function(self, rowIndex, columnData)
		return self.tableRows
	end,

	["SetBackdrop"] = function(self, ...)
		self.frame:SetBackdrop(...)
	end,

	["SetBackdropColor"] = function(self, ...)
		self.frame:SetBackdropColor(...)
	end,

	["GetBackdropInset"] = function(self, posIndex)
		if posIndex then
			return self.backdropInset[posIndex]
		else
			return self.backdropInset
		end
	end,

	["SetBackdropInset"] = function(self, ...)
		local distance = { ... }
		self.backdropInset = {
			distance[1], distance[2] or distance[1],
			distance[3] or distance[1], distance[4] or distance[2] or distance[1]
		}
		self.scrollframe:SetPoint("TOPLEFT", self.backdropInset[1], self.backdropInset[2] * -1)
		self.scrollframe:SetPoint("BOTTOMRIGHT", self.backdropInset[3] * -1, self.backdropInset[4])
	end,

	["ResizeRows"] = function(self)
		local doLayout = not self.LayoutPaused
		self:PauseLayout()
		for i, header in ipairs(self.tableHeaders) do
			header:SetHeight(self.tableRowHeight)
		end
		for i, cells in ipairs(self.tableCells) do
			for j, cell in ipairs(cells) do
				cell:SetHeight(self.tableRowHeight)
			end
		end
		if doLayout then
			self:ResumeLayout()
			self:DoLayout()
		end
	end,

	["ReleaseCleanup"] = function(self)
		if self.tableHeaders then
			for i, columnHeader in ipairs(self.tableHeaders) do
				if columnHeader.tableButtonHack then
					-- Restore original script handlers
					columnHeader.frame:SetScript("OnMouseDown", UIPanelButton_OnMouseDown)
					columnHeader.frame:SetScript("OnMouseUp", UIPanelButton_OnMouseUp)
					columnHeader.frame:SetScript("OnShow", UIPanelButton_OnShow)
					columnHeader.frame:SetScript("OnDisable", UIPanelButton_OnDisable)
					columnHeader.frame:SetScript("OnEnable", UIPanelButton_OnEnable)
				end
				self:Fire("OnTableHeaderBeforeRelease", columnHeader, i)
			end
		end
	end,

	["UpdateData"] = function(self)
		self:Fire("OnUpdateData")
		self:UpdateRows()
	end,

	["UpdateRows"] = function(self)
		local doLayout = not self.LayoutPaused
		self:PauseLayout()
		local rowCountOverall = self:GetRowCount()
		local rowCountUsed = self:GetRowCountVisible()
		if (rowCountUsed > self.tableRowCount) then
			rowCountUsed = self.tableRowCount
		end
		-- Hide highlight and selection for now
		self.highlightSelection:Hide()
		self.highlightSelection:ClearAllPoints()
		self.highlightHover:Hide()
		self.highlightHover:ClearAllPoints()
		-- Update / create relevant rows
		local rowCount = max(rowCountUsed, #(self.tableCells))
		for i = 1, rowCount do
			if (i <= rowCountUsed) then
				if not self.tableCells[i] then
					-- Create table cells for the current row
					self.tableCells[i] = {}
					for j = 1, self.tableCols do
						local tableCell = AceGUI:Create(self:GetCellType(j))
						if tableCell.SetJustifyV then
				      tableCell:SetJustifyV("MIDDLE")
						end
						tableCell:SetCallback("OnEnter", function(widget)
							self.tableHoverIndex = i
							self:Fire("OnTableRowEnter", self.tableCells[i], self.tableOffset + i)
							self:Fire("OnTableCellEnter", tableCell, j, self.tableOffset + i)
							self:UpdateRows()
						end)
						tableCell:SetCallback("OnLeave", function(widget)
							self.tableHoverIndex = nil
							self:Fire("OnTableRowLeave", self.tableCells[i], self.tableOffset + i)
							self:Fire("OnTableCellLeave", tableCell, j, self.tableOffset + i)
							self:UpdateRows()
						end)
						tableCell:SetCallback("OnClick", function(widget, ...)
							if (self.tableSelIndex ~= self.tableOffset + i) then
								-- Select
								self.tableSelIndex = self.tableOffset + i
							else
								-- Deselect
								self.tableSelIndex = nil
							end
							self:Fire("OnTableSel", self.tableSelIndex)
							self:Fire("OnTableRowClick", self.tableCells[i], self.tableOffset + i)
							self:Fire("OnTableCellClick", tableCell, j, self.tableOffset + i)
							self:UpdateRows()
						end)
						self:Fire("OnTableCellCreated", tableCell, j, i)
						self:AddChild(tableCell)
						tinsert(self.tableCells[i], tableCell)
					end
				end
				for j, tableCell in ipairs(self.tableCells[i]) do
					tableCell.frame:Show()
					self:Fire("OnTableCellUpdate", tableCell, j, self.tableOffset + i)
				end
				self:Fire("OnTableRowUpdate", self.tableCells[i], self.tableOffset + i)
			else
				for j, tableCell in pairs(self.tableCells[i]) do
					tableCell.frame:Hide()
				end
			end
		end
		self:ResizeRows()
		if (rowCountUsed < rowCountOverall) then
			-- Show scrollbar
			if not self.scrollBarShown then
				self.scrollBarShown = true
				self.scrollbar:Show()
				self.scrollframe:SetPoint("BOTTOMRIGHT", -20 - self:GetBackdropInset(3), self:GetBackdropInset(4))
				if self.content.original_width then
					self.content.width = self.content.original_width - 20
				end
			end
			local scrollRange = max(1, rowCountOverall - rowCountUsed)
			local value = min(self.tableOffset, scrollRange)
			self.scrollbar:SetMinMaxValues(0, scrollRange)
			self.scrollbar:SetValue(value)
			self:SetScroll(value)
		else
			-- Hide scrollbar
			if self.scrollBarShown then
				self.scrollBarShown = nil
				self.scrollbar:Hide()
				self.scrollbar:SetValue(0)
				self.scrollframe:SetPoint("BOTTOMRIGHT", self:GetBackdropInset(3) *-1, self:GetBackdropInset(4))
				if self.content.original_width then
					self.content.width = self.content.original_width
				end
			end
		end
		if doLayout then
			self:ResumeLayout()
			self:DoLayout()
			--self.scrollframe:SetScript("OnUpdate", FirstFrameUpdate)
		end
		if self.tableHoverIndex then
			local hoverCells = self.tableCells[ self.tableHoverIndex ]
			if hoverCells and hoverCells[1].frame:IsVisible() then
				-- Place hover texture
				local cellFirst, cellLast = hoverCells[1].frame, hoverCells[ #(hoverCells) ].frame
				self.highlightHover:ClearAllPoints()
				self.highlightHover:SetPoint("TOPLEFT", cellFirst, "TOPLEFT", 0, 2)
				self.highlightHover:SetPoint("TOPRIGHT", cellLast, "TOPRIGHT", 0, -2)
				self.highlightHover:SetHeight(self.tableRowHeight + 4)
				self.highlightHover:Show()
			else
				self.highlightHover:Hide()
			end
		else
			self.highlightHover:Hide()
		end
		if self.tableSelIndex then
			if self.tableSelIndex > self.tableRowCount then
				-- Selection out of bounds, move it back
				self.tableSelIndex = self.tableRowCount
				-- Update selected row
				self:Fire("OnTableSel", self.tableSelIndex)
			end
			-- Place hover texture
			local selectedCells = self.tableCells[ self.tableSelIndex - self.tableOffset ]
			if selectedCells and selectedCells[1].frame:IsVisible() then
				local cellFirst, cellLast = selectedCells[1].frame, selectedCells[ #(selectedCells) ].frame
				self.highlightSelection:ClearAllPoints()
				self.highlightSelection:SetPoint("TOPLEFT", cellFirst, "TOPLEFT", 0, 2)
				self.highlightSelection:SetPoint("TOPRIGHT", cellLast, "TOPRIGHT", 0, -2)
				self.highlightSelection:SetHeight(self.tableRowHeight + 4)
				self.highlightSelection:Show()
			else
				self.highlightSelection:Hide()
			end
		else
			self.highlightSelection:Hide()
		end
	end,

}
--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local function Constructor()
	local frame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	local num = AceGUI:GetNextWidgetNum(Type)

	local scrollframe = CreateFrame("Frame", nil, frame)
	scrollframe:SetPoint("TOPLEFT", 6, -6)
	scrollframe:SetPoint("BOTTOMRIGHT", -6, 6)
	scrollframe:EnableMouseWheel(true)
	scrollframe:SetScript("OnMouseWheel", Table_OnMouseWheel)
	scrollframe:SetScript("OnSizeChanged", Table_OnSizeChanged)
	scrollframe.SetVerticalScroll = function(value)
		-- Dummy function
	end

	local scrollbar = CreateFrame("Slider", ("AceConfigDialogScrollFrame%dScrollBar"):format(num), scrollframe, "UIPanelScrollBarTemplate")
	scrollbar:SetPoint("TOPLEFT", scrollframe, "TOPRIGHT", 4, -16)
	scrollbar:SetPoint("BOTTOMLEFT", scrollframe, "BOTTOMRIGHT", 4, 16)
	scrollbar:SetMinMaxValues(0, 1000)
	scrollbar:SetValueStep(1)
	scrollbar:SetValue(0)
	scrollbar:SetWidth(16)
	scrollbar:Hide()
	-- set the script as the last step, so it doesn't fire yet
	scrollbar:SetScript("OnValueChanged", ScrollBar_OnScrollValueChanged)

	local scrollbg = scrollbar:CreateTexture(nil, "BACKGROUND")
	scrollbg:SetAllPoints(scrollbar)
	scrollbg:SetColorTexture(0, 0, 0, 0.4)

	local highlightSelection = frame:CreateTexture(nil, "OVERLAY")
	highlightSelection:ClearAllPoints()
	highlightSelection:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight-Yellow")
	highlightSelection:SetBlendMode("ADD")

	local highlightHover = frame:CreateTexture(nil, "OVERLAY")
	highlightHover:ClearAllPoints()
	highlightHover:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight")
	highlightHover:SetBlendMode("ADD")

	--Container Support
	local content = CreateFrame("Frame", nil, scrollframe)
	content:SetPoint("TOPLEFT")
	content:SetPoint("TOPRIGHT")
	content:SetHeight(400)
	--scrollframe:SetScrollChild(content)

	local widget = {
		localstatus = { scrollvalue = 0 },
		scrollframe = scrollframe,
		scrollbar   = scrollbar,
		content     = content,
		frame       = frame,
		type        = Type,
		tableCols   = 0,
		tableRowCount		= 0,
		tableRowHeight  = 16,
		tableDataVis    = {},
		tableHeaders    = {},
		tableHeaderType = "Button",
		tableCells      = {},
		tableCellType   = "Label",
		tableHoverIndex = nil,
		tableSelIndex   = nil,
		backdropInset   = { 6, 6, 6, 6 },
		highlightHover     = highlightHover,
		highlightSelection = highlightSelection
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end
	scrollframe.obj, scrollbar.obj = widget, widget

	return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
