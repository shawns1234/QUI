--- QuaziiUI Perfect Pixel System - Optimized
--- Provides pixel-perfect UI scaling and calculations with minimal CPU usage

local ADDON_NAME, ns = ...

-- Get QUICore - must load after quicore_main.lua
local QUICore = ns.Addon or (QuaziiUI and QuaziiUI.QUICore)

if not QUICore then
    print("|cFFFF0000[QuaziiUI] ERROR: perfectpixel.lua loaded before quicore_main.lua!|r")
    return
end

local min, max, floor, ceil, abs = min, max, math.floor, math.ceil, math.abs

local _G = _G
local UIParent = UIParent
local GetScreenWidth = GetScreenWidth
local GetScreenHeight = GetScreenHeight
local InCombatLockdown = InCombatLockdown
local GetPhysicalScreenSize = GetPhysicalScreenSize

-- Cached values to minimize API calls
local cachedPhysicalWidth, cachedPhysicalHeight = 0, 0
local cachedScreenWidth, cachedScreenHeight = 0, 0
local cachedResolution = ""
local cachedAspectRatio = 1.0
local cachedEffectiveWidth = 0
local cachedPixelSize = 1.0
local cachedMult = 1.0
local cachedUIScale = 1.0

-- Constants for multi-monitor detection
local ULTRAWIDE_ASPECT_RATIO = 2.37  -- 21:9
local EYEFINITY_ASPECT_RATIO = 3.5    -- Very wide setups
local REFERENCE_HEIGHT = 768         -- WoW UI reference height

-- Refresh global FX scenes (prevents taint from RefreshModelScene)
function QUICore:RefreshGlobalFX()
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

-- Optimized multi-monitor detection using aspect ratios
local function DetectMultiMonitorSetup(physicalWidth, physicalHeight)
    local aspectRatio = physicalWidth / physicalHeight

    -- Eyefinity detection (very wide aspect ratios or specific patterns)
    if aspectRatio >= EYEFINITY_ASPECT_RATIO or physicalWidth >= 5000 then
        -- Return effective width for centering (common resolutions)
        if physicalWidth >= 9840 then return 3280  -- WQSXGA
        elseif physicalWidth >= 7680 then return 2560  -- WQXGA
        elseif physicalWidth >= 5760 then return 1920  -- WUXGA & HDTV
        elseif physicalWidth >= 5040 then return 1680  -- WSXGA+
        elseif physicalWidth >= 4800 and physicalHeight == 900 then return 1600  -- UXGA & HD+
        elseif physicalWidth >= 4320 then return 1440  -- WSXGA
        elseif physicalWidth >= 4080 then return 1360  -- WXGA
        elseif physicalWidth >= 3840 then return 1224  -- SXGA & SXGA (UVGA) & WXGA & HDTV
        end
    end

    -- Ultrawide detection (21:9+ aspect ratios)
    if aspectRatio >= ULTRAWIDE_ASPECT_RATIO then
        -- Return effective width for centering
        if physicalWidth >= 3440 and (physicalHeight == 1440 or physicalHeight == 1600) then
            return 2560  -- DQHD, DQHD+, WQHD & WQHD+
        elseif physicalWidth >= 2560 and (physicalHeight == 1080 or physicalHeight == 1200) then
            return 1920  -- WFHD, DFHD & WUXGA
        end
    end

    return nil  -- Standard monitor, use full width
end

-- Update cached screen dimensions (call when resolution changes)
local function UpdateScreenCache()
    cachedPhysicalWidth, cachedPhysicalHeight = GetPhysicalScreenSize()
    cachedScreenWidth, cachedScreenHeight = GetScreenWidth(), GetScreenHeight()
    cachedResolution = format('%dx%d', cachedPhysicalWidth, cachedPhysicalHeight)
    cachedAspectRatio = cachedPhysicalWidth / cachedPhysicalHeight
end

-- Calculate pixel-perfect scaling values for crisp rendering
local function UpdateScalingCache()
    -- Calculate effective width for multi-monitor setups
    cachedEffectiveWidth = DetectMultiMonitorSetup(cachedPhysicalWidth, cachedPhysicalHeight) or cachedScreenWidth

    -- For crisp text and icons, we want 1 UI unit = 1 physical pixel when possible
    -- Calculate the scale that would make this true
    local idealScale = cachedPhysicalHeight / REFERENCE_HEIGHT

    -- For multi-monitor setups, we may need to adjust based on effective width
    if cachedEffectiveWidth ~= cachedScreenWidth then
        -- Adjust scale to account for centering on effective width
        local widthRatio = cachedScreenWidth / cachedEffectiveWidth
        idealScale = idealScale * widthRatio
    end

    -- Store the pixel size (how many physical pixels per UI unit)
    cachedPixelSize = 1.0 / (cachedUIScale * idealScale)

    -- For the Scale function, we want to snap to pixel boundaries
    -- This is the size of 1 UI unit in physical pixels
    cachedMult = 1.0 / cachedUIScale
end

-- Calculate the UI multiplier for pixel snapping
function QUICore:UIMult()
    cachedUIScale = QUICore.db and QUICore.db.profile and QUICore.db.profile.general and
                    QUICore.db.profile.general.uiScale or 1.0
    UpdateScalingCache()
end

-- Apply UI scale to UIParent with combat protection
function QUICore:UIScale()
    if InCombatLockdown() then
        -- Defer scale change until out of combat
        if not self._UIScalePending then
            self._UIScalePending = true
            self:RegisterEvent('PLAYER_REGEN_ENABLED', function()
                self._UIScalePending = nil
                self:UnregisterEvent('PLAYER_REGEN_ENABLED')
                self:UIScale()
            end)
        end
        return
    end

    -- Get target scale
    local targetScale = QUICore.db and QUICore.db.profile and QUICore.db.profile.general and
                       QUICore.db.profile.general.uiScale or 1.0

    -- Use pcall to catch protected states not detected by InCombatLockdown
    local success = pcall(function() UIParent:SetScale(targetScale) end)
    if not success then
        -- Protected state detected - defer to combat end
        if not self._UIScalePending then
            self._UIScalePending = true
            self:RegisterEvent('PLAYER_REGEN_ENABLED', function()
                self._UIScalePending = nil
                self:UnregisterEvent('PLAYER_REGEN_ENABLED')
                self:UIScale()
            end)
        end
        return
    end

    -- Update cached values
    cachedUIScale = UIParent:GetScale()
    UpdateScalingCache()

    -- For multi-monitor setups, center UIParent
    if cachedEffectiveWidth ~= cachedScreenWidth then
        local scaleFactor = cachedScreenHeight / cachedPhysicalHeight
        local centeredWidth = cachedEffectiveWidth * scaleFactor
        -- Note: UIParent centering would require additional positioning logic
        -- This is handled by the effective width calculation for layout purposes
    end

    -- Refresh GlobalFX if in Retail
    if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and _G.GlobalFXDialogModelScene then
        QUICore:RefreshGlobalFX()
    end
end

-- Get the best pixel size for current setup (legacy compatibility)
function QUICore:PixelBestSize()
    return max(0.4, min(1.15, cachedPixelSize))
end

-- Handle UI scale and display size changes
function QUICore:PixelScaleChanged(event)
    if event == 'UI_SCALE_CHANGED' or event == 'DISPLAY_SIZE_CHANGED' then
        UpdateScreenCache()
        QUICore:UIMult()
        QUICore:UIScale()
    end
end

-- Pixel-perfect scaling function for crisp rendering
-- Intelligently handles positioning vs sizing for optimal text/icon clarity
function QUICore:Scale(x)
    if x == 0 then return 0 end

    -- For UI scales close to 1.0, minimal adjustment needed
    if cachedUIScale >= 0.95 and cachedUIScale <= 1.05 then
        return x
    end

    -- Calculate pixel size (physical pixels per UI unit)
    local pixelSize = 1.0 / cachedUIScale

    -- For positioning (small values), snap to pixel boundaries
    if x >= -100 and x <= 100 then
        -- Position snapping: round to nearest pixel
        return floor(x * pixelSize + 0.5) / pixelSize
    else
        -- For sizing (larger values), use more conservative snapping
        -- This prevents font sizes from being forced to awkward values
        local snapped = floor(x * pixelSize + 0.5) / pixelSize
        -- Only snap if the difference is small (prevents major size changes)
        if abs(snapped - x) < 0.5 then
            return snapped
        else
            return x
        end
    end
end

-- Initialize the pixel perfect system
function QUICore:InitializePixelPerfect()
    -- Initialize cached screen dimensions
    UpdateScreenCache()

    -- Initialize scaling (will be 1.0 until db is ready)
    cachedMult = 1.0
    cachedPixelSize = 1.0

    -- Calculate initial scaling if db is ready
    if self.db and self.db.profile then
        self:UIMult()
    end

    -- Register for UI scale and display size changes
    self:RegisterEvent('UI_SCALE_CHANGED', 'PixelScaleChanged')
    self:RegisterEvent('DISPLAY_SIZE_CHANGED', 'PixelScaleChanged')
end

-- Get smart default scale based on screen resolution (Option 3)
function QUICore:GetSmartDefaultScale()
    if cachedPhysicalHeight >= 2160 then      -- 4K
        return 0.53
    elseif cachedPhysicalHeight >= 1440 then  -- 1440p
        return 0.64
    else                              -- 1080p or lower
        return 1.0
    end
end

-- Apply saved UI scale (call this after db is initialized)
function QUICore:ApplyUIScale()
    if not self.db or not self.db.profile or not self.db.profile.general then
        return
    end

    local savedScale = self.db.profile.general.uiScale
    local scaleToApply
    if savedScale and savedScale > 0 then
        scaleToApply = savedScale
    else
        -- No saved scale - use smart default based on resolution
        scaleToApply = self:GetSmartDefaultScale()
        self.db.profile.general.uiScale = scaleToApply
    end

    -- Apply scale with combat protection
    if InCombatLockdown() then
        -- Defer to combat end
        if not self._UIScalePending then
            self._UIScalePending = true
            self:RegisterEvent('PLAYER_REGEN_ENABLED', function()
                self._UIScalePending = nil
                self:UnregisterEvent('PLAYER_REGEN_ENABLED')
                self:ApplyUIScale()
            end)
        end
        return
    end

    local success = pcall(function() UIParent:SetScale(scaleToApply) end)
    if not success then
        -- Protected state detected - defer to combat end
        if not self._UIScalePending then
            self._UIScalePending = true
            self:RegisterEvent('PLAYER_REGEN_ENABLED', function()
                self._UIScalePending = nil
                self:UnregisterEvent('PLAYER_REGEN_ENABLED')
                self:ApplyUIScale()
            end)
        end
        return
    end

    -- Update pixel perfect calculations
    if self.UIMult and self.UIScale then
        self:UIMult()
        self:UIScale()
    end
end