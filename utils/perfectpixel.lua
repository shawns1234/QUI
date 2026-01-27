--- QuaziiUI Pixel Precision System (AbstractFramework Integration)
--- Professional pixel-perfect UI scaling with advanced font handling

local ADDON_NAME, ns = ...
local AF = _G.AbstractFramework

if not AF then
    print("|cFFFF0000[QuaziiUI] ERROR: AbstractFramework not loaded!|r")
    return
end

local QUICore = ns.Addon or (QuaziiUI and QuaziiUI.QUICore)

if not QUICore then
    print("|cFFFF0000[QuaziiUI] ERROR: QUICore not loaded before pixelprecision.lua!|r")
    return
end

-- ============================================================================
-- EXTENDED ABSTRACTFRAMEWORK FONT FUNCTIONALITY
-- ============================================================================

---@param fontString FontString
---@param fontPath string|nil default is "Fonts\\FRIZQT__.TTF"
---@param size number
---@param flags string|nil default is "OUTLINE"
function AF.SetFont(fontString, fontPath, size, flags)
    if not fontString then return end

    -- Calculate pixel-perfect font size using AF's proven algorithm
    local pixelScale = AF.GetPixelFactor()
    local pixelPerfectSize = AF.GetNearestPixelSize(size, pixelScale)

    -- Set defaults with WoW 12.x compatibility
    fontPath = fontPath or "Fonts\\FRIZQT__.TTF"
    flags = flags or "OUTLINE"

    -- Safe font setting with error handling
    pcall(fontString.SetFont, fontString, fontPath, pixelPerfectSize, flags)
end

---@param parent Frame
---@param fontPath string|nil
---@param size number
---@param flags string|nil
---@return FontString
function AF.CreateFontString(parent, fontPath, size, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")

    -- Store font settings for automatic pixel updates
    fs._fontPath = fontPath
    fs._fontSize = size
    fs._fontFlags = flags

    -- Apply pixel-perfect font immediately
    AF.SetFont(fs, fontPath, size, flags)

    -- Add to AF's automatic pixel updater system
    AF.AddToPixelUpdater_Auto(fs, function(f)
        AF.SetFont(f, f._fontPath, f._fontSize, f._fontFlags)
        AF.RePoint(f)
    end)

    return fs
end

-- ============================================================================
-- QUI CUSTOM UI SCALING CONFIGURATION
-- ============================================================================

--- Apply configured UI scale with QUI's custom logic
--- Maintains user choice between presets and custom ratios
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

    -- Apply with combat state protection (WoW 12.x requirement)
    if InCombatLockdown() then
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

    -- Trigger AF pixel updates after scale change
    AF.UpdatePixels_Auto()
end

--- Determine intelligent default scale based on display resolution
--- Professional algorithm considering modern monitor standards
function QUICore:GetIntelligentDefaultScale()
    local physicalWidth, physicalHeight = GetPhysicalScreenSize()

    if physicalHeight >= 2160 then      -- 4K displays
        return 0.53
    elseif physicalHeight >= 1440 then  -- 1440p displays
        return 0.64
    else                              -- 1080p and lower
        return 1.0
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function QUICore:InitializePixelPrecision()
    -- Register for scale and resolution change events
    self:RegisterEvent('UI_SCALE_CHANGED', 'ApplyConfiguredUIScale')
    self:RegisterEvent('DISPLAY_SIZE_CHANGED', 'ApplyConfiguredUIScale')

    -- Apply initial scaling
    self:ApplyConfiguredUIScale()
end

-- ============================================================================
-- BACKWARD COMPATIBILITY & API EXPOSURE
-- ============================================================================

-- Maintain compatibility with existing QUI Scale function calls
QUICore.Scale = AF.GetNearestPixelSize

-- Expose AF functions through QUICore for existing code
-- This provides a clean API while using AF internally
QUICore.SetSize = AF.SetSize
QUICore.SetPoint = AF.SetPoint
QUICore.SetWidth = AF.SetWidth
QUICore.SetHeight = AF.SetHeight
QUICore.SafeSetFont = AF.SetFont
