--[[
    QUI Layout Control Options Module
    Reusable UI component for layout controls (anchoring, offset, size, presets)
    Provides a unified interface that can be used by any Options UI
    All implementation details are private local functions
]]

local ADDON_NAME, ns = ...

local QUI_LayoutControl_Options = {}
ns.QUI_LayoutControl_Options = QUI_LayoutControl_Options

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
        accent = {0.2, 0.6, 1},
        bg = {0.1, 0.1, 0.1}
    }
end

---------------------------------------------------------------------------
-- LOCAL HELPER FUNCTIONS (Private implementation details)
---------------------------------------------------------------------------

-- Create anchor dropdown
local function CreateAnchorDropdown(parent, label, frame, anchorKey, x, y, width, onChange, includeList, excludeList, excludeSelf)
    if not ns.QUI_Anchoring or not ns.QUI_Anchoring.GetAnchorTargetList then
        return nil
    end
    
    if not frame then
        return nil
    end
    
    local GUI = GetGUI()
    if not GUI then
        return nil
    end
    
    -- Get anchor options list (support dynamic options via function)
    local function GetAnchorOptions()
        return ns.QUI_Anchoring:GetAnchorTargetList(includeList, excludeList, excludeSelf)
    end
    local anchorOptions = GetAnchorOptions()
    
    -- Get current value from layout system (source of truth)
    local frameConfig = ns.QUI_LayoutManager:GetLayout(frame)
    if not frameConfig then
        return nil
    end
    
    -- Callback that updates layout system directly when anchor changes
    local function OnChangeWrapper(newAnchor)
        if not newAnchor then return end
        
        -- Read current value from layout system (source of truth) to check if it's actually a change
        local layout = ns.QUI_LayoutManager:GetLayout(frame)
        local currentAnchor = layout and layout.anchorTarget or "none"
        
        -- Only update if it's actually different
        if newAnchor ~= currentAnchor then
            -- Reset offsets to 0 when anchor changes (layout system handles this)
            ns.QUI_LayoutManager:UpdateLayout(frame, {
                anchorTarget = newAnchor,
                offsetX = 0,
                offsetY = 0,
            })
        end
        
        -- Call the original onChange callback if provided
        if onChange then
            onChange()
        end
    end
    
    -- Create dropdown using GUI helper without dbTable/dbKey - we'll override GetValue to read from layout system
    local container = GUI:CreateFormDropdown(parent, label, anchorOptions, nil, nil, OnChangeWrapper, nil, nil, GetAnchorOptions)
    
    -- Override GetValue to read directly from layout system (source of truth)
    local originalGetValue = container.GetValue
    container.GetValue = function(self)
        local layout = ns.QUI_LayoutManager:GetLayout(frame)
        if layout and layout.anchorTarget then
            return layout.anchorTarget
        end
        return originalGetValue and originalGetValue(self) or "none"
    end
    
    -- Store frame reference for refresh
    container._anchorFrame = frame
    
    -- Initialize with current value from layout system
    local initialValue = frameConfig.anchorTarget or "none"
    container:SetValue(initialValue, true)
    
    if x and y then
        container:SetPoint("TOPLEFT", x, y)
    end
    
    if width then
        container:SetPoint("RIGHT", parent, "RIGHT", -x or 0, 0)
    end
    
    return container
end

-- Create offset controls
local function CreateOffsetControls(parent, frame, x, y, onChange, PAD, FORM_ROW, offsetMin, offsetMax)
    local GUI = GetGUI()
    if not GUI then
        return nil, nil, y
    end
    
    if not frame or not ns.QUI_Anchoring then
        return nil, nil, y
    end
    
    -- Get current values from layout system (source of truth)
    local frameConfig = ns.QUI_LayoutManager:GetLayout(frame)
    if not frameConfig then
        return nil, nil, y
    end
    
    offsetMin = offsetMin or -500
    offsetMax = offsetMax or 500
    
    -- Ensure onChange is a function (default to empty function if nil)
    onChange = onChange or function() end
    
    -- Create temporary settings table for sliders (GUI helper expects it)
    local tempSettings = {}
    tempSettings.offsetX = tonumber(frameConfig.offsetX) or 0
    tempSettings.offsetY = tonumber(frameConfig.offsetY) or 0
    
    -- Wrapper for offsetX that updates layout system
    local function OnOffsetXChange()
        local newValue = tempSettings.offsetX
        ns.QUI_LayoutManager:UpdateLayout(frame, {offsetX = newValue})
        onChange()
    end
    
    -- Wrapper for offsetY that updates layout system
    local function OnOffsetYChange()
        local newValue = tempSettings.offsetY
        ns.QUI_LayoutManager:UpdateLayout(frame, {offsetY = newValue})
        onChange()
    end
    
    local offsetXSlider = GUI:CreateFormSlider(parent, "Offset X", offsetMin, offsetMax, 1, "offsetX", tempSettings, OnOffsetXChange)
    if offsetXSlider then
        offsetXSlider:SetPoint("TOPLEFT", x or PAD, y)
        offsetXSlider:SetPoint("RIGHT", parent, "RIGHT", -(x or PAD), 0)
        y = y - FORM_ROW
    end
    
    local offsetYSlider = GUI:CreateFormSlider(parent, "Offset Y", offsetMin, offsetMax, 1, "offsetY", tempSettings, OnOffsetYChange)
    if offsetYSlider then
        offsetYSlider:SetPoint("TOPLEFT", x or PAD, y)
        offsetYSlider:SetPoint("RIGHT", parent, "RIGHT", -(x or PAD), 0)
        y = y - FORM_ROW
    end
    
    return offsetXSlider, offsetYSlider, y
end

-- Create width/height controls
local function CreateWidthHeightControls(parent, frame, x, y, onChange, PAD, FORM_ROW, widthMin, widthMax, heightMin, heightMax)
    widthMin = widthMin or 0
    widthMax = widthMax or 2000
    heightMin = heightMin or 1
    heightMax = heightMax or 100
    
    local GUI = GetGUI()
    if not GUI then
        return nil, nil, y
    end
    
    if not frame or not ns.QUI_Anchoring then
        return nil, nil, y
    end
    
    -- Get current values from layout system (source of truth)
    local frameConfig = ns.QUI_LayoutManager:GetLayout(frame)
    if not frameConfig then
        return nil, nil, y
    end
    
    -- Create temporary settings table for sliders (GUI helper expects it)
    local tempSettings = {}
    tempSettings.width = tonumber(frameConfig.width) or 250  -- Default if nil
    tempSettings.height = tonumber(frameConfig.height) or 25  -- Default if nil
    
    -- Width/height sliders update the layout system directly
    -- Read current value from tempSettings (which is updated by the slider in real-time)
    local function OnWidthChange()
        local newValue = tempSettings.width
        if newValue and newValue > 0 then
            -- Always update layout - it will handle auto-sizing checks internally
            ns.QUI_LayoutManager:UpdateLayout(frame, {width = newValue})
        end
    end
    
    local function OnHeightChange()
        local newValue = tempSettings.height
        if newValue and newValue > 0 then
            -- Always update layout - it will handle auto-sizing checks internally
            ns.QUI_LayoutManager:UpdateLayout(frame, {height = newValue})
        end
    end
    
    -- Create width slider
    local widthSlider = GUI:CreateFormSlider(parent, "Width", widthMin, widthMax, 1, "width", tempSettings, OnWidthChange)
    if widthSlider then
        widthSlider:SetPoint("TOPLEFT", x or PAD, y)
        widthSlider:SetPoint("RIGHT", parent, "RIGHT", -(x or PAD), 0)
        y = y - FORM_ROW
    end
    
    -- Create height slider
    local heightSlider = GUI:CreateFormSlider(parent, "Height", heightMin, heightMax, 1, "height", tempSettings, OnHeightChange)
    if heightSlider then
        heightSlider:SetPoint("TOPLEFT", x or PAD, y)
        heightSlider:SetPoint("RIGHT", parent, "RIGHT", -(x or PAD), 0)
        y = y - FORM_ROW
    end
    
    -- Update enabled state based on anchor configuration
    local function UpdateWidthHeightState()
        local layout = ns.QUI_LayoutManager:GetLayout(frame)
        local autoConfig = layout and ns.QUI_Sizing:GetAutoConfig(layout.anchors, layout.anchorTarget) or nil
        if autoConfig then
            -- Width auto-managed by horizontal dual anchors
            if autoConfig.widthAuto and widthSlider then
                -- Get current width from frame (dual anchors set it automatically)
                local currentWidth = frame:GetWidth()
                if currentWidth and currentWidth > 0 then
                    -- Update layout system state with current frame width
                    ns.QUI_LayoutManager:UpdateLayout(frame, {width = currentWidth})
                    -- Update tempSettings so slider displays correct value
                    tempSettings.width = currentWidth
                    -- Update slider value to match
                    widthSlider:SetValue(currentWidth, true)
                end
                -- Disable width slider (auto-managed by dual anchors)
                widthSlider:SetEnabled(false)
            elseif widthSlider then
                widthSlider:SetEnabled(true)
            end
            
            -- Height auto-managed by vertical dual anchors
            if autoConfig.heightAuto and heightSlider then
                -- Get current height from frame (dual anchors set it automatically)
                local currentHeight = frame:GetHeight()
                if currentHeight and currentHeight > 0 then
                    -- Update layout system state with current frame height
                    ns.QUI_LayoutManager:UpdateLayout(frame, {height = currentHeight})
                    -- Update tempSettings so slider displays correct value
                    tempSettings.height = currentHeight
                    -- Update slider value to match
                    heightSlider:SetValue(currentHeight, true)
                end
                -- Disable height slider (auto-managed by dual anchors)
                heightSlider:SetEnabled(false)
            elseif heightSlider then
                heightSlider:SetEnabled(true)
            end
        else
            -- No auto-config - enable both
            if widthSlider then widthSlider:SetEnabled(true) end
            if heightSlider then heightSlider:SetEnabled(true) end
        end
    end
    
    -- Update state initially
    UpdateWidthHeightState()
    
    -- Return sliders, update function, and y position
    return widthSlider, heightSlider, UpdateWidthHeightState, y
end

-- Create multi-anchor popover
local function CreateMultiAnchorPopover(anchorButton, frame, onChange, maxAnchors)
    maxAnchors = maxAnchors or 2
    
    if not frame or not ns.QUI_Anchoring then
        return nil
    end
    
    local C = GetColors()
    local GUI = GetGUI()
    if not GUI then return nil end
    
    -- Get anchors from layout system (source of truth)
    local frameConfig = ns.QUI_LayoutManager:GetLayout(frame)
    if not frameConfig then
        return nil
    end
    
    -- Initialize anchors array if not exists
    local anchors = frameConfig.anchors
    if not anchors or #anchors == 0 then
        anchors = {{source = "BOTTOMLEFT", target = "BOTTOMLEFT"}}
        frameConfig.anchors = anchors
    end
    
    -- Create popover frame (anchored to button/container)
    local popover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popover:SetSize(420, 300)
    popover:SetPoint("TOPLEFT", anchorButton, "BOTTOMLEFT", 0, -5)
    popover:SetFrameStrata("FULLSCREEN_DIALOG")
    popover:SetFrameLevel(500)
    popover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    popover:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.98)
    popover:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    popover:EnableMouse(true)
    popover:SetClampedToScreen(true)
    popover:Hide()
    
    -- Close button in top right
    local closeBtn = GUI:CreateButton(popover, "×", 24, 24, function()
        popover:Hide()
    end)
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    if closeBtn.text then
        local fontPath = GUI.GetFontPath and GUI:GetFontPath() or "Fonts\\FRIZQT__.TTF"
        closeBtn.text:SetFont(fontPath, 16, "")
    end
    
    -- Title text
    local titleText = popover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", 5, -5)
    titleText:SetText("Advanced Anchor Settings")
    titleText:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 1)
    
    -- Content area (no scrolling needed for max 2 anchors)
    local content = CreateFrame("Frame", nil, popover)
    content:SetPoint("TOPLEFT", 2, -28)
    content:SetPoint("BOTTOMRIGHT", -2, 2)
    
    -- Create multi-anchor controls inside the content
    local PAD = 5  -- Reduced padding
    local FORM_ROW = 30
    local selectorSize = 75
    local spacing = 8  -- Reduced spacing
    local rowHeight = selectorSize + 30
    local currentY = -PAD
    
    -- Store references
    popover.anchors = anchors
    popover.maxAnchors = maxAnchors
    popover.onChange = onChange
    popover.anchorRows = {}
    
    -- Function to rebuild all anchor rows
    local function RebuildAnchors()
        -- Clear existing rows
        for i, row in ipairs(popover.anchorRows) do
            if row.frame then
                row.frame:Hide()
                row.frame:SetParent(nil)
            end
        end
        popover.anchorRows = {}
        currentY = -PAD
        
        -- Use popover.anchors (source of truth) instead of local anchors variable
        local anchorsToUse = popover.anchors or anchors
        
        -- Create rows for each anchor pair with improved styling
        for i, anchor in ipairs(anchorsToUse) do
            -- Container frame with background for list item appearance
            local rowFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
            rowFrame:SetHeight(rowHeight + 8)
            rowFrame:SetPoint("TOPLEFT", PAD, currentY)
            rowFrame:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
            
            -- Background for list item
            rowFrame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
                insets = {left = 2, right = 2, top = 2, bottom = 2}
            })
            rowFrame:SetBackdropColor(C.bg[1] * 1.2, C.bg[2] * 1.2, C.bg[3] * 1.2, 0.5)
            rowFrame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.3)
            
            -- Label for anchor pair number
            local label = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            label:SetPoint("LEFT", 5, 0)
            label:SetText("Anchor " .. i)
            label:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 1)
            
            -- Wrapper onChange that updates layout system
            local function OnAnchorChange()
                -- Update layout system when anchor points change
                ns.QUI_LayoutManager:UpdateLayout(frame, {anchors = popover.anchors})
                if onChange then onChange() end
            end
            
            -- Source anchor point selector (use public API from qui_anchoring_options)
            local sourceSelector = nil
            if ns.QUI_Anchoring_Options and ns.QUI_Anchoring_Options.CreateAnchorPointSelector then
                sourceSelector = ns.QUI_Anchoring_Options:CreateAnchorPointSelector(
                    rowFrame,
                    "Source",
                    anchor,
                    "source",
                    70,
                    0,
                    OnAnchorChange,
                    selectorSize
                )
            end
            
            -- Target anchor point selector
            local targetSelector = nil
            if ns.QUI_Anchoring_Options and ns.QUI_Anchoring_Options.CreateAnchorPointSelector then
                targetSelector = ns.QUI_Anchoring_Options:CreateAnchorPointSelector(
                    rowFrame,
                    "Target",
                    anchor,
                    "target",
                    70 + selectorSize + spacing,
                    0,
                    OnAnchorChange,
                    selectorSize
                )
            end
            
            -- Remove button (only show if more than 1 anchor)
            local removeButton
            if #anchorsToUse > 1 then
                removeButton = GUI:CreateButton(rowFrame, "×", 24, 24, function()
                    table.remove(popover.anchors, i)
                    -- Update layout system
                    ns.QUI_LayoutManager:UpdateLayout(frame, {anchors = popover.anchors})
                    RebuildAnchors()
                    if onChange then onChange() end
                end)
                removeButton:SetPoint("RIGHT", -5, 0)
                if removeButton.text then
                    local fontPath = GUI.GetFontPath and GUI:GetFontPath() or "Fonts\\FRIZQT__.TTF"
                    removeButton.text:SetFont(fontPath, 14, "")
                    removeButton.text:SetTextColor(0.9, 0.3, 0.3, 1) -- Red tint for remove
                end
            end
            
            table.insert(popover.anchorRows, {
                frame = rowFrame,
                sourceSelector = sourceSelector,
                targetSelector = targetSelector,
                removeButton = removeButton
            })
            
            currentY = currentY - (rowHeight + 8) - 3 -- Reduced spacing between items
        end
        
        -- Add button (only show if under max) - styled as a list item
        if #anchorsToUse < maxAnchors then
            if not popover.addButton then
                local addButtonFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
                addButtonFrame:SetHeight(FORM_ROW + 6)
                addButtonFrame:SetPoint("TOPLEFT", PAD, currentY)
                addButtonFrame:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
                
                addButtonFrame:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                    insets = {left = 2, right = 2, top = 2, bottom = 2}
                })
                addButtonFrame:SetBackdropColor(C.bg[1] * 1.1, C.bg[2] * 1.1, C.bg[3] * 1.1, 0.3)
                addButtonFrame:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.5)
                
                popover.addButton = GUI:CreateButton(addButtonFrame, "+ Add Anchor", 100, 22, function()
                    table.insert(popover.anchors, {source = "BOTTOMLEFT", target = "BOTTOMLEFT"})
                    -- Update layout system
                    ns.QUI_LayoutManager:UpdateLayout(frame, {anchors = popover.anchors})
                    RebuildAnchors()
                    if onChange then onChange() end
                end)
                popover.addButton:SetPoint("CENTER", 0, 0)
                popover.addButtonFrame = addButtonFrame
            end
            popover.addButtonFrame:SetPoint("TOPLEFT", PAD, currentY)
            popover.addButtonFrame:Show()
            currentY = currentY - (FORM_ROW + 6) - 3
        else
            if popover.addButtonFrame then
                popover.addButtonFrame:Hide()
            end
        end
    end
    
    -- Initial build
    RebuildAnchors()
    
    -- Click outside to close
    local clickFrame = CreateFrame("Frame", nil, UIParent)
    clickFrame:SetAllPoints(UIParent)
    clickFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    clickFrame:SetFrameLevel(499)
    clickFrame:EnableMouse(true)
    clickFrame:Hide()
    clickFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            popover:Hide()
        end
    end)
    popover.clickFrame = clickFrame
    
    -- ESC key to close
    popover:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    popover:EnableKeyboard(true)
    
    -- Expose methods
    popover.Show = function(self)
        -- Refresh before showing to ensure it displays current state
        if self.Refresh then
            self:Refresh()
        end
        self:SetShown(true)
        clickFrame:Show()
        -- Reposition relative to anchor (button or container)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", anchorButton, "BOTTOMLEFT", 0, -5)
    end
    
    popover.Hide = function(self)
        self:SetShown(false)
        clickFrame:Hide()
    end
    
    popover.Toggle = function(self)
        if self:IsShown() then
            self:Hide()
        else
            self:Show()
        end
    end
    
    popover.Refresh = function(self)
        -- Re-read anchors from layout system (source of truth)
        local currentFrameConfig = ns.QUI_LayoutManager:GetLayout(frame)
        if currentFrameConfig and currentFrameConfig.anchors then
            -- Create a copy of the anchors array to avoid reference issues
            local newAnchors = {}
            for _, anchor in ipairs(currentFrameConfig.anchors) do
                table.insert(newAnchors, {source = anchor.source, target = anchor.target})
            end
            -- Update the popover's stored reference (this is what RebuildAnchors uses)
            popover.anchors = newAnchors
            -- Also update the local variable for backward compatibility
            anchors = newAnchors
        end
        RebuildAnchors()
    end
    
    return popover
end

-- Create anchor preset controls
local function CreateAnchorPresetControls(parent, frame, x, y, onChange, PAD, FORM_ROW, maxAnchors, onPresetChange, offsetXSlider, offsetYSlider)
    maxAnchors = maxAnchors or 2
    
    if not frame or not ns.QUI_Anchoring then
        return nil, nil, nil, y
    end
    
    local C = GetColors()
    local GUI = GetGUI()
    if not GUI then return nil, nil, nil, y end
    
    -- Get anchors from layout system (source of truth)
    local frameConfig = ns.QUI_LayoutManager:GetLayout(frame)
    if not frameConfig then
        return nil, nil, nil, y
    end
    
    -- Initialize anchors array if not exists
    local anchors = frameConfig.anchors
    if not anchors or #anchors == 0 then
        anchors = {{source = "BOTTOMLEFT", target = "BOTTOMLEFT"}}
        frameConfig.anchors = anchors
    end
    
    -- Preset buttons container
    local presetButtonContainer = CreateFrame("Frame", nil, parent)
    presetButtonContainer:SetHeight(FORM_ROW)
    presetButtonContainer:SetPoint("TOPLEFT", x or PAD, y)
    presetButtonContainer:SetPoint("RIGHT", parent, "RIGHT", -(x or PAD), 0)
    
    local presetLabel = presetButtonContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    presetLabel:SetPoint("LEFT", 0, 0)
    presetLabel:SetText("Anchor presets (auto-size):")
    presetLabel:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
    
    local buttonSpacing = 8
    local labelWidth = 180  -- Width reserved for label
    local buttonsPerRow = 4
    
    -- Create all auto-size preset buttons array (declared early so RelayoutPresetButtons can access it)
    local autoSizeButtons = {}
    
    -- Helper function to calculate and apply button widths dynamically
    local function RelayoutPresetButtons()
        local containerWidth = presetButtonContainer:GetWidth()
        if containerWidth < 1 then return end  -- Not sized yet
        
        if not autoSizeButtons or #autoSizeButtons == 0 then return end  -- Buttons not created yet
        
        local availableWidth = containerWidth - labelWidth - buttonSpacing
        local totalSpacing = (buttonsPerRow - 1) * buttonSpacing
        local buttonWidth = math.floor((availableWidth - totalSpacing) / buttonsPerRow)
        buttonWidth = math.max(buttonWidth, 60)  -- Minimum 60px
        
        -- Update all auto-size buttons
        for i, button in ipairs(autoSizeButtons) do
            button:SetWidth(buttonWidth)
            local rowIndex = math.floor((i - 1) / buttonsPerRow)
            local colIndex = (i - 1) % buttonsPerRow
            
            button:ClearAllPoints()
            if colIndex == 0 then
                -- First button in row - align with label
                button:SetPoint("TOPLEFT", presetButtonContainer, "TOPLEFT", labelWidth, -rowIndex * FORM_ROW)
            else
                -- Subsequent button - align with previous button in same row
                local previousButton = autoSizeButtons[i - 1]
                button:SetPoint("LEFT", previousButton, "RIGHT", buttonSpacing, 0)
            end
        end
    end
    
    -- Hook resize to relayout buttons dynamically
    presetButtonContainer:SetScript("OnSizeChanged", RelayoutPresetButtons)
    
    -- Helper function to position buttons with wrapping (initial positioning)
    local function PositionButton(button, buttonIndex, allButtons)
        local rowIndex = math.floor((buttonIndex - 1) / buttonsPerRow)
        local colIndex = (buttonIndex - 1) % buttonsPerRow
        
        if colIndex == 0 then
            -- First button in row - align with label
            button:SetPoint("TOPLEFT", presetButtonContainer, "TOPLEFT", labelWidth, -rowIndex * FORM_ROW)
        else
            -- Subsequent button - align with previous button in same row
            local previousButton = allButtons[buttonIndex - 1]
            button:SetPoint("LEFT", previousButton, "RIGHT", buttonSpacing, 0)
        end
    end
    
    -- Helper function to update width/height sliders after positioning
    -- Called after SetPoint completes to sync locked sliders with actual frame dimensions
    local function UpdateAutoSizeSliders()
        -- Defer to allow SetPoint to complete
        C_Timer.After(0, function()
            local config = ns.QUI_LayoutManager:GetLayout(frame)
            local autoConfig = config and ns.QUI_Sizing:GetAutoConfig(config.anchors, config.anchorTarget) or nil
            if autoConfig then
                -- Width auto-managed by horizontal dual anchors
                if autoConfig.widthAuto then
                    local currentWidth = frame:GetWidth()
                    if currentWidth and currentWidth > 0 then
                        -- Update layout system state with current frame width
                        ns.QUI_LayoutManager:UpdateLayout(frame, {width = currentWidth})
                    end
                end
                
                -- Height auto-managed by vertical dual anchors
                if autoConfig.heightAuto then
                    local currentHeight = frame:GetHeight()
                    if currentHeight and currentHeight > 0 then
                        -- Update layout system state with current frame height
                        ns.QUI_LayoutManager:UpdateLayout(frame, {height = currentHeight})
                    end
                end
            end
        end)
    end
    
    -- Helper function to apply preset and refresh
    local function ApplyPreset(presetAnchors, refreshPopover)
        -- Create new anchors array
        local newAnchors = {}
        for _, anchor in ipairs(presetAnchors) do
            table.insert(newAnchors, anchor)
        end
        
        -- Update layout system (reset offsets to 0 when applying presets)
        ns.QUI_LayoutManager:UpdateLayout(frame, {
            anchors = newAnchors,
            offsetX = 0,
            offsetY = 0,
        })
        
        -- Update anchors reference
        frameConfig.anchors = newAnchors
        anchors = newAnchors
        
        -- Update slider values to reflect the reset offsets
        if offsetXSlider then
            offsetXSlider:SetValue(0, true)
        end
        if offsetYSlider then
            offsetYSlider:SetValue(0, true)
        end
        
        if onPresetChange then
            onPresetChange()
        end
        if onChange then
            onChange()
        end
        
        -- Update width/height sliders if auto-managed by dual anchors
        UpdateAutoSizeSliders()
        
        if refreshPopover then
            refreshPopover()
        end
    end
    
    -- Above (auto width) - castbar above target, auto width matching
    local presetAboveBtn = GUI:CreateButton(presetButtonContainer, "Above (auto)", 110, 24, function()
        ApplyPreset({
            {source = "BOTTOMLEFT", target = "TOPLEFT"},
            {source = "BOTTOMRIGHT", target = "TOPRIGHT"}
        })
    end)
    table.insert(autoSizeButtons, presetAboveBtn)
    
    -- Below (auto width) - castbar below target, auto width matching
    local presetBelowBtn = GUI:CreateButton(presetButtonContainer, "Below (auto)", 110, 24, function()
        ApplyPreset({
            {source = "TOPLEFT", target = "BOTTOMLEFT"},
            {source = "TOPRIGHT", target = "BOTTOMRIGHT"}
        })
    end)
    table.insert(autoSizeButtons, presetBelowBtn)
    
    -- Left (auto height) - castbar to the left of target, auto height matching
    local presetLeftBtn = GUI:CreateButton(presetButtonContainer, "Left (auto)", 110, 24, function()
        ApplyPreset({
            {source = "TOPRIGHT", target = "TOPLEFT"},
            {source = "BOTTOMRIGHT", target = "BOTTOMLEFT"}
        })
    end)
    table.insert(autoSizeButtons, presetLeftBtn)
    
    -- Right (auto height) - castbar to the right of target, auto height matching
    local presetRightBtn = GUI:CreateButton(presetButtonContainer, "Right (auto)", 110, 24, function()
        -- Handler will be replaced by UpdatePresetHandler below
    end)
    table.insert(autoSizeButtons, presetRightBtn)
    
    -- Position all buttons with wrapping (initial positioning)
    for i, button in ipairs(autoSizeButtons) do
        PositionButton(button, i, autoSizeButtons)
    end
    
    -- Update container height to accommodate buttons
    local totalButtons = #autoSizeButtons
    local rows = math.ceil(totalButtons / buttonsPerRow)
    presetButtonContainer:SetHeight(rows * FORM_ROW)
    
    -- Trigger initial relayout after container is sized
    C_Timer.After(0, function()
        RelayoutPresetButtons()
    end)
    
    y = y - (rows * FORM_ROW)  -- Account for button rows
    
    -- Create refresh function for popover (will be updated after dialog is created)
    local RefreshPopover = function()
        -- This will be updated after advancedAnchorDialog is created
    end
    
    -- Update preset button handlers to refresh popover
    local function UpdatePresetHandler(btn, presetAnchors)
        local originalOnClick = btn:GetScript("OnClick")
        btn:SetScript("OnClick", function()
            ApplyPreset(presetAnchors, RefreshPopover)
        end)
    end
    
    UpdatePresetHandler(presetAboveBtn, {
        {source = "BOTTOMLEFT", target = "TOPLEFT"},
        {source = "BOTTOMRIGHT", target = "TOPRIGHT"}
    })
    
    UpdatePresetHandler(presetBelowBtn, {
        {source = "TOPLEFT", target = "BOTTOMLEFT"},
        {source = "TOPRIGHT", target = "BOTTOMRIGHT"}
    })
    
    UpdatePresetHandler(presetLeftBtn, {
        {source = "TOPRIGHT", target = "TOPLEFT"},
        {source = "BOTTOMRIGHT", target = "BOTTOMLEFT"}
    })
    
    UpdatePresetHandler(presetRightBtn, {
        {source = "TOPLEFT", target = "TOPRIGHT"},
        {source = "BOTTOMLEFT", target = "BOTTOMRIGHT"}
    })
    
    -- Second row: Single anchor presets (center-to-center, no auto-sizing)
    local singleAnchorContainer = CreateFrame("Frame", nil, parent)
    singleAnchorContainer:SetPoint("TOPLEFT", x or PAD, y)
    singleAnchorContainer:SetPoint("RIGHT", parent, "RIGHT", -(x or PAD), 0)
    
    local singleAnchorLabel = singleAnchorContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    singleAnchorLabel:SetPoint("LEFT", 0, 0)
    singleAnchorLabel:SetText("Anchor presets:")
    singleAnchorLabel:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
    
    -- Fixed 2x2 grid layout (2 buttons per row, 2 rows)
    local singleButtonsPerRow = 4
    
    -- Create all single anchor preset buttons array (declared early so RelayoutSingleButtons can access it)
    local singleButtons = {}
    
    -- Helper function to calculate and apply single anchor button widths dynamically
    local function RelayoutSingleButtons()
        local containerWidth = singleAnchorContainer:GetWidth()
        if containerWidth < 1 then return end  -- Not sized yet
        
        if not singleButtons or #singleButtons == 0 then return end  -- Buttons not created yet
        
        local availableWidth = containerWidth - labelWidth - buttonSpacing
        local totalSpacing = (singleButtonsPerRow - 1) * buttonSpacing
        local buttonWidth = math.floor((availableWidth - totalSpacing) / singleButtonsPerRow)
        buttonWidth = math.max(buttonWidth, 60)  -- Minimum 60px
        
        -- Update all single anchor buttons
        for i, button in ipairs(singleButtons) do
            button:SetWidth(buttonWidth)
            local rowIndex = math.floor((i - 1) / singleButtonsPerRow)
            local colIndex = (i - 1) % singleButtonsPerRow
            
            button:ClearAllPoints()
            if colIndex == 0 then
                -- First button in row - align with label
                button:SetPoint("TOPLEFT", singleAnchorContainer, "TOPLEFT", labelWidth, -rowIndex * FORM_ROW)
            else
                -- Subsequent button - align with previous button in same row
                local previousButton = singleButtons[i - 1]
                button:SetPoint("LEFT", previousButton, "RIGHT", buttonSpacing, 0)
            end
        end
    end
    
    -- Hook resize to relayout buttons dynamically
    singleAnchorContainer:SetScript("OnSizeChanged", RelayoutSingleButtons)
    
    -- Helper function to position single anchor buttons with wrapping (initial positioning)
    local function PositionSingleButton(button, buttonIndex, allButtons)
        local rowIndex = math.floor((buttonIndex - 1) / singleButtonsPerRow)
        local colIndex = (buttonIndex - 1) % singleButtonsPerRow
        
        if colIndex == 0 then
            -- First button in row - align with label
            button:SetPoint("TOPLEFT", singleAnchorContainer, "TOPLEFT", labelWidth, -rowIndex * FORM_ROW)
        else
            -- Subsequent button - align with previous button in same row
            local previousButton = allButtons[buttonIndex - 1]
            button:SetPoint("LEFT", previousButton, "RIGHT", buttonSpacing, 0)
        end
    end
    
    -- Above - BOTTOM (source) -> TOP (target), center to center (source above target)
    local singleAboveBtn = GUI:CreateButton(singleAnchorContainer, "Above", 110, 24, function()
        ApplyPreset({{source = "BOTTOM", target = "TOP"}}, RefreshPopover)
    end)
    table.insert(singleButtons, singleAboveBtn)
    
    -- Below - TOP (source) -> BOTTOM (target), center to center
    local singleBelowBtn = GUI:CreateButton(singleAnchorContainer, "Below", 110, 24, function()
        ApplyPreset({{source = "TOP", target = "BOTTOM"}}, RefreshPopover)
    end)
    table.insert(singleButtons, singleBelowBtn)
    
    -- Left - RIGHT (source) -> LEFT (target), middle to middle (source to left of target)
    local singleLeftBtn = GUI:CreateButton(singleAnchorContainer, "Left", 110, 24, function()
        ApplyPreset({{source = "RIGHT", target = "LEFT"}}, RefreshPopover)
    end)
    table.insert(singleButtons, singleLeftBtn)
    
    -- Right - LEFT (source) -> RIGHT (target), middle to middle
    local singleRightBtn = GUI:CreateButton(singleAnchorContainer, "Right", 110, 24, function()
        ApplyPreset({{source = "LEFT", target = "RIGHT"}}, RefreshPopover)
    end)
    table.insert(singleButtons, singleRightBtn)
    
    -- Position all buttons with wrapping (initial positioning)
    for i, button in ipairs(singleButtons) do
        PositionSingleButton(button, i, singleButtons)
    end
    
    -- Update container height to accommodate wrapped buttons
    local totalSingleButtons = #singleButtons
    local singleRows = math.ceil(totalSingleButtons / singleButtonsPerRow)
    singleAnchorContainer:SetHeight(singleRows * FORM_ROW)
    
    -- Trigger initial relayout after container is sized
    C_Timer.After(0, function()
        RelayoutSingleButtons()
    end)
    
    y = y - (singleRows * FORM_ROW)  -- Account for button rows
    
    -- Third row: Advanced button
    local advancedContainer = CreateFrame("Frame", nil, parent)
    advancedContainer:SetHeight(FORM_ROW)
    advancedContainer:SetPoint("TOPLEFT", x or PAD, y)
    advancedContainer:SetPoint("RIGHT", parent, "RIGHT", -(x or PAD), 0)
    
    local advancedAnchorButton = GUI:CreateButton(
        advancedContainer,
        "Advanced...",
        110,  -- Fixed width for Advanced button
        24,
        function()
            -- Toggle will be handled by the popover creation
        end
    )
    advancedAnchorButton:SetPoint("LEFT", advancedContainer, "LEFT", 180, 0)  -- Align with other buttons
    
    -- Create advanced anchor popover (anchored to the Advanced button)
    local advancedAnchorDialog = CreateMultiAnchorPopover(
        advancedAnchorButton,  -- Anchor to Advanced button
        frame,
        onChange,
        maxAnchors
    )
    
    -- Update RefreshPopover to use the created dialog
    RefreshPopover = function()
        if advancedAnchorDialog and advancedAnchorDialog.Refresh then
            advancedAnchorDialog:Refresh()
        end
    end
    
    -- Hook into popover's Show event to refresh when opened (ensures it shows current state)
    advancedAnchorDialog:HookScript("OnShow", function()
        RefreshPopover()
    end)
    
    -- Set button click handler to toggle popover
    advancedAnchorButton:SetScript("OnClick", function()
        if advancedAnchorDialog then
            -- Refresh before showing to ensure it displays current state
            if not advancedAnchorDialog:IsShown() then
                RefreshPopover()
            end
            advancedAnchorDialog:Toggle()
        end
    end)
    
    -- Store reference to popover refresh in button for preset updates
    advancedAnchorButton._popover = advancedAnchorDialog
    
    y = y - FORM_ROW  -- Account for third row
    
    return presetButtonContainer, advancedAnchorButton, advancedAnchorDialog, y
end

---------------------------------------------------------------------------
-- PUBLIC API
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- CREATE LAYOUT CONTROL
-- Creates a unified layout control component with configurable sections
-- Parameters:
--   parent: Parent frame to add controls to
--   frame: The frame being configured (required for layout system)
--   y: Current y position (will be updated and returned)
--   PAD: Padding constant
--   FORM_ROW: Form row height constant
--   onChange: Optional callback when values change
--   options: Optional configuration table with:
--     sectionTitle: Title for the main collapsible section (default: "Layout")
--     showAnchoring: Show anchor dropdown section (default: true)
--     showOffset: Show offset sliders section (default: true)
--     showSize: Show width/height sliders section (default: true)
--     showPresets: Show preset buttons section (default: true)
--     isExpandedByDefault: Whether section starts expanded (default: false)
--     previousSection: Optional previous section for relative positioning
--     Plus all existing CreateAnchorControls options (anchorKey, maxAnchors, offsetMin, offsetMax, widthMin, widthMax, heightMin, heightMax, etc.)
-- Returns:
--   layoutSection: The main collapsible section frame
--   layoutContent: The content frame inside the section
--   updatedY: Updated y position
--   controls: Table containing references to all created controls
---------------------------------------------------------------------------
function QUI_LayoutControl_Options:CreateLayoutControl(parent, frame, y, PAD, FORM_ROW, onChange, options)
    -- Validate required parameters
    if not frame or not ns.QUI_Anchoring then
        return nil, nil, y, {}
    end
    
    -- Validate parameter types
    if type(y) ~= "number" then
        error(string.format("CreateLayoutControl: parameter 'y' must be a number, got %s.", type(y)), 2)
    end
    if type(onChange) ~= "function" and onChange ~= nil then
        error(string.format("CreateLayoutControl: parameter 'onChange' must be a function or nil, got %s.", type(onChange)), 2)
    end
    if type(PAD) ~= "number" then
        error(string.format("CreateLayoutControl: parameter 'PAD' must be a number, got %s.", type(PAD)), 2)
    end
    if type(FORM_ROW) ~= "number" then
        error(string.format("CreateLayoutControl: parameter 'FORM_ROW' must be a number, got %s.", type(FORM_ROW)), 2)
    end
    
    options = options or {}
    
    -- Extract layout control specific options (default all to true)
    local sectionTitle = options.sectionTitle or "Layout"
    local showAnchoring = options.showAnchoring ~= false  -- Default to true
    local showOffset = options.showOffset ~= false  -- Default to true
    local showSize = options.showSize ~= false  -- Default to true
    local showPresets = options.showPresets ~= false  -- Default to true
    local isExpandedByDefault = options.isExpandedByDefault or false
    local previousSection = options.previousSection
    
    -- Get OptionsShared for creating collapsible sections
    local OptionsShared = ns.OptionsShared
    if not OptionsShared then
        return nil, nil, y, {}
    end
    
    -- Ensure onChange is a function
    onChange = onChange or function() end
    
    -- Create main collapsible "Layout" section
    local layoutSection, layoutContent, updatedY = OptionsShared.CreateCollapsibleSection(
        parent, sectionTitle, y, PAD, isExpandedByDefault, previousSection
    )
    
    -- Controls table to return
    local controls = {
        layoutSection = layoutSection,
        layoutContent = layoutContent,
        anchorDropdown = nil,
        offsetXSlider = nil,
        offsetYSlider = nil,
        widthSlider = nil,
        heightSlider = nil,
        presetContainer = nil,
        advancedButton = nil,
        popover = nil,
    }
    
    -- Track current Y position inside the layout content
    local layoutY = 0
    
    -- Get frame config from layout system (source of truth)
    local frameConfig = ns.QUI_LayoutManager:GetLayout(frame)
    if not frameConfig then
        return layoutSection, layoutContent, updatedY, controls
    end
    
    -- Extract options for anchor controls
    local anchorOptions = {}
    for k, v in pairs(options) do
        -- Skip our layout control specific options
        if k ~= "sectionTitle" and k ~= "showAnchoring" and k ~= "showOffset" and 
           k ~= "showSize" and k ~= "showPresets" and k ~= "isExpandedByDefault" and 
           k ~= "previousSection" then
            anchorOptions[k] = v
        end
    end
    
    -- Initialize wrappedOnChange (will be updated if width/height controls are created)
    local wrappedOnChange = onChange
    
    -- ========================================
    -- ANCHOR TO SECTION (if showAnchoring)
    -- ========================================
    local anchorSection, anchorContent
    local anchorDropdown
    if showAnchoring then
        local dropdownLabel = anchorOptions.dropdownLabel or "Anchor To"
        anchorSection, anchorContent, layoutY = OptionsShared.CreateCollapsibleSection(
            layoutContent, dropdownLabel, layoutY, PAD, true, nil  -- Expanded by default
        )
        local anchorY = 0
        
        -- Create anchor dropdown inside the section
        anchorDropdown = CreateAnchorDropdown(
            anchorContent, dropdownLabel, frame, anchorOptions.anchorKey or "anchorTo", PAD, anchorY, nil, onChange, nil, nil, anchorOptions.excludeSelf
        )
        if anchorDropdown then
            anchorDropdown:SetPoint("TOPLEFT", PAD, anchorY)
            anchorDropdown:SetPoint("RIGHT", anchorContent, "RIGHT", -PAD, 0)
            anchorY = anchorY - FORM_ROW
        end
        
        -- Update anchor section height
        anchorContent:SetHeight(math.abs(anchorY) + 4)
        anchorSection:UpdateHeight()
        
        controls.anchorDropdown = anchorDropdown
    end
    
    -- ========================================
    -- PRESETS SECTION (if showPresets) - placed under Anchor To
    -- ========================================
    local presetSection, presetContent
    local presetContainer, advancedButton, popover
    if showPresets then
        -- Chain to Anchor To section (or nil if anchoring is hidden)
        local previousSectionForPresets = showAnchoring and anchorSection or nil
        presetSection, presetContent, layoutY = OptionsShared.CreateCollapsibleSection(
            layoutContent, "Presets", layoutY, PAD, false, previousSectionForPresets  -- Collapsed by default
        )
        local presetY = 0
        
        -- Create preset controls inside the section
        local maxAnchors = anchorOptions.maxAnchors or 2
        presetContainer, advancedButton, popover, presetY = CreateAnchorPresetControls(
            presetContent, frame, PAD, presetY, wrappedOnChange, PAD, FORM_ROW, maxAnchors, anchorOptions.onPresetChange, offsetXSlider, offsetYSlider
        )
        
        -- Update preset section height
        if presetY then
            presetContent:SetHeight(math.abs(presetY) + 4)
            presetSection:UpdateHeight()
        end
        
        controls.presetContainer = presetContainer
        controls.advancedButton = advancedButton
        controls.popover = popover
    end
    
    -- ========================================
    -- OFFSET SECTION (if showOffset)
    -- ========================================
    local offsetSection, offsetContent
    local offsetXSlider, offsetYSlider
    if showOffset then
        -- Chain to Presets if shown, otherwise Anchor To
        local previousSectionForOffset = showPresets and presetSection or (showAnchoring and anchorSection or nil)
        offsetSection, offsetContent, layoutY = OptionsShared.CreateCollapsibleSection(
            layoutContent, "Offset", layoutY, PAD, true, previousSectionForOffset  -- Expanded by default
        )
        local offsetY = 0
        
        -- Create offset sliders inside the section
        local offsetMin = anchorOptions.offsetMin or -500
        local offsetMax = anchorOptions.offsetMax or 500
        offsetXSlider, offsetYSlider, offsetY = CreateOffsetControls(
            offsetContent, frame, PAD, offsetY, onChange, PAD, FORM_ROW, offsetMin, offsetMax
        )
        
        -- Update offset section height
        if offsetY then
            offsetContent:SetHeight(math.abs(offsetY) + 4)
            offsetSection:UpdateHeight()
        end
        
        controls.offsetXSlider = offsetXSlider
        controls.offsetYSlider = offsetYSlider
    end
    
    -- ========================================
    -- SIZE SECTION (if showSize)
    -- ========================================
    local sizeSection, sizeContent
    local widthSlider, heightSlider, updateWidthHeightState
    if showSize then
        -- Chain to Offset if shown, otherwise Presets, otherwise Anchor To
        local previousSectionForSize = showOffset and offsetSection or (showPresets and presetSection or (showAnchoring and anchorSection or nil))
        sizeSection, sizeContent, layoutY = OptionsShared.CreateCollapsibleSection(
            layoutContent, "Size", layoutY, PAD, true, previousSectionForSize  -- Expanded by default
        )
        local sizeY = 0
        
        widthSlider, heightSlider, updateWidthHeightState, sizeY = CreateWidthHeightControls(
            sizeContent, frame, PAD, sizeY, onChange, PAD, FORM_ROW,
            anchorOptions.widthMin, anchorOptions.widthMax, anchorOptions.heightMin, anchorOptions.heightMax
        )
        
        -- Wrap onChange to also update width/height state when anchors change
        local originalOnChange = onChange
        wrappedOnChange = function()
            if originalOnChange then originalOnChange() end
            -- Update width/height state after anchors change (dual anchors may have changed)
            if updateWidthHeightState then
                C_Timer.After(0, updateWidthHeightState)  -- Defer to allow frame size to update
            end
        end
        
        -- Update size section height
        if sizeY then
            sizeContent:SetHeight(math.abs(sizeY) + 4)
            sizeSection:UpdateHeight()
        end
        
        controls.widthSlider = widthSlider
        controls.heightSlider = heightSlider
    end
    
    
    -- Update layout content height
    if layoutY then
        layoutContent:SetHeight(math.abs(layoutY) + 4)
        layoutSection:UpdateHeight()
    end
    
    -- Initialize UI controls from layout system (source of truth)
    if frameConfig.anchorTarget and anchorDropdown then
        anchorDropdown:SetValue(frameConfig.anchorTarget, true)
    end
    if type(frameConfig.offsetX) == "number" and offsetXSlider then
        offsetXSlider:SetValue(frameConfig.offsetX, true)
    end
    if type(frameConfig.offsetY) == "number" and offsetYSlider then
        offsetYSlider:SetValue(frameConfig.offsetY, true)
    end
    if showSize then
        if type(frameConfig.width) == "number" and widthSlider then
            widthSlider:SetValue(frameConfig.width, true)
        end
        if type(frameConfig.height) == "number" and heightSlider then
            heightSlider:SetValue(frameConfig.height, true)
        end
    end
    
    -- Store controls reference on frame for later refresh
    if not frame._layoutControls then
        frame._layoutControls = {}
    end
    frame._layoutControls[parent] = controls
    
    -- Update final Y position (account for collapsed/expanded state)
    updatedY = updatedY - layoutSection:GetHeight()
    
    return layoutSection, layoutContent, updatedY, controls
end

return QUI_LayoutControl_Options
