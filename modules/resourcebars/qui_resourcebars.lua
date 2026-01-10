--[[
    QUI Resource Bars Module
    Handles primary and secondary class resource bars (mana, energy, rage, etc.)
    Fully integrated with the layout system for positioning, sizing, and anchoring
]]

local ADDON_NAME, ns = ...

-- Check if module should load
local shouldLoad = true
if ns.ShouldLoadModule then
    shouldLoad = ns.ShouldLoadModule("resourcebars", { name = "Resource Bars", enabled = true })
end
if not shouldLoad then
    return
end

local QUICore = ns.Addon
local LSM = LibStub("LibSharedMedia-3.0")

---------------------------------------------------------------------------
-- MODULE TABLE
---------------------------------------------------------------------------
local QUI_ResourceBars = {}
ns.QUI_ResourceBars = QUI_ResourceBars

-- Reference to anchoring and layout modules
local QUI_Anchoring = ns.QUI_Anchoring
local QUI_LayoutManager = ns.QUI_LayoutManager

-- Module state
QUI_ResourceBars.primaryBar = nil
QUI_ResourceBars.secondaryBar = nil

local Helpers = {}

---------------------------------------------------------------------------
-- SETUP HELPERS
---------------------------------------------------------------------------
function QUI_ResourceBars:SetHelpers(helpers)
    Helpers = helpers or {}
end

-- Helper function wrappers
local function Scale(x)
    if Helpers.Scale then
        return Helpers.Scale(x)
    elseif QUICore and QUICore.Scale then
        return QUICore:Scale(x)
    end
    return x
end

local function GetDB()
    if Helpers.GetDB then
        return Helpers.GetDB()
    elseif QUICore and QUICore.db then
        return QUICore.db
    end
    return nil
end

-- Helper to get texture from general settings (falls back to default)
local function GetDefaultTexture()
    local db = GetDB()
    if db and db.profile and db.profile.general then
        return db.profile.general.texture or "Quazii"
    end
    return "Quazii"
end

-- Helper to get bar-specific texture (falls back to Solid)
local function GetBarTexture(cfg)
    if cfg and cfg.texture then
        return cfg.texture
    end
    return "Solid"
end

-- Helper to get font from general settings
local function GetGeneralFont()
    local db = GetDB()
    if db and db.profile and db.profile.general then
        local general = db.profile.general
        local fontName = general.font or "Friz Quadrata TT"
        return LSM:Fetch("font", fontName) or "Fonts\\FRIZQT__.TTF"
    end
    return "Fonts\\FRIZQT__.TTF"
end

local function GetGeneralFontOutline()
    local db = GetDB()
    if db and db.profile and db.profile.general then
        return db.profile.general.fontOutline or "OUTLINE"
    end
    return "OUTLINE"
end

--TABLES

local tocVersion = select(4, GetBuildInfo())
local HAS_UNIT_POWER_PERCENT = type(UnitPowerPercent) == "function"

-- Power percent with 12.01 API compatibility
-- API signature changed: old (unit, powerType, scaleTo100) -> new (unit, powerType, usePredicted, curve)
local function GetPowerPct(unit, powerType, usePredicted)
    if (tonumber(tocVersion) or 0) >= 120000 and HAS_UNIT_POWER_PERCENT then
        local ok, pct
        -- 12.01+: Use curve parameter (new API)
        if CurveConstants and CurveConstants.ScaleTo100 then
            ok, pct = pcall(UnitPowerPercent, unit, powerType, usePredicted, CurveConstants.ScaleTo100)
        end
        -- Fallback for older builds
        if not ok or pct == nil then
            ok, pct = pcall(UnitPowerPercent, unit, powerType, usePredicted)
        end
        if ok and pct ~= nil then
            return pct
        end
    end
    -- Manual calculation fallback
    local cur = UnitPower(unit, powerType)
    local max = UnitPowerMax(unit, powerType)
    if cur and max and max > 0 then
        return (cur / max) * 100
    end
    return nil
end

local tickedPowerTypes = {
    [Enum.PowerType.ArcaneCharges] = true,
    [Enum.PowerType.Chi] = true,
    [Enum.PowerType.ComboPoints] = true,
    [Enum.PowerType.Essence] = true,
    [Enum.PowerType.HolyPower] = true,
    [Enum.PowerType.Runes] = true,
    [Enum.PowerType.SoulShards] = true,
}

local fragmentedPowerTypes = {
    [Enum.PowerType.Runes] = true,
}

-- Smooth rune timer update state
local runeUpdateElapsed = 0
local runeUpdateRunning = false

-- Event throttle (16ms = ~60 FPS, smooth updates while managing CPU)
local UPDATE_THROTTLE = 0.016
local lastPrimaryUpdate = 0
local lastSecondaryUpdate = 0

-- Discrete resources that need instant feedback (no throttle)
-- These change infrequently and users expect immediate visual response
local instantFeedbackTypes = {
    [Enum.PowerType.HolyPower] = true,
    [Enum.PowerType.ComboPoints] = true,
    [Enum.PowerType.Chi] = true,
    [Enum.PowerType.Runes] = true,
    [Enum.PowerType.ArcaneCharges] = true,
    [Enum.PowerType.Essence] = true,
    [Enum.PowerType.SoulShards] = true,
}

-- Druid utility forms (show spec resource instead of form resource)
local druidUtilityForms = {
    [0]  = true,  -- Human/Caster
    [2]  = true,  -- Tree of Life (Resto talent)
    [3]  = true,  -- Travel (ground)
    [4]  = true,  -- Aquatic
    [27] = true,  -- Swift Travel/Flight
}

-- Druid spec primary resources
local druidSpecResource = {
    [1] = Enum.PowerType.LunarPower,  -- Balance
    [2] = Enum.PowerType.Energy,       -- Feral
    [3] = Enum.PowerType.Rage,         -- Guardian
    [4] = Enum.PowerType.Mana,         -- Restoration
}

-- RESOURCE DETECTION

local function GetPrimaryResource()
    local playerClass = select(2, UnitClass("player"))
    local primaryResources = {
        ["DEATHKNIGHT"] = Enum.PowerType.RunicPower,
        ["DEMONHUNTER"] = Enum.PowerType.Fury,
        ["DRUID"]       = {
            [0]   = Enum.PowerType.Mana,        -- Human/Caster
            [1]   = Enum.PowerType.Energy,      -- Cat
            [3]   = Enum.PowerType.Mana,        -- Travel (ground) - fallback
            [4]   = Enum.PowerType.Mana,        -- Aquatic - fallback
            [5]   = Enum.PowerType.Rage,        -- Bear
            [27]  = Enum.PowerType.Mana,        -- Swift Travel - fallback
            [31]  = Enum.PowerType.LunarPower,  -- Moonkin
        },
        ["EVOKER"]      = Enum.PowerType.Mana,
        ["HUNTER"]      = Enum.PowerType.Focus,
        ["MAGE"]        = Enum.PowerType.Mana,
        ["MONK"]        = {
            [268] = Enum.PowerType.Energy, -- Brewmaster
            [269] = Enum.PowerType.Energy, -- Windwalker
            [270] = Enum.PowerType.Mana, -- Mistweaver
        },
        ["PALADIN"]     = Enum.PowerType.Mana,
        ["PRIEST"]      = {
            [256] = Enum.PowerType.Mana, -- Disciple
            [257] = Enum.PowerType.Mana, -- Holy,
            [258] = Enum.PowerType.Insanity, -- Shadow,
        },
        ["ROGUE"]       = Enum.PowerType.Energy,
        ["SHAMAN"]      = {
            [262] = Enum.PowerType.Maelstrom, -- Elemental
            [263] = Enum.PowerType.Mana, -- Enhancement
            [264] = Enum.PowerType.Mana, -- Restoration
        },
        ["WARLOCK"]     = Enum.PowerType.Mana,
        ["WARRIOR"]     = Enum.PowerType.Rage,
    }

    local spec = GetSpecialization()
    local specID = GetSpecializationInfo(spec)

    -- Druid: spec-aware for utility forms, form-based for combat forms
    if playerClass == "DRUID" then
        local formID = GetShapeshiftFormID()
        -- In utility forms (travel/aquatic/flight), show spec's primary resource
        if druidUtilityForms[formID or 0] then
            local druidSpec = GetSpecialization()
            if druidSpec and druidSpecResource[druidSpec] then
                return druidSpecResource[druidSpec]
            end
        end
        -- Combat forms and caster form: use form-based resource
        return primaryResources[playerClass][formID or 0]
    end

    if type(primaryResources[playerClass]) == "table" then
        return primaryResources[playerClass][specID]
    else 
        return primaryResources[playerClass]
    end
end

local function GetSecondaryResource()
    local playerClass = select(2, UnitClass("player"))
    local secondaryResources = {
        ["DEATHKNIGHT"] = Enum.PowerType.Runes,
        ["DEMONHUNTER"] = {
            [1480] = "SOUL", -- Aldrachi Reaver
        },
        ["DRUID"]       = {
            [1]    = Enum.PowerType.ComboPoints, -- Cat
            [31]   = Enum.PowerType.Mana, -- Moonkin
        },
        ["EVOKER"]      = Enum.PowerType.Essence,
        ["HUNTER"]      = nil,
        ["MAGE"]        = {
            [62]   = Enum.PowerType.ArcaneCharges, -- Arcane
        },
        ["MONK"]        = {
            [268]  = "STAGGER", -- Brewmaster
            [269]  = Enum.PowerType.Chi, -- Windwalker
        },
        ["PALADIN"]     = Enum.PowerType.HolyPower,
        ["PRIEST"]      = {
            [258]  = Enum.PowerType.Mana, -- Shadow
        },
        ["ROGUE"]       = Enum.PowerType.ComboPoints,
        ["SHAMAN"]      = {
            [262]  = Enum.PowerType.Mana, -- Elemental
        },
        ["WARLOCK"]     = Enum.PowerType.SoulShards,
        ["WARRIOR"]     = nil,
    }

    local spec = GetSpecialization()
    local specID = GetSpecializationInfo(spec)

    -- Druid: spec-aware for utility/caster forms, form-based for combat forms
    if playerClass == "DRUID" then
        local formID = GetShapeshiftFormID()
        -- In utility/caster forms, show Mana as secondary if spec primary isn't Mana
        if druidUtilityForms[formID] or formID == nil then
            local druidSpec = GetSpecialization()
            -- Only show Mana secondary for non-Resto specs (Resto primary is already Mana)
            if druidSpec and druidSpec ~= 4 then
                return Enum.PowerType.Mana
            end
            return nil
        end
        -- Combat forms: use form-based secondary
        return secondaryResources[playerClass][formID]
    end

    if type(secondaryResources[playerClass]) == "table" then
        return secondaryResources[playerClass][specID]
    else 
        return secondaryResources[playerClass]
    end
end

local function GetResourceColor(resource)
    -- Check for custom power colors first
    local db = GetDB()
    local pc = db and db.profile and db.profile.powerColors

    if pc then
        local customColor = nil

        if resource == "STAGGER" then
            customColor = pc.stagger
        elseif resource == "SOUL" then
            customColor = pc.soulFragments
        elseif resource == Enum.PowerType.SoulShards then
            customColor = pc.soulShards
        elseif resource == Enum.PowerType.Runes then
            -- Check DK spec for spec-specific rune colors
            local _, class = UnitClass("player")
            if class == "DEATHKNIGHT" then
                local spec = GetSpecialization()
                if spec == 1 then customColor = pc.bloodRunes
                elseif spec == 2 then customColor = pc.frostRunes
                elseif spec == 3 then customColor = pc.unholyRunes
                else customColor = pc.runes end
            else
                customColor = pc.runes
            end
        elseif resource == Enum.PowerType.Essence then
            customColor = pc.essence
        elseif resource == Enum.PowerType.ComboPoints then
            customColor = pc.comboPoints
        elseif resource == Enum.PowerType.Chi then
            customColor = pc.chi
        elseif resource == Enum.PowerType.Mana then
            customColor = pc.mana
        elseif resource == Enum.PowerType.Rage then
            customColor = pc.rage
        elseif resource == Enum.PowerType.Energy then
            customColor = pc.energy
        elseif resource == Enum.PowerType.Focus then
            customColor = pc.focus
        elseif resource == Enum.PowerType.RunicPower then
            customColor = pc.runicPower
        elseif resource == Enum.PowerType.Insanity then
            customColor = pc.insanity
        elseif resource == Enum.PowerType.Fury then
            customColor = pc.fury
        elseif resource == Enum.PowerType.Maelstrom then
            customColor = pc.maelstrom
        elseif resource == Enum.PowerType.LunarPower then
            customColor = pc.lunarPower
        elseif resource == Enum.PowerType.HolyPower then
            customColor = pc.holyPower
        elseif resource == Enum.PowerType.ArcaneCharges then
            customColor = pc.arcaneCharges
        end

        if customColor then
            return { r = customColor[1], g = customColor[2], b = customColor[3], a = customColor[4] }
        end
    end

    -- Fallback to Blizzard's power bar colors
    local powerName = nil
    if type(resource) == "number" then
        for name, value in pairs(Enum.PowerType) do
            if value == resource then
                powerName = name:gsub("(%u)", "_%1"):gsub("^_", ""):upper()
                break
            end
        end
    end

    return GetPowerBarColor(powerName)
        or GetPowerBarColor(resource)
        or GetPowerBarColor("MANA")
end

-- DEMON HUNTER SOUL FRAGMENTS BAR HANDLING

local function EnsureDemonHunterSoulBar()
    -- Ensure the Demon Hunter soul fragments bar is always shown and functional
    -- This is needed even when custom unit frames are enabled
    local _, class = UnitClass("player")
    if class ~= "DEMONHUNTER" then return end
    
    local spec = GetSpecialization()
    if spec ~= 3 then return end -- Devourer (spec 3, ID 1480)
    
    local soulBar = _G["DemonHunterSoulFragmentsBar"]
    if soulBar then
        -- Reparent to UIParent if not already (so it's not affected by PlayerFrame)
        if soulBar:GetParent() ~= UIParent then
            if not InCombatLockdown() then
                soulBar:SetParent(UIParent)
            end
        end
        -- Ensure it's shown (even if PlayerFrame is hidden)
        if not soulBar:IsShown() then
            soulBar:Show()
        end
        soulBar:SetAlpha(0)  -- ALWAYS hide visually (fixes Devourer spec)
        -- Unhook any hide scripts that might prevent it from showing
        if not InCombatLockdown() then
            soulBar:SetScript("OnShow", nil)
            -- Set OnHide to immediately show it again
            soulBar:SetScript("OnHide", function(self)
                if not InCombatLockdown() then
                    self:Show()
                    self:SetAlpha(0)
                end
            end)
        end
    end
end

-- GET RESOURCE VALUES

local function GetPrimaryResourceValue(resource, cfg)
    if not resource then return nil, nil, nil, nil end

    local current = UnitPower("player", resource)
    local max = UnitPowerMax("player", resource)
    if max <= 0 then return nil, nil, nil, nil end

    -- Check both old (showManaAsPercent) and new (showPercent) field names
    if (cfg.showPercent or cfg.showManaAsPercent) and resource == Enum.PowerType.Mana then
        if HAS_UNIT_POWER_PERCENT then
            return max, current, GetPowerPct("player", resource, false), "percent"
        else
            return max, current, math.floor((current / max) * 100 + 0.5), "percent"
        end
    else
        return max, current, current, "number"
    end
end

local function GetSecondaryResourceValue(resource)
    if not resource then return nil, nil, nil, nil end

    if resource == "STAGGER" then
        local stagger = UnitStagger("player") or 0
        local maxHealth = UnitHealthMax("player") or 1
        return maxHealth, stagger, stagger, "number"
    end

    if resource == "SOUL" then
        -- DH souls – get from default Blizzard bar
        local soulBar = _G["DemonHunterSoulFragmentsBar"]
        if not soulBar then return nil, nil, nil, nil end
        
        -- Ensure the bar is shown (even if PlayerFrame is hidden)
        if not soulBar:IsShown() then
            soulBar:Show()
            soulBar:SetAlpha(0)
        end

        local current = soulBar:GetValue()
        local _, max = soulBar:GetMinMaxValues()

        return max, current, current, "number"
    end

    if resource == Enum.PowerType.Runes then
        local current = 0
        local max = UnitPowerMax("player", resource)
        if max <= 0 then return nil, nil, nil, nil end

        for i = 1, max do
            local runeReady = select(3, GetRuneCooldown(i))
            if runeReady then
                current = current + 1
            end
        end

        return max, current, current, "number"
    end

    if resource == Enum.PowerType.SoulShards then
        local _, class = UnitClass("player")
        if class == "WARLOCK" then
            local spec = GetSpecialization()

            -- Destruction: use FRAGMENTS (0–50) directly for bar + text
            if spec == 3 then
                local current = UnitPower("player", resource, true)          -- 0–50
                local max     = UnitPowerMax("player", resource, true)       -- 0–50
                if max <= 0 then return nil, nil, nil, nil end

                -- bar fill = fragments, text = fragments (34, 45, etc.)
                return max, current, current, "number"
            end
        end

        -- Any other spec/class that somehow hits SoulShards:
        -- use NORMAL shard count (0–5) for both bar + text
        local current = UnitPower("player", resource)             -- 0–5
        local max     = UnitPowerMax("player", resource)          -- 0–5
        if max <= 0 then return nil, nil, nil, nil end

        -- bar = 0–5, text = 3, 4, 5 etc.
        return max, current, current, "number"
    end

    -- Default case for all other power types (ComboPoints, Chi, HolyPower, etc.)
    local current = UnitPower("player", resource)
    local max = UnitPowerMax("player", resource)
    if max <= 0 then return nil, nil, nil, nil end

    return max, current, current, "number"
end

-- Helper function to determine orientation when set to AUTO
-- TODO: Orientation handling will be implemented through the layout system (anchoring or width/height swap)
-- For now, AUTO defaults to HORIZONTAL
local function GetAutoOrientation(cfg, db)
    if not cfg or cfg.orientation ~= "AUTO" then
        return nil  -- Not AUTO mode
    end
    
    -- TODO: When orientation is implemented in layout system, check anchor target's orientation
    -- For now, default to horizontal
    return false  -- HORIZONTAL
end

-- PRIMARY POWER BAR

function QUI_ResourceBars:GetPrimaryBar()
    if self.primaryBar then return self.primaryBar end

    local db = GetDB()
    if not db then return nil end
    
    local cfg = db.profile.powerBar
    
    -- Always parent to UIParent so power bar works independently of Essential Cooldowns
    local bar = CreateFrame("Frame", ADDON_NAME .. "PowerBar", UIParent)
    bar:SetFrameStrata("MEDIUM")
    -- Set default size and position BEFORE layout registration
    bar:SetSize(200, 8)
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    -- Layout system manages width, height, and position - register once during creation
    if QUI_LayoutManager then
        QUI_LayoutManager:RegisterFrame(bar, "resourceBars.primary", "resourceBars", {
            editMode = {
                label = "Primary",
                elementKey = "primary",
                skipKeyboardEnable = false,
                elementType = "powerbar",  -- For selection handling
            },
        })
    end

    -- BACKGROUND
    bar.Background = bar:CreateTexture(nil, "BACKGROUND")
    bar.Background:SetAllPoints()
    local bgColor = cfg.bgColor or { 0.15, 0.15, 0.15, 1 }
    bar.Background:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)

    -- STATUS BAR
    bar.StatusBar = CreateFrame("StatusBar", nil, bar)
    bar.StatusBar:SetAllPoints()
    local tex = LSM:Fetch("statusbar", GetBarTexture(cfg))
    bar.StatusBar:SetStatusBarTexture(tex)
    bar.StatusBar:SetFrameLevel(bar:GetFrameLevel())

    -- BORDER (pixel-perfect 1px, raw pixels when snapped to CDM)
    local borderSize = cfg.useRawPixels and (cfg.borderSize or 1) or Scale(cfg.borderSize or 1)
    bar.Border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    bar.Border:SetPoint("TOPLEFT", bar, -borderSize, borderSize)
    bar.Border:SetPoint("BOTTOMRIGHT", bar, borderSize, -borderSize)
    bar.Border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = borderSize,
    })
    bar.Border:SetBackdropBorderColor(0, 0, 0, 1)

    -- TEXT FRAME (MEDIUM strata with high frame level to render above castbar)
    bar.TextFrame = CreateFrame("Frame", nil, bar)
    bar.TextFrame:SetAllPoints(bar)
    bar.TextFrame:SetFrameStrata("MEDIUM")
    bar.TextFrame:SetFrameLevel(300)

    bar.TextValue = bar.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.TextValue:SetPoint("CENTER", bar.TextFrame, "CENTER", Scale(cfg.textX or 0), Scale(cfg.textY or 0))
    bar.TextValue:SetJustifyH("CENTER")
    bar.TextValue:SetFont(GetGeneralFont(), Scale(cfg.textSize or 12), GetGeneralFontOutline())
    bar.TextValue:SetShadowOffset(0, 0)
    bar.TextValue:SetText("0")

    -- TICKS
    bar.ticks = {}

    self.primaryBar = bar
    
    -- Register as anchor target (register immediately if available, or will be registered on next update)
    if QUI_Anchoring then
        QUI_Anchoring:RegisterAnchorTarget("primary", bar, {
            displayName = "Primary Resource Bar",
            category = "Resource Bars",
            categoryOrder = 3,
            order = 1
        })
    end
    
    return bar
end

function QUI_ResourceBars:UpdatePrimaryBar()
    local db = GetDB()
    if not db then return end
    
    local cfg = db.profile.powerBar
    local bar = self:GetPrimaryBar()
    
    -- Handle enabled/disabled state
    if not cfg.enabled then
        if bar then
            bar:Hide()
        end
        return
    end
    
    -- Bar is enabled, ensure it's shown
    if not bar then return end
    bar:Show()
    
    -- Ensure layout is applied
    if QUI_LayoutManager then
        QUI_LayoutManager:ApplyLayout(bar)
    end
    
    local resource = GetPrimaryResource()
    if not resource then
        return
    end

    -- Get resource values
    local max, current, displayValue, valueType = GetPrimaryResourceValue(resource, cfg)
    if not max then
        -- Resource value function returned nil (resource doesn't exist or isn't initialized)
        return
    end

    -- Determine effective orientation (AUTO/HORIZONTAL/VERTICAL)
    local orientation = cfg.orientation or "AUTO"
    local isVertical = (orientation == "VERTICAL")

    -- For AUTO, inherit orientation from anchor target
    if orientation == "AUTO" then
        local autoOrientation = GetAutoOrientation(cfg, db.profile)
        if autoOrientation ~= nil then
            isVertical = autoOrientation
        end
    end

    -- Apply orientation to StatusBar
    bar.StatusBar:SetOrientation(isVertical and "VERTICAL" or "HORIZONTAL")

    -- Layout system manages width, height, and position automatically
    -- If frames are anchored to this power bar, the layout system will update them automatically

    -- Update border size only when changed (prevents flicker)
    local borderSize = cfg.useRawPixels and (cfg.borderSize or 1) or Scale(cfg.borderSize or 1)
    if bar.Border and bar._cachedBorderSize ~= borderSize then
        bar.Border:ClearAllPoints()
        bar.Border:SetPoint("TOPLEFT", bar, -borderSize, borderSize)
        bar.Border:SetPoint("BOTTOMRIGHT", bar, borderSize, -borderSize)
        bar.Border:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = borderSize,
        })
        bar.Border:SetBackdropBorderColor(0, 0, 0, 1)
        bar.Border:SetShown(borderSize > 0)
        bar._cachedBorderSize = borderSize
    end

    -- Update background color
    local bgColor = cfg.bgColor or { 0.15, 0.15, 0.15, 1 }
    if bar.Background then
        bar.Background:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    end

    -- Update texture only when changed (prevents flicker)
    local tex = LSM:Fetch("statusbar", GetBarTexture(cfg))
    if bar._cachedTex ~= tex then
        bar.StatusBar:SetStatusBarTexture(tex)
        bar._cachedTex = tex
    end

    -- Set bar values
    bar.StatusBar:SetMinMaxValues(0, max)
    bar.StatusBar:SetValue(current)

    -- Set bar color based on checkboxes: Power Type > Class > Custom
    if cfg.usePowerColor then
        -- Power type color (Mana=blue, Rage=red, Energy=yellow, etc.)
        local color = GetResourceColor(resource)
        bar.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
    elseif cfg.useClassColor then
        -- Class color
        local _, class = UnitClass("player")
        local classColor = RAID_CLASS_COLORS[class]
        if classColor then
            bar.StatusBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
        else
            local color = GetResourceColor(resource)
            bar.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
        end
    elseif cfg.useCustomColor and cfg.customColor then
        -- Custom color override
        local c = cfg.customColor
        bar.StatusBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
    else
        -- Power type color (default)
        local color = GetResourceColor(resource)
        bar.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
    end

    -- Update text
    if valueType == "percent" then
        bar.TextValue:SetText(string.format("%.0f%%", displayValue))
    else
        bar.TextValue:SetText(tostring(displayValue))
    end

    bar.TextValue:SetFont(GetGeneralFont(), Scale(cfg.textSize or 12), GetGeneralFontOutline())
    bar.TextValue:SetShadowOffset(0, 0)

    -- Apply text color
    if cfg.textUseClassColor then
        local _, class = UnitClass("player")
        local classColor = RAID_CLASS_COLORS[class]
        if classColor then
            bar.TextValue:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
        end
    else
        local c = cfg.textCustomColor or { 1, 1, 1, 1 }
        bar.TextValue:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    end

    -- Only reposition text when offset changed (prevents flicker)
    local textX = Scale(cfg.textX or 0)
    local textY = Scale(cfg.textY or 0)
    if bar._cachedTextX ~= textX or bar._cachedTextY ~= textY then
        bar.TextValue:ClearAllPoints()
        bar.TextValue:SetPoint("CENTER", bar.TextFrame, "CENTER", textX, textY)
        bar._cachedTextX = textX
        bar._cachedTextY = textY
    end

    -- Show text based on config
    bar.TextFrame:SetShown(cfg.showText ~= false)

    -- Update ticks if this is a ticked power type
    self:UpdatePrimaryBarTicks(bar, resource, max)

    -- Note: Frames anchored to this power bar will update automatically when they are repositioned
    -- The anchoring system handles updates internally - no need to manually call UpdateFramesForTarget
    -- Layout manager handles all positioning and sizing automatically
end

function QUI_ResourceBars:UpdatePrimaryBarTicks(bar, resource, max)
    local db = GetDB()
    if not db then return end
    
    local cfg = db.profile.powerBar

    -- Hide all ticks first
    for _, tick in ipairs(bar.ticks) do
        tick:Hide()
    end

    if not cfg.showTicks or not tickedPowerTypes[resource] then
        return
    end

    local width = bar:GetWidth()
    local height = bar:GetHeight()
    if width <= 0 or height <= 0 then return end

    -- Determine if bar is vertical
    local orientation = cfg.orientation or "AUTO"
    local isVertical = (orientation == "VERTICAL")
    if orientation == "AUTO" then
        if cfg.anchorTo == "essential" then
            local viewer = _G.EssentialCooldownViewer
            isVertical = viewer and viewer.__cdmLayoutDirection == "VERTICAL"
        elseif cfg.anchorTo == "utility" then
            local viewer = _G.UtilityCooldownViewer
            isVertical = viewer and viewer.__cdmLayoutDirection == "VERTICAL"
        end
    end

    local tickThickness = Scale(cfg.tickThickness or 1)
    local tc = cfg.tickColor or { 0, 0, 0, 1 }
    local needed = max - 1
    for i = 1, needed do
        local tick = bar.ticks[i]
        if not tick then
            tick = bar:CreateTexture(nil, "OVERLAY")
            bar.ticks[i] = tick
        end
        tick:SetColorTexture(tc[1], tc[2], tc[3], tc[4] or 1)
        tick:ClearAllPoints()

        if isVertical then
            -- Vertical bar: ticks go along height (Y axis)
            local y = (i / max) * height
            tick:SetPoint("BOTTOM", bar.StatusBar, "BOTTOM", 0, Scale(y - (tickThickness / 2)))
            tick:SetSize(width, tickThickness)
        else
            -- Horizontal bar: ticks go along width (X axis)
            local x = (i / max) * width
            tick:SetPoint("LEFT", bar.StatusBar, "LEFT", Scale(x - (tickThickness / 2)), 0)
            tick:SetSize(tickThickness, height)
        end
        tick:Show()
    end

    -- Hide extra ticks
    for i = needed + 1, #bar.ticks do
        if bar.ticks[i] then
            bar.ticks[i]:Hide()
        end
    end
end

-- SECONDARY POWER BAR

function QUI_ResourceBars:GetSecondaryBar()
    if self.secondaryBar then return self.secondaryBar end

    local db = GetDB()
    if not db then return nil end
    
    local cfg = db.profile.secondaryPowerBar
    
    -- Always parent to UIParent so secondary power bar works independently
    local bar = CreateFrame("Frame", ADDON_NAME .. "SecondaryPowerBar", UIParent)
    bar:SetFrameStrata("MEDIUM")
    -- Set default size and position BEFORE layout registration
    bar:SetSize(200, 8)
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    -- Layout system manages width, height, and position - register once during creation
    if QUI_LayoutManager then
        QUI_LayoutManager:RegisterFrame(bar, "resourceBars.secondary", "resourceBars", {
            editMode = {
                label = "Secondary",
                elementKey = "secondary",
                skipKeyboardEnable = false,
                elementType = "powerbar",  -- For selection handling
            },
        })
    end

    -- BACKGROUND
    bar.Background = bar:CreateTexture(nil, "BACKGROUND")
    bar.Background:SetAllPoints()
    local bgColor = cfg.bgColor or { 0.15, 0.15, 0.15, 1 }
    bar.Background:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)

    -- STATUS BAR (for non-fragmented resources)
    bar.StatusBar = CreateFrame("StatusBar", nil, bar)
    bar.StatusBar:SetAllPoints()
    local tex = LSM:Fetch("statusbar", GetBarTexture(cfg))
    bar.StatusBar:SetStatusBarTexture(tex)
    bar.StatusBar:SetFrameLevel(bar:GetFrameLevel())

    -- BORDER (pixel-perfect)
    local borderSize = Scale(cfg.borderSize or 1)
    bar.Border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    bar.Border:SetPoint("TOPLEFT", bar, -borderSize, borderSize)
    bar.Border:SetPoint("BOTTOMRIGHT", bar, borderSize, -borderSize)
    bar.Border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = borderSize,
    })
    bar.Border:SetBackdropBorderColor(0, 0, 0, 1)

    -- TEXT FRAME (MEDIUM strata with high frame level to render above castbar)
    bar.TextFrame = CreateFrame("Frame", nil, bar)
    bar.TextFrame:SetAllPoints(bar)
    bar.TextFrame:SetFrameStrata("MEDIUM")
    bar.TextFrame:SetFrameLevel(300)

    bar.TextValue = bar.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.TextValue:SetPoint("CENTER", bar.TextFrame, "CENTER", Scale(cfg.textX or 0), Scale(cfg.textY or 0))
    bar.TextValue:SetJustifyH("CENTER")
    bar.TextValue:SetFont(GetGeneralFont(), Scale(cfg.textSize or 12), GetGeneralFontOutline())
    bar.TextValue:SetShadowOffset(0, 0)
    bar.TextValue:SetText("0")

    -- Fake decimal for Destro shards
    bar.SoulShardDecimal = bar.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.SoulShardDecimal:SetFont(GetGeneralFont(), Scale(cfg.textSize or 12), GetGeneralFontOutline())
    bar.SoulShardDecimal:SetShadowOffset(0, 0)
    bar.SoulShardDecimal:SetText(".")
    bar.SoulShardDecimal:Hide()

    -- FRAGMENTED POWER BARS (for Runes)
    bar.FragmentedPowerBars = {}
    bar.FragmentedPowerBarTexts = {}

    -- TICKS
    bar.ticks = {}

    self.secondaryBar = bar
    
    -- Register as anchor target (register immediately if available, or will be registered on next update)
    if QUI_Anchoring then
        QUI_Anchoring:RegisterAnchorTarget("secondary", bar, {
            displayName = "Secondary Resource Bar",
            category = "Resource Bars",
            categoryOrder = 3,
            order = 2
        })
    end
    
    return bar
end

function QUI_ResourceBars:CreateFragmentedPowerBars(bar, resource, isVertical)
    local db = GetDB()
    if not db then return end
    
    local cfg = db.profile.secondaryPowerBar
    local maxPower = UnitPowerMax("player", resource)

    for i = 1, maxPower do
        if not bar.FragmentedPowerBars[i] then
            local fragmentBar = CreateFrame("StatusBar", nil, bar)
            local tex = LSM:Fetch("statusbar", GetBarTexture(cfg))
            fragmentBar:SetStatusBarTexture(tex)
            fragmentBar:GetStatusBarTexture()
            fragmentBar:SetOrientation(isVertical and "VERTICAL" or "HORIZONTAL")
            fragmentBar:SetFrameLevel(bar.StatusBar:GetFrameLevel())
            bar.FragmentedPowerBars[i] = fragmentBar
            
            -- Create text for reload time display (pixel-perfect)
            local text = fragmentBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("CENTER", fragmentBar, "CENTER", Scale(cfg.runeTimerTextX or 0), Scale(cfg.runeTimerTextY or 0))
            text:SetJustifyH("CENTER")
            text:SetFont(GetGeneralFont(), Scale(cfg.runeTimerTextSize or 10), GetGeneralFontOutline())
            text:SetShadowOffset(0, 0)
            text:SetText("")
            bar.FragmentedPowerBarTexts[i] = text
        end
    end
end

function QUI_ResourceBars:UpdateFragmentedPowerDisplay(bar, resource, isVertical)
    local db = GetDB()
    if not db then return end
    
    local cfg = db.profile.secondaryPowerBar
    local maxPower = UnitPowerMax("player", resource)
    if maxPower <= 0 then return end

    local current = UnitPower("player", resource)
    local barWidth = bar:GetWidth()
    local barHeight = bar:GetHeight()

    -- Calculate fragment dimensions based on orientation
    local fragmentedBarWidth, fragmentedBarHeight
    if isVertical then
        fragmentedBarHeight = barHeight / maxPower
        fragmentedBarWidth = barWidth
    else
        fragmentedBarWidth = barWidth / maxPower
        fragmentedBarHeight = barHeight
    end
    
    -- Hide the main status bar fill (we display bars representing one (1) unit of resource each)
    bar.StatusBar:SetAlpha(0)

    -- Update texture for all fragmented bars
    local tex = LSM:Fetch("statusbar", GetDefaultTexture())
    for i = 1, maxPower do
        if bar.FragmentedPowerBars[i] then
            bar.FragmentedPowerBars[i]:SetStatusBarTexture(tex)
        end
    end

    -- Determine color based on checkboxes: Power Type > Class > Custom
    local color

    if cfg.usePowerColor then
        -- Power type color
        color = GetResourceColor(resource)
    elseif cfg.useClassColor then
        local _, class = UnitClass("player")
        local classColor = RAID_CLASS_COLORS[class]
        if classColor then
            color = { r = classColor.r, g = classColor.g, b = classColor.b }
        else
            color = GetResourceColor(resource)
        end
    elseif cfg.useCustomColor and cfg.customColor then
        -- Custom color override
        local c = cfg.customColor
        color = { r = c[1], g = c[2], b = c[3], a = c[4] or 1 }
    else
        -- Power type color (default)
        color = GetResourceColor(resource)
    end

    if resource == Enum.PowerType.Runes then
        -- Collect rune states: ready and recharging
        local readyList = {}
        local cdList = {}
        local now = GetTime()
        
        for i = 1, maxPower do
            local start, duration, runeReady = GetRuneCooldown(i)
            if runeReady then
                table.insert(readyList, { index = i })
            else
                if start and duration and duration > 0 then
                    local elapsed = now - start
                    local remaining = math.max(0, duration - elapsed)
                    local frac = math.max(0, math.min(1, elapsed / duration))
                    table.insert(cdList, { index = i, remaining = remaining, frac = frac })
                else
                    table.insert(cdList, { index = i, remaining = math.huge, frac = 0 })
                end
            end
        end

        -- Sort cdList by ascending remaining time
        table.sort(cdList, function(a, b)
            return a.remaining < b.remaining
        end)

        -- Build final display order: ready runes first, then CD runes sorted
        local displayOrder = {}
        local readyLookup = {}
        local cdLookup = {}
        
        for _, v in ipairs(readyList) do
            table.insert(displayOrder, v.index)
            readyLookup[v.index] = true
        end
        
        for _, v in ipairs(cdList) do
            table.insert(displayOrder, v.index)
            cdLookup[v.index] = v
        end

        for pos = 1, #displayOrder do
            local runeIndex = displayOrder[pos]
            local runeFrame = bar.FragmentedPowerBars[runeIndex]
            local runeText = bar.FragmentedPowerBarTexts[runeIndex]

            if runeFrame then
                runeFrame:ClearAllPoints()
                runeFrame:SetSize(fragmentedBarWidth, fragmentedBarHeight)
                if isVertical then
                    runeFrame:SetPoint("BOTTOM", bar, "BOTTOM", 0, (pos - 1) * fragmentedBarHeight)
                else
                    runeFrame:SetPoint("LEFT", bar, "LEFT", (pos - 1) * fragmentedBarWidth, 0)
                end

                -- Update rune timer text position and font size
                if runeText then
                    runeText:ClearAllPoints()
                    runeText:SetPoint("CENTER", runeFrame, "CENTER", Scale(cfg.runeTimerTextX or 0), Scale(cfg.runeTimerTextY or 0))
                    runeText:SetFont(GetGeneralFont(), Scale(cfg.runeTimerTextSize or 10), GetGeneralFontOutline())
                    runeText:SetShadowOffset(0, 0)
                end

                if readyLookup[runeIndex] then
                    -- Ready rune
                    runeFrame:SetMinMaxValues(0, 1)
                    runeFrame:SetValue(1)
                    runeText:SetText("")
                    runeFrame:SetStatusBarColor(color.r, color.g, color.b)
                else
                    -- Recharging rune
                    local cdInfo = cdLookup[runeIndex]
                    if cdInfo then
                        runeFrame:SetMinMaxValues(0, 1)
                        runeFrame:SetValue(cdInfo.frac)
                        
                        -- Only show timer text if enabled
                        if cfg.showFragmentedPowerBarText ~= false then
                            runeText:SetText(string.format("%.1f", math.max(0, cdInfo.remaining)))
                        else
                            runeText:SetText("")
                        end
                        
                        runeFrame:SetStatusBarColor(color.r * 0.5, color.g * 0.5, color.b * 0.5)
                    else
                        runeFrame:SetMinMaxValues(0, 1)
                        runeFrame:SetValue(0)
                        runeText:SetText("")
                        runeFrame:SetStatusBarColor(color.r * 0.5, color.g * 0.5, color.b * 0.5)
                    end
                end

                runeFrame:Show()
            end
        end

        -- Hide any extra rune frames beyond current maxPower
        for i = maxPower + 1, #bar.FragmentedPowerBars do
            if bar.FragmentedPowerBars[i] then
                bar.FragmentedPowerBars[i]:Hide()
                if bar.FragmentedPowerBarTexts[i] then
                    bar.FragmentedPowerBarTexts[i]:SetText("")
                end
            end
        end
        
        -- Add ticks between rune segments if enabled (pixel-perfect)
        if cfg.showTicks then
            local tickThickness = Scale(cfg.tickThickness or 1)
            local tc = cfg.tickColor or { 0, 0, 0, 1 }
            for i = 1, maxPower - 1 do
                local tick = bar.ticks[i]
                if not tick then
                    tick = bar:CreateTexture(nil, "OVERLAY")
                    bar.ticks[i] = tick
                end
                tick:SetColorTexture(tc[1], tc[2], tc[3], tc[4] or 1)

                tick:ClearAllPoints()
                if isVertical then
                    local y = i * fragmentedBarHeight
                    tick:SetPoint("BOTTOM", bar, "BOTTOM", 0, Scale(y - (tickThickness / 2)))
                    tick:SetSize(barWidth, tickThickness)
                else
                    local x = i * fragmentedBarWidth
                    tick:SetPoint("LEFT", bar, "LEFT", Scale(x - (tickThickness / 2)), 0)
                    tick:SetSize(tickThickness, barHeight)
                end
                tick:Show()
            end
            
            -- Hide extra ticks
            for i = maxPower, #bar.ticks do
                if bar.ticks[i] then
                    bar.ticks[i]:Hide()
                end
            end
        else
            -- Hide all ticks if disabled
            for _, tick in ipairs(bar.ticks) do
                tick:Hide()
            end
        end
    end
end

-- Smooth rune timer update (runs at 20 FPS when runes are on cooldown)
local function RuneTimerOnUpdate(bar, delta)
    runeUpdateElapsed = runeUpdateElapsed + delta
    if runeUpdateElapsed < 0.05 then return end  -- 20 FPS throttle (smoother cooldown animation)
    runeUpdateElapsed = 0

    -- Quick update: refresh text/fill without full layout recalc
    local now = GetTime()
    local anyOnCooldown = false
    local db = GetDB()

    for i = 1, 6 do
        local runeFrame = bar.FragmentedPowerBars and bar.FragmentedPowerBars[i]
        local runeText = bar.FragmentedPowerBarTexts and bar.FragmentedPowerBarTexts[i]
        if runeFrame and runeFrame:IsShown() then
            local start, duration, runeReady = GetRuneCooldown(i)
            if not runeReady and start and duration and duration > 0 then
                anyOnCooldown = true
                local remaining = math.max(0, duration - (now - start))
                local frac = math.max(0, math.min(1, (now - start) / duration))
                runeFrame:SetValue(frac)
                if runeText and db then
                    local cfg = db.profile.secondaryPowerBar
                    if cfg.showFragmentedPowerBarText ~= false then
                        runeText:SetText(string.format("%.1f", remaining))
                    else
                        runeText:SetText("")
                    end
                end
            end
        end
    end

    -- Auto-disable when all runes are ready
    if not anyOnCooldown then
        bar:SetScript("OnUpdate", nil)
        runeUpdateRunning = false
    end
end

function QUI_ResourceBars:UpdateSecondaryBarTicks(bar, resource, max)
    local db = GetDB()
    if not db then return end
    
    local cfg = db.profile.secondaryPowerBar

    -- Hide all ticks first
    for _, tick in ipairs(bar.ticks) do
        tick:Hide()
    end

    -- Don't show ticks if disabled, not a ticked power type, or if it's fragmented
    if not cfg.showTicks or not tickedPowerTypes[resource] or fragmentedPowerTypes[resource] then
        return
    end

    local width  = bar:GetWidth()
    local height = bar:GetHeight()
    if width <= 0 or height <= 0 then return end

    -- Determine if bar is vertical
    local orientation = cfg.orientation or "AUTO"
    local isVertical = (orientation == "VERTICAL")
    if orientation == "AUTO" then
        local autoOrientation = GetAutoOrientation(cfg, db.profile)
        if autoOrientation ~= nil then
            isVertical = autoOrientation
        end
    end

    -- For Soul Shards, use the display max (not the internal fractional max)
    local displayMax = max
    if resource == Enum.PowerType.SoulShards then
        displayMax = UnitPowerMax("player", resource) -- non-fractional max (usually 5)
    end

    local tickThickness = Scale(cfg.tickThickness or 1)
    local tc = cfg.tickColor or { 0, 0, 0, 1 }
    local needed = displayMax - 1
    for i = 1, needed do
        local tick = bar.ticks[i]
        if not tick then
            tick = bar:CreateTexture(nil, "OVERLAY")
            bar.ticks[i] = tick
        end
        tick:SetColorTexture(tc[1], tc[2], tc[3], tc[4] or 1)
        tick:ClearAllPoints()

        if isVertical then
            -- Vertical bar: ticks go along height (Y axis)
            local y = (i / displayMax) * height
            tick:SetPoint("BOTTOM", bar.StatusBar, "BOTTOM", 0, Scale(y - (tickThickness / 2)))
            tick:SetSize(width, tickThickness)
        else
            -- Horizontal bar: ticks go along width (X axis)
            local x = (i / displayMax) * width
            tick:SetPoint("LEFT", bar.StatusBar, "LEFT", Scale(x - (tickThickness / 2)), 0)
            tick:SetSize(tickThickness, height)
        end
        tick:Show()
    end

    -- Hide extra ticks
    for i = needed + 1, #bar.ticks do
        if bar.ticks[i] then
            bar.ticks[i]:Hide()
        end
    end
end

function QUI_ResourceBars:UpdateSecondaryBar()
    local db = GetDB()
    if not db then return end
    
    local cfg = db.profile.secondaryPowerBar
    local bar = self:GetSecondaryBar()
    
    -- Handle enabled/disabled state
    if not cfg.enabled then
        if bar then
            bar:Hide()
        end
        return
    end
    
    -- Bar is enabled, ensure it's shown
    if not bar then return end
    bar:Show()
    
    local resource = GetSecondaryResource()
    if not resource then
        return
    end

    -- Get resource values
    local max, current, displayValue, valueType = GetSecondaryResourceValue(resource)
    if not max then
        -- Resource value function returned nil (resource doesn't exist or isn't initialized)
        return
    end
    
    -- Ensure layout is applied before updating ticks (so bar has correct size)
    if QUI_LayoutManager then
        QUI_LayoutManager:ApplyLayout(bar)
    end

    -- Determine effective orientation (AUTO/HORIZONTAL/VERTICAL)
    local orientation = cfg.orientation or "AUTO"
    local isVertical = (orientation == "VERTICAL")

    -- For AUTO, inherit orientation from anchor target
    if orientation == "AUTO" then
        local autoOrientation = GetAutoOrientation(cfg, db.profile)
        if autoOrientation ~= nil then
            isVertical = autoOrientation
        end
    end

    -- Apply orientation to StatusBar
    bar.StatusBar:SetOrientation(isVertical and "VERTICAL" or "HORIZONTAL")

    -- Layout system manages width, height, and position automatically
    -- If frames are anchored to this power bar, the layout system will update them automatically

    -- Update border size (pixel-perfect)
    local borderSize = cfg.useRawPixels and (cfg.borderSize or 1) or Scale(cfg.borderSize or 1)
    if bar.Border then
        bar.Border:ClearAllPoints()
        bar.Border:SetPoint("TOPLEFT", bar, -borderSize, borderSize)
        bar.Border:SetPoint("BOTTOMRIGHT", bar, borderSize, -borderSize)
        bar.Border:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = borderSize,
        })
        bar.Border:SetBackdropBorderColor(0, 0, 0, 1)
        bar.Border:SetShown(borderSize > 0)
    end

    -- Update background color
    local bgColor = cfg.bgColor or { 0.15, 0.15, 0.15, 1 }
    if bar.Background then
        bar.Background:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    end

    -- Only update texture when changed (prevents flicker)
    local tex = LSM:Fetch("statusbar", GetBarTexture(cfg))
    if bar._cachedTex ~= tex then
        bar.StatusBar:SetStatusBarTexture(tex)
        bar._cachedTex = tex
    end

    -- Handle fragmented power types (Runes)
    if fragmentedPowerTypes[resource] then
        self:CreateFragmentedPowerBars(bar, resource, isVertical)
        self:UpdateFragmentedPowerDisplay(bar, resource, isVertical)

        bar.StatusBar:SetMinMaxValues(0, max)
        bar.StatusBar:SetValue(current)

        -- Set bar color based on checkboxes: Power Type > Class > Custom
        if cfg.usePowerColor then
            local color = GetResourceColor(resource)
            bar.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
        elseif cfg.useClassColor then
            local _, class = UnitClass("player")
            local classColor = RAID_CLASS_COLORS[class]
            if classColor then
                bar.StatusBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
            else
                local color = GetResourceColor(resource)
                bar.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
            end
        elseif cfg.useCustomColor and cfg.customColor then
            -- Custom color override
            local c = cfg.customColor
            bar.StatusBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
        else
            -- Power type color (default)
            local color = GetResourceColor(resource)
            bar.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
        end

        bar.TextValue:SetText(tostring(current))
    else
        -- Normal bar display
        bar.StatusBar:SetAlpha(1)
        bar.StatusBar:SetMinMaxValues(0, max)
        bar.StatusBar:SetValue(current)

        -- Set bar color based on checkboxes: Power Type > Class > Custom
        if cfg.usePowerColor then
            local color = GetResourceColor(resource)
            bar.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
        elseif cfg.useClassColor then
            local _, class = UnitClass("player")
            local classColor = RAID_CLASS_COLORS[class]
            if classColor then
                bar.StatusBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
            else
                local color = GetResourceColor(resource)
                bar.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
            end
        elseif cfg.useCustomColor and cfg.customColor then
            -- Custom color override
            local c = cfg.customColor
            bar.StatusBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
        else
            -- Power type color (default)
            local color = GetResourceColor(resource)
            bar.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
        end

        -- Update text (safe: uses only displayValue)
        bar.TextValue:SetText(tostring(displayValue or 0))
        
        -- Hide fragmented bars
        for _, fragmentBar in ipairs(bar.FragmentedPowerBars) do
            fragmentBar:Hide()
        end
    end  -- End else block for normal bar display

    -- Text formatting (applies to both fragmented and normal displays)
    bar.TextValue:SetFont(GetGeneralFont(), Scale(cfg.textSize or 12), GetGeneralFontOutline())
    bar.TextValue:SetShadowOffset(0, 0)
    bar.TextValue:ClearAllPoints()
    bar.TextValue:SetPoint("CENTER", bar.TextFrame, "CENTER", Scale(cfg.textX or 0), Scale(cfg.textY or 0))

    -- Apply text color
    if cfg.textUseClassColor then
        local _, class = UnitClass("player")
        local classColor = RAID_CLASS_COLORS[class]
        if classColor then
            bar.TextValue:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
        end
    else
        local c = cfg.textCustomColor or { 1, 1, 1, 1 }
        bar.TextValue:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    end

    if bar.SoulShardDecimal then
        bar.SoulShardDecimal:SetFont(GetGeneralFont(), Scale(cfg.textSize or 12), GetGeneralFontOutline())
        bar.SoulShardDecimal:SetShadowOffset(0, 0)
        -- Apply same text color to soul shard decimal
        if cfg.textUseClassColor then
            local _, class = UnitClass("player")
            local classColor = RAID_CLASS_COLORS[class]
            if classColor then
                bar.SoulShardDecimal:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
            end
        else
            local c = cfg.textCustomColor or { 1, 1, 1, 1 }
            bar.SoulShardDecimal:SetTextColor(c[1], c[2], c[3], c[4] or 1)
        end
    end

    -- Show text
    bar.TextFrame:SetShown(cfg.showText ~= false)

    if not fragmentedPowerTypes[resource] then
        -- Defer tick update to ensure bar has valid size after layout
        C_Timer.After(0, function()
            if bar and bar:IsShown() and bar:GetWidth() > 0 then
                self:UpdateSecondaryBarTicks(bar, resource, max)
            end
        end)
    end

    -- Handle fake decimal for Destruction Warlock
    if bar.SoulShardDecimal then
        local _, class = UnitClass("player")
        local spec = GetSpecialization()

        if resource == Enum.PowerType.SoulShards
            and class == "WARLOCK"
            and spec == 3
        then
            bar.SoulShardDecimal:ClearAllPoints()
            bar.SoulShardDecimal:SetPoint("CENTER", bar.TextValue, "CENTER", 0, 0)
            bar.SoulShardDecimal:Show()
        else
            bar.SoulShardDecimal:Hide()
        end
    end

    -- Note: Frames anchored to this power bar will update automatically when they are repositioned
    -- Layout system handles updates automatically - no need to manually call update functions
    -- Layout manager handles all positioning and sizing automatically
end

-- EVENT HANDLER

local function OnUnitPower(_, unit)
    -- Be forgiving: if unit is nil or not "player", still update.
    -- It's cheap and avoids missing power updates.
    if unit and unit ~= "player" then
        return
    end

    local db = GetDB()
    local unthrottled = db and db.profile and db.profile.powerBar and db.profile.powerBar.unthrottledCPU
    local now = GetTime()

    -- Primary bar
    if unthrottled or (now - lastPrimaryUpdate >= UPDATE_THROTTLE) then
        QUI_ResourceBars:UpdatePrimaryBar()
        lastPrimaryUpdate = now
    end

    -- Secondary bar: instant for discrete resources, unthrottled mode, or throttled otherwise
    local resource = GetSecondaryResource()
    if unthrottled or instantFeedbackTypes[resource] then
        QUI_ResourceBars:UpdateSecondaryBar()
    elseif now - lastSecondaryUpdate >= UPDATE_THROTTLE then
        QUI_ResourceBars:UpdateSecondaryBar()
        lastSecondaryUpdate = now
    end
end

-- EVENT-DRIVEN RUNE UPDATES
-- RUNE_POWER_UPDATE triggers full layout refresh; smooth timer enabled while runes recharge

local function OnRunePowerUpdate()
    local now = GetTime()
    if now - lastSecondaryUpdate < UPDATE_THROTTLE then
        return
    end
    lastSecondaryUpdate = now

    local resource = GetSecondaryResource()
    if resource == Enum.PowerType.Runes then
        local bar = QUI_ResourceBars.secondaryBar
        if bar and bar:IsShown() and fragmentedPowerTypes[resource] then
            -- Determine orientation for proper positioning
            local db = GetDB()
            if not db then return end
            
            local cfg = db.profile.secondaryPowerBar
            local orientation = cfg.orientation or "HORIZONTAL"
            local isVertical = (orientation == "VERTICAL")
            QUI_ResourceBars:UpdateFragmentedPowerDisplay(bar, resource, isVertical)

            -- Check if any runes are on cooldown
            local anyOnCooldown = false
            for i = 1, 6 do
                local _, _, runeReady = GetRuneCooldown(i)
                if not runeReady then
                    anyOnCooldown = true
                    break
                end
            end

            -- Enable/disable smooth updater
            if anyOnCooldown and not runeUpdateRunning then
                runeUpdateRunning = true
                runeUpdateElapsed = 0
                bar:SetScript("OnUpdate", RuneTimerOnUpdate)
            elseif not anyOnCooldown and runeUpdateRunning then
                bar:SetScript("OnUpdate", nil)
                runeUpdateRunning = false
            end
        end
    end
end

local function OnSpecChanged()
    -- Ensure Demon Hunter soul bar is spawned when spec changes
    EnsureDemonHunterSoulBar()

    QUI_ResourceBars:UpdatePrimaryBar()
    QUI_ResourceBars:UpdateSecondaryBar()
end

local function OnShapeshiftChanged()
    -- Druid form changes affect primary/secondary resources
    QUI_ResourceBars:UpdatePrimaryBar()
    QUI_ResourceBars:UpdateSecondaryBar()
end

-- INITIALIZATION

function QUI_ResourceBars:Initialize()
    -- Register events on QUICore if available, otherwise create our own event frame
    if QUICore then
        QUICore:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", OnSpecChanged)
        QUICore:RegisterEvent("UPDATE_SHAPESHIFT_FORM", OnShapeshiftChanged)
        QUICore:RegisterEvent("PLAYER_ENTERING_WORLD", function()
            EnsureDemonHunterSoulBar()
            OnUnitPower()
        end)

        -- POWER UPDATES
        QUICore:RegisterEvent("UNIT_POWER_FREQUENT", OnUnitPower)
        QUICore:RegisterEvent("UNIT_POWER_UPDATE", OnUnitPower)
        QUICore:RegisterEvent("UNIT_MAXPOWER", OnUnitPower)
        QUICore:RegisterEvent("RUNE_POWER_UPDATE", OnRunePowerUpdate)  -- DK rune updates (event-driven, replaces ticker)

        -- Combat state events - force update on combat transitions
        -- Ensures bars show correct values when entering/exiting combat
        QUICore:RegisterEvent("PLAYER_REGEN_DISABLED", OnUnitPower)
        QUICore:RegisterEvent("PLAYER_REGEN_ENABLED", OnUnitPower)
    else
        -- Fallback: create our own event frame
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("UNIT_POWER_FREQUENT")
        eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
        eventFrame:RegisterEvent("UNIT_MAXPOWER")
        eventFrame:RegisterEvent("RUNE_POWER_UPDATE")
        eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        
        eventFrame:SetScript("OnEvent", function(self, event, ...)
            if event == "PLAYER_SPECIALIZATION_CHANGED" then
                OnSpecChanged()
            elseif event == "UPDATE_SHAPESHIFT_FORM" then
                OnShapeshiftChanged()
            elseif event == "PLAYER_ENTERING_WORLD" then
                EnsureDemonHunterSoulBar()
                OnUnitPower()
            elseif event == "RUNE_POWER_UPDATE" then
                OnRunePowerUpdate()
            else
                OnUnitPower(event, ...)
            end
        end)
    end

    -- Ensure Demon Hunter soul bar is spawned
    EnsureDemonHunterSoulBar()

    -- Initial update
    self:UpdatePrimaryBar()
    self:UpdateSecondaryBar()
end

-- Initialize when module loads
-- Use event frame to initialize after PLAYER_LOGIN to ensure QUICore is ready
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Delay initialization to ensure DB is ready
        C_Timer.After(0.5, function()
            QUI_ResourceBars:Initialize()
        end)
    end
end)

return QUI_ResourceBars
