--[[
    QUI Custom Trackers
    User-configurable icon bars for tracking spells, items, trinkets, consumables
    Drag-and-drop spell/item input
]]

local ADDON_NAME, ns = ...

if not ns.ShouldLoadModule("customtrackers", { name = "Custom Trackers", enabled = true }) then
    return
end

local QUI = QuaziiUI  -- Use global addon table, not ns.Addon (which is QUICore)
local LSM = LibStub("LibSharedMedia-3.0")
local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)  -- For active state glow

---------------------------------------------------------------------------
-- MODULE NAMESPACE
---------------------------------------------------------------------------
local CustomTrackers = {}
CustomTrackers.activeBars = {}   -- Runtime bar frames indexed by barID
CustomTrackers.infoCache = {}    -- Cached spell/item info

-- Will be set during initialization when QUICore is available
local QUICore

---------------------------------------------------------------------------
-- CONSTANTS
---------------------------------------------------------------------------
local ASPECT_RATIOS = {
    square = { w = 1, h = 1 },
    flat = { w = 4, h = 3 },
}

-- Migrate old 'shape' setting to 'aspectRatioCrop' for custom tracker bars
local function MigrateBarAspect(config)
    if config and config.aspectRatioCrop == nil and config.shape then
        if config.shape == "flat" then
            config.aspectRatioCrop = 1.33  -- 4:3 aspect ratio
        else
            config.aspectRatioCrop = 1.0   -- square
        end
    end
    return config.aspectRatioCrop or 1.0
end

local BASE_CROP = 0.08  -- Standard WoW icon crop

-- Housing instance types - excluded from "Show in Instance" detection
local HOUSING_INSTANCE_TYPES = {
    ["neighborhood"] = true,  -- Founder's Point, Razorwind Shores
    ["interior"] = true,      -- Inside player houses
}

-- Helper: Check if player is in an instance (excludes housing zones)
local function IsPlayerInInstance()
    local _, instanceType = GetInstanceInfo()
    if instanceType == "none" or instanceType == nil then
        return false
    end
    if HOUSING_INSTANCE_TYPES[instanceType] then
        return false
    end
    return true
end

---------------------------------------------------------------------------
-- LAYOUT MANAGER REGISTRATION
---------------------------------------------------------------------------
local function RegisterBarWithLayoutManager(bar)
    if not bar or not bar.config then return end
    local config = bar.config
    local QUI_LayoutManager = ns.QUI_LayoutManager
    
    if not QUI_LayoutManager then
        -- Fallback: If LayoutManager is not available, use basic center point
        bar:SetParent(UIParent)
        bar:ClearAllPoints()
        bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        return
    end
    
    -- Unregister first in case anchor settings changed
    QUI_LayoutManager:UnregisterFrame(bar)
    
    -- Register with LayoutManager - handles all anchor types including "none", "player", "target", etc.
    local trackerFrameKey = "customTrackers." .. (config.id or "default")
    QUI_LayoutManager:RegisterFrame(bar, trackerFrameKey, "customTrackers", {
        parentFrame = UIParent,
        editMode = {
            label = config.name or "Custom Tracker",
            elementKey = config.id or "default",
            skipKeyboardEnable = false,
            elementType = "customTracker",
        },
    })
end

---------------------------------------------------------------------------
-- DATABASE ACCESS
---------------------------------------------------------------------------
local function GetDB()
    if QUICore and QUICore.db and QUICore.db.profile and QUICore.db.profile.customTrackers then
        return QUICore.db.profile.customTrackers
    end
    return nil
end

---------------------------------------------------------------------------
-- FONT HELPERS (matches NCDM pattern)
---------------------------------------------------------------------------
local function GetGeneralFont()
    if QUICore and QUICore.db and QUICore.db.profile and QUICore.db.profile.general then
        local general = QUICore.db.profile.general
        local fontName = general.font or "Friz Quadrata TT"
        return LSM:Fetch("font", fontName) or "Fonts\\FRIZQT__.TTF"
    end
    return "Fonts\\FRIZQT__.TTF"
end

local function GetGeneralFontOutline()
    if QUICore and QUICore.db and QUICore.db.profile and QUICore.db.profile.general then
        return QUICore.db.profile.general.fontOutline or "OUTLINE"
    end
    return "OUTLINE"
end

---------------------------------------------------------------------------
-- INFO CACHE (prevents repeated API calls)
---------------------------------------------------------------------------
local function GetCachedSpellInfo(spellID)
    if not spellID then return nil end
    local cacheKey = "spell_" .. spellID
    if CustomTrackers.infoCache[cacheKey] then
        return CustomTrackers.infoCache[cacheKey]
    end
    local info = C_Spell.GetSpellInfo(spellID)
    if info then
        CustomTrackers.infoCache[cacheKey] = {
            name = info.name,
            icon = info.iconID,
            id = spellID,
            type = "spell",
        }
        return CustomTrackers.infoCache[cacheKey]
    end
    return nil
end

local function GetCachedItemInfo(itemID)
    if not itemID then return nil end
    local cacheKey = "item_" .. itemID
    if CustomTrackers.infoCache[cacheKey] then
        return CustomTrackers.infoCache[cacheKey]
    end
    local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
    if name then
        CustomTrackers.infoCache[cacheKey] = {
            name = name,
            icon = icon,
            id = itemID,
            type = "item",
        }
        return CustomTrackers.infoCache[cacheKey]
    end
    -- Item not cached yet, request it
    C_Item.RequestLoadItemDataByID(itemID)
    return nil
end

---------------------------------------------------------------------------
-- COOLDOWN INFO HELPERS
---------------------------------------------------------------------------
local function GetSpellCooldownInfo(spellID)
    if not spellID then return 0, 0, false, nil end
    local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
    if cooldownInfo then
        return cooldownInfo.startTime, cooldownInfo.duration, cooldownInfo.isEnabled, cooldownInfo.isOnGCD
    end
    return 0, 0, true, nil
end

local function GetItemCooldownInfo(itemID)
    if not itemID then return 0, 0, false end
    local startTime, duration, enable = C_Item.GetItemCooldown(itemID)
    return startTime or 0, duration or 0, enable ~= 0
end

local function GetItemStackCount(itemID)
    if not itemID then return 0 end
    return C_Item.GetItemCount(itemID, false, false, true) or 0
end

local function GetSpellChargeCount(spellID)
    if not spellID then return 0, 1 end
    local chargeInfo = C_Spell.GetSpellCharges(spellID)
    if not chargeInfo or not chargeInfo.maxCharges then
        return 0, 1  -- Not a charge-based spell
    end

    -- Handle secret values (protected in combat)
    -- If maxCharges is secret, spell definitely has charges - use safe default
    if issecretvalue and issecretvalue(chargeInfo.maxCharges) then
        return chargeInfo.currentCharges, 2  -- Return secret currentCharges, SetText handles it
    end

    -- Normal case: safe to compare
    if chargeInfo.maxCharges > 1 then
        return chargeInfo.currentCharges or 0, chargeInfo.maxCharges
    end
    return 0, 1  -- Single charge spell (not multi-charge)
end

-- Check if item is equipment (armor/weapon) vs consumable
local function IsEquipmentItem(itemID)
    local classID = select(6, C_Item.GetItemInfoInstant(itemID))
    if not classID then return false end
    return classID == Enum.ItemClass.Armor or classID == Enum.ItemClass.Weapon
end

-- Check if item is usable
-- Equipment: must be equipped (ignore bag count)
-- Consumables: must have count > 0
local function IsItemUsable(itemID, itemCount)
    if IsEquipmentItem(itemID) then
        -- Equipment: ONLY check if equipped, bag count irrelevant
        return C_Item.IsEquippedItem(itemID)
    else
        -- Consumables: check stack count
        return itemCount and itemCount > 0
    end
end

-- Check if spell is known and usable
local function IsSpellUsable(spellID)
    -- Check if spell exists
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if not spellInfo then return false end

    -- Check if known (handles talent overrides)
    if IsSpellKnownOrOverridesKnown then
        return IsSpellKnownOrOverridesKnown(spellID)
    elseif IsPlayerSpell then
        return IsPlayerSpell(spellID)
    end

    return IsSpellKnown(spellID)
end

---------------------------------------------------------------------------
-- ACTIVE STATE DETECTION (casting/channeling/buff active)
---------------------------------------------------------------------------

-- Check if player is currently casting a specific spell
-- Returns: isActive, startTimeMS, endTimeMS (or nil if not casting)
local function GetSpellCastInfo(spellID)
    if not spellID then return false end
    local _, _, _, startTimeMS, endTimeMS, _, _, _, castSpellID = UnitCastingInfo("player")
    if castSpellID and castSpellID == spellID then
        return true, startTimeMS, endTimeMS
    end
    return false
end

-- Check if player is currently channeling a specific spell
-- Returns: isActive, startTimeMS, endTimeMS (or nil if not channeling)
local function GetSpellChannelInfo(spellID)
    if not spellID then return false end
    local _, _, _, startTimeMS, endTimeMS, _, _, _, channelSpellID = UnitChannelInfo("player")
    if channelSpellID and channelSpellID == spellID then
        return true, startTimeMS, endTimeMS
    end
    return false
end

-- Check if player has a buff with a specific spell ID
-- Returns: isActive, expirationTime, duration (or nil if no buff)
local function GetSpellBuffInfo(spellID)
    if not spellID then return false end
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local auraData = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if auraData then
            return true, auraData.expirationTime, auraData.duration
        end
    end
    return false
end

-- Check if a spell is currently "active" (casting, channeling, or buff present)
-- Returns: isActive, startTime (seconds), duration (seconds), activeType
local function GetSpellActiveInfo(spellID)
    if not spellID then return false end

    -- Check casting first (shortest duration typically)
    local isCasting, castStart, castEnd = GetSpellCastInfo(spellID)
    if isCasting and castStart and castEnd then
        local startSec = castStart / 1000
        local durationSec = (castEnd - castStart) / 1000
        return true, startSec, durationSec, "cast"
    end

    -- Check channeling
    local isChanneling, channelStart, channelEnd = GetSpellChannelInfo(spellID)
    if isChanneling and channelStart and channelEnd then
        local startSec = channelStart / 1000
        local durationSec = (channelEnd - channelStart) / 1000
        return true, startSec, durationSec, "channel"
    end

    -- Check buff (longest duration typically)
    local hasBuff, expiration, buffDuration = GetSpellBuffInfo(spellID)
    if hasBuff and expiration and buffDuration then
        local startSec = expiration - buffDuration
        return true, startSec, buffDuration, "buff"
    end

    return false
end

-- Check if an item's buff is active
local function GetItemActiveInfo(itemID)
    if not itemID then return false end
    local itemSpellID = select(2, C_Item.GetItemSpell(itemID))
    if itemSpellID then
        return GetSpellActiveInfo(itemSpellID)
    end
    return false
end

---------------------------------------------------------------------------
-- ACTIVE STATE GLOW (using LibCustomGlow)
---------------------------------------------------------------------------

-- Start active glow on an icon (supports multiple glow types)
local function StartActiveGlow(icon, config)
    if not icon or not LCG then return end
    if icon._activeGlowShown then return end

    if config and config.activeGlowEnabled == false then return end

    local glowType = (config and config.activeGlowType) or "Button Glow"
    local color = (config and config.activeGlowColor) or { 1, 0.85, 0.3, 1 }
    local lines = (config and config.activeGlowLines) or 8
    local frequency = (config and config.activeGlowFrequency) or 0.25
    local thickness = (config and config.activeGlowThickness) or 2
    local scale = (config and config.activeGlowScale) or 1.0

    if glowType == "Pixel Glow" then
        LCG.PixelGlow_Start(icon, color, lines, frequency, nil, thickness, 0, 0, true, "_QUIActiveGlow")
    elseif glowType == "Autocast Shine" then
        LCG.AutoCastGlow_Start(icon, color, lines, frequency, scale, 0, 0, "_QUIActiveGlow")
    else
        LCG.ButtonGlow_Start(icon, color, frequency)
    end

    icon._activeGlowShown = true
    icon._activeGlowType = glowType
end

-- Stop active glow on an icon
local function StopActiveGlow(icon)
    if not icon or not LCG then return end
    if not icon._activeGlowShown then return end

    local glowType = icon._activeGlowType or "Button Glow"

    if glowType == "Pixel Glow" then
        pcall(LCG.PixelGlow_Stop, icon, "_QUIActiveGlow")
    elseif glowType == "Autocast Shine" then
        pcall(LCG.AutoCastGlow_Stop, icon, "_QUIActiveGlow")
    else
        pcall(LCG.ButtonGlow_Stop, icon)
    end

    icon._activeGlowShown = nil
    icon._activeGlowType = nil
end

---------------------------------------------------------------------------
-- ICON CREATION
---------------------------------------------------------------------------
local function CreateTrackerIcon(parent)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(36, 36)  -- Default, will be resized

    -- Border (BACKGROUND texture at sublevel -8, combat-safe)
    icon.border = icon:CreateTexture(nil, "BACKGROUND", nil, -8)
    icon.border:SetColorTexture(0, 0, 0, 1)

    -- Icon texture
    icon.tex = icon:CreateTexture(nil, "ARTWORK")
    icon.tex:SetAllPoints()

    -- Cooldown overlay - USE Blizzard's built-in countdown (handles secret values internally)
    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints()
    icon.cooldown:SetDrawSwipe(false)             -- NO swipe animation
    icon.cooldown:SetDrawEdge(false)              -- NO edge glow
    icon.cooldown:SetHideCountdownNumbers(false)  -- Still show countdown numbers!

    -- Duration text (on icon, not cooldown - more control)
    icon.durationText = icon:CreateFontString(nil, "OVERLAY")
    icon.durationText:SetFont(GetGeneralFont(), 14, GetGeneralFontOutline())

    -- Stack text
    icon.stackText = icon:CreateFontString(nil, "OVERLAY")
    icon.stackText:SetFont(GetGeneralFont(), 12, GetGeneralFontOutline())

    -- Keybind text (top-left by default)
    icon.keybindText = icon:CreateFontString(nil, "OVERLAY")
    icon.keybindText:SetFont(GetGeneralFont(), 10, GetGeneralFontOutline())
    icon.keybindText:SetShadowOffset(1, -1)
    icon.keybindText:SetShadowColor(0, 0, 0, 1)
    icon.keybindText:Hide()

    -- Cooldown state persistence (prevents false "ready" states from bad API reads)
    icon.lastKnownCDEnd = 0

    -- Tooltip on mouseover (skip if icon is hidden via alpha for showOnlyOnCooldown mode)
    icon:SetScript("OnEnter", function(self)
        if self:GetAlpha() == 0 then return end  -- Don't show tooltip when visually hidden
        if self.entry then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.entry.type == "spell" then
                GameTooltip:SetSpellByID(self.entry.id)
            elseif self.entry.type == "item" then
                GameTooltip:SetItemByID(self.entry.id)
            end
        end
    end)

    icon:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return icon
end

---------------------------------------------------------------------------
-- ICON STYLING
---------------------------------------------------------------------------
local function StyleTrackerIcon(icon, config)
    if not icon or not config then return end

    -- Calculate size based on aspect ratio
    MigrateBarAspect(config)
    local aspectRatio = config.aspectRatioCrop or 1.0
    local width = config.iconSize or 36
    local height = width / aspectRatio
    icon:SetSize(width, height)

    -- Border
    local bs = config.borderSize or 2
    if bs > 0 then
        icon.border:Show()
        icon.border:ClearAllPoints()
        icon.border:SetPoint("TOPLEFT", -bs, bs)
        icon.border:SetPoint("BOTTOMRIGHT", bs, -bs)
    else
        icon.border:Hide()
    end

    -- TexCoord (zoom + base crop + aspect ratio cropping)
    local zoom = config.zoom or 0
    local aspectRatio = config.aspectRatioCrop or 1.0

    -- Start with base crop + zoom
    local left = BASE_CROP + zoom
    local right = 1 - BASE_CROP - zoom
    local top = BASE_CROP + zoom
    local bottom = 1 - BASE_CROP - zoom

    -- Apply aspect ratio crop ON TOP of existing crop (crops from center)
    if aspectRatio > 1.0 then
        -- Wider/flatter: crop MORE from top/bottom to center the icon
        local cropAmount = 1.0 - (1.0 / aspectRatio)
        local availableHeight = bottom - top
        local offset = (cropAmount * availableHeight) / 2.0
        top = top + offset
        bottom = bottom - offset
    end

    icon.tex:SetTexCoord(left, right, top, bottom)

    -- Duration text style
    local fontPath = GetGeneralFont()
    local fontOutline = GetGeneralFontOutline()

    icon.durationText:SetFont(fontPath, config.durationSize or 14, fontOutline)
    local dColor = config.durationColor or {1, 1, 1, 1}
    icon.durationText:SetTextColor(dColor[1], dColor[2], dColor[3], dColor[4] or 1)
    icon.durationText:ClearAllPoints()
    icon.durationText:SetPoint(
        config.durationAnchor or "CENTER",
        icon,
        config.durationAnchor or "CENTER",
        config.durationOffsetX or 0,
        config.durationOffsetY or 0
    )

    -- ALSO style Blizzard's built-in countdown text for consistency
    -- (Used during combat when secret values prevent custom text display)
    if icon.cooldown then
        local cooldown = icon.cooldown
        if cooldown.text then
            cooldown.text:SetFont(fontPath, config.durationSize or 14, fontOutline)
            cooldown.text:SetTextColor(dColor[1], dColor[2], dColor[3], dColor[4] or 1)
            pcall(function()
                cooldown.text:ClearAllPoints()
                cooldown.text:SetPoint(
                    config.durationAnchor or "CENTER",
                    icon,
                    config.durationAnchor or "CENTER",
                    config.durationOffsetX or 0,
                    config.durationOffsetY or 0
                )
            end)
        end

        -- Also check GetRegions for FontStrings (fallback)
        local ok, regions = pcall(function() return { cooldown:GetRegions() } end)
        if ok and regions then
            for _, region in ipairs(regions) do
                if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                    region:SetFont(fontPath, config.durationSize or 14, fontOutline)
                    region:SetTextColor(dColor[1], dColor[2], dColor[3], dColor[4] or 1)
                    pcall(function()
                        region:ClearAllPoints()
                        region:SetPoint(
                            config.durationAnchor or "CENTER",
                            icon,
                            config.durationAnchor or "CENTER",
                            config.durationOffsetX or 0,
                            config.durationOffsetY or 0
                        )
                    end)
                end
            end
        end
    end

    -- Stack text style
    icon.stackText:SetFont(fontPath, config.stackSize or 12, fontOutline)
    local sColor = config.stackColor or {1, 1, 1, 1}
    icon.stackText:SetTextColor(sColor[1], sColor[2], sColor[3], sColor[4] or 1)
    icon.stackText:ClearAllPoints()
    icon.stackText:SetPoint(
        config.stackAnchor or "BOTTOMRIGHT",
        icon,
        config.stackAnchor or "BOTTOMRIGHT",
        config.stackOffsetX or -2,
        config.stackOffsetY or 2
    )

    -- Keybind text style (uses global settings from customTrackers.keybinds)
    if icon.keybindText then
        local db = QUICore and QUICore.db and QUICore.db.profile
        local keybindSettings = db and db.customTrackers and db.customTrackers.keybinds
        if keybindSettings then
            icon.keybindText:SetFont(fontPath, keybindSettings.keybindTextSize or 10, fontOutline)
            local kColor = keybindSettings.keybindTextColor or {1, 0.82, 0, 1}
            icon.keybindText:SetTextColor(kColor[1], kColor[2], kColor[3], kColor[4] or 1)
            icon.keybindText:ClearAllPoints()
            icon.keybindText:SetPoint("TOPLEFT", icon, "TOPLEFT",
                keybindSettings.keybindOffsetX or 2,
                keybindSettings.keybindOffsetY or -2
            )
        end
    end
end

---------------------------------------------------------------------------
-- KEYBIND DISPLAY FOR TRACKER ICONS
---------------------------------------------------------------------------
local function ApplyKeybindToTrackerIcon(icon)
    if not icon or not icon.entry then return end

    local db = QUICore and QUICore.db and QUICore.db.profile
    local keybindSettings = db and db.customTrackers and db.customTrackers.keybinds

    if not keybindSettings or not keybindSettings.showKeybinds then
        if icon.keybindText then
            icon.keybindText:SetText("")
            icon.keybindText:Hide()
        end
        return
    end

    -- Get keybind based on entry type
    local keybind = nil
    local entry = icon.entry

    -- Access keybind functions from ns namespace (addon namespace, not AceAddon)
    local QUIKeybinds = ns and ns.Keybinds
    if not QUIKeybinds then
        if icon.keybindText then
            icon.keybindText:Hide()
        end
        return
    end

    if entry.type == "spell" and entry.id then
        keybind = QUIKeybinds.GetKeybindForSpell(entry.id)
        -- Try spell name fallback if no keybind found
        if not keybind and QUIKeybinds.GetKeybindForSpellName then
            local spellInfo = C_Spell.GetSpellInfo(entry.id)
            if spellInfo and spellInfo.name then
                keybind = QUIKeybinds.GetKeybindForSpellName(spellInfo.name)
            end
        end
    elseif entry.type == "item" and entry.id then
        keybind = QUIKeybinds.GetKeybindForItem(entry.id)
        -- Try item name fallback if no keybind found
        if not keybind and QUIKeybinds.GetKeybindForItemName then
            local itemName = C_Item.GetItemInfo(entry.id)
            if itemName then
                keybind = QUIKeybinds.GetKeybindForItemName(itemName)
            end
        end
    end

    if not icon.keybindText then return end

    if keybind then
        icon.keybindText:SetText(keybind)
        icon.keybindText:Show()
    else
        icon.keybindText:SetText("")
        icon.keybindText:Hide()
    end
end

---------------------------------------------------------------------------
-- BAR ICON LAYOUT (two-pass pattern)
---------------------------------------------------------------------------
local function LayoutBarIcons(bar)
    if not bar or not bar.icons then return end

    local config = bar.config
    local entries = config.entries or {}
    local growDir = config.growDirection or "RIGHT"
    local spacing = config.spacing or 4

    -- Calculate icon dimensions
    local aspectRatio = config.aspectRatioCrop or 1.0
    local iconWidth = config.iconSize or 36
    local iconHeight = iconWidth / aspectRatio

    -- PASS 1: Clear all points
    for _, icon in ipairs(bar.icons) do
        icon:ClearAllPoints()
    end

    -- PASS 2: Position based on grow direction
    local numIcons = #bar.icons
    for i, icon in ipairs(bar.icons) do
        local offset = (i - 1) * (iconWidth + spacing)

        if growDir == "RIGHT" then
            icon:SetPoint("LEFT", bar, "LEFT", offset, 0)
        elseif growDir == "LEFT" then
            icon:SetPoint("RIGHT", bar, "RIGHT", -offset, 0)
        elseif growDir == "DOWN" then
            offset = (i - 1) * (iconHeight + spacing)
            icon:SetPoint("TOP", bar, "TOP", 0, -offset)
        elseif growDir == "UP" then
            offset = (i - 1) * (iconHeight + spacing)
            icon:SetPoint("BOTTOM", bar, "BOTTOM", 0, offset)
        elseif growDir == "CENTER" then
            -- Center-based positioning: icons spread equally from center
            local totalWidth = (numIcons * iconWidth) + ((numIcons - 1) * spacing)
            local startX = -totalWidth / 2 + iconWidth / 2
            local x = startX + (i - 1) * (iconWidth + spacing)
            icon:SetPoint("CENTER", bar, "CENTER", x, 0)
        end

        icon:Show()
    end

    -- Update bar size to fit icons
    if numIcons == 0 then
        bar:SetSize(1, 1)
        return
    end

    if growDir == "RIGHT" or growDir == "LEFT" or growDir == "CENTER" then
        local totalWidth = (numIcons * iconWidth) + ((numIcons - 1) * spacing)
        bar:SetSize(totalWidth, iconHeight)
    else
        local totalHeight = (numIcons * iconHeight) + ((numIcons - 1) * spacing)
        bar:SetSize(iconWidth, totalHeight)
    end
end

---------------------------------------------------------------------------
-- LAYOUT VISIBLE ICONS (for hideNonUsable mode)
---------------------------------------------------------------------------
local function LayoutVisibleIcons(bar)
    if not bar or not bar.icons then return end

    local config = bar.config
    local growDir = config.growDirection or "RIGHT"
    local spacing = config.spacing or 4

    -- Calculate icon dimensions
    local aspectRatio = config.aspectRatioCrop or 1.0
    local iconWidth = config.iconSize or 36
    local iconHeight = iconWidth / aspectRatio

    -- Collect only visible icons
    local visibleIcons = {}
    for _, icon in ipairs(bar.icons) do
        if icon.isVisible ~= false then
            table.insert(visibleIcons, icon)
        end
    end

    -- PASS 1: Clear all points on ALL icons
    for _, icon in ipairs(bar.icons) do
        icon:ClearAllPoints()
    end

    -- PASS 2: Position only visible icons
    local numIcons = #visibleIcons
    for i, icon in ipairs(visibleIcons) do
        local offset = (i - 1) * (iconWidth + spacing)

        if growDir == "RIGHT" then
            icon:SetPoint("LEFT", bar, "LEFT", offset, 0)
        elseif growDir == "LEFT" then
            icon:SetPoint("RIGHT", bar, "RIGHT", -offset, 0)
        elseif growDir == "DOWN" then
            offset = (i - 1) * (iconHeight + spacing)
            icon:SetPoint("TOP", bar, "TOP", 0, -offset)
        elseif growDir == "UP" then
            offset = (i - 1) * (iconHeight + spacing)
            icon:SetPoint("BOTTOM", bar, "BOTTOM", 0, offset)
        elseif growDir == "CENTER" then
            -- Center-based positioning: icons spread equally from center
            local totalWidth = (numIcons * iconWidth) + ((numIcons - 1) * spacing)
            local startX = -totalWidth / 2 + iconWidth / 2
            local x = startX + (i - 1) * (iconWidth + spacing)
            icon:SetPoint("CENTER", bar, "CENTER", x, 0)
        end
    end

    -- Resize bar to fit only visible icons
    if numIcons == 0 then
        bar:SetSize(1, 1)
        return
    end

    if growDir == "RIGHT" or growDir == "LEFT" or growDir == "CENTER" then
        local totalWidth = (numIcons * iconWidth) + ((numIcons - 1) * spacing)
        bar:SetSize(totalWidth, iconHeight)
    else
        local totalHeight = (numIcons * iconHeight) + ((numIcons - 1) * spacing)
        bar:SetSize(iconWidth, totalHeight)
    end
end

---------------------------------------------------------------------------
-- UPDATE BAR ICONS (recreate icons for entries)
---------------------------------------------------------------------------
function CustomTrackers:UpdateBarIcons(bar)
    if not bar then return end

    local config = bar.config
    local entries = config.entries or {}

    -- Hide and clear existing icons
    for _, icon in ipairs(bar.icons or {}) do
        icon:Hide()
        icon:SetParent(nil)
    end
    bar.icons = {}

    if #entries == 0 then
        bar:SetSize(1, 1)
        if bar.bg then bar.bg:SetAlpha(0) end
        return
    end

    -- Create icons for each entry
    for i, entry in ipairs(entries) do
        local icon = CreateTrackerIcon(bar)
        StyleTrackerIcon(icon, config)

        -- Store entry reference
        icon.entry = entry
        icon.isVisible = true  -- Initialize visibility state for hideNonUsable tracking

        -- Set icon texture
        local info
        if entry.type == "spell" then
            info = GetCachedSpellInfo(entry.id)
        else
            info = GetCachedItemInfo(entry.id)
        end

        if info and info.icon then
            icon.tex:SetTexture(info.icon)
        else
            icon.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        table.insert(bar.icons, icon)
    end

    -- Layout the icons (sets bar size)
    LayoutBarIcons(bar)

    -- If bar is already registered with Layout Manager, recalculate position with new size
    -- This ensures position stays correct when icons are added/removed
    local QUI_LayoutManager = ns.QUI_LayoutManager
    if QUI_LayoutManager and QUI_LayoutManager.frames and QUI_LayoutManager.frames[bar] then
        QUI_LayoutManager:ApplyLayout(bar)
    end

    -- Show background if there are icons
    if bar.bg then
        bar.bg:SetAlpha(config.bgOpacity or 0)
    end
end

---------------------------------------------------------------------------
-- COOLDOWN POLLING
---------------------------------------------------------------------------
local function FormatDuration(seconds)
    if seconds >= 3600 then
        return string.format("%dh", math.floor(seconds / 3600))
    elseif seconds >= 60 then
        return string.format("%dm", math.floor(seconds / 60))
    elseif seconds >= 10 then
        return string.format("%d", math.floor(seconds))
    elseif seconds > 0 then
        return string.format("%.1f", seconds)
    end
    return ""
end

function CustomTrackers:StartCooldownPolling(bar)
    if not bar then return end

    if bar.ticker then
        bar.ticker:Cancel()
    end

    -- Create update function that can be called from both ticker and events
    bar.DoUpdate = function()
        if not bar:IsShown() then return end

        local config = bar.config
        local hideNonUsable = config.hideNonUsable
        local showOnlyOnCooldown = config.showOnlyOnCooldown
        local showActiveState = config.showActiveState
        local visibilityChanged = false

        for _, icon in ipairs(bar.icons or {}) do
            local entry = icon.entry
            if entry and entry.id then
                local startTime, duration, enabled, isOnGCD
                local count = 0
                local maxCharges = 1

                if entry.type == "spell" then
                    startTime, duration, enabled, isOnGCD = GetSpellCooldownInfo(entry.id)
                    count, maxCharges = GetSpellChargeCount(entry.id)
                else
                    startTime, duration, enabled = GetItemCooldownInfo(entry.id)
                    count = GetItemStackCount(entry.id)
                    isOnGCD = false  -- Items don't have GCD
                end

                -- Simplified cooldown handling - let Blizzard's Cooldown frame handle secrets
                local hideGCD = config.hideGCD ~= false

                -- Pass cooldown values directly to Blizzard's Cooldown frame
                -- The CooldownFrameTemplate handles secret values internally
                local setCDOk = pcall(function()
                    if startTime and duration then
                        icon.cooldown:SetCooldown(startTime, duration)
                    end
                end)

                -- Determine if on cooldown using isOnGCD flag (the reliable way!)
                -- No secret value comparisons needed - isOnGCD is a boolean
                local isOnCD = false
                if setCDOk then
                    if hideGCD and isOnGCD then
                        -- It's just GCD - clear cooldown display, don't desaturate
                        icon.cooldown:Clear()
                    else
                        -- Not GCD (or hideGCD is off) - check if cooldown is visible
                        isOnCD = icon.cooldown:IsVisible()
                    end
                end

                -- Check if spell/item is currently active (casting/channeling/buff)
                local isActive = false
                local activeStartTime, activeDuration, activeType
                if showActiveState then
                    if entry.type == "spell" then
                        isActive, activeStartTime, activeDuration, activeType = GetSpellActiveInfo(entry.id)
                    elseif entry.type == "item" then
                        isActive, activeStartTime, activeDuration, activeType = GetItemActiveInfo(entry.id)
                    end
                end

                -- Determine usability state
                local isUsable = true
                if entry.type == "item" then
                    isUsable = IsItemUsable(entry.id, count)
                elseif entry.type == "spell" then
                    isUsable = IsSpellUsable(entry.id)
                end

                -- Determine if icon should be visible (hideNonUsable mode)
                local shouldBeVisible = isUsable or (not hideNonUsable)

                -- Track visibility state change
                if shouldBeVisible ~= icon.isVisible then
                    visibilityChanged = true
                    icon.isVisible = shouldBeVisible
                    if shouldBeVisible then
                        icon:Show()
                    else
                        icon:Hide()
                    end
                end

                -- Apply visual state only if icon is visible
                if shouldBeVisible then
                    if showOnlyOnCooldown then
                        -- Alpha-based visibility (preserves position)
                        if isActive then
                            -- Active state: saturated + glow + duration display
                            icon:SetAlpha(1)
                            icon.tex:SetDesaturated(false)
                            StartActiveGlow(icon, config)
                            if activeStartTime and activeDuration and activeDuration > 0 then
                                icon.cooldown:SetReverse(true)
                                icon.cooldown:SetCooldown(activeStartTime, activeDuration)
                            end
                        elseif isOnCD then
                            icon:SetAlpha(1)
                            icon.tex:SetDesaturated(true)
                            StopActiveGlow(icon)
                            icon.cooldown:SetReverse(false)
                        else
                            icon:SetAlpha(0)
                            icon.tex:SetDesaturated(false)
                            StopActiveGlow(icon)
                            icon.cooldown:SetReverse(false)
                        end
                    else
                        -- Normal mode
                        icon:SetAlpha(1)
                        if isActive then
                            -- Active state: saturated + glow + duration display
                            icon.tex:SetDesaturated(false)
                            StartActiveGlow(icon, config)
                            if activeStartTime and activeDuration and activeDuration > 0 then
                                icon.cooldown:SetReverse(true)
                                icon.cooldown:SetCooldown(activeStartTime, activeDuration)
                            end
                        elseif not isUsable then
                            -- Not usable but visible (hideNonUsable off): desaturated
                            icon.tex:SetDesaturated(true)
                            icon.cooldown:Clear()
                            StopActiveGlow(icon)
                            icon.cooldown:SetReverse(false)
                        elseif isOnCD then
                            -- On cooldown: desaturate icon
                            icon.tex:SetDesaturated(true)
                            StopActiveGlow(icon)
                            icon.cooldown:SetReverse(false)
                        else
                            -- Ready to use: normal color
                            icon.tex:SetDesaturated(false)
                            StopActiveGlow(icon)
                            icon.cooldown:SetReverse(false)
                        end
                    end
                else
                    -- Icon not visible, stop any active glow
                    StopActiveGlow(icon)
                end

                -- Duration text: Always use Blizzard's built-in countdown
                -- (Styled in StyleTrackerIcon, handles secret values internally)
                icon.durationText:Hide()
                icon.cooldown:SetHideCountdownNumbers(config.hideDurationText == true)

                -- Update stack count (for items and spell charges)
                local showStack = (entry.type == "item") or (entry.type == "spell" and maxCharges > 1)

                if showStack then
                    -- Handle secret values: SetText handles them, but comparisons crash
                    local isSecret = issecretvalue and issecretvalue(count)
                    if isSecret then
                        -- Secret value: pass directly to SetText (it handles secrets)
                        icon.stackText:SetText(count)
                        icon.stackText:SetTextColor(1, 1, 1, 1)
                        if not config.hideStackText then
                            icon.stackText:Show()
                        else
                            icon.stackText:Hide()
                        end
                    elseif count > 1 then
                        icon.stackText:SetText(count)
                        icon.stackText:SetTextColor(1, 1, 1, 1)
                        if not config.hideStackText then
                            icon.stackText:Show()
                        else
                            icon.stackText:Hide()
                        end
                    elseif count == 1 then
                        icon.stackText:SetText("")
                        icon.stackText:Hide()
                    else
                        -- Show 0 in dim color when depleted
                        icon.stackText:SetText("0")
                        icon.stackText:SetTextColor(0.5, 0.5, 0.5, 1)
                        if not config.hideStackText then
                            icon.stackText:Show()
                        else
                            icon.stackText:Hide()
                        end
                    end
                else
                    icon.stackText:Hide()
                end

                -- Apply keybind display
                ApplyKeybindToTrackerIcon(icon)
            end
        end

        -- Relayout if visibility changed (hideNonUsable mode)
        if visibilityChanged then
            LayoutVisibleIcons(bar)
        end
    end

    -- Performance: Use slower fallback ticker (0.5s) since events handle immediate updates
    -- Events (SPELL_UPDATE_COOLDOWN, ACTIONBAR_UPDATE_COOLDOWN) call bar.DoUpdate() directly
    bar.ticker = C_Timer.NewTicker(0.5, bar.DoUpdate)
end

---------------------------------------------------------------------------
-- REFRESH BAR POSITION (called when anchor settings change in options)
---------------------------------------------------------------------------
function CustomTrackers:RefreshBarPosition(barID)
    local bar = self.activeBars[barID]
    if bar then
        RegisterBarWithLayoutManager(bar)
    end
end

---------------------------------------------------------------------------
-- BAR CREATION
---------------------------------------------------------------------------
function CustomTrackers:CreateBar(barID, config)
    if not barID or not config then return nil end

    if self.activeBars[barID] then
        return self.activeBars[barID]
    end

    local bar = CreateFrame("Frame", "QUI_CustomTracker_" .. barID, UIParent, "BackdropTemplate")
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(50)

    -- Store references (needed before Layout Manager registration)
    bar.barID = barID
    bar.config = config

    -- Set default size and position BEFORE layout registration
    -- This ensures Layout Manager can properly restore saved positions
    bar:SetSize(200, 36)  -- Default size (will be updated by LayoutBarIcons)
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    -- Background
    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    local bgColor = config.bgColor or {0, 0, 0, 1}
    bar:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], config.bgOpacity or 0)

    -- Initialize icons array
    bar.icons = {}

    -- Register with Layout Manager BEFORE creating icons
    -- This ensures layout is applied before icons are laid out
    RegisterBarWithLayoutManager(bar)

    -- Ensure layout is applied before creating icons (fixes scaling issue)
    local QUI_LayoutManager = ns.QUI_LayoutManager
    if QUI_LayoutManager then
        QUI_LayoutManager:ApplyLayout(bar)
    end

    -- Create icons for entries (this sets the final bar size)
    self:UpdateBarIcons(bar)

    -- Start cooldown polling
    self:StartCooldownPolling(bar)

    self.activeBars[barID] = bar

    if config.enabled then
        bar:Show()
    else
        bar:Hide()
    end

    return bar
end

---------------------------------------------------------------------------
-- BAR DELETION
---------------------------------------------------------------------------
function CustomTrackers:DeleteBar(barID)
    local bar = self.activeBars[barID]
    if bar then
        if bar.ticker then
            bar.ticker:Cancel()
        end
        -- Hide and clear icons
        for _, icon in ipairs(bar.icons or {}) do
            icon:Hide()
            icon:SetParent(nil)
        end
        bar:Hide()
        bar:SetParent(nil)
        self.activeBars[barID] = nil
    end
end

---------------------------------------------------------------------------
-- UPDATE SINGLE BAR
---------------------------------------------------------------------------
function CustomTrackers:UpdateBar(barID)
    local bar = self.activeBars[barID]
    if not bar then return end

    local db = GetDB()
    if not db or not db.bars then return end

    for _, barConfig in ipairs(db.bars) do
        if barConfig.id == barID then
            bar.config = barConfig

            -- Ensure layout is applied before updating icons (fixes scaling issue)
            local QUI_LayoutManager = ns.QUI_LayoutManager
            if QUI_LayoutManager then
                QUI_LayoutManager:ApplyLayout(bar)
            end

            -- Update background
            local bgColor = barConfig.bgColor or {0, 0, 0, 1}
            bar:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], barConfig.bgOpacity or 0)

            -- Update icons
            self:UpdateBarIcons(bar)

            -- Show/hide
            if barConfig.enabled then
                bar:Show()
            else
                bar:Hide()
            end

            break
        end
    end
end

---------------------------------------------------------------------------
-- REFRESH ALL BARS
---------------------------------------------------------------------------
function CustomTrackers:RefreshAll()
    -- Delete all existing bars
    for barID in pairs(self.activeBars) do
        self:DeleteBar(barID)
    end

    -- Recreate from DB
    local db = GetDB()
    if not db or not db.bars then return end

    for _, barConfig in ipairs(db.bars) do
        if barConfig.id then
            self:CreateBar(barConfig.id, barConfig)
        end
    end
end

---------------------------------------------------------------------------
-- ENTRY MANAGEMENT
---------------------------------------------------------------------------
function CustomTrackers:AddEntry(barID, entryType, entryID)
    local db = GetDB()
    if not db or not db.bars then return false end

    for _, barConfig in ipairs(db.bars) do
        if barConfig.id == barID then
            if not barConfig.entries then barConfig.entries = {} end

            -- Check for duplicates
            for _, entry in ipairs(barConfig.entries) do
                if entry.type == entryType and entry.id == entryID then
                    return false  -- Already exists
                end
            end

            table.insert(barConfig.entries, {
                type = entryType,
                id = entryID,
            })

            -- Refresh the bar
            if self.activeBars[barID] then
                self.activeBars[barID].config = barConfig
                self:UpdateBarIcons(self.activeBars[barID])
            end

            return true
        end
    end
    return false
end

function CustomTrackers:RemoveEntry(barID, entryType, entryID)
    local db = GetDB()
    if not db or not db.bars then return false end

    for _, barConfig in ipairs(db.bars) do
        if barConfig.id == barID then
            if barConfig.entries then
                for i, entry in ipairs(barConfig.entries) do
                    if entry.type == entryType and entry.id == entryID then
                        table.remove(barConfig.entries, i)

                        -- Refresh the bar
                        if self.activeBars[barID] then
                            self.activeBars[barID].config = barConfig
                            self:UpdateBarIcons(self.activeBars[barID])
                        end

                        return true
                    end
                end
            end
        end
    end
    return false
end

function CustomTrackers:MoveEntry(barID, entryIndex, direction)
    local db = GetDB()
    if not db or not db.bars then return false end

    for _, barConfig in ipairs(db.bars) do
        if barConfig.id == barID then
            local entries = barConfig.entries
            if not entries then return false end

            local newIndex = entryIndex + direction
            if newIndex < 1 or newIndex > #entries then return false end

            -- Swap entries
            local entry = table.remove(entries, entryIndex)
            table.insert(entries, newIndex, entry)

            -- Refresh bar display
            if self.activeBars[barID] then
                self.activeBars[barID].config = barConfig
                self:UpdateBarIcons(self.activeBars[barID])
            end
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- GLOBAL REFRESH FUNCTION
---------------------------------------------------------------------------
_G.QuaziiUI_RefreshCustomTrackers = function()
    -- Use local CustomTrackers directly since QUICore might not be set yet
    if CustomTrackers then
        CustomTrackers:RefreshAll()
    end
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
initFrame:RegisterEvent("BAG_UPDATE_DELAYED")
initFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
initFrame:RegisterEvent("SPELL_UPDATE_USABLE")
initFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")  -- Performance: event-driven cooldown updates
initFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")  -- Performance: catches action bar cooldown changes
-- Active state detection events (casting/channeling/buff)
initFrame:RegisterEvent("UNIT_SPELLCAST_START")
initFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
initFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
initFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
initFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
initFrame:RegisterEvent("UNIT_AURA")
initFrame:SetScript("OnEvent", function(self, event, ...)
    -- Event-driven cooldown updates (reduces ticker frequency)
    if event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_COOLDOWN" then
        -- Update all active bars immediately on cooldown change
        for _, bar in pairs(CustomTrackers.activeBars) do
            if bar and bar:IsShown() and bar.DoUpdate then
                bar.DoUpdate()
            end
        end
        return
    end

    -- Active state events (casting/channeling/aura) - only update bars with showActiveState enabled
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_STOP" or
       event == "UNIT_SPELLCAST_SUCCEEDED" or
       event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local unit = ...
        if unit == "player" then
            for _, bar in pairs(CustomTrackers.activeBars) do
                if bar and bar:IsShown() and bar.DoUpdate and bar.config and bar.config.showActiveState then
                    bar.DoUpdate()
                end
            end
        end
        return
    end

    if event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then
            for _, bar in pairs(CustomTrackers.activeBars) do
                if bar and bar:IsShown() and bar.DoUpdate and bar.config and bar.config.showActiveState then
                    bar.DoUpdate()
                end
            end
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        -- Set QUICore reference now that it's available
        QUICore = QUI.QUICore
        if QUICore then
            QUICore.CustomTrackers = CustomTrackers
        end

        C_Timer.After(0.6, function()
            CustomTrackers:RefreshAll()
        end)
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- Item info loaded, refresh bars to update any "?" icons
        local itemID = ...
        if itemID then
            -- Clear cache for this item so it gets re-fetched
            CustomTrackers.infoCache["item_" .. itemID] = nil
            -- Quick refresh of all bars
            for _, bar in pairs(CustomTrackers.activeBars) do
                for _, icon in ipairs(bar.icons or {}) do
                    if icon.entry and icon.entry.type == "item" and icon.entry.id == itemID then
                        local info = GetCachedItemInfo(itemID)
                        if info and info.icon then
                            icon.tex:SetTexture(info.icon)
                        end
                    end
                end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- VISIBILITY SYSTEM
---------------------------------------------------------------------------
local CustomTrackersVisibility = {
    currentlyHidden = false,
    isFading = false,
    fadeStart = 0,
    fadeStartAlpha = 1,
    fadeTargetAlpha = 1,
    fadeFrame = nil,
    mouseOver = false,
    mouseoverDetector = nil,
}

local function GetCustomTrackersVisibilitySettings()
    local db = QUI.QUICore and QUI.QUICore.db
    if not db or not db.profile then return nil end
    return db.profile.customTrackersVisibility
end

local function GetCustomTrackerFrames()
    local frames = {}
    if CustomTrackers and CustomTrackers.activeBars then
        for _, bar in pairs(CustomTrackers.activeBars) do
            -- Only include enabled bars that are shown
            if bar and bar.config and bar.config.enabled and bar:IsShown() then
                table.insert(frames, bar)
            end
        end
    end
    return frames
end

local function ShouldCustomTrackersBeVisible()
    local vis = GetCustomTrackersVisibilitySettings()
    if not vis then return true end

    -- Hide When Mounted overrides all other conditions
    if vis.hideWhenMounted and IsMounted() then return false end

    -- Show Always overrides all conditions
    if vis.showAlways then return true end

    -- OR logic: show if ANY condition is met
    if vis.showWhenTargetExists and UnitExists("target") then return true end
    if vis.showInCombat and UnitAffectingCombat("player") then return true end
    if vis.showInGroup and IsInGroup() then return true end
    if vis.showInInstance and IsPlayerInInstance() then return true end
    if vis.showOnMouseover and CustomTrackersVisibility.mouseOver then return true end

    return false
end

local function OnCustomTrackersFadeUpdate(self, elapsed)
    local now = GetTime()
    local vis = GetCustomTrackersVisibilitySettings()
    local duration = vis and vis.fadeDuration or 0.2

    local progress = (now - CustomTrackersVisibility.fadeStart) / duration
    if progress >= 1 then
        progress = 1
        CustomTrackersVisibility.isFading = false
        self:SetScript("OnUpdate", nil)
    end

    local alpha = CustomTrackersVisibility.fadeStartAlpha +
        (CustomTrackersVisibility.fadeTargetAlpha - CustomTrackersVisibility.fadeStartAlpha) * progress

    local frames = GetCustomTrackerFrames()
    for _, frame in ipairs(frames) do
        frame:SetAlpha(alpha)
    end
end

local function StartCustomTrackersFade(targetAlpha)
    local frames = GetCustomTrackerFrames()
    if #frames == 0 then return end

    local currentAlpha = frames[1]:GetAlpha()

    -- Skip if already at target
    if math.abs(currentAlpha - targetAlpha) < 0.01 and not CustomTrackersVisibility.isFading then
        return
    end

    CustomTrackersVisibility.fadeStart = GetTime()
    CustomTrackersVisibility.fadeStartAlpha = currentAlpha
    CustomTrackersVisibility.fadeTargetAlpha = targetAlpha
    CustomTrackersVisibility.isFading = true

    if not CustomTrackersVisibility.fadeFrame then
        CustomTrackersVisibility.fadeFrame = CreateFrame("Frame")
    end
    CustomTrackersVisibility.fadeFrame:SetScript("OnUpdate", OnCustomTrackersFadeUpdate)
end

local function UpdateCustomTrackersVisibility()
    local vis = GetCustomTrackersVisibilitySettings()
    if not vis then return end

    local shouldShow = ShouldCustomTrackersBeVisible()

    if shouldShow then
        StartCustomTrackersFade(1)
        CustomTrackersVisibility.currentlyHidden = false
    else
        StartCustomTrackersFade(vis.fadeOutAlpha or 0)
        CustomTrackersVisibility.currentlyHidden = true
    end
end

local function SetupCustomTrackersMouseoverDetector()
    local vis = GetCustomTrackersVisibilitySettings()
    if not vis then return end

    -- Clean up existing detector
    if CustomTrackersVisibility.mouseoverDetector then
        CustomTrackersVisibility.mouseoverDetector:SetScript("OnUpdate", nil)
        CustomTrackersVisibility.mouseoverDetector:Hide()
        CustomTrackersVisibility.mouseoverDetector = nil
    end

    -- Only create detector if mouseover is enabled and showAlways is disabled
    if not vis.showOnMouseover or vis.showAlways then
        return
    end

    local detector = CreateFrame("Frame")
    local lastCheck = 0
    detector:SetScript("OnUpdate", function(self, elapsed)
        -- Skip during combat for CPU efficiency
        if InCombatLockdown() then return end

        lastCheck = lastCheck + elapsed
        if lastCheck < 0.066 then return end  -- 66ms (~15 FPS) for CPU efficiency
        lastCheck = 0

        local wasOver = CustomTrackersVisibility.mouseOver
        local isOver = false

        local frames = GetCustomTrackerFrames()
        for _, frame in ipairs(frames) do
            if frame:IsMouseOver() then
                isOver = true
                break
            end
        end

        if isOver ~= wasOver then
            CustomTrackersVisibility.mouseOver = isOver
            UpdateCustomTrackersVisibility()
        end
    end)
    detector:Show()
    CustomTrackersVisibility.mouseoverDetector = detector
end

---------------------------------------------------------------------------
-- VISIBILITY EVENT HANDLING
---------------------------------------------------------------------------
local visibilityEventFrame = CreateFrame("Frame")
visibilityEventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
visibilityEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
visibilityEventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
visibilityEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
visibilityEventFrame:RegisterEvent("GROUP_JOINED")
visibilityEventFrame:RegisterEvent("GROUP_LEFT")
visibilityEventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
visibilityEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
visibilityEventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
visibilityEventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.5, function()
            SetupCustomTrackersMouseoverDetector()
            UpdateCustomTrackersVisibility()
        end)
    else
        UpdateCustomTrackersVisibility()
    end
end)

---------------------------------------------------------------------------
-- GLOBAL REFRESH FUNCTIONS FOR OPTIONS PANEL
---------------------------------------------------------------------------
_G.QuaziiUI_RefreshCustomTrackersVisibility = UpdateCustomTrackersVisibility
_G.QuaziiUI_RefreshCustomTrackersMouseover = SetupCustomTrackersMouseoverDetector

-- Refresh keybind display on all custom tracker icons
_G.QuaziiUI_RefreshCustomTrackerKeybinds = function()
    for _, bar in pairs(CustomTrackers.activeBars or {}) do
        if bar and bar.icons then
            for _, icon in ipairs(bar.icons) do
                -- Re-style to update font/position
                StyleTrackerIcon(icon, bar.config)
                -- Re-apply keybind
                ApplyKeybindToTrackerIcon(icon)
            end
        end
    end
end
