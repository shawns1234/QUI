---------------------------------------------------------------------------
-- QuaziiUI Tooltip Module
-- Cursor-following tooltips with per-context visibility controls
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

if not ns.ShouldLoadModule("tooltips", { name = "Tooltips", enabled = true }) then
    return
end

local QUI = ns.QUI or {}
ns.QUI = QUI

-- Locals for performance
local GameTooltip = GameTooltip
local UIParent = UIParent
local IsShiftKeyDown = IsShiftKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsAltKeyDown = IsAltKeyDown
local InCombatLockdown = InCombatLockdown
local strfind = string.find
local strmatch = string.match
local GetMouseFoci = GetMouseFoci
local WorldFrame = WorldFrame

---------------------------------------------------------------------------
-- Mouse Focus Detection
-- Gets topmost frame under mouse cursor (API compatibility wrapper)
---------------------------------------------------------------------------
local function GetTopMouseFrame()
    if GetMouseFoci then
        local frames = GetMouseFoci()
        return frames and frames[1]
    else
        return GetMouseFocus and GetMouseFocus()
    end
end

-- Check if a UI frame is blocking mouse from the 3D world
local function IsFrameBlockingMouse()
    local focus = GetTopMouseFrame()
    if not focus then return false end

    -- WorldFrame means mouse is over the 3D world, not a UI panel
    if focus == WorldFrame then return false end

    -- If there's any other visible frame under the mouse, it's blocking
    return focus:IsVisible()
end

-- State
local cachedSettings = nil
local originalSetDefaultAnchor = nil

---------------------------------------------------------------------------
-- Get settings from database (cached for performance)
---------------------------------------------------------------------------
local function GetSettings()
    if cachedSettings then return cachedSettings end
    local QUICore = _G.QuaziiUI and _G.QuaziiUI.QUICore
    if QUICore and QUICore.db and QUICore.db.profile and QUICore.db.profile.tooltip then
        cachedSettings = QUICore.db.profile.tooltip
        return cachedSettings
    end
    return nil
end

-- Cache invalidation (called on profile change or settings update)
local function InvalidateCache()
    cachedSettings = nil
end

---------------------------------------------------------------------------
-- Context Detection
-- Determines what triggered the tooltip based on owner frame
---------------------------------------------------------------------------
local function GetTooltipContext(owner)
    if not owner then return "npcs" end

    local name = owner:GetName() or ""

    -- Abilities: Check for action button patterns
    if strmatch(name, "ActionButton") or
       strmatch(name, "MultiBar") or
       strmatch(name, "PetActionButton") or
       strmatch(name, "StanceButton") or
       strmatch(name, "OverrideActionBar") or
       strmatch(name, "ExtraActionButton") or
       strmatch(name, "BT4Button") or           -- Bartender4
       strmatch(name, "DominosActionButton") or -- Dominos
       strmatch(name, "ElvUI_Bar") then         -- ElvUI
        return "abilities"
    end

    -- Items: Check for container/bag frame patterns
    if strmatch(name, "ContainerFrame") or
       strmatch(name, "BagSlot") or
       strmatch(name, "BankFrame") or
       strmatch(name, "ReagentBank") or
       strmatch(name, "BagItem") or
       strmatch(name, "Baganator") then         -- Baganator addon
        return "items"
    end

    -- Check parent for bag items (nested frames)
    local parent = owner:GetParent()
    if parent then
        local parentName = parent:GetName() or ""
        if strmatch(parentName, "ContainerFrame") or
           strmatch(parentName, "BankFrame") or
           strmatch(parentName, "Baganator") then
            return "items"
        end
    end

    -- Frames: Check for unit frame patterns
    if owner.unit or                            -- Standard unit attribute
       strmatch(name, "UnitFrame") or
       strmatch(name, "PlayerFrame") or
       strmatch(name, "TargetFrame") or
       strmatch(name, "FocusFrame") or
       strmatch(name, "PartyMemberFrame") or
       strmatch(name, "CompactRaidFrame") or
       strmatch(name, "CompactPartyFrame") or
       strmatch(name, "NamePlate") or
       strmatch(name, "Quazii.*Frame") then     -- QuaziiUI unit frames
        return "frames"
    end

    -- Default: NPCs, players, objects in the game world
    return "npcs"
end

---------------------------------------------------------------------------
-- Modifier Key Check
---------------------------------------------------------------------------
local function IsModifierActive(modKey)
    if modKey == "SHIFT" then return IsShiftKeyDown() end
    if modKey == "CTRL" then return IsControlKeyDown() end
    if modKey == "ALT" then return IsAltKeyDown() end
    return false
end

---------------------------------------------------------------------------
-- Visibility Logic
-- Determines if tooltip should be shown based on context and settings
---------------------------------------------------------------------------
local function ShouldShowTooltip(context)
    local settings = GetSettings()
    if not settings or not settings.enabled then
        return true  -- Module disabled = default behavior
    end

    -- Combat check - if hideInCombat is enabled and we're in combat
    if settings.hideInCombat and InCombatLockdown() then
        -- Check if combat key is set and pressed
        if settings.combatKey and settings.combatKey ~= "NONE" then
            if IsModifierActive(settings.combatKey) then
                return true  -- Force show in combat with modifier
            end
        end
        return false  -- Hide in combat (no key pressed)
    end

    local visibility = settings.visibility and settings.visibility[context]
    if not visibility then
        return true  -- Unknown context = show by default
    end

    -- Context visibility check
    if visibility == "SHOW" then
        return true
    elseif visibility == "HIDE" then
        return false
    else
        -- Modifier-based visibility (SHIFT/CTRL/ALT)
        return IsModifierActive(visibility)
    end
end

---------------------------------------------------------------------------
-- Tooltip Hook
-- Intercepts GameTooltip_SetDefaultAnchor to apply cursor anchoring
---------------------------------------------------------------------------
local function SetupTooltipHook()
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
        local settings = GetSettings()
        if not settings or not settings.enabled then
            return  -- Module disabled, use default behavior
        end

        -- Get context from parent (owner)
        local context = GetTooltipContext(parent)

        -- Check visibility for this context
        if not ShouldShowTooltip(context) then
            tooltip:Hide()
            return
        end

        -- Cursor anchor logic
        if settings.anchorToCursor then
            -- Use WoW's built-in cursor anchor (handles positioning automatically)
            tooltip:SetOwner(parent, "ANCHOR_CURSOR")
        end
    end)

    -- Hook SetUnit to suppress tooltips when a UI frame blocks the mouse
    hooksecurefunc(GameTooltip, "SetUnit", function(tooltip, unit)
        local settings = GetSettings()
        if not settings or not settings.enabled then return end

        -- If owner is UIParent (world tooltip) and a UI frame is blocking the mouse
        if tooltip:GetOwner() == UIParent and IsFrameBlockingMouse() then
            tooltip:Hide()
        end
    end)
end

---------------------------------------------------------------------------
-- Modifier State Handler
-- Re-evaluates tooltip visibility when modifier keys change
---------------------------------------------------------------------------
local function OnModifierStateChanged()
    -- Only process if tooltip is currently shown
    if not GameTooltip:IsShown() then return end

    local settings = GetSettings()
    if not settings or not settings.enabled then return end

    local owner = GameTooltip:GetOwner()
    local context = GetTooltipContext(owner)

    -- If tooltip should now be hidden, hide it
    if not ShouldShowTooltip(context) then
        GameTooltip:Hide()
    end
end

---------------------------------------------------------------------------
-- Event Frame
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Delay hook setup to ensure database is ready
        C_Timer.After(0.5, function()
            SetupTooltipHook()
        end)
    elseif event == "MODIFIER_STATE_CHANGED" then
        OnModifierStateChanged()
    end
end)

---------------------------------------------------------------------------
-- Global Refresh Function (called from options panel)
---------------------------------------------------------------------------
_G.QuaziiUI_RefreshTooltips = function()
    InvalidateCache()
    -- Settings will apply on next tooltip show
end
