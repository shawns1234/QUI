-- customglows.lua
-- Custom glow effects for Essential and Utility cooldown viewers
-- Uses Blizzard's SpellActivationAlert system for proper sizing
-- Falls back to LibCustomGlow for additional glow styles

local _, QUI = ...

-- Get LibCustomGlow for fallback styles
local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

-- Track which icons currently have active glows
local activeGlowIcons = {}  -- [icon] = true

-- Glow templates for proc effects
local GlowTemplates = {
    LoopGlow = {
        {
            name = "Default Blizzard Glow",
            atlas = "UI-HUD-ActionBar-Proc-Loop-Flipbook",
            rows = 6, columns = 5, frames = 30, duration = 1.0,
        },
        {
            name = "Blue Assist Glow",
            atlas = "RotationHelper-ProcLoopBlue-Flipbook",
            rows = 6, columns = 5, frames = 30, duration = 1.0,
        },
        {
            name = "Classic Ants",
            texture = "Interface\\SpellActivationOverlay\\IconAlertAnts",
            rows = 5, columns = 5, frames = 25, duration = 0.8,
        },
    },
}

-- ======================================================
-- Settings Access
-- ======================================================
local function GetSettings()
    local QUICore = _G.QuaziiUI and _G.QuaziiUI.QUICore
    if not QUICore or not QUICore.db or not QUICore.db.profile then
        return nil
    end
    return QUICore.db.profile.customGlow
end

local function GetEffectsSettings()
    local QUICore = _G.QuaziiUI and _G.QuaziiUI.QUICore
    if not QUICore or not QUICore.db or not QUICore.db.profile then
        return { hideEssential = true, hideUtility = true }
    end
    return QUICore.db.profile.cooldownEffects or { hideEssential = true, hideUtility = true }
end

-- ======================================================
-- Determine viewer type from icon
-- ======================================================
local function GetViewerType(icon)
    if not icon then return nil end
    
    local parent = icon:GetParent()
    if not parent then return nil end
    
    local parentName = parent:GetName()
    if not parentName then return nil end
    
    if parentName:find("EssentialCooldown") then
        return "Essential"
    elseif parentName:find("UtilityCooldown") then
        return "Utility"
    end
    
    return nil
end

-- ======================================================
-- Get settings for viewer type
-- ======================================================
local function GetViewerSettings(viewerType)
    local settings = GetSettings()
    if not settings then return nil end

    local effectsSettings = GetEffectsSettings()

    if viewerType == "Essential" then
        if not effectsSettings.hideEssential then return nil end
        if not settings.essentialEnabled then return nil end
        local glowType = settings.essentialGlowType or "Pixel Glow"
        if glowType == "Proc Glow" then glowType = "Pixel Glow" end
        return {
            enabled = true,
            glowType = glowType,
            color = settings.essentialColor or {0.95, 0.95, 0.32, 1},
            lines = settings.essentialLines or 14,
            frequency = settings.essentialFrequency or 0.25,
            thickness = settings.essentialThickness or 2,
            scale = settings.essentialScale or 1,
            xOffset = settings.essentialXOffset or 0,
            yOffset = settings.essentialYOffset or 0,
        }
    elseif viewerType == "Utility" then
        if not effectsSettings.hideUtility then return nil end
        if not settings.utilityEnabled then return nil end
        local glowType = settings.utilityGlowType or "Pixel Glow"
        if glowType == "Proc Glow" then glowType = "Pixel Glow" end
        return {
            enabled = true,
            glowType = glowType,
            color = settings.utilityColor or {0.95, 0.95, 0.32, 1},
            lines = settings.utilityLines or 14,
            frequency = settings.utilityFrequency or 0.25,
            thickness = settings.utilityThickness or 2,
            scale = settings.utilityScale or 1,
            xOffset = settings.utilityXOffset or 0,
            yOffset = settings.utilityYOffset or 0,
        }
    end

    return nil
end

-- ======================================================
-- Customize Blizzard's SpellActivationAlert
-- ======================================================
local function CustomizeBlizzardGlow(button, viewerSettings)
    if not button then return false end
    
    local region = button.SpellActivationAlert
    if not region then return false end
    
    -- Get the loop flipbook texture
    local loopFlipbook = region.ProcLoopFlipbook
    if not loopFlipbook then return false end
    
    -- Apply custom color
    local color = viewerSettings.color or {0.95, 0.95, 0.32, 1}
    loopFlipbook:SetDesaturated(true)  -- Desaturate first so color applies properly
    loopFlipbook:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    
    -- Also color the start flipbook if it exists
    local startFlipbook = region.ProcStartFlipbook
    if startFlipbook then
        startFlipbook:SetDesaturated(true)
        startFlipbook:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    end
    
    -- Mark as customized
    button._QUICustomGlowActive = true
    activeGlowIcons[button] = true
    
    return true
end

-- ======================================================
-- LibCustomGlow application (supports 3 glow types)
-- ======================================================
local function ApplyLibCustomGlow(icon, viewerSettings)
    if not LCG then return false end
    if not icon then return false end

    local glowType = viewerSettings.glowType
    local color = viewerSettings.color
    local lines = viewerSettings.lines
    local frequency = viewerSettings.frequency
    local thickness = viewerSettings.thickness
    local scale = viewerSettings.scale or 1
    local xOffset = viewerSettings.xOffset or 0
    local yOffset = viewerSettings.yOffset or 0

    -- Stop any existing glow first
    StopGlow(icon)

    if glowType == "Pixel Glow" then
        -- Pixel Glow: animated lines around the border
        -- Parameters: frame, color, numLines, frequency, length, thickness, xOffset, yOffset, border, key
        LCG.PixelGlow_Start(icon, color, lines, frequency, nil, thickness, 0, 0, true, "_QUICustomGlow")
        local glowFrame = icon["_PixelGlow_QUICustomGlow"]
        if glowFrame then
            glowFrame:ClearAllPoints()
            -- Apply offset: negative expands outward, positive shrinks inward
            glowFrame:SetPoint("TOPLEFT", icon, "TOPLEFT", -xOffset, xOffset)
            glowFrame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", xOffset, -xOffset)
        end

    elseif glowType == "Autocast Shine" then
        -- Autocast Shine: orbiting sparkle spots
        -- Parameters: frame, color, numSpots, frequency, scale, xOffset, yOffset, key
        LCG.AutoCastGlow_Start(icon, color, lines, frequency, scale, 0, 0, "_QUICustomGlow")
        local glowFrame = icon["_AutoCastGlow_QUICustomGlow"]
        if glowFrame then
            glowFrame:ClearAllPoints()
            glowFrame:SetPoint("TOPLEFT", icon, "TOPLEFT", -xOffset, xOffset)
            glowFrame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", xOffset, -xOffset)
        end
    end

    -- Flag already set by StartGlow, just ensure it's there
    icon._QUICustomGlowActive = true
    activeGlowIcons[icon] = true

    return true
end

-- ======================================================
-- Main glow application function
-- ======================================================
local function StartGlow(icon)
    if not icon then return end
    
    -- Already has our glow? Skip
    if icon._QUICustomGlowActive then return end
    
    local viewerType = GetViewerType(icon)
    if not viewerType then return end
    
    local viewerSettings = GetViewerSettings(viewerType)
    if not viewerSettings then return end
    
    -- Always use LibCustomGlow since we hide Blizzard's SpellActivationAlert
    -- Set the flag FIRST so cooldowneffects.lua doesn't interfere
    icon._QUICustomGlowActive = true
    activeGlowIcons[icon] = true
    
    ApplyLibCustomGlow(icon, viewerSettings)
end

-- Stop all glow effects on an icon
function StopGlow(icon)
    if not icon then return end
    
    -- Stop LibCustomGlow effects
    if LCG then
        pcall(LCG.PixelGlow_Stop, icon, "_QUICustomGlow")
        pcall(LCG.AutoCastGlow_Stop, icon, "_QUICustomGlow")
    end
    
    icon._QUICustomGlowActive = nil
    activeGlowIcons[icon] = nil
end

-- ======================================================
-- Hook into Blizzard's glow system
-- ======================================================
local function SetupGlowHooks()
    -- Hook ActionButton_ShowOverlayGlow - this is called when a proc happens
    -- We apply our glow IMMEDIATELY (no delay) so the flag is set before cooldowneffects.lua runs
    if type(ActionButton_ShowOverlayGlow) == "function" then
        hooksecurefunc("ActionButton_ShowOverlayGlow", function(button)
            if not button then return end
            
            local viewerType = GetViewerType(button)
            if not viewerType then return end
            
            local viewerSettings = GetViewerSettings(viewerType)
            if not viewerSettings then return end
            
            -- Apply immediately - no delay! This sets the flag before cooldowneffects.lua checks it
            if button:IsShown() then
                StartGlow(button)
            end
        end)
    end
    
    -- Hook ActionButton_HideOverlayGlow - this is called when proc ends
    if type(ActionButton_HideOverlayGlow) == "function" then
        hooksecurefunc("ActionButton_HideOverlayGlow", function(button)
            if not button then return end
            
            local viewerType = GetViewerType(button)
            if viewerType then
                StopGlow(button)
            end
        end)
    end
    
    -- Also listen for spell activation events directly
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
    eventFrame:SetScript("OnEvent", function(self, event, spellID)
        if not spellID then return end
        
        -- Find the icon with this spellID in our viewers
        local viewers = {
            {name = "EssentialCooldownViewer", type = "Essential"},
            {name = "UtilityCooldownViewer", type = "Utility"},
        }
        
        for _, viewerInfo in ipairs(viewers) do
            local viewer = _G[viewerInfo.name]
            if viewer then
                local children = {viewer:GetChildren()}
                for _, child in ipairs(children) do
                    if child:IsShown() then
                        -- Wrap spell ID access and comparison in pcall to handle "secret" values
                        local matched = false
                        pcall(function()
                            local iconSpellID = child.spellID or child.SpellID or 
                                               (child.GetSpellID and child:GetSpellID())
                            if iconSpellID and iconSpellID == spellID then
                                matched = true
                            end
                        end)
                        
                        if matched then
                            if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
                                -- Apply immediately - no delay!
                                StartGlow(child)
                            else
                                StopGlow(child)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- ======================================================
-- Refresh all glows (called when settings change)
-- ======================================================
local function RefreshAllGlows()
    -- Store which icons had glows before refresh
    local iconsWithGlows = {}
    for icon, _ in pairs(activeGlowIcons) do
        if icon then
            iconsWithGlows[icon] = true
        end
    end
    
    -- Stop all existing custom glows
    for icon, _ in pairs(activeGlowIcons) do
        if icon then
            StopGlow(icon)
        end
    end
    wipe(activeGlowIcons)
    
    -- Re-apply glows to icons that had them before
    for icon, _ in pairs(iconsWithGlows) do
        if icon and icon:IsShown() then
            StartGlow(icon)
        end
    end
end

-- ======================================================
-- Initialize
-- ======================================================
local glowHooksSetup = false

local function EnsureGlowHooks()
    if glowHooksSetup then return end
    glowHooksSetup = true
    SetupGlowHooks()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" and arg == "Blizzard_CooldownManager" then
        -- Set up hooks immediately - no delay!
        EnsureGlowHooks()
    elseif event == "PLAYER_LOGIN" then
        -- Backup: ensure hooks are set up by login
        EnsureGlowHooks()
    end
end)

-- ======================================================
-- Export to QUI namespace
-- ======================================================
QUI.CustomGlows = {
    StartGlow = StartGlow,
    StopGlow = StopGlow,
    RefreshAllGlows = RefreshAllGlows,
    GetViewerType = GetViewerType,
    activeGlowIcons = activeGlowIcons,
}

-- Global function for config panel to call
_G.QuaziiUI_RefreshCustomGlows = RefreshAllGlows

-- Debug functions
_G.QuaziiUI_TestCustomGlow = function(viewerType)
    viewerType = viewerType or "Essential"
    local viewer = _G[viewerType .. "CooldownViewer"]
    if viewer then
        local children = {viewer:GetChildren()}
        for i, child in ipairs(children) do
            if child:IsShown() then
                StartGlow(child)
                print("|cFF00FF00[QuaziiUI]|r Test glow applied to " .. viewerType .. " icon #" .. i)
                return
            end
        end
        print("|cFFFF0000[QuaziiUI]|r No visible icons in " .. viewerType .. " viewer")
    else
        print("|cFFFF0000[QuaziiUI]|r " .. viewerType .. "CooldownViewer not found")
    end
end

_G.QuaziiUI_StopAllCustomGlows = function()
    for icon, _ in pairs(activeGlowIcons) do
        if icon then
            StopGlow(icon)
        end
    end
    wipe(activeGlowIcons)
    print("|cFF00FF00[QuaziiUI]|r All custom glows stopped")
end
