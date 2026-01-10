--[[
    QUI Layout Manager Options Module
    Coordinator for layout system options
    Combines options from Positioning, Sizing, and LayoutState modules
    Single Responsibility: Coordinate and combine layout options UI
]]

local ADDON_NAME, ns = ...

local QUI_LayoutManager_Options = {}
ns.QUI_LayoutManager_Options = QUI_LayoutManager_Options

-- Helper to get GUI (lazy load to avoid initialization order issues)
local function GetGUI()
    local QUI = _G.QuaziiUI
    if QUI and QUI.GUI then
        return QUI.GUI
    end
    return nil
end

---------------------------------------------------------------------------
-- CREATE COMPLETE LAYOUT CONTROLS
---------------------------------------------------------------------------
-- Create all layout controls for a frame
-- This is a wrapper around CreateLayoutControl for consistency
-- Parameters:
--   parent: Parent frame
--   frame: The frame being configured
--   x, y: Starting position (y is used for first section positioning)
--   onLayoutChange: Optional callback when layout changes
--   PAD: Padding constant (optional, defaults to 10)
--   FORM_ROW: Form row height constant (optional, defaults to 32)
--   options: Optional table with same options as CreateLayoutControl
-- Returns: controls table from CreateLayoutControl
function QUI_LayoutManager_Options:CreateLayoutControls(parent, frame, x, y, onLayoutChange, PAD, FORM_ROW, options)
    if not frame or not ns.QUI_LayoutControl_Options then return nil end
    
    PAD = PAD or 10
    FORM_ROW = FORM_ROW or 32
    options = options or {}
    
    -- Use the unified layout control helper
    local layoutSection, layoutContent, newY, controls = ns.QUI_LayoutControl_Options:CreateLayoutControl(
        parent, frame, y, PAD, FORM_ROW, onLayoutChange, options
    )
    
    -- Controls are already stored on frame._layoutControls[parent] by CreateLayoutControl
    -- Just return the controls directly
    return controls
end

---------------------------------------------------------------------------
-- UPDATE ALL LAYOUT CONTROLS
---------------------------------------------------------------------------
-- Update all layout controls based on current frame state
-- Parameters:
--   controls: Controls table from CreateLayoutControls
--   frame: The frame being configured
function QUI_LayoutManager_Options:UpdateLayoutControls(controls, frame)
    if not controls or not frame then return end
    
    local QUI_LayoutManager = ns.QUI_LayoutManager
    if not QUI_LayoutManager then return end
    
    local layout = QUI_LayoutManager:GetLayout(frame)
    if not layout then return end
    
    -- Update anchor dropdown (use silent SetValue to prevent feedback loops)
    if controls.anchorDropdown then
        local anchorValue = layout.anchorTarget or "none"
        controls.anchorDropdown:SetValue(anchorValue, true)
    end
    
    -- Update offset sliders (use silent SetValue to prevent feedback loops)
    if controls.offsetXSlider and type(layout.offsetX) == "number" then
        controls.offsetXSlider:SetValue(layout.offsetX, true)
    end
    if controls.offsetYSlider and type(layout.offsetY) == "number" then
        controls.offsetYSlider:SetValue(layout.offsetY, true)
    end
    
    -- Update size sliders (use silent SetValue to prevent feedback loops)
    if controls.widthSlider and type(layout.width) == "number" then
        controls.widthSlider:SetValue(layout.width, true)
    end
    if controls.heightSlider and type(layout.height) == "number" then
        controls.heightSlider:SetValue(layout.height, true)
    end
end

---------------------------------------------------------------------------
-- CREATE FRAME LAYOUT PAGE
---------------------------------------------------------------------------
-- Create a complete options page for configuring a specific frame's layout
-- Parameters:
--   parent: Parent frame
--   frame: The frame to configure
--   title: Optional title (defaults to frame's editMode.label)
function QUI_LayoutManager_Options:CreateFrameLayoutPage(parent, frame, title)
    if not frame then return end
    
    local GUI = GetGUI()
    if not GUI then return end
    
    local QUI_LayoutManager = ns.QUI_LayoutManager
    if not QUI_LayoutManager then return end
    
    local layout = QUI_LayoutManager:GetLayout(frame)
    if not layout then return end
    
    -- Get title
    local pageTitle = title or (layout.editMode and layout.editMode.label) or "Frame Layout"
    
    -- Create title
    local titleText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", 20, -20)
    titleText:SetText(pageTitle)
    
    -- Create all layout controls
    local controls = self:CreateLayoutControls(parent, frame, 20, -60, function()
        -- Refresh controls when layout changes
        self:UpdateLayoutControls(controls, frame)
    end)
    
    return controls
end

---------------------------------------------------------------------------
-- CREATE LAYOUT SYSTEM PAGE
---------------------------------------------------------------------------
-- Create a complete options page for the layout system (all frames)
-- Parameters:
--   parent: Parent frame
function QUI_LayoutManager_Options:CreateLayoutSystemPage(parent)
    local GUI = GetGUI()
    if not GUI then return end
    
    local QUI_LayoutManager = ns.QUI_LayoutManager
    if not QUI_LayoutManager then return end
    
    -- Create title
    local titleText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", 20, -20)
    titleText:SetText("Layout System")
    
    -- Frame selector
    local selectedFrame = nil
    if ns.QUI_LayoutState_Options then
        local frameSelector = ns.QUI_LayoutState_Options:CreateFrameSelector(parent, 20, -60, function(frame)
            selectedFrame = frame
            -- Update controls for selected frame
            if frame and controls then
                self:UpdateLayoutControls(controls, frame)
            end
        end)
    end
    
    -- State management controls (for all frames)
    local stateControls = nil
    if ns.QUI_LayoutState_Options then
        stateControls = ns.QUI_LayoutState_Options:CreateStateControls(parent, nil, 20, -100, function()
            -- Refresh when state changes
        end)
    end
    
    -- Create a container for frame-specific controls
    local frameContainer = CreateFrame("Frame", nil, parent)
    frameContainer:SetPoint("TOPLEFT", 20, -150)
    frameContainer:SetPoint("BOTTOMRIGHT", -20, 20)
    
    local controls = nil
    
    -- Update function
    local function UpdateFrameControls()
        -- Clear existing controls
        if controls then
            -- Controls are managed by their respective modules
        end
        
        if selectedFrame then
            -- Create controls for selected frame
            controls = self:CreateLayoutControls(frameContainer, selectedFrame, 0, 0, function()
                self:UpdateLayoutControls(controls, selectedFrame)
            end)
        end
    end
    
    return {
        frameSelector = frameSelector,
        stateControls = stateControls,
        frameContainer = frameContainer,
        updateControls = UpdateFrameControls,
    }
end

---------------------------------------------------------------------------
-- TEST FUNCTION (for debugging)
---------------------------------------------------------------------------
-- Test anchor dropdown SetValue
-- Usage: /script local ns=_G.QuaziiUI;ns.QUI_LayoutManager_Options:TestAnchorDropdown("player")
function QUI_LayoutManager_Options:TestAnchorDropdown(unitKey)
    unitKey = unitKey or "player"
    
    local ns = _G.QuaziiUI
    if not ns then
        print("ERROR: QuaziiUI not found")
        return
    end
    
    -- Get unit frame
    local QUI_UF = ns.QUI_UF
    if not QUI_UF or not QUI_UF.frames then
        print("ERROR: Could not find unit frames")
        return
    end
    
    local frame = QUI_UF.frames[unitKey]
    if not frame then
        print("ERROR: Could not find frame for:", unitKey)
        return
    end
    
    print("✓ Found frame for:", unitKey)
    
    -- Get layout controls
    if not frame._layoutControls then
        print("ERROR: Frame has no _layoutControls")
        return
    end
    
    -- Find the anchor dropdown
    local anchorDropdown = nil
    for parent, controls in pairs(frame._layoutControls) do
        if controls and controls.anchorDropdown then
            anchorDropdown = controls.anchorDropdown
            print("✓ Found anchor dropdown")
            break
        end
    end
    
    if not anchorDropdown then
        print("ERROR: Could not find anchor dropdown")
        return
    end
    
    -- Get current value
    local currentValue = anchorDropdown:GetValue()
    print("Current dropdown value:", tostring(currentValue))
    
    -- Check options
    local optionsCount = anchorDropdown.options and #anchorDropdown.options or 0
    print("Options count:", optionsCount)
    
    -- Check if "none" is in options
    local hasNone = false
    local noneText = nil
    if anchorDropdown.options then
        for _, opt in ipairs(anchorDropdown.options) do
            if opt.value == "none" then
                hasNone = true
                noneText = opt.text
                print("✓ Found 'none' option with text:", tostring(opt.text))
                break
            end
        end
    end
    
    if not hasNone then
        print("WARNING: 'none' option not found in options list!")
        print("First 5 options:")
        if anchorDropdown.options then
            for i = 1, math.min(5, #anchorDropdown.options) do
                local opt = anchorDropdown.options[i]
                print(string.format("  [%d] value=%s, text=%s", i, tostring(opt.value), tostring(opt.text)))
            end
        end
    end
    
    -- Get current display text
    local currentText = ""
    if anchorDropdown.dropdown and anchorDropdown.dropdown.selected then
        currentText = anchorDropdown.dropdown.selected:GetText()
        print("Current display text:", tostring(currentText))
    end
    
    -- Test SetValue with "none"
    print("\n--- Testing SetValue('none', true) ---")
    anchorDropdown:SetValue("none", true)
    
    -- Check if it updated
    local newValue = anchorDropdown:GetValue()
    print("New dropdown value:", tostring(newValue))
    
    local newText = ""
    if anchorDropdown.dropdown and anchorDropdown.dropdown.selected then
        newText = anchorDropdown.dropdown.selected:GetText()
        print("New display text:", tostring(newText))
    end
    
    if newText ~= (noneText or "None") then
        print("❌ FAILED: Display text did not update correctly!")
        print("Expected:", tostring(noneText or "None"))
        print("Got:", tostring(newText))
    else
        print("✓ SUCCESS: Display text updated correctly")
    end
    
    print("\nTest complete!")
end

-- Global function for easier access
_G.QuaziiUI_TestAnchorDropdown = function(unitKey)
    local ns = _G.QuaziiUI
    if ns and ns.QUI_LayoutManager_Options then
        ns.QUI_LayoutManager_Options:TestAnchorDropdown(unitKey)
    else
        print("ERROR: QUI_LayoutManager_Options not found")
    end
end

return QUI_LayoutManager_Options
