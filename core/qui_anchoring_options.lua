--[[
    QUI Anchoring Options Module
    Public utility functions for anchoring-related UI components.
    For layout controls, use QUI_LayoutControl_Options:CreateLayoutControl instead.
]]

local ADDON_NAME, ns = ...

local QUI_Anchoring_Options = {}
ns.QUI_Anchoring_Options = QUI_Anchoring_Options

-- Helper to get GUI (lazy load to avoid initialization order issues)
local function GetGUI()
    local QUI = _G.QuaziiUI
    if QUI and QUI.GUI then
        return QUI.GUI
    end
    return nil
end

-- Helper to get Colors (lazy load)
local function GetColors()
    local GUI = GetGUI()
    if GUI and GUI.Colors then
        return GUI.Colors
    end
    -- Fallback colors if GUI not available
    return {
        text = {1, 1, 1},
        border = {0.3, 0.3, 0.3},
        accent = {0.2, 0.6, 1}
    }
end

---------------------------------------------------------------------------
-- GET NINE POINT ANCHOR OPTIONS
-- Returns the standard 9-point anchor options array
---------------------------------------------------------------------------
function QUI_Anchoring_Options:GetNinePointAnchorOptions()
    return {
        {value = "TOPLEFT", text = "Top Left"},
        {value = "TOP", text = "Top Center"},
        {value = "TOPRIGHT", text = "Top Right"},
        {value = "LEFT", text = "Center Left"},
        {value = "CENTER", text = "Center"},
        {value = "RIGHT", text = "Center Right"},
        {value = "BOTTOMLEFT", text = "Bottom Left"},
        {value = "BOTTOM", text = "Bottom Center"},
        {value = "BOTTOMRIGHT", text = "Bottom Right"},
    }
end

---------------------------------------------------------------------------
-- CREATE ANCHOR POINT SELECTOR WIDGET
-- Creates a visual grid-based anchor point selector
-- Parameters:
--   parent: Parent frame
--   label: Label text
--   settingsDB: Settings database table
--   key: Key name in settingsDB for anchor point value
--   x, y: Position
--   onChange: Callback function when value changes
--   size: Size of the selector widget (default: 200)
-- Returns: selector widget frame
---------------------------------------------------------------------------
function QUI_Anchoring_Options:CreateAnchorPointSelector(parent, label, settingsDB, key, x, y, onChange, size)
    size = size or 200
    local C = GetColors()
    
    -- Container frame
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(size, size + 30) -- Extra height for label
    
    if x and y then
        container:SetPoint("TOPLEFT", x, y)
    end
    
    -- Label
    local labelText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("TOPLEFT", 0, 0)
    labelText:SetText(label)
    labelText:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
    
    -- Grid container
    local gridSize = size
    local cellSize = gridSize / 3
    local grid = CreateFrame("Frame", nil, container, "BackdropTemplate")
    grid:SetSize(gridSize, gridSize)
    grid:SetPoint("TOPLEFT", 0, -25)
    grid:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = {left = 1, right = 1, top = 1, bottom = 1}
    })
    grid:SetBackdropColor(0.1, 0.1, 0.1, 1)
    grid:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.5)
    
    -- Anchor point mapping: [row][col] = anchorPoint
    local anchorPoints = {
        {"TOPLEFT", "TOP", "TOPRIGHT"},
        {"LEFT", "CENTER", "RIGHT"},
        {"BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT"},
    }
    
    -- Create cells
    local cells = {}
    for row = 1, 3 do
        cells[row] = {}
        for col = 1, 3 do
            local cell = CreateFrame("Button", nil, grid, "BackdropTemplate")
            cell:SetSize(cellSize - 2, cellSize - 2)
            cell:SetPoint("TOPLEFT", grid, "TOPLEFT", (col - 1) * cellSize + 1, -(row - 1) * cellSize - 1)
            
            cell:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            cell:SetBackdropColor(0.15, 0.15, 0.15, 1)
            cell:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.3)
            
            -- Visual indicator (small square representing the anchor point)
            local indicator = cell:CreateTexture(nil, "OVERLAY")
            indicator:SetSize(cellSize * 0.3, cellSize * 0.3)
            
            local anchorPoint = anchorPoints[row][col]
            local offsetX, offsetY = 0, 0
            
            -- Position indicator based on anchor point
            if anchorPoint:find("LEFT") then
                offsetX = cellSize * 0.15
            elseif anchorPoint:find("RIGHT") then
                offsetX = cellSize * 0.55
            else
                offsetX = cellSize * 0.35
            end
            
            if anchorPoint:find("TOP") then
                offsetY = -cellSize * 0.15
            elseif anchorPoint:find("BOTTOM") then
                offsetY = -cellSize * 0.55
            else
                offsetY = -cellSize * 0.35
            end
            
            indicator:SetPoint("TOPLEFT", cell, "TOPLEFT", offsetX, offsetY)
            indicator:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.6)
            
            -- Store anchor point and indicator reference
            cell.anchorPoint = anchorPoint
            cell.indicator = indicator
            
            -- Hover effects
            cell:SetScript("OnEnter", function(self)
                self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
                indicator:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
            end)
            
            cell:SetScript("OnLeave", function(self)
                local currentValue = settingsDB[key]
                if currentValue == self.anchorPoint then
                    self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
                    if self.indicator then
                        self.indicator:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.8)
                    end
                else
                    self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.3)
                    if self.indicator then
                        self.indicator:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.6)
                    end
                end
            end)
            
            -- Store reference to cells table for UpdateSelection
            cell.cells = cells
            cell.settingsDB = settingsDB
            cell.key = key
            cell.C = C
            
            -- Update selection visual (updates all cells)
            cell.UpdateSelection = function(self)
                local currentValue = self.settingsDB[self.key]
                for r = 1, 3 do
                    for c = 1, 3 do
                        local cellFrame = self.cells[r][c]
                        if cellFrame.anchorPoint == currentValue then
                            cellFrame:SetBackdropBorderColor(self.C.accent[1], self.C.accent[2], self.C.accent[3], 1)
                            cellFrame:SetBackdropColor(0.2, 0.2, 0.2, 1)
                            if cellFrame.indicator then
                                cellFrame.indicator:SetColorTexture(self.C.accent[1], self.C.accent[2], self.C.accent[3], 0.8)
                            end
                        else
                            cellFrame:SetBackdropBorderColor(self.C.border[1], self.C.border[2], self.C.border[3], 0.3)
                            cellFrame:SetBackdropColor(0.15, 0.15, 0.15, 1)
                            if cellFrame.indicator then
                                cellFrame.indicator:SetColorTexture(self.C.accent[1], self.C.accent[2], self.C.accent[3], 0.6)
                            end
                        end
                    end
                end
            end
            
            -- Click handler
            cell:SetScript("OnClick", function(self)
                self.settingsDB[self.key] = self.anchorPoint
                self:UpdateSelection()
                if onChange then
                    onChange()
                end
            end)
            
            cells[row][col] = cell
        end
    end
    
    -- Initialize selection (use first cell's UpdateSelection to update all)
    if settingsDB[key] and cells[1][1] then
        cells[1][1]:UpdateSelection()
    end
    
    -- Store cells and update function for external access
    container.cells = cells
    container.UpdateSelection = function(self)
        if cells[1][1] then
            cells[1][1]:UpdateSelection()
        end
    end
    
    return container
end

-- Internal implementation functions (CreateAnchorDropdown, CreateOffsetControls, CreateWidthHeightControls,
-- CreateAnchorPresetControls, CreateMultiAnchorPopover) have been moved to qui_layout_control_options.lua
-- as local functions. Use QUI_LayoutControl_Options:CreateLayoutControl instead.
