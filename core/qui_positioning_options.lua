--[[
    QUI Positioning Options Module
    UI components for positioning-related options
    Single Responsibility: Provide UI for positioning configuration
]]

local ADDON_NAME, ns = ...

local QUI_Positioning_Options = {}
ns.QUI_Positioning_Options = QUI_Positioning_Options

-- Helper to get GUI (lazy load to avoid initialization order issues)
local function GetGUI()
    local QUI = _G.QuaziiUI
    if QUI and QUI.GUI then
        return QUI.GUI
    end
    return nil
end

---------------------------------------------------------------------------
-- CREATE POSITIONING CONTROLS
---------------------------------------------------------------------------
-- Create offset controls (X and Y)
-- Parameters:
--   parent: Parent frame
--   frame: The frame being configured
--   x, y: Position
--   onChange: Optional callback when values change
--   offsetMin: Optional minimum value (default: -500)
--   offsetMax: Optional maximum value (default: 500)
-- Returns: {xControl, yControl} or nil
function QUI_Positioning_Options:CreateOffsetControls(parent, frame, x, y, onChange, offsetMin, offsetMax)
    if not frame then return nil end
    
    local GUI = GetGUI()
    if not GUI then return nil end
    
    local QUI_LayoutManager = ns.QUI_LayoutManager
    if not QUI_LayoutManager then return nil end
    
    local layout = QUI_LayoutManager:GetLayout(frame)
    if not layout then return nil end
    
    -- Default min/max values (matching CreateAnchorControls defaults)
    offsetMin = offsetMin or -500
    offsetMax = offsetMax or 500
    
    -- X Offset control (read directly from layout, no tempSettings needed)
    local xControl = GUI:CreateFormSlider(parent, "X Offset", offsetMin, offsetMax, 1, nil, nil, function(value)
        QUI_LayoutManager:UpdateLayout(frame, {offsetX = value})
        if onChange then onChange() end
    end)
    if xControl then
        xControl:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, y or 0)
        xControl:SetPoint("RIGHT", parent, "RIGHT", -(x or 0), 0)
        xControl:SetValue(layout.offsetX or 0)
    end
    
    -- Y Offset control (read directly from layout, no tempSettings needed)
    local yControl = GUI:CreateFormSlider(parent, "Y Offset", offsetMin, offsetMax, 1, nil, nil, function(value)
        QUI_LayoutManager:UpdateLayout(frame, {offsetY = value})
        if onChange then onChange() end
    end)
    if yControl then
        local yPos = (y or 0) - 32  -- FORM_ROW spacing
        yControl:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, yPos)
        yControl:SetPoint("RIGHT", parent, "RIGHT", -(x or 0), 0)
        yControl:SetValue(layout.offsetY or 0)
    end
    
    return {xControl = xControl, yControl = yControl}
end

---------------------------------------------------------------------------
-- CREATE ANCHOR POINT CONTROLS
---------------------------------------------------------------------------
-- Create controls for selecting anchor points
-- Parameters:
--   parent: Parent frame
--   frame: The frame being configured
--   x, y: Position
--   onChange: Optional callback when values change
-- Returns: anchorControls table or nil
function QUI_Positioning_Options:CreateAnchorPointControls(parent, frame, x, y, onChange)
    if not frame then return nil end
    
    local GUI = GetGUI()
    if not GUI then return nil end
    
    local QUI_LayoutManager = ns.QUI_LayoutManager
    if not QUI_LayoutManager then return nil end
    
    local layout = QUI_LayoutManager:GetLayout(frame)
    if not layout or not layout.anchors or #layout.anchors == 0 then return nil end
    
    local anchorControls = {}
    
    -- Create controls for each anchor pair
    for i, anchorPair in ipairs(layout.anchors) do
        local anchorY = (y or 0) - ((i - 1) * 60)
        
        -- Source anchor point dropdown
        local sourceOptions = {
            {value = "TOPLEFT", text = "Top Left"},
            {value = "TOP", text = "Top"},
            {value = "TOPRIGHT", text = "Top Right"},
            {value = "LEFT", text = "Left"},
            {value = "CENTER", text = "Center"},
            {value = "RIGHT", text = "Right"},
            {value = "BOTTOMLEFT", text = "Bottom Left"},
            {value = "BOTTOM", text = "Bottom"},
            {value = "BOTTOMRIGHT", text = "Bottom Right"},
        }
        
        local sourceControl = GUI:CreateDropdown(parent, "Source Point", sourceOptions, nil, nil, function(value)
            local anchors = {}
            for j, pair in ipairs(layout.anchors) do
                if j == i then
                    anchors[j] = {source = value, target = pair.target or "CENTER"}
                else
                    anchors[j] = {source = pair.source, target = pair.target}
                end
            end
            QUI_LayoutManager:UpdateLayout(frame, {anchors = anchors})
            if onChange then onChange() end
        end)
        if sourceControl then
            sourceControl:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, anchorY)
            sourceControl:SetWidth(150)
            sourceControl:SetValue(anchorPair.source or "CENTER", true)
        end
        
        -- Target anchor point dropdown
        local targetControl = GUI:CreateDropdown(parent, "Target Point", sourceOptions, nil, nil, function(value)
            local anchors = {}
            for j, pair in ipairs(layout.anchors) do
                if j == i then
                    anchors[j] = {source = pair.source or "CENTER", target = value}
                else
                    anchors[j] = {source = pair.source, target = pair.target}
                end
            end
            QUI_LayoutManager:UpdateLayout(frame, {anchors = anchors})
            if onChange then onChange() end
        end)
        if targetControl then
            targetControl:SetPoint("LEFT", sourceControl, "RIGHT", 10, 0)
            targetControl:SetWidth(150)
            targetControl:SetValue(anchorPair.target or "CENTER", true)
        end
        
        anchorControls[i] = {
            source = sourceControl,
            target = targetControl,
        }
    end
    
    return anchorControls
end

---------------------------------------------------------------------------
-- UPDATE OFFSET CONTROLS
-- Update offset controls based on current layout state
-- Parameters:
--   controls: Controls table from CreateOffsetControls
--   frame: The frame being configured
---------------------------------------------------------------------------
function QUI_Positioning_Options:UpdateOffsetControls(controls, frame)
    if not controls or not frame then return end
    
    local QUI_LayoutManager = ns.QUI_LayoutManager
    if not QUI_LayoutManager then return end
    
    local layout = QUI_LayoutManager:GetLayout(frame)
    if not layout then return end
    
    -- Update X offset control directly from layout (no tempSettings needed)
    if controls.xControl and type(layout.offsetX) == "number" then
        controls.xControl:SetValue(layout.offsetX, true)
    end
    
    -- Update Y offset control directly from layout (no tempSettings needed)
    if controls.yControl and type(layout.offsetY) == "number" then
        controls.yControl:SetValue(layout.offsetY, true)
    end
end

---------------------------------------------------------------------------
-- UPDATE ANCHOR POINT CONTROLS
-- Update anchor point controls based on current layout state
-- Parameters:
--   controls: Controls table from CreateAnchorPointControls
--   frame: The frame being configured
---------------------------------------------------------------------------
function QUI_Positioning_Options:UpdateAnchorPointControls(controls, frame)
    if not controls or not frame then return end
    
    local QUI_LayoutManager = ns.QUI_LayoutManager
    if not QUI_LayoutManager then return end
    
    local layout = QUI_LayoutManager:GetLayout(frame)
    if not layout or not layout.anchors then return end
    
    -- Update each anchor pair control
    for i, anchorPair in ipairs(layout.anchors) do
        if controls[i] then
            if controls[i].source and anchorPair.source then
                controls[i].source:SetValue(anchorPair.source, true)
            end
            if controls[i].target and anchorPair.target then
                controls[i].target:SetValue(anchorPair.target, true)
            end
        end
    end
end

return QUI_Positioning_Options
