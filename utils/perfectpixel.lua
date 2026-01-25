--- QuaziiUI Pixel Precision System
--- Advanced UI scaling with intelligent pixel alignment for crystal-clear visuals
--- Integrates Blizzard's PixelUtil for optimal performance and accuracy

local ADDON_NAME, ns = ...

-- Access QUICore - must be loaded after quicore_main.lua
local QUICore = ns.Addon or (QuaziiUI and QuaziiUI.QUICore)

if not QUICore then
    print("|cFFFF0000[QuaziiUI] ERROR: pixelprecision.lua loaded before quicore_main.lua!|r")
    return
end

local min, max, floor, ceil, abs = min, max, math.floor, math.ceil, math.abs

local _G = _G
local UIParent = UIParent
local GetScreenWidth = GetScreenWidth
local GetScreenHeight = GetScreenHeight
local InCombatLockdown = InCombatLockdown
local GetPhysicalScreenSize = GetPhysicalScreenSize

-- Performance-optimized cached values to reduce API overhead
local screenPhysicalWidth, screenPhysicalHeight = 0, 0
local screenWidth, screenHeight = 0, 0
local screenResolutionString = ""
local screenAspectRatio = 1.0
local multiMonitorEffectiveWidth = 0
local pixelToUIUnitFactor = 1.0
local currentUIScale = 1.0

-- Multi-monitor configuration constants
local ULTRAWIDE_RATIO_THRESHOLD = 2.37  -- 21:9 and wider
local EYEFINITY_RATIO_THRESHOLD = 3.5    -- Very wide multi-monitor setups
local WOW_REFERENCE_HEIGHT = 768         -- Blizzard's base UI height

-- Performance optimization constants
local SIZE_UPDATE_INTERVAL = 0.016  -- ~60 FPS update rate for slider dragging
local lastSizeUpdate = 0

-- Slider update system for performance optimization
local sliderDragging = false
local sliderLightweightFunc = nil
local sliderUpdateCallCount = 0

-- Update global model scenes to prevent tainting issues
function QUICore:UpdateGlobalModelScenes()
    if _G.GlobalFXDialogModelScene then
        _G.GlobalFXDialogModelScene:Hide()
        _G.GlobalFXDialogModelScene:Show()
    end

    if _G.GlobalFXMediumModelScene then
        _G.GlobalFXMediumModelScene:Hide()
        _G.GlobalFXMediumModelScene:Show()
    end

    if _G.GlobalFXBackgroundModelScene then
        _G.GlobalFXBackgroundModelScene:Hide()
        _G.GlobalFXBackgroundModelScene:Show()
    end
end

--- Advanced multi-monitor configuration detection
--- Analyzes physical screen dimensions to determine optimal UI centering
local function DetermineMultiMonitorLayout(physicalWidth, physicalHeight)
    local aspectRatio = physicalWidth / physicalHeight

    -- Detect Eyefinity-style very wide configurations
    if aspectRatio >= EYEFINITY_RATIO_THRESHOLD or physicalWidth >= 5000 then
        -- Return optimal centering width for various resolutions
        if physicalWidth >= 9840 then return 3280  -- WQSXGA
        elseif physicalWidth >= 7680 then return 2560  -- WQXGA
        elseif physicalWidth >= 5760 then return 1920  -- WUXGA & HDTV
        elseif physicalWidth >= 5040 then return 1680  -- WSXGA+
        elseif physicalWidth >= 4800 and physicalHeight == 900 then return 1600  -- UXGA & HD+
        elseif physicalWidth >= 4320 then return 1440  -- WSXGA
        elseif physicalWidth >= 4080 then return 1360  -- WXGA
        elseif physicalWidth >= 3840 then return 1224  -- SXGA & variants
        end
    end

    -- Detect ultrawide monitor configurations
    if aspectRatio >= ULTRAWIDE_RATIO_THRESHOLD then
        -- Return centering width for ultrawide resolutions
        if physicalWidth >= 3440 and (physicalHeight == 1440 or physicalHeight == 1600) then
            return 2560  -- DQHD, DQHD+, WQHD & WQHD+
        elseif physicalWidth >= 2560 and (physicalHeight == 1080 or physicalHeight == 1200) then
            return 1920  -- WFHD, DFHD & WUXGA
        end
    end

    return nil  -- Standard single monitor setup
end

--- Refresh cached display metrics when resolution changes
local function RefreshDisplayMetrics()
    screenPhysicalWidth, screenPhysicalHeight = GetPhysicalScreenSize()
    screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()
    screenResolutionString = format('%dx%d', screenPhysicalWidth, screenPhysicalHeight)
    screenAspectRatio = screenPhysicalWidth / screenPhysicalHeight
end

--- Compute optimal scaling parameters using PixelUtil
local function RecalculateScalingParameters()
    -- Determine effective width for multi-monitor centering
    multiMonitorEffectiveWidth = DetermineMultiMonitorLayout(screenPhysicalWidth, screenPhysicalHeight) or screenWidth

    -- Calculate PixelUtil scaling factor for current UI scale
    pixelToUIUnitFactor = PixelUtil.GetPixelToUIUnitFactor()

    -- Adjust for multi-monitor centering requirements
    if multiMonitorEffectiveWidth ~= screenWidth then
        local centeringAdjustment = screenWidth / multiMonitorEffectiveWidth
        pixelToUIUnitFactor = pixelToUIUnitFactor * centeringAdjustment
    end
end

--- Update pixel scaling multiplier based on current UI scale
function QUICore:CalculatePixelMultiplier()
    currentUIScale = QUICore.db and QUICore.db.profile and QUICore.db.profile.general and
                     QUICore.db.profile.general.uiScale or 1.0
    RecalculateScalingParameters()
end

--- Apply UI scaling with comprehensive combat state protection
function QUICore:ApplyUIScaling()
    if InCombatLockdown() then
        -- Queue scaling operation for after combat ends
        if not self._scalingOperationPending then
            self._scalingOperationPending = true
            self:RegisterEvent('PLAYER_REGEN_ENABLED', function()
                self._scalingOperationPending = nil
                self:UnregisterEvent('PLAYER_REGEN_ENABLED')
                self:ApplyUIScaling()
            end)
        end
        return
    end

    -- Retrieve target UI scale from configuration
    local targetScale = QUICore.db and QUICore.db.profile and QUICore.db.profile.general and
                       QUICore.db.profile.general.uiScale or 1.0

    -- Safely apply scale with error handling for protected states
    local scaleApplied = pcall(function() UIParent:SetScale(targetScale) end)
    if not scaleApplied then
        -- Handle protected UI state by deferring operation
        if not self._scalingOperationPending then
            self._scalingOperationPending = true
            self:RegisterEvent('PLAYER_REGEN_ENABLED', function()
                self._scalingOperationPending = nil
                self:UnregisterEvent('PLAYER_REGEN_ENABLED')
                self:ApplyUIScaling()
            end)
        end
        return
    end

    -- Update cached scaling values
    currentUIScale = UIParent:GetScale()
    RecalculateScalingParameters()

    -- Handle multi-monitor UI centering calculations
    if multiMonitorEffectiveWidth ~= screenWidth then
        local centeringScale = screenHeight / screenPhysicalHeight
        local centeredWidth = multiMonitorEffectiveWidth * centeringScale
        -- UI centering logic handled through effective width calculations
    end

    -- Update global model scenes for Retail WoW
    if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and _G.GlobalFXDialogModelScene then
        QUICore:UpdateGlobalModelScenes()
    end
end

--- Calculate optimal pixel size for current display configuration
function QUICore:GetOptimalPixelSize()
    return max(0.4, min(1.15, pixelToUIUnitFactor))
end

--- Event handler for UI scale and display resolution changes
function QUICore:OnResolutionOrScaleChange(event)
    if event == 'UI_SCALE_CHANGED' or event == 'DISPLAY_SIZE_CHANGED' then
        RefreshDisplayMetrics()
        QUICore:CalculatePixelMultiplier()
        QUICore:ApplyUIScaling()
    end
end

--- Intelligent pixel grid snapping using PixelUtil for optimal visual clarity
--- Distinguishes between positioning and sizing for natural rendering
function QUICore:SnapToPixelGrid(value)
    if value == 0 then return 0 end

    -- Use PixelUtil for precise pixel alignment
    return PixelUtil.GetNearestPixelSize(value, 1.0, value)
end

--- Lightweight UI scale update for slider dragging performance
--- Only updates scaling calculations without full frame refreshes
function QUICore:LightweightUpdateUIScale()
    -- Frame-skip throttle to maintain 60 FPS during dragging
    local now = GetTime()
    if now - lastSizeUpdate < SIZE_UPDATE_INTERVAL then
        return
    end
    lastSizeUpdate = now

    sliderUpdateCallCount = sliderUpdateCallCount + 1

    -- Update only the scale value and pixel calculations
    -- Skip expensive operations like frame repositioning
    currentUIScale = QUICore.db and QUICore.db.profile and QUICore.db.profile.general and
                     QUICore.db.profile.general.uiScale or 1.0
    RecalculateScalingParameters()
end

--- Initialize the pixel precision system
function QUICore:InitializePixelPrecision()
    -- Cache initial display metrics
    RefreshDisplayMetrics()

    -- Set initial scaling values
    pixelToUIUnitFactor = 1.0

    -- Calculate scaling if database is available
    if self.db and self.db.profile then
        self:CalculatePixelMultiplier()
    end

    -- Register for scale and resolution change events
    self:RegisterEvent('UI_SCALE_CHANGED', 'OnResolutionOrScaleChange')
    self:RegisterEvent('DISPLAY_SIZE_CHANGED', 'OnResolutionOrScaleChange')
end

--- Determine intelligent default scale based on display resolution
function QUICore:GetIntelligentDefaultScale()
    if screenPhysicalHeight >= 2160 then      -- 4K displays
        return 0.53
    elseif screenPhysicalHeight >= 1440 then  -- 1440p displays
        return 0.64
    else                              -- 1080p and lower
        return 1.0
    end
end

--- Apply configured UI scale with comprehensive protection
function QUICore:ApplyConfiguredUIScale()
    if not self.db or not self.db.profile or not self.db.profile.general then
        return
    end

    local configuredScale = self.db.profile.general.uiScale
    local scaleToApply
    if configuredScale and configuredScale > 0 then
        scaleToApply = configuredScale
    else
        -- Use intelligent default based on resolution
        scaleToApply = self:GetIntelligentDefaultScale()
        self.db.profile.general.uiScale = scaleToApply
    end

    -- Apply with combat state protection
    if InCombatLockdown() then
        -- Defer until combat ends
        if not self._scalingOperationPending then
            self._scalingOperationPending = true
            self:RegisterEvent('PLAYER_REGEN_ENABLED', function()
                self._scalingOperationPending = nil
                self:UnregisterEvent('PLAYER_REGEN_ENABLED')
                self:ApplyConfiguredUIScale()
            end)
        end
        return
    end

    local scaleApplied = pcall(function() UIParent:SetScale(scaleToApply) end)
    if not scaleApplied then
        -- Handle protected state by deferring
        if not self._scalingOperationPending then
            self._scalingOperationPending = true
            self:RegisterEvent('PLAYER_REGEN_ENABLED', function()
                self._scalingOperationPending = nil
                self:UnregisterEvent('PLAYER_REGEN_ENABLED')
                self:ApplyConfiguredUIScale()
            end)
        end
        return
    end

    -- Update pixel precision calculations
    if self.CalculatePixelMultiplier and self.ApplyUIScaling then
        self:CalculatePixelMultiplier()
        self:ApplyUIScaling()
    end
end

--- Slider drag start handler for performance optimization
function QUICore:OnSliderDragStart(lightweightFunc, funcName)
    sliderDragging = true
    sliderLightweightFunc = lightweightFunc
    sliderUpdateCallCount = 0

    if QUICore.debugEnabled then
        print("|cff00ff00[QuaziiUI Pixel]|r Drag START - lightweight: " .. (funcName or "unknown"))
    end
end

--- Slider drag stop handler - performs full update
function QUICore:OnSliderDragStop()
    if QUICore.debugEnabled then
        print("|cff00ff00[QuaziiUI Pixel]|r Drag STOP - " .. sliderUpdateCallCount .. " lightweight calls, now FULL UpdateAll()")
    end

    sliderDragging = false
    sliderLightweightFunc = nil

    -- Perform full update now that dragging has stopped
    QUICore:ApplyConfiguredUIScale()
end

--- Throttled update system for optimal performance
function QUICore:ThrottledUpdateAll()
    if sliderDragging then
        if sliderLightweightFunc then
            -- During drag with lightweight function, call it directly
            sliderLightweightFunc()
        end
        -- If no lightweight func, just skip
        return
    end

    -- Not dragging - just call full update directly
    QUICore:ApplyConfiguredUIScale()
end

-- Maintain backward compatibility with existing Scale function calls
QUICore.Scale = QUICore.SnapToPixelGrid