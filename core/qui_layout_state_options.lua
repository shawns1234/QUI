--[[
    QUI Layout State Options Module
    UI components for layout state/persistence options
    Single Responsibility: Provide UI for layout state management
]]

local ADDON_NAME, ns = ...

local QUI_LayoutState_Options = {}
ns.QUI_LayoutState_Options = QUI_LayoutState_Options

-- Helper to get GUI (lazy load to avoid initialization order issues)
local function GetGUI()
    local QUI = _G.QuaziiUI
    if QUI and QUI.GUI then
        return QUI.GUI
    end
    return nil
end

---------------------------------------------------------------------------
-- CREATE STATE MANAGEMENT CONTROLS
---------------------------------------------------------------------------
-- Create controls for managing layout state (save, load, reset)
-- Parameters:
--   parent: Parent frame
--   frame: The frame being configured (optional - if nil, applies to all frames)
--   x, y: Position
--   onStateChange: Optional callback when state changes
-- Returns: controls table or nil
function QUI_LayoutState_Options:CreateStateControls(parent, frame, x, y, onStateChange)
    local GUI = GetGUI()
    if not GUI then return nil end
    
    local QUI_LayoutManager = ns.QUI_LayoutManager
    local QUI_LayoutState = ns.QUI_LayoutState
    if not QUI_LayoutManager or not QUI_LayoutState then return nil end
    
    local controls = {}
    
    -- Save button
    local saveBtn = GUI:CreateButton(parent, "Save Layout", 120, 30, function()
        if frame then
            -- Save specific frame
            local layout = QUI_LayoutManager:GetLayout(frame)
            if layout and layout.frameKey then
                QUI_LayoutState:SaveConfig(layout.frameKey, layout)
            end
        else
            -- Save all frames
            for f, config in pairs(QUI_LayoutManager.frames) do
                if config.frameKey then
                    QUI_LayoutState:SaveConfig(config.frameKey, config)
                end
            end
        end
        if onStateChange then onStateChange() end
    end)
    if saveBtn then
        saveBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, y or 0)
    end
    controls.saveBtn = saveBtn
    
    -- Load button
    local loadBtn = GUI:CreateButton(parent, "Load Layout", 120, 30, function()
        if frame then
            -- Load specific frame
            local layout = QUI_LayoutManager:GetLayout(frame)
            if layout and layout.frameKey then
                local loaded = QUI_LayoutState:LoadConfig(layout.frameKey)
                if loaded then
                    QUI_LayoutManager:UpdateLayout(frame, loaded)
                end
            end
        else
            -- Reload all frames
            QUI_LayoutManager:UpdateAllFrames()
        end
        if onStateChange then onStateChange() end
    end)
    if loadBtn then
        loadBtn:SetPoint("LEFT", saveBtn, "RIGHT", 10, 0)
    end
    controls.loadBtn = loadBtn
    
    -- Reset button
    local resetBtn = GUI:CreateButton(parent, "Reset to Defaults", 150, 30, function()
        if frame then
            -- Reset specific frame
            local layout = QUI_LayoutManager:GetLayout(frame)
            if layout and layout.frameKey then
                -- Extract frameType from frameKey
                local frameType = layout.frameKey:match("^([^.]+)")
                if frameType then
                    local defaults = QUI_LayoutState:ApplyDefaults(layout.frameKey, frameType)
                    QUI_LayoutManager:UpdateLayout(frame, defaults)
                end
            end
        else
            -- Reset all frames
            QUI_LayoutManager:ResetToDefaults()
        end
        if onStateChange then onStateChange() end
    end)
    if resetBtn then
        resetBtn:SetPoint("LEFT", loadBtn, "RIGHT", 10, 0)
    end
    controls.resetBtn = resetBtn
    
    return controls
end

---------------------------------------------------------------------------
-- CREATE FRAME SELECTOR
---------------------------------------------------------------------------
-- Create a dropdown to select which frame to configure
-- Parameters:
--   parent: Parent frame
--   x, y: Position
--   onFrameSelected: Callback(frame) when frame is selected
-- Returns: dropdown widget or nil
function QUI_LayoutState_Options:CreateFrameSelector(parent, x, y, onFrameSelected)
    local GUI = GetGUI()
    if not GUI then return nil end
    
    local QUI_LayoutManager = ns.QUI_LayoutManager
    if not QUI_LayoutManager then return nil end
    
    -- Build frame options list
    local frameOptions = {}
    table.insert(frameOptions, {value = nil, text = "All Frames"})
    
    for frame, config in pairs(QUI_LayoutManager.frames) do
        if config.frameKey and config.editMode and config.editMode.label then
            table.insert(frameOptions, {
                value = frame,
                text = config.editMode.label,
            })
        end
    end
    
    -- Sort by label
    table.sort(frameOptions, function(a, b)
        if a.value == nil then return true end
        if b.value == nil then return false end
        return a.text < b.text
    end)
    
    local selectedFrame = nil
    
    local dropdown = GUI:CreateDropdown(parent, "Frame", x, y, 200, frameOptions, nil, function(value)
        selectedFrame = value
        if onFrameSelected then
            onFrameSelected(value)
        end
    end)
    
    return dropdown
end

return QUI_LayoutState_Options
