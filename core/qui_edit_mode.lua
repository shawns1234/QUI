--[[
    QUI Edit Mode Module
    Handles edit mode functionality for layout system
    Single Responsibility: Manage edit mode (drag, keyboard nudging, overlays)
]]

local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- MODULE TABLE
---------------------------------------------------------------------------
local QUI_EditMode = {}
ns.QUI_EditMode = QUI_EditMode

---------------------------------------------------------------------------
-- ENABLE EDIT MODE DRAG TRACKING
---------------------------------------------------------------------------
-- Enable edit mode drag tracking for a frame
-- Automatically handles drag start/stop, unregisters anchor, updates config
-- Parameters:
--   frame: The frame to track
--   configCallback: Function(config) that updates the config table with new values and returns the config
--   updateCallback: Optional function() to call after config update to refresh the frame (e.g., UpdatePowerBar)
--   notifyCallbacks: Optional table with {onAnchorChanged, onPositionChanged} for UI notifications
-- Returns: cleanup function to call when edit mode is disabled
function QUI_EditMode:EnableDragTracking(frame, configCallback, updateCallback, notifyCallbacks)
    if not frame or not configCallback then return function() end end
    
    local originalOnDragStart = frame:GetScript("OnDragStart")
    local originalOnDragStop = frame:GetScript("OnDragStop")
    
    frame:SetScript("OnDragStart", function(self)
        -- Capture current position using GetRect() - more reliable than GetCenter() for secure frames
        local left, bottom, width, height = self:GetRect()
        local parentLeft, parentBottom, parentWidth, parentHeight = UIParent:GetRect()
        
        local currentOffsetX, currentOffsetY = 0, 0
        
        -- Get existing position from config as fallback
        local QUI_LayoutManager = ns.QUI_LayoutManager
        local frameConfig = QUI_LayoutManager and QUI_LayoutManager:GetLayout(self) or nil
        if frameConfig then
            currentOffsetX = frameConfig.offsetX or 0
            currentOffsetY = frameConfig.offsetY or 0
        end
        
        -- Calculate center position from rect (more reliable than GetCenter())
        if left and bottom and width and height and parentLeft and parentBottom and parentWidth and parentHeight then
            local selfCenterX = left + (width / 2)
            local selfCenterY = bottom + (height / 2)
            local parentCenterX = parentLeft + (parentWidth / 2)
            local parentCenterY = parentBottom + (parentHeight / 2)
            
            currentOffsetX = math.floor(selfCenterX - parentCenterX + 0.5)
            currentOffsetY = math.floor(selfCenterY - parentCenterY + 0.5)
        end
        -- If GetRect() failed, we use the existing position from frameConfig above
        
        -- Update config with current position AND anchor = "none"
        -- configCallback updates the layout system (UpdateLayout) which handles config updates and repositioning
        configCallback({
            anchorTo = "none",
            offsetX = currentOffsetX,
            offsetY = currentOffsetY,
        })
        
        -- Now start the drag
        if originalOnDragStart then
            originalOnDragStart(self)
        else
            self:StartMoving()
        end
    end)
    
    frame:SetScript("OnDragStop", function(self)
        -- Stop moving first
        if originalOnDragStop then
            originalOnDragStop(self)
        else
            self:StopMovingOrSizing()
        end
        
        -- Read final position using GetRect() - more reliable than GetCenter() for secure frames
        local left, bottom, width, height = self:GetRect()
        local parentLeft, parentBottom, parentWidth, parentHeight = UIParent:GetRect()
        
        if left and bottom and width and height and parentLeft and parentBottom and parentWidth and parentHeight then
            -- Calculate center position from rect
            local selfCenterX = left + (width / 2)
            local selfCenterY = bottom + (height / 2)
            local parentCenterX = parentLeft + (parentWidth / 2)
            local parentCenterY = parentBottom + (parentHeight / 2)
            
            local offsetX = math.floor(selfCenterX - parentCenterX + 0.5)
            local offsetY = math.floor(selfCenterY - parentCenterY + 0.5)
            
            -- Update config (frame stays registered in our system)
            -- configCallback updates the layout system (UpdateLayout) which handles config updates, saving, and repositioning
            -- UpdateLayout will automatically refresh the options UI
            configCallback({
                anchorTo = "none",
                offsetX = offsetX,
                offsetY = offsetY,
            })
            
            -- Optional: update UI
            if updateCallback then
                updateCallback()
            end
            if notifyCallbacks and notifyCallbacks.onPositionChanged then
                notifyCallbacks.onPositionChanged(offsetX, offsetY)
            end
        end
    end)
    
    -- Cleanup
    return function()
        frame:SetScript("OnDragStart", originalOnDragStart)
        frame:SetScript("OnDragStop", originalOnDragStop)
    end
end

---------------------------------------------------------------------------
-- ENABLE EDIT MODE KEYBOARD NUDGING
---------------------------------------------------------------------------
-- Enable edit mode keyboard nudging for a frame
-- Automatically handles arrow key nudging, unregisters anchor, updates config, and re-registers
-- Parameters:
--   frame: The frame to track
--   configCallback: Function(config) that updates the config table with new values and returns the config
--   updateCallback: Optional function() to call after config update to refresh the frame
--   notifyCallbacks: Optional table with {onAnchorChanged, onPositionChanged} for UI notifications
--   skipKeyboardEnable: Optional boolean to skip EnableKeyboard call (for secure frames)
-- Returns: cleanup function to call when edit mode is disabled
function QUI_EditMode:EnableKeyboardNudging(frame, configCallback, updateCallback, notifyCallbacks, skipKeyboardEnable)
    if not frame or not configCallback then return function() end end
    
    local originalOnKeyDown = frame:GetScript("OnKeyDown")
    
    -- Enable keyboard input if not skipped (some secure frames can't enable keyboard)
    if not skipKeyboardEnable then
        frame:EnableKeyboard(true)
    end
    
    frame:SetScript("OnKeyDown", function(self, key)
        local deltaX, deltaY = 0, 0
        if key == "LEFT" then deltaX = -1
        elseif key == "RIGHT" then deltaX = 1
        elseif key == "UP" then deltaY = 1
        elseif key == "DOWN" then deltaY = -1
        else 
            -- Pass through to original handler for other keys
            if originalOnKeyDown then
                originalOnKeyDown(self, key)
            end
            return
        end
        
        -- Get current position using GetRect() - more reliable than GetCenter() for secure frames
        local left, bottom, width, height = self:GetRect()
        local parentLeft, parentBottom, parentWidth, parentHeight = UIParent:GetRect()
        
        if not (left and bottom and width and height and parentLeft and parentBottom and parentWidth and parentHeight) then
            -- Cannot calculate position - fail gracefully
            return
        end
        
        -- Calculate step size (shift = 10 pixels, normal = 1 pixel)
        local shift = IsShiftKeyDown()
        local step = shift and 10 or 1
        
        -- Calculate center position from rect
        local selfCenterX = left + (width / 2)
        local selfCenterY = bottom + (height / 2)
        local parentCenterX = parentLeft + (parentWidth / 2)
        local parentCenterY = parentBottom + (parentHeight / 2)
        
        -- Calculate new position
        local currentOffsetX = math.floor(selfCenterX - parentCenterX + 0.5)
        local currentOffsetY = math.floor(selfCenterY - parentCenterY + 0.5)
        local newOffsetX = currentOffsetX + (deltaX * step)
        local newOffsetY = currentOffsetY + (deltaY * step)
        
        -- Update config (frame stays registered in our system)
        -- configCallback updates the layout system (UpdateLayout) which handles config updates and repositioning
        -- UpdateLayout will automatically refresh the options UI
        configCallback({
            anchorTo = "none",
            offsetX = newOffsetX,
            offsetY = newOffsetY,
        })
        
        -- Notify UI if callbacks provided
        if notifyCallbacks then
            if notifyCallbacks.onAnchorChanged then
                notifyCallbacks.onAnchorChanged("none")
            end
            if notifyCallbacks.onPositionChanged then
                notifyCallbacks.onPositionChanged(newOffsetX, newOffsetY)
            end
        end
        
        -- Update frame position immediately
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", newOffsetX, newOffsetY)
        
        -- Call update callback to refresh frame
        if updateCallback then
            updateCallback()
        end
    end)
    
    -- Return cleanup function
    return function()
        frame:SetScript("OnKeyDown", originalOnKeyDown)
        if not skipKeyboardEnable then
            frame:EnableKeyboard(false)
        end
    end
end

---------------------------------------------------------------------------
-- ENABLE EDIT MODE FOR FRAME
---------------------------------------------------------------------------
-- Enable edit mode for a frame with minimal boilerplate
-- This is a high-level helper that sets up everything needed for edit mode
-- Parameters:
--   frame: The frame to enable edit mode for
--   updateCallback: Function() to call after config update to refresh the frame
--   label: Optional label for the edit mode overlay (defaults to frame name)
--   elementKey: Optional key for the edit mode overlay (defaults to frame name)
--   skipKeyboardEnable: Optional boolean to skip EnableKeyboard call (for secure frames)
--   elementType: Optional element type for selection ("unitframe", "powerbar", "castbar", etc.)
-- Returns: cleanup function to call when edit mode is disabled
function QUI_EditMode:EnableForFrame(frame, updateCallback, label, elementKey, skipKeyboardEnable, elementType)
    if not frame then
        return function() end
    end
    
    -- updateCallback is optional - layout system manages state automatically
    updateCallback = updateCallback or function() end
    
    -- Get config from registry - layout system manages all state
    local QUI_LayoutManager = ns.QUI_LayoutManager
    local frameConfig = QUI_LayoutManager and QUI_LayoutManager:GetLayout(frame) or nil
    if not frameConfig then
        return function() end
    end
    
    elementKey = elementKey or (frame:GetName() or "frame")
    label = label or elementKey
    
    -- Create edit mode overlay with nudge buttons
    if not frame.editOverlay then
        frame.editOverlay = self:CreateOverlay(frame, label, elementKey, updateCallback)
    end
    
    -- Show overlay
    if frame.editOverlay then
        self:UpdateOverlayInfo(frame, label)
        frame.editOverlay:Show()
    end
    
    -- Enable dragging
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    
    -- Store element info for selection handler
    if elementType and elementKey then
        frame._editModeElementType = elementType
        frame._editModeElementKey = elementKey
    end
    
    -- Set up click handler for element selection (if elementType provided)
    local originalOnMouseDown = frame:GetScript("OnMouseDown")
    if elementType then
        frame:SetScript("OnMouseDown", function(self, button)
            -- Handle selection on left click (but allow dragging to work)
            if button == "LeftButton" then
                local QUICore = ns.Addon
                if QUICore and QUICore.SelectEditModeElement then
                    QUICore:SelectEditModeElement(elementType, self._editModeElementKey)
                end
            end
            
            -- Call original handler if it exists (for drag support)
            if originalOnMouseDown then
                originalOnMouseDown(self, button)
            end
        end)
    end
    
    -- Create config callback that updates the layout system (the source of truth)
    local configCallback = function(newConfig)
        -- Update the layout system directly
        if QUI_LayoutManager then
            QUI_LayoutManager:UpdateLayout(frame, {
                anchorTarget = newConfig.anchorTo or "none",
                offsetX = newConfig.offsetX,
                offsetY = newConfig.offsetY,
            })
            return QUI_LayoutManager:GetLayout(frame) or newConfig
        end
        return newConfig
    end
    
    -- Create notify callbacks for overlay updates
    local notifyCallbacks = {
        onPositionChanged = function(offsetX, offsetY)
            if frame.editOverlay then
                self:UpdateOverlayInfo(frame, label, offsetX, offsetY)
            end
        end,
    }
    
    -- Enable drag tracking
    local dragCleanup = self:EnableDragTracking(frame, configCallback, updateCallback, notifyCallbacks)
    
    -- Enable keyboard nudging
    local keyboardCleanup = self:EnableKeyboardNudging(frame, configCallback, updateCallback, notifyCallbacks, skipKeyboardEnable)
    
    -- Return combined cleanup function
    return function()
        -- Defer operations that might cause taint during secure execution
        C_Timer.After(0, function()
            -- Hide overlay
            if frame.editOverlay then
                frame.editOverlay:Hide()
            end
            
            -- Call individual cleanup functions
            if dragCleanup then
                pcall(dragCleanup)
            end
            if keyboardCleanup then
                pcall(keyboardCleanup)
            end
            
            -- Disable dragging (use pcall for safety)
            pcall(function()
                frame:RegisterForDrag()
                frame:SetScript("OnMouseDown", nil)
            end)
        end)
    end
end

---------------------------------------------------------------------------
-- ENABLE EDIT MODE FOR ALL FRAMES
---------------------------------------------------------------------------
-- Enable edit mode for all registered frames that have edit mode configuration
function QUI_EditMode:Enable()
    if InCombatLockdown() then
        return
    end
    
    local QUI_LayoutManager = ns.QUI_LayoutManager
    if QUI_LayoutManager then
        for frame, frameConfig in pairs(QUI_LayoutManager.frames) do
            if frameConfig.editMode and frame and frame:IsShown() then
                local editModeConfig = frameConfig.editMode
                -- updateCallback is optional - layout system manages state automatically
                -- It's only needed for visual refreshes (textures, colors, etc.) unrelated to positioning
                frame._editModeCleanup = self:EnableForFrame(
                    frame,
                    editModeConfig.updateCallback,  -- Optional - only for visual refreshes
                    editModeConfig.label,
                    editModeConfig.elementKey,
                    editModeConfig.skipKeyboardEnable or false,
                    editModeConfig.elementType  -- Pass elementType for selection handling
                )
            end
        end
    end
end

---------------------------------------------------------------------------
-- DISABLE EDIT MODE FOR ALL FRAMES
---------------------------------------------------------------------------
-- Disable edit mode for all registered frames
function QUI_EditMode:Disable()
    -- Defer cleanup to break out of secure execution context
    -- This prevents taint errors when exiting edit mode during combat
    C_Timer.After(0, function()
        local QUI_LayoutManager = ns.QUI_LayoutManager
        if QUI_LayoutManager then
            for frame, frameConfig in pairs(QUI_LayoutManager.frames) do
                if frame and frame._editModeCleanup then
                    -- Use pcall to safely handle any errors during cleanup
                    pcall(function()
                        frame._editModeCleanup()
                    end)
                    frame._editModeCleanup = nil
                end
            end
        end
    end)
end

---------------------------------------------------------------------------
-- EDIT MODE OVERLAY
---------------------------------------------------------------------------
-- CREATE EDIT MODE OVERLAY
-- Creates a standard edit mode overlay with info text that updates from layout system
-- Parameters:
--   frame: The frame to create overlay for
--   label: Display label for the frame (e.g., "Primary", "Player", "Target")
--   elementKey: Optional key for selection manager (defaults to label)
--   updateCallback: Optional function() to call after position update
-- Returns: overlay frame with infoText property
---------------------------------------------------------------------------
function QUI_EditMode:CreateOverlay(frame, label, elementKey, updateCallback)
    if not frame then return nil end
    if frame.editOverlay then return frame.editOverlay end
    
    local overlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    overlay:SetAllPoints()
    overlay:SetFrameLevel(frame:GetFrameLevel() + 10)
    overlay:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    overlay:SetBackdropColor(0.2, 0.8, 1, 0.3)
    overlay:SetBackdropBorderColor(0.2, 0.8, 1, 1)
    
    -- Info text (positioned at top center, will be updated by layout system)
    local infoText = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("TOP", overlay, "TOP", 0, -4)
    infoText:SetTextColor(0.7, 0.7, 0.7, 1)
    overlay.infoText = infoText
    overlay.label = label or "Frame"
    
    -- Store elementKey for selection manager
    overlay.elementKey = elementKey or label
    
    -- Allow clicks to pass through overlay to frame for dragging
    overlay:EnableMouse(false)
    
    -- Create nudge buttons - layout system manages state
    self:CreateNudgeButtons(overlay, frame, updateCallback)
    
    overlay:Hide()
    frame.editOverlay = overlay
    
    return overlay
end

---------------------------------------------------------------------------
-- CREATE NUDGE BUTTON
-- Creates a single nudge button with chevron arrows
-- Parameters:
--   parent: Parent frame (overlay)
--   direction: "UP", "DOWN", "LEFT", "RIGHT"
--   deltaX: X delta for this direction (-1, 0, or 1)
--   deltaY: Y delta for this direction (-1, 0, or 1)
--   updateCallback: Function() to call after position update
-- Returns: button frame
---------------------------------------------------------------------------
local function CreateNudgeButton(parent, direction, deltaX, deltaY, updateCallback)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(18, 18)

    -- Background - dark grey at 70% for visibility over any game content
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.1, 0.1, 0.1, 0.7)
    btn.bg = bg

    -- Chevron lines - white for high contrast
    local line1 = btn:CreateTexture(nil, "ARTWORK")
    line1:SetColorTexture(1, 1, 1, 0.9)
    line1:SetSize(7, 2)

    local line2 = btn:CreateTexture(nil, "ARTWORK")
    line2:SetColorTexture(1, 1, 1, 0.9)
    line2:SetSize(7, 2)

    -- Direction-specific angles and positions
    if direction == "DOWN" then
        line1:SetPoint("CENTER", btn, "CENTER", -2, 1)
        line1:SetRotation(math.rad(-45))
        line2:SetPoint("CENTER", btn, "CENTER", 2, 1)
        line2:SetRotation(math.rad(45))
    elseif direction == "UP" then
        line1:SetPoint("CENTER", btn, "CENTER", -2, -1)
        line1:SetRotation(math.rad(45))
        line2:SetPoint("CENTER", btn, "CENTER", 2, -1)
        line2:SetRotation(math.rad(-45))
    elseif direction == "LEFT" then
        line1:SetPoint("CENTER", btn, "CENTER", -1, -2)
        line1:SetRotation(math.rad(-45))
        line2:SetPoint("CENTER", btn, "CENTER", -1, 2)
        line2:SetRotation(math.rad(45))
    elseif direction == "RIGHT" then
        line1:SetPoint("CENTER", btn, "CENTER", 1, -2)
        line1:SetRotation(math.rad(45))
        line2:SetPoint("CENTER", btn, "CENTER", 1, 2)
        line2:SetRotation(math.rad(-45))
    end
    btn.line1 = line1
    btn.line2 = line2

    -- Hover effect - mint accent on hover
    btn:SetScript("OnEnter", function(self)
        self.line1:SetColorTexture(0.204, 0.827, 0.6, 1)
        self.line2:SetColorTexture(0.204, 0.827, 0.6, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self.line1:SetColorTexture(1, 1, 1, 0.9)
        self.line2:SetColorTexture(1, 1, 1, 0.9)
    end)
    
    btn:SetScript("OnClick", function()
        -- Get frame from parent overlay
        local frame = parent:GetParent()
        if not frame then return end
        
        -- Get current config from layout system's registry (the source of truth)
        local QUI_LayoutManager = ns.QUI_LayoutManager
        if not QUI_LayoutManager then return end
        
        local frameConfig = QUI_LayoutManager:GetLayout(frame)
        if not frameConfig then return end
        
        -- Only nudge when manually positioned (anchorTarget == "none")
        if frameConfig.anchorTarget and frameConfig.anchorTarget ~= "none" then
            return
        end

        -- Calculate step size (shift = 10 pixels, normal = 1 pixel)
        local shift = IsShiftKeyDown()
        local step = shift and 10 or 1

        -- Calculate new position from layout system's registry
        local newOffsetX = (frameConfig.offsetX or 0) + (deltaX * step)
        local newOffsetY = (frameConfig.offsetY or 0) + (deltaY * step)
        
        -- Update layout system's registry (the source of truth)
        QUI_LayoutManager:UpdateLayout(frame, {
            anchorTarget = "none",
            offsetX = newOffsetX,
            offsetY = newOffsetY,
        })
        
        -- Layout system will apply position automatically via UpdateLayout
        -- Call update callback for visual refreshes if needed
        if updateCallback then
            updateCallback()
        end
    end)

    return btn
end

---------------------------------------------------------------------------
-- CREATE NUDGE BUTTONS
-- Creates 4 nudge buttons (up, down, left, right) on an overlay
-- Parameters:
--   overlay: The overlay frame
--   frame: The frame being nudged
--   updateCallback: Function() to call after position update
---------------------------------------------------------------------------
function QUI_EditMode:CreateNudgeButtons(overlay, frame, updateCallback)
    if not overlay or not frame then return end
    
    -- Create 4 nudge buttons
    local nudgeUp = CreateNudgeButton(overlay, "UP", 0, 1, updateCallback)
    nudgeUp:SetPoint("BOTTOM", overlay, "TOP", 0, 4)
    
    local nudgeDown = CreateNudgeButton(overlay, "DOWN", 0, -1, updateCallback)
    nudgeDown:SetPoint("TOP", overlay, "BOTTOM", 0, -4)
    
    local nudgeLeft = CreateNudgeButton(overlay, "LEFT", -1, 0, updateCallback)
    nudgeLeft:SetPoint("RIGHT", overlay, "LEFT", -4, 0)
    
    local nudgeRight = CreateNudgeButton(overlay, "RIGHT", 1, 0, updateCallback)
    nudgeRight:SetPoint("LEFT", overlay, "RIGHT", 4, 0)
    
    -- Store buttons on overlay
    overlay.nudgeUp = nudgeUp
    overlay.nudgeDown = nudgeDown
    overlay.nudgeLeft = nudgeLeft
    overlay.nudgeRight = nudgeRight
    
    -- Initially hide all buttons (shown when element is selected)
    nudgeUp:Hide()
    nudgeDown:Hide()
    nudgeLeft:Hide()
    nudgeRight:Hide()
end

---------------------------------------------------------------------------
-- UPDATE EDIT MODE OVERLAY INFO TEXT
-- Updates the info text on an edit overlay based on current layout state
-- Parameters:
--   frame: The frame with the overlay
--   label: Display label for the frame
--   offsetX: Optional X offset to display
--   offsetY: Optional Y offset to display
---------------------------------------------------------------------------
function QUI_EditMode:UpdateOverlayInfo(frame, label, offsetX, offsetY)
    if not frame or not frame.editOverlay or not frame.editOverlay.infoText then return end
    
    local overlay = frame.editOverlay
    local displayLabel = label or overlay.label or "Frame"
    
    local QUI_LayoutManager = ns.QUI_LayoutManager
    if QUI_LayoutManager then
        local config = QUI_LayoutManager:GetLayout(frame)
        if config then
            local anchorTarget = config.anchorTarget
            if anchorTarget and anchorTarget ~= "none" and anchorTarget ~= "screen" then
                -- Anchored - show anchor name
                local anchorNames = {
                    essential = "Essential",
                    utility = "Utility",
                    primary = "Primary",
                    secondary = "Secondary",
                }
                local anchorName = anchorNames[anchorTarget] or anchorTarget
                overlay.infoText:SetText(displayLabel .. "  (Locked to " .. anchorName .. ")")
            else
                -- Not anchored - show coordinates
                local x = offsetX or config.offsetX or 0
                local y = offsetY or config.offsetY or 0
                overlay.infoText:SetText(string.format("%s  X:%d Y:%d", displayLabel, x, y))
            end
        else
            -- No config - show default
            overlay.infoText:SetText(displayLabel)
        end
    else
        -- No layout system - show default
        overlay.infoText:SetText(displayLabel)
    end
end

return QUI_EditMode
