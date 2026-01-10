---------------------------------------------------------------------------
-- QuaziiUI Crosshair Module
-- A simple screen center crosshair overlay
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

if not ns.ShouldLoadModule("crosshair", { name = "Crosshair", enabled = true }) then
    return
end

local QUI = ns.QUI or {}
ns.QUI = QUI

local crosshairFrame, horizLine, vertLine, horizBorder, vertBorder

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
    local r = settings.r or 1
    local g = settings.g or 0.949
    local b = settings.b or 0
    local a = settings.a or 1
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
    horizLine:SetColorTexture(r, g, b, a)
    vertLine:SetColorTexture(r, g, b, a)
    
    -- Show/hide based on settings
    if not enabled then
        crosshairFrame:Hide()
    elseif onlyInCombat then
        crosshairFrame:SetShown(InCombatLockdown())
    else
        crosshairFrame:Show()
    end
end

---------------------------------------------------------------------------
-- Combat visibility handling
---------------------------------------------------------------------------
local function OnCombatStart()
    local settings = GetSettings()
    if settings and settings.enabled and settings.onlyInCombat then
        if crosshairFrame then
            crosshairFrame:Show()
        end
    end
end

local function OnCombatEnd()
    local settings = GetSettings()
    if settings and settings.onlyInCombat then
        if crosshairFrame then
            crosshairFrame:Hide()
        end
    end
end

---------------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
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

