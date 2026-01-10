---------------------------------------------------------------------------
-- QuaziiUI Crosshair Module
-- A simple screen center crosshair overlay
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local QUI = ns.QUI or {}
ns.QUI = QUI

local crosshairFrame, horizLine, vertLine, horizBorder, vertBorder

-- Range tracking state
local isOutOfRange = false
local rangeCheckElapsed = 0
local RANGE_CHECK_INTERVAL = 0.1  -- Check range 10 times per second

---------------------------------------------------------------------------
-- Get settings from database
---------------------------------------------------------------------------
local function GetSettings()
    local QUICore = _G.QuaziiUI and _G.QuaziiUI.QUICore
    if QUICore and QUICore.db and QUICore.db.profile and QUICore.db.profile.crosshair then
        return QUICore.db.profile.crosshair
    end
    return nil
end

---------------------------------------------------------------------------
-- Check if target is out of melee range
-- Uses C_Spell.IsSpellInRange with Attack spell for accurate auto-attack range
-- Based on MSUF implementation for robust range detection
---------------------------------------------------------------------------
local ATTACK_SPELL_ID = 6603  -- Auto-attack spell ID

local function IsOutOfMeleeRange()
    -- No target = not out of range (use normal color)
    if not UnitExists("target") then
        return false
    end
    
    -- Must be an attackable target
    if not UnitCanAttack("player", "target") then
        return false
    end
    
    -- Dead targets don't count
    if UnitIsDeadOrGhost("target") then
        return false
    end
    
    -- Use auto-attack (Attack spell ID 6603) for accurate melee range
    -- C_Spell.IsSpellInRange returns: true/1 = in range, false/0 = out of range, nil = not applicable
    if C_Spell and C_Spell.IsSpellInRange then
        local inRange = C_Spell.IsSpellInRange(ATTACK_SPELL_ID, "target")
        -- Handle both true and 1 as valid "in range" values for compatibility
        if inRange == true or inRange == 1 then
            return false  -- In range, not out of range
        elseif inRange == false or inRange == 0 then
            return true   -- Out of range
        end
        -- nil = spell check didn't work, fall through to fallback
    end
    
    -- Fallback to CheckInteractDistance if spell check fails
    local inRange = CheckInteractDistance("target", 3)
    return not inRange
end

---------------------------------------------------------------------------
-- Apply crosshair color based on range state
---------------------------------------------------------------------------
local function ApplyCrosshairColor(settings, outOfRange)
    if not horizLine or not vertLine then return end
    
    local r, g, b, a
    
    if outOfRange and settings.changeColorOnRange then
        -- Use out-of-range color
        local oorColor = settings.outOfRangeColor or { 1, 0.2, 0.2, 1 }
        r = oorColor[1] or 1
        g = oorColor[2] or 0.2
        b = oorColor[3] or 0.2
        a = oorColor[4] or 1
    else
        -- Use normal color
        r = settings.r or 1
        g = settings.g or 0.949
        b = settings.b or 0
        a = settings.a or 1
    end
    
    horizLine:SetColorTexture(r, g, b, a)
    vertLine:SetColorTexture(r, g, b, a)
end

---------------------------------------------------------------------------
-- Range check OnUpdate handler
---------------------------------------------------------------------------
local function OnRangeUpdate(self, elapsed)
    rangeCheckElapsed = rangeCheckElapsed + elapsed
    if rangeCheckElapsed < RANGE_CHECK_INTERVAL then return end
    rangeCheckElapsed = 0
    
    local settings = GetSettings()
    if not settings or not settings.enabled or not settings.changeColorOnRange then
        -- Feature disabled, stop checking
        self:SetScript("OnUpdate", nil)
        return
    end
    
    -- Check if we should only track range in combat
    if settings.rangeColorInCombatOnly and not InCombatLockdown() then
        -- Not in combat and combat-only is enabled, use normal color
        if isOutOfRange then
            isOutOfRange = false
            ApplyCrosshairColor(settings, false)
        end
        return
    end
    
    local newOutOfRange = IsOutOfMeleeRange()
    if newOutOfRange ~= isOutOfRange then
        isOutOfRange = newOutOfRange
        ApplyCrosshairColor(settings, isOutOfRange)
    end
end

---------------------------------------------------------------------------
-- Start or stop range checking based on settings
---------------------------------------------------------------------------
local function UpdateRangeChecking()
    if not crosshairFrame then return end
    
    local settings = GetSettings()
    if settings and settings.enabled and settings.changeColorOnRange then
        -- Enable range checking
        rangeCheckElapsed = 0
        crosshairFrame:SetScript("OnUpdate", OnRangeUpdate)
        
        -- Immediately check range (respecting combat-only setting)
        if settings.rangeColorInCombatOnly and not InCombatLockdown() then
            isOutOfRange = false
            ApplyCrosshairColor(settings, false)
        else
            isOutOfRange = IsOutOfMeleeRange()
            ApplyCrosshairColor(settings, isOutOfRange)
        end
    else
        -- Disable range checking
        crosshairFrame:SetScript("OnUpdate", nil)
        isOutOfRange = false
    end
end

---------------------------------------------------------------------------
-- Create the crosshair frame and textures
---------------------------------------------------------------------------
local function CreateCrosshair()
    if crosshairFrame then return end
    
    crosshairFrame = CreateFrame("Frame", "QuaziiUI_Crosshair", UIParent)
    crosshairFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    crosshairFrame:SetSize(1, 1)
    crosshairFrame:SetFrameStrata("HIGH")
    
    -- Border textures (drawn behind main lines)
    horizBorder = crosshairFrame:CreateTexture(nil, "BACKGROUND")
    horizBorder:SetPoint("CENTER", crosshairFrame)
    horizBorder:SetColorTexture(0, 0, 0, 1)
    
    vertBorder = crosshairFrame:CreateTexture(nil, "BACKGROUND")
    vertBorder:SetPoint("CENTER", crosshairFrame)
    vertBorder:SetColorTexture(0, 0, 0, 1)
    
    -- Main crosshair lines (drawn above borders)
    horizLine = crosshairFrame:CreateTexture(nil, "ARTWORK")
    horizLine:SetPoint("CENTER", crosshairFrame)
    horizLine:SetColorTexture(1, 0.949, 0, 1)  -- Default yellow
    
    vertLine = crosshairFrame:CreateTexture(nil, "ARTWORK")
    vertLine:SetPoint("CENTER", crosshairFrame)
    vertLine:SetColorTexture(1, 0.949, 0, 1)  -- Default yellow
    
    crosshairFrame:Hide()
end

---------------------------------------------------------------------------
-- Update crosshair appearance from settings
---------------------------------------------------------------------------
local function UpdateCrosshair()
    if not crosshairFrame then
        CreateCrosshair()
    end
    
    local settings = GetSettings()
    if not settings then
        crosshairFrame:Hide()
        return
    end
    
    -- Get settings with defaults
    local enabled = settings.enabled
    local size = settings.size or 12
    local thickness = settings.thickness or 3
    local borderSize = settings.borderSize or 2
    local offsetX = settings.offsetX or 0
    local offsetY = settings.offsetY or 0
    local borderR = settings.borderR or 0
    local borderG = settings.borderG or 0
    local borderB = settings.borderB or 0
    local borderA = settings.borderA or 1
    local strata = settings.strata or "HIGH"
    local onlyInCombat = settings.onlyInCombat
    
    -- Apply strata and position
    crosshairFrame:SetFrameStrata(strata)
    crosshairFrame:ClearAllPoints()
    crosshairFrame:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
    
    -- Size the border textures (slightly larger than main lines)
    horizBorder:SetSize((size * 2) + borderSize * 2, thickness + borderSize * 2)
    vertBorder:SetSize(thickness + borderSize * 2, (size * 2) + borderSize * 2)
    horizBorder:SetColorTexture(borderR, borderG, borderB, borderA)
    vertBorder:SetColorTexture(borderR, borderG, borderB, borderA)
    
    -- Size the main crosshair lines
    horizLine:SetSize(size * 2, thickness)
    vertLine:SetSize(thickness, size * 2)
    
    -- Apply color based on range state (if feature enabled)
    if settings.changeColorOnRange then
        isOutOfRange = IsOutOfMeleeRange()
        ApplyCrosshairColor(settings, isOutOfRange)
    else
        -- Use normal color
        local r = settings.r or 1
        local g = settings.g or 0.949
        local b = settings.b or 0
        local a = settings.a or 1
        horizLine:SetColorTexture(r, g, b, a)
        vertLine:SetColorTexture(r, g, b, a)
    end
    
    -- Show/hide based on settings
    if not enabled then
        crosshairFrame:Hide()
        crosshairFrame:SetScript("OnUpdate", nil)
    elseif onlyInCombat then
        crosshairFrame:SetShown(InCombatLockdown())
    else
        crosshairFrame:Show()
    end
    
    -- Update range checking state
    UpdateRangeChecking()
end

---------------------------------------------------------------------------
-- Combat visibility handling
---------------------------------------------------------------------------
local function OnCombatStart()
    local settings = GetSettings()
    if settings and settings.enabled and settings.onlyInCombat then
        if crosshairFrame then
            crosshairFrame:Show()
            UpdateRangeChecking()
        end
    end
end

local function OnCombatEnd()
    local settings = GetSettings()
    if settings and settings.onlyInCombat then
        if crosshairFrame then
            crosshairFrame:Hide()
            crosshairFrame:SetScript("OnUpdate", nil)
        end
    end
end

---------------------------------------------------------------------------
-- Target changed handler
---------------------------------------------------------------------------
local function OnTargetChanged()
    local settings = GetSettings()
    if settings and settings.enabled and settings.changeColorOnRange then
        -- Immediately update color when target changes
        isOutOfRange = IsOutOfMeleeRange()
        ApplyCrosshairColor(settings, isOutOfRange)
    end
end

---------------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(1, function()
            CreateCrosshair()
            UpdateCrosshair()
        end)
    elseif event == "PLAYER_REGEN_DISABLED" then
        OnCombatStart()
    elseif event == "PLAYER_REGEN_ENABLED" then
        OnCombatEnd()
    elseif event == "PLAYER_TARGET_CHANGED" then
        OnTargetChanged()
    end
end)

---------------------------------------------------------------------------
-- Global refresh function for GUI
---------------------------------------------------------------------------
_G.QuaziiUI_RefreshCrosshair = UpdateCrosshair

QUI.Crosshair = {
    Update = UpdateCrosshair,
    Create = CreateCrosshair,
}

