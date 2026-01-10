--[[
    QUI Sizing Options Module
    UI components for sizing-related options
    Single Responsibility: Provide UI for sizing configuration
]]

local ADDON_NAME, ns = ...

local QUI_Sizing_Options = {}
ns.QUI_Sizing_Options = QUI_Sizing_Options

-- Helper to get GUI (lazy load to avoid initialization order issues)
local function GetGUI()
    local QUI = _G.QuaziiUI
    if QUI and QUI.GUI then
        return QUI.GUI
    end
    return nil
end

---------------------------------------------------------------------------
-- CREATE SIZE CONTROLS
---------------------------------------------------------------------------
-- Create width and height controls
-- Parameters:
--   parent: Parent frame
--   frame: The frame being configured
--   x, y: Position
--   onChange: Optional callback when values change
--   widthMin: Optional minimum value (default: 0)
--   widthMax: Optional maximum value (default: 2000)
--   heightMin: Optional minimum value (default: 1)
--   heightMax: Optional maximum value (default: 100)
-- Returns: {widthControl, heightControl, autoWidthBtn, autoHeightBtn} or nil
function QUI_Sizing_Options:CreateSizeControls(parent, frame, x, y, onChange, widthMin, widthMax, heightMin, heightMax)
    if not frame then return nil end
    
    local GUI = GetGUI()
    if not GUI then return nil end
    
    local QUI_LayoutManager = ns.QUI_LayoutManager
    local QUI_Sizing = ns.QUI_Sizing
    if not QUI_LayoutManager or not QUI_Sizing then return nil end
    
    local layout = QUI_LayoutManager:GetLayout(frame)
    if not layout then return nil end
    
    -- Default min/max values (matching CreateAnchorControls defaults)
    widthMin = widthMin or 0
    widthMax = widthMax or 2000
    heightMin = heightMin or 1
    heightMax = heightMax or 100
    
    -- Get auto-config state
    local autoConfig = QUI_Sizing:GetAutoConfig(layout.anchors, layout.anchorTarget)
    local widthAuto = autoConfig and autoConfig.widthAuto or false
    local heightAuto = autoConfig and autoConfig.heightAuto or false
    
    -- Width control (read directly from layout, no tempSettings needed)
    local widthControl = GUI:CreateFormSlider(parent, "Width", widthMin, widthMax, 1, nil, nil, function(value)
        QUI_LayoutManager:UpdateLayout(frame, {width = value})
        if onChange then onChange() end
    end)
    if widthControl then
        widthControl:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, y or 0)
        widthControl:SetPoint("RIGHT", parent, "RIGHT", -(x or 0), 0)
        if layout.width then
            widthControl:SetValue(layout.width)
        end
        widthControl:SetEnabled(not widthAuto)
    end
    
    -- Auto Width button
    local autoWidthBtn = GUI:CreateButton(parent, widthAuto and "Auto Width: ON" or "Auto Width: OFF", 120, 30, function()
        -- Toggle auto width by adding/removing horizontal dual anchors
        -- This is handled by the anchor system, not directly here
        -- For now, just show current state
    end)
    if autoWidthBtn then
        autoWidthBtn:SetPoint("LEFT", widthControl, "RIGHT", 10, 0)
        autoWidthBtn:SetEnabled(not widthAuto) -- Disable if already auto
    end
    
    -- Height control (read directly from layout, no tempSettings needed)
    local heightControl = GUI:CreateFormSlider(parent, "Height", heightMin, heightMax, 1, nil, nil, function(value)
        QUI_LayoutManager:UpdateLayout(frame, {height = value})
        if onChange then onChange() end
    end)
    if heightControl then
        local yPos = (y or 0) - 32  -- FORM_ROW spacing
        heightControl:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, yPos)
        heightControl:SetPoint("RIGHT", parent, "RIGHT", -(x or 0), 0)
        if layout.height then
            heightControl:SetValue(layout.height)
        end
        heightControl:SetEnabled(not heightAuto)
    end
    
    -- Auto Height button
    local autoHeightBtn = GUI:CreateButton(parent, heightAuto and "Auto Height: ON" or "Auto Height: OFF", 120, 30, function()
        -- Toggle auto height by adding/removing vertical dual anchors
        -- This is handled by the anchor system, not directly here
        -- For now, just show current state
    end)
    if autoHeightBtn then
        autoHeightBtn:SetPoint("LEFT", heightControl, "RIGHT", 10, 0)
        autoHeightBtn:SetEnabled(not heightAuto) -- Disable if already auto
    end
    
    return {
        widthControl = widthControl,
        heightControl = heightControl,
        autoWidthBtn = autoWidthBtn,
        autoHeightBtn = autoHeightBtn,
    }
end

---------------------------------------------------------------------------
-- UPDATE SIZE CONTROLS
---------------------------------------------------------------------------
-- Update size controls based on current layout state
-- Parameters:
--   controls: Controls table from CreateSizeControls
--   frame: The frame being configured
function QUI_Sizing_Options:UpdateSizeControls(controls, frame)
    if not controls or not frame then return end
    
    local QUI_LayoutManager = ns.QUI_LayoutManager
    local QUI_Sizing = ns.QUI_Sizing
    if not QUI_LayoutManager or not QUI_Sizing then return end
    
    local layout = QUI_LayoutManager:GetLayout(frame)
    if not layout then return end
    
    -- Get auto-config state
    local autoConfig = QUI_Sizing:GetAutoConfig(layout.anchors, layout.anchorTarget)
    local widthAuto = autoConfig and autoConfig.widthAuto or false
    local heightAuto = autoConfig and autoConfig.heightAuto or false
    
    -- Update width control (use silent SetValue to prevent feedback loops)
    if controls.widthControl then
        if layout.width then
            controls.widthControl:SetValue(layout.width, true)
        end
        controls.widthControl:SetEnabled(not widthAuto)
    end
    
    -- Update height control (use silent SetValue to prevent feedback loops)
    if controls.heightControl then
        if layout.height then
            controls.heightControl:SetValue(layout.height, true)
        end
        controls.heightControl:SetEnabled(not heightAuto)
    end
    
    -- Update auto buttons
    if controls.autoWidthBtn then
        controls.autoWidthBtn:SetText(widthAuto and "Auto Width: ON" or "Auto Width: OFF")
        controls.autoWidthBtn:SetEnabled(not widthAuto)
    end
    
    if controls.autoHeightBtn then
        controls.autoHeightBtn:SetText(heightAuto and "Auto Height: ON" or "Auto Height: OFF")
        controls.autoHeightBtn:SetEnabled(not heightAuto)
    end
end

return QUI_Sizing_Options
