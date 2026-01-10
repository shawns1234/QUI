--- QuaziiUI Perfect Pixel System
--- Provides pixel-perfect UI scaling and calculations

local ADDON_NAME, ns = ...

-- Get QUICore - must load after quicore_main.lua
local QUICore = ns.Addon or (QuaziiUI and QuaziiUI.QUICore)

if not QUICore then
    print("|cFFFF0000[QuaziiUI] ERROR: perfectpixel.lua loaded before quicore_main.lua!|r")
    return
end

local min, max, format = min, max, string.format

local _G = _G
local UIParent = UIParent
local GetScreenWidth = GetScreenWidth
local GetScreenHeight = GetScreenHeight
local InCombatLockdown = InCombatLockdown
local GetPhysicalScreenSize = GetPhysicalScreenSize

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

-- Check for Eyefinity (triple monitor) setup
function QUICore:IsEyefinity(width, height)
    if QUICore.db and QUICore.db.profile.general.eyefinity and width >= 3840 then
        -- HQ resolution
        if width >= 9840 then return 3280 end                   -- WQSXGA
        if width >= 7680 and width < 9840 then return 2560 end  -- WQXGA
        if width >= 5760 and width < 7680 then return 1920 end  -- WUXGA & HDTV
        if width >= 5040 and width < 5760 then return 1680 end  -- WSXGA+

        -- Adding height condition for bezel compensation
        if width >= 4800 and width < 5760 and height == 900 then return 1600 end -- UXGA & HD+

        -- Low resolution screen
        if width >= 4320 and width < 4800 then return 1440 end  -- WSXGA
        if width >= 4080 and width < 4320 then return 1360 end  -- WXGA
        if width >= 3840 and width < 4080 then return 1224 end  -- SXGA & SXGA (UVGA) & WXGA & HDTV
    end
end

-- Check for Ultrawide setup
function QUICore:IsUltrawide(width, height)
    if QUICore.db and QUICore.db.profile.general.ultrawide and width >= 2560 then
        -- HQ Resolution
        if width >= 3440 and (height == 1440 or height == 1600) then return 2560 end -- DQHD, DQHD+, WQHD & WQHD+

        -- Low resolution
        if width >= 2560 and (height == 1080 or height == 1200) then return 1920 end -- WFHD, DFHD & WUXGA
    end
end

-- Calculate the UI multiplier for pixel snapping
function QUICore:UIMult()
    local uiScale = 1.0
    if QUICore.db and QUICore.db.profile and QUICore.db.profile.general then
        uiScale = QUICore.db.profile.general.uiScale or 1.0
    end
    QUICore.mult = QUICore.perfect / uiScale
end

-- Apply UI scale to UIParent
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
    else
        local uiScale = 1.0
        if QUICore.db and QUICore.db.profile and QUICore.db.profile.general then
            uiScale = QUICore.db.profile.general.uiScale or 1.0
        end
        
        UIParent:SetScale(uiScale)

        QUICore.uiscale = UIParent:GetScale()
        QUICore.screenWidth, QUICore.screenHeight = GetScreenWidth(), GetScreenHeight()

        local width, height = QUICore.physicalWidth, QUICore.physicalHeight
        QUICore.eyefinity = QUICore:IsEyefinity(width, height)
        QUICore.ultrawide = QUICore:IsUltrawide(width, height)

        local newWidth = QUICore.eyefinity or QUICore.ultrawide
        if newWidth then
            -- Center UIParent for multi-monitor setups
            width, height = newWidth / (height / QUICore.screenHeight), QUICore.screenHeight
        else
            width, height = QUICore.screenWidth, QUICore.screenHeight
        end

        -- Refresh GlobalFX if in Retail
        if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and _G.GlobalFXDialogModelScene then
            QUICore:RefreshGlobalFX()
        end
    end
end

-- Get the best pixel size for current setup
function QUICore:PixelBestSize()
    return max(0.4, min(1.15, QUICore.perfect))
end

-- Handle UI scale changes
function QUICore:PixelScaleChanged(event)
    if event == 'UI_SCALE_CHANGED' then
        QUICore.physicalWidth, QUICore.physicalHeight = GetPhysicalScreenSize()
        QUICore.resolution = format('%dx%d', QUICore.physicalWidth, QUICore.physicalHeight)
        QUICore.perfect = 768 / QUICore.physicalHeight
    end

    QUICore:UIMult()
    QUICore:UIScale()
end

-- Scale a value to align with physical pixels
-- This is the core pixel-perfect function
function QUICore:Scale(x)
    local m = QUICore.mult
    if m == 1 or x == 0 then
        return x
    else
        local y = m > 1 and m or -m
        return x - x % (x < 0 and y or -y)
    end
end

-- Initialize the pixel perfect system
function QUICore:InitializePixelPerfect()
    -- Initialize physical screen size and perfect scale
    self.physicalWidth, self.physicalHeight = GetPhysicalScreenSize()
    self.resolution = format('%dx%d', self.physicalWidth, self.physicalHeight)
    self.perfect = 768 / self.physicalHeight
    
    -- Initialize multiplier (will be 1.0 until db is ready)
    self.mult = 1.0
    
    -- Calculate initial multiplier if db is ready
    if self.db and self.db.profile then
        self:UIMult()
    end
    
    -- Register for UI scale changes
    self:RegisterEvent('UI_SCALE_CHANGED', 'PixelScaleChanged')
end

-- Get smart default scale based on screen resolution (Option 3)
function QUICore:GetSmartDefaultScale()
    local _, screenHeight = GetPhysicalScreenSize()
    
    if screenHeight >= 2160 then      -- 4K
        return 0.53
    elseif screenHeight >= 1440 then  -- 1440p
        return 0.64
    else                              -- 1080p or lower
        return 1.0
    end
end

-- Apply saved UI scale (call this after db is initialized)
function QUICore:ApplyUIScale()
    if self.db and self.db.profile and self.db.profile.general then
        local savedScale = self.db.profile.general.uiScale
        if savedScale and savedScale > 0 then
            UIParent:SetScale(savedScale)
        else
            -- Option 3: No saved scale - use smart default based on resolution
            local smartScale = self:GetSmartDefaultScale()
            self.db.profile.general.uiScale = smartScale
            UIParent:SetScale(smartScale)
        end
    end
    
    -- Update pixel perfect calculations
    if self.UIMult and self.UIScale then
        self:UIMult()
        self:UIScale()
    end
end

