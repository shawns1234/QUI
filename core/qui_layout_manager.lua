--[[
    QUI Layout Manager Module
    Coordinates layout operations across specialized modules
    Single Responsibility: Orchestrate layout operations across modules
]]

local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- MODULE TABLE
---------------------------------------------------------------------------
local QUI_LayoutManager = {}
ns.QUI_LayoutManager = QUI_LayoutManager

-- Frame registry: { frame = { config data } }
QUI_LayoutManager.frames = {}

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------
-- Set helpers for all modules
function QUI_LayoutManager:SetHelpers(helpers)
    if ns.QUI_Positioning then
        ns.QUI_Positioning:SetHelpers(helpers)
    end
    if ns.QUI_Anchoring then
        ns.QUI_Anchoring:SetHelpers(helpers)
    end
end

---------------------------------------------------------------------------
-- FRAME REGISTRATION
---------------------------------------------------------------------------
-- Register a frame with full layout management
-- Parameters:
--   frame: The frame to register
--   frameKey: Unique key for this frame (e.g., "unitFrames.player", "resourceBars.primary")
--   frameType: Optional - "unitFrames", "castbars", "resourceBars", "customTrackers" (for automatic defaults)
--   options: Optional table with {parentFrame, editMode}
-- Returns: success boolean
function QUI_LayoutManager:RegisterFrame(frame, frameKey, frameType, options)
    if not frame then return false end
    
    -- Validate frameKey is a string (required parameter)
    if type(frameKey) ~= "string" then
        return false
    end
    
    options = options or {}
    
    -- Load layout state from database
    local QUI_LayoutState = ns.QUI_LayoutState
    if not QUI_LayoutState then
        return false
    end
    
    local saved = QUI_LayoutState:LoadConfig(frameKey)
    
    -- Apply defaults if frameType is provided and no saved config exists
    -- Check if we have any meaningful saved data (anchorTarget is the key field)
    local hasSavedConfig = saved.anchorTarget ~= nil
    
    if frameType and not hasSavedConfig then
        local defaults = QUI_LayoutState:ApplyDefaults(frameKey, frameType)
        -- Merge defaults into saved
        for k, v in pairs(defaults) do
            if saved[k] == nil then
                saved[k] = v
            end
        end
    end
    
    -- Migrate config
    saved = QUI_LayoutState:MigrateConfig(saved)
    
    -- Normalize anchors
    local anchors = saved.anchors
    if not anchors or #anchors == 0 then
        anchors = {{source = "CENTER", target = "CENTER"}}
    end
    
    -- Check for circular dependencies
    local QUI_Anchoring = ns.QUI_Anchoring
    if QUI_Anchoring and saved.anchorTarget and saved.anchorTarget ~= "screen" and saved.anchorTarget ~= "none" then
        if QUI_Anchoring:CheckCircularDependency(frame, saved.anchorTarget) then
            -- Circular dependency detected - don't register
            return false
        end
    end
    
    -- Build config
    local config = {
        anchorTarget = saved.anchorTarget or "none",
        anchors = anchors,
        offsetX = saved.offsetX or 0,
        offsetY = saved.offsetY or 0,
        width = saved.width,
        height = saved.height,
        parentFrame = options.parentFrame,
        frameKey = frameKey,
        editMode = options.editMode,
    }
    
    -- Store in registry
    self.frames[frame] = config
    
    -- Apply layout immediately
    -- Defer if in combat or secure context
    if InCombatLockdown() then
        C_Timer.After(0, function()
            self:RegisterFrame(frame, frameKey, frameType, options)
        end)
        return true
    end
    
    -- Apply layout
    self:ApplyLayout(frame)
    
    -- Re-register state drivers for unit frames after positioning (ClearAllPoints breaks them)
    if frame._quiReRegisterStateDriver then
        C_Timer.After(0, function()
            if frame and frame._quiReRegisterStateDriver then
                frame._quiReRegisterStateDriver()
            end
        end)
    end
    
    return true
end

---------------------------------------------------------------------------
-- LAYOUT APPLICATION
---------------------------------------------------------------------------
-- Apply layout to a frame (position and size)
-- Parameters:
--   frame: Frame to apply layout to
function QUI_LayoutManager:ApplyLayout(frame)
    if not frame then return false end
    
    local config = self.frames[frame]
    if not config then return false end
    
    -- Defer if in combat
    if InCombatLockdown() then
        C_Timer.After(0, function()
            self:ApplyLayout(frame)
        end)
        return false
    end
    
    local QUI_Positioning = ns.QUI_Positioning
    local QUI_Sizing = ns.QUI_Sizing
    local QUI_Anchoring = ns.QUI_Anchoring
    
    if not QUI_Positioning or not QUI_Sizing or not QUI_Anchoring then
        return false
    end
    
    -- Position frame
    local getAnchorTarget = function(name)
        return QUI_Anchoring:GetAnchorTarget(name)
    end
    
    QUI_Positioning:PositionFrame(
        frame,
        config.anchorTarget,
        config.anchors,
        config.offsetX,
        config.offsetY,
        config.parentFrame,
        getAnchorTarget
    )
    
    -- Apply size (after positioning)
    local autoConfig = QUI_Sizing:GetAutoConfig(config.anchors, config.anchorTarget)
    QUI_Sizing:ApplySize(frame, config.width, config.height, autoConfig)
    
    -- Ensure frame stays visible during edit mode (state drivers are unregistered in edit mode)
    if frame.editOverlay and frame.editOverlay:IsShown() then
        frame:Show()
    end
    
    return true
end

---------------------------------------------------------------------------
-- LAYOUT UPDATES
---------------------------------------------------------------------------
-- Update layout properties (coordinated update)
-- Parameters:
--   frame: Frame to update
--   updates: Table with anchorTarget, anchors, offsetX, offsetY, width, height (all optional)
-- Returns: success boolean
function QUI_LayoutManager:UpdateLayout(frame, updates)
    if not frame or not updates then return false end
    
    local config = self.frames[frame]
    if not config then return false end
    
    -- Update config
    if updates.anchorTarget ~= nil then
        config.anchorTarget = updates.anchorTarget
    end
    if updates.anchors and #updates.anchors > 0 then
        config.anchors = updates.anchors
    end
    if updates.offsetX ~= nil then
        config.offsetX = tonumber(updates.offsetX) or 0
    end
    if updates.offsetY ~= nil then
        config.offsetY = tonumber(updates.offsetY) or 0
    end
    if updates.width ~= nil then
        config.width = tonumber(updates.width)
        -- Ensure width is valid
        if not config.width or config.width <= 0 then
            config.width = nil
        end
    end
    if updates.height ~= nil then
        config.height = tonumber(updates.height)
        -- Ensure height is valid
        if not config.height or config.height <= 0 then
            config.height = nil
        end
    end
    
    -- Validate size
    local QUI_Sizing = ns.QUI_Sizing
    if QUI_Sizing then
        local validated = QUI_Sizing:ValidateSize(config.width, config.height)
        config.width = validated.width
        config.height = validated.height
    end
    
    -- Save to database
    local QUI_LayoutState = ns.QUI_LayoutState
    if QUI_LayoutState and config.frameKey then
        QUI_LayoutState:SaveConfig(config.frameKey, config)
    end
    
    -- Apply layout immediately if anchor/offset changed
    if updates.anchorTarget ~= nil or updates.offsetX ~= nil or updates.offsetY ~= nil or updates.anchors then
        self:ApplyLayout(frame)
    elseif updates.width ~= nil or updates.height ~= nil then
        -- Always reapply layout when size changes to ensure it takes effect
        -- This ensures the frame is properly updated regardless of anchor configuration
        self:ApplyLayout(frame)
    end
    
    -- Always refresh options UI after layout changes (defer to avoid taint)
    -- Update functions use silent SetValue() to prevent feedback loops
    C_Timer.After(0, function()
        self:RefreshOptionsUI(frame)
    end)
    
    return true
end

---------------------------------------------------------------------------
-- REFRESH OPTIONS UI
-- Refresh all options UI controls for a frame (coordinated refresh)
-- Parameters:
--   frame: Frame whose options UI should be refreshed
---------------------------------------------------------------------------
function QUI_LayoutManager:RefreshOptionsUI(frame)
    if not frame then return end
    
    -- Refresh layout controls (handled via the layout manager options coordinator)
    -- The unified layout control system handles all refreshing internally
    local QUI_LayoutManager_Options = ns.QUI_LayoutManager_Options
    if not QUI_LayoutManager_Options then return end
    
    if frame._layoutControls then
        -- _layoutControls is keyed by parent frame, iterate over all entries
        for parent, controls in pairs(frame._layoutControls) do
            if controls then
                QUI_LayoutManager_Options:UpdateLayoutControls(controls, frame)
            end
        end
    end
end

---------------------------------------------------------------------------
-- LAYOUT RETRIEVAL
---------------------------------------------------------------------------
-- Get complete layout config for a frame
-- Parameters:
--   frame: Frame to get layout for
-- Returns: layoutConfig table or nil
function QUI_LayoutManager:GetLayout(frame)
    if not frame then return nil end
    return self.frames[frame]
end

---------------------------------------------------------------------------
-- FRAME UNREGISTRATION
---------------------------------------------------------------------------
-- Unregister frame
-- Parameters:
--   frame: Frame to unregister
-- Returns: success boolean
function QUI_LayoutManager:UnregisterFrame(frame)
    if not frame then return false end
    self.frames[frame] = nil
    return true
end

---------------------------------------------------------------------------
-- BATCH OPERATIONS
---------------------------------------------------------------------------
-- Update all frames (for screen resize, etc.)
function QUI_LayoutManager:UpdateAllFrames()
    if InCombatLockdown() then
        C_Timer.After(0, function()
            self:UpdateAllFrames()
        end)
        return
    end
    
    for frame, config in pairs(self.frames) do
        if frame and frame:IsShown() then
            self:ApplyLayout(frame)
        end
    end
end

-- Reset all frames to defaults
function QUI_LayoutManager:ResetToDefaults()
    if InCombatLockdown() then
        print("|cFF56D1FFQuaziiUI|r: Cannot reset layout during combat.")
        return false
    end
    
    local resetCount = 0
    local QUI_LayoutState = ns.QUI_LayoutState
    local QUI_Anchoring_Defaults = ns.QUI_Anchoring_Defaults
    
    if not QUI_LayoutState or not QUI_Anchoring_Defaults then
        print("|cFF56D1FFQuaziiUI|r: Layout system not available.")
        return false
    end
    
    -- Reset all registered frames
    for frame, config in pairs(self.frames) do
        if config and config.frameKey then
            local frameKey = config.frameKey
            
            -- Extract frameType and shortKey from frameKey
            local frameType, shortKey = frameKey:match("^([^.]+)%.(.+)$")
            
            if frameType and shortKey then
                -- Normalize boss frames
                if frameType == "unitFrames" and shortKey:match("^boss%d+$") then
                    shortKey = "boss"
                end
                
                -- Get defaults
                local defaults = QUI_Anchoring_Defaults:GetDefaultAnchorConfig(frameType, shortKey)
                if defaults then
                    -- Convert defaults to layout system format
                    local layoutDefaults = {
                        anchorTarget = defaults.anchorTo or defaults.anchor or "none",
                        offsetX = defaults.offsetX or 0,
                        offsetY = defaults.offsetY or 0,
                        anchors = defaults.anchors or {{source = "CENTER", target = "CENTER"}},
                        width = defaults.width,
                        height = defaults.height,
                    }
                    
                    -- Save to database
                    QUI_LayoutState:SaveConfig(frameKey, layoutDefaults)
                    
                    -- Update registry and apply
                    self:UpdateLayout(frame, layoutDefaults)
                    resetCount = resetCount + 1
                end
            end
        end
    end
    
    -- Apply all changes
    self:UpdateAllFrames()
    
    print(string.format("|cFF56D1FFQuaziiUI|r: Reset %d frame(s) to default layout.", resetCount))
    return true
end

-- Update frames anchored to a specific anchor target
function QUI_LayoutManager:UpdateFramesForTarget(anchorTargetName)
    if InCombatLockdown() then
        C_Timer.After(0, function()
            self:UpdateFramesForTarget(anchorTargetName)
        end)
        return
    end
    
    for frame, config in pairs(self.frames) do
        if frame and frame:IsShown() and config.anchorTarget == anchorTargetName then
            self:ApplyLayout(frame)
        end
    end
end

---------------------------------------------------------------------------
-- EDIT MODE DELEGATION
---------------------------------------------------------------------------
-- Enable edit mode for all registered frames
function QUI_LayoutManager:EnableEditMode()
    local QUI_EditMode = ns.QUI_EditMode
    if QUI_EditMode then
        return QUI_EditMode:Enable()
    end
    return false
end

-- Disable edit mode for all registered frames
function QUI_LayoutManager:DisableEditMode()
    local QUI_EditMode = ns.QUI_EditMode
    if QUI_EditMode then
        return QUI_EditMode:Disable()
    end
end

-- Enable edit mode for a specific frame
-- Parameters:
--   frame: The frame to enable edit mode for
--   updateCallback: Optional function() to call after config update
--   label: Optional label for the edit mode overlay
--   elementKey: Optional key for the edit mode overlay
--   skipKeyboardEnable: Optional boolean to skip EnableKeyboard call
--   elementType: Optional element type for selection
-- Returns: cleanup function
function QUI_LayoutManager:EnableEditModeForFrame(frame, updateCallback, label, elementKey, skipKeyboardEnable, elementType)
    local QUI_EditMode = ns.QUI_EditMode
    if QUI_EditMode then
        return QUI_EditMode:EnableForFrame(frame, updateCallback, label, elementKey, skipKeyboardEnable, elementType)
    end
    return function() end
end
