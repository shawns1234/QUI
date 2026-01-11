---------------------------------------------------------------------------
-- QuaziiUI Crosshair Module
-- A simple screen center crosshair overlay
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local QUI = ns.QUI or {}
ns.QUI = QUI

local crosshairFrame, horizLine, vertLine, horizBorder, vertBorder

-- Separate frame for range checking (always visible so OnUpdate runs even when crosshair is hidden)
local rangeCheckFrame

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
-- Hybrid implementation: uses class-specific melee spells for accuracy,
-- falls back to 5-yard item check for casters
---------------------------------------------------------------------------

-- Get player class once at load time
local _, playerClass = UnitClass("player")

-- Melee spell IDs by class and spec (for hitbox-accurate range detection)
-- Multiple fallbacks per spec to handle talent variations
-- Spec IDs: use GetSpecializationInfo(GetSpecialization()) to get current spec
local MELEE_SPELLS_BY_SPEC = {
    -- WARRIOR (Arms=71, Fury=72, Protection=73)
    [71]  = { 12294, 772 },       -- Arms: Mortal Strike, Rend
    [72]  = { 23881, 184367 },    -- Fury: Bloodthirst, Rampage
    [73]  = { 23922, 6572 },      -- Protection: Shield Slam, Revenge
    
    -- PALADIN (Holy=65, Protection=66, Retribution=70)
    [65]  = { 35395 },            -- Holy: Crusader Strike (if talented)
    [66]  = { 53600, 31935 },     -- Protection: Shield of the Righteous, Avenger's Shield
    [70]  = { 35395, 184575 },    -- Retribution: Crusader Strike, Blade of Justice
    
    -- HUNTER (Beast Mastery=253, Marksmanship=254, Survival=255)
    [253] = { },                  -- BM: ranged, no melee
    [254] = { },                  -- MM: ranged, no melee
    [255] = { 186270, 259387 },   -- Survival: Raptor Strike, Mongoose Bite
    
    -- ROGUE (Assassination=259, Outlaw=260, Subtlety=261)
    [259] = { 1329, 5374 },       -- Assassination: Mutilate, Mutilate (off-hand)
    [260] = { 193315, 315341 },   -- Outlaw: Sinister Strike, Between the Eyes
    [261] = { 185438, 53 },       -- Subtlety: Shadowstrike, Backstab
    
    -- PRIEST (Discipline=256, Holy=257, Shadow=258) - all ranged
    [256] = { },
    [257] = { },
    [258] = { },
    
    -- DEATH KNIGHT (Blood=250, Frost=251, Unholy=252)
    [250] = { 49998, 206930 },    -- Blood: Death Strike, Heart Strike
    [251] = { 49143, 49998 },     -- Frost: Frost Strike, Death Strike
    [252] = { 55090, 49998 },     -- Unholy: Scourge Strike, Death Strike
    
    -- SHAMAN (Elemental=262, Enhancement=263, Restoration=264)
    [262] = { },                  -- Elemental: ranged
    [263] = { 17364, 60103 },     -- Enhancement: Stormstrike, Lava Lash
    [264] = { },                  -- Restoration: ranged healer
    
    -- MAGE (Arcane=62, Fire=63, Frost=64) - all ranged
    [62]  = { },
    [63]  = { },
    [64]  = { },
    
    -- WARLOCK (Affliction=265, Demonology=266, Destruction=267) - all ranged
    [265] = { },
    [266] = { },
    [267] = { },
    
    -- MONK (Brewmaster=268, Mistweaver=270, Windwalker=269)
    [268] = { 100780 },   -- Brewmaster: Tiger Palm
    [269] = { 100780, 107428 },   -- Windwalker: Tiger Palm, Rising Sun Kick
    [270] = { 100780 },           -- Mistweaver: Tiger Palm
    
    -- DRUID (Balance=102, Feral=103, Guardian=104, Restoration=105)
    [102] = { },                  -- Balance: ranged
    [103] = { 5221, 1822 },       -- Feral: Shred, Rake
    [104] = { 33917, 6807 },      -- Guardian: Mangle, Maul
    [105] = { },                  -- Restoration: ranged healer
    
    -- DEMON HUNTER (Havoc=577, Vengeance=581)
    [577] = { 162794 },   -- Havoc: Chaos Strike
    [581] = { 228478 },   -- Vengeance: Soul Cleave
    
    -- EVOKER (Devastation=1467, Preservation=1468, Augmentation=1473) - all ranged/mid-range
    [1467] = { },
    [1468] = { },
    [1473] = { },
}

-- Class-level fallback spells (used if spec detection fails or no spec spells available)
local MELEE_SPELLS_CLASS_FALLBACK = {
    WARRIOR = { 6552 },           -- Pummel (interrupt, all specs have it)
    PALADIN = { 35395 },          -- Crusader Strike
    ROGUE = { 1966 },             -- Feint (all specs)
    DRUID = { 5176 },             -- Wrath (ranged fallback)
    DEATHKNIGHT = { 49998 },      -- Death Strike (all specs)
    MONK = { 100780 },            -- Tiger Palm (all specs)
    SHAMAN = { 188389 },          -- Flame Shock (ranged fallback)
    HUNTER = { },                 -- Most hunters are ranged
    DEMONHUNTER = { 162243 },     -- Demon's Bite (baseline)
    EVOKER = { },                 -- All ranged
    PRIEST = { },                 -- All ranged
    MAGE = { },                   -- All ranged
    WARLOCK = { },                -- All ranged
}

-- Get the current spec's melee spells with fallback
local function GetMeleeSpellsForCurrentSpec()
    local specIndex = GetSpecialization and GetSpecialization()
    if specIndex then
        local specID = GetSpecializationInfo and GetSpecializationInfo(specIndex)
        if specID and MELEE_SPELLS_BY_SPEC[specID] then
            local spells = MELEE_SPELLS_BY_SPEC[specID]
            if #spells > 0 then
                return spells
            end
        end
    end
    -- Fallback to class-level spells
    return MELEE_SPELLS_CLASS_FALLBACK[playerClass] or {}
end

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
    
    -- Try spec-specific melee spells (most accurate with hitbox)
    local meleeSpells = GetMeleeSpellsForCurrentSpec()
    if C_Spell and C_Spell.IsSpellInRange then
        for _, spellID in ipairs(meleeSpells) do
            -- Check if spell is known before using it
            local spellKnown = IsSpellKnown and IsSpellKnown(spellID)
            if spellKnown then
                local inRange = C_Spell.IsSpellInRange(spellID, "target")
                if inRange == true or inRange == 1 then
                    return false  -- In range
                elseif inRange == false or inRange == 0 then
                    return true   -- Out of range
                end
                -- nil = try next spell
            end
        end
    end
    
    -- Fallback: CheckInteractDistance index 3 (~10ish yards, closer to melee range)
    local inRange = CheckInteractDistance("target", 3)
    if inRange ~= nil then
        return not inRange
    end
    
    -- Last resort: index 2 (~11ish yards)
    inRange = CheckInteractDistance("target", 2)
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
    
    local inCombat = InCombatLockdown()
    
    -- Check if we should only track range in combat
    if settings.rangeColorInCombatOnly and not inCombat then
        -- Not in combat and combat-only is enabled, use normal color
        if isOutOfRange then
            isOutOfRange = false
            ApplyCrosshairColor(settings, false)
        end
        -- If hideUntilOutOfRange, hide the crosshair when not in combat
        if settings.hideUntilOutOfRange and crosshairFrame then
            crosshairFrame:Hide()
        end
        return
    end
    
    local newOutOfRange = IsOutOfMeleeRange()
    if newOutOfRange ~= isOutOfRange then
        isOutOfRange = newOutOfRange
        ApplyCrosshairColor(settings, isOutOfRange)
    end
    
    -- Handle hideUntilOutOfRange visibility
    if settings.hideUntilOutOfRange and crosshairFrame then
        if inCombat and isOutOfRange then
            crosshairFrame:Show()
        else
            crosshairFrame:Hide()
        end
    end
end

---------------------------------------------------------------------------
-- Start or stop range checking based on settings
---------------------------------------------------------------------------
local function UpdateRangeChecking()
    if not crosshairFrame then return end
    
    -- Create the range check frame if needed (separate frame so OnUpdate runs even when crosshair is hidden)
    if not rangeCheckFrame then
        rangeCheckFrame = CreateFrame("Frame", "QuaziiUI_CrosshairRangeCheck", UIParent)
        rangeCheckFrame:SetSize(1, 1)
        rangeCheckFrame:SetPoint("CENTER")
        rangeCheckFrame:Show()  -- Always visible
    end
    
    local settings = GetSettings()
    if settings and settings.enabled and settings.changeColorOnRange then
        -- Enable range checking on the always-visible frame
        rangeCheckElapsed = 0
        rangeCheckFrame:SetScript("OnUpdate", OnRangeUpdate)
        
        local inCombat = InCombatLockdown()
        
        -- Immediately check range (respecting combat-only setting)
        if settings.rangeColorInCombatOnly and not inCombat then
            isOutOfRange = false
            ApplyCrosshairColor(settings, false)
        else
            isOutOfRange = IsOutOfMeleeRange()
            ApplyCrosshairColor(settings, isOutOfRange)
        end
        
        -- Handle hideUntilOutOfRange initial visibility
        if settings.hideUntilOutOfRange then
            if inCombat and isOutOfRange then
                crosshairFrame:Show()
            else
                crosshairFrame:Hide()
            end
        end
    else
        -- Disable range checking
        if rangeCheckFrame then
            rangeCheckFrame:SetScript("OnUpdate", nil)
        end
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

