local addonName, ns = ...

---------------------------------------------------------------------------
-- READY CHECK CONSUMABLE DISPLAY
-- Shows consumable status buttons above ReadyCheckFrame during ready checks
---------------------------------------------------------------------------

-- LibCustomGlow for highlight effect on missing buffs
local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

local DEFAULT_BUTTON_SIZE = 40
local BUTTON_SPACING = 0  -- Seamless icon layout
local STATUS_ICON_SIZE = 18

-- Consumable spell IDs for The War Within (Season 3)
local FOOD_BUFFS = {
    -- TWW Food (Well Fed buffs)
    [462210] = true, [462212] = true, [462213] = true, [462214] = true,  -- Primary stats
    [462215] = true, [462216] = true, [462217] = true, [462218] = true,  -- Secondary stats
    [462270] = true, [462271] = true, [462272] = true, [462273] = true,  -- Dual stats
    -- Dragonflight food (still valid)
    [382145] = true, [382146] = true, [382149] = true, [382150] = true,
    [382152] = true, [382153] = true, [382154] = true, [382155] = true,
    [382156] = true, [382157] = true, [382246] = true, [382247] = true,
    [396092] = true,
}

local FLASK_BUFFS = {
    -- Midnight Flasks
    [1235057] = true, [1235108] = true, [1235110] = true, [1235111] = true,
    -- TWW Flasks
    [432021] = true, [432473] = true, [431971] = true, [431972] = true,
    [431973] = true, [431974] = true,
    -- Dragonflight Flasks
    [371339] = true, [374000] = true, [371354] = true, [371204] = true,
    [370662] = true, [373257] = true, [371386] = true, [370652] = true,
    [371172] = true, [371186] = true,
}

local RUNE_BUFFS = {
    -- Augment Runes
    [453250] = true,   -- Crystallized Augment Rune (TWW)
    [393438] = true,   -- Draconic Augment Rune (DF)
    [367405] = true,   -- Eternal Augment Rune
    [347901] = true,   -- Veiled Augment Rune
    [270058] = true,   -- Battle-Scarred Augment Rune
    [317065] = true,   -- Lightless Force (SL)
    [1234969] = true,  -- Midnight Augment Rune
    [1242347] = true,  -- Greater Midnight Augment Rune
}


-- Flask item IDs for inventory check
local FLASK_ITEMS = {
    241320, 241322, 241324, 241326,  -- Midnight Flasks
    212283, 212284, 212285, 212286, 212287, 212288,  -- TWW Flasks
    191318, 191319, 191320, 191321, 191322, 191323, 191324, 191325, 191326, 191327,  -- DF Flasks
}

-- Rune item IDs
local RUNE_ITEMS = {
    224572,  -- Crystallized Augment Rune (TWW)
    201325,  -- Draconic Augment Rune (DF)
    190384,  -- Eternal Augment Rune
}

-- Weapon oil item IDs
local OIL_ITEMS = {
    -- TWW Oils
    222502, 222503, 222504,  -- Oil of Beledar's Grace
    222508, 222509, 222510,  -- Bubbling Wax
    222888, 222889, 222890, 222891, 222892, 222893, 222894, 222895, 222896,  -- Algari Mana Oil
    -- TWW Stones
    219906, 219907, 219908,
    219909, 219910, 219911,
    219912, 219913, 219914,
    224105, 224106, 224107,
    224108, 224109, 224110,
    224111, 224112, 224113,
    -- DF Oils
    191933, 191939, 191940,
    191943, 191944, 191945,
    191948, 191949, 191950,
}

-- Weapon enchant icon mapping
local WEAPON_ENCHANTS = {
    -- TWW Oils/Stones (7xxx enchant IDs)
    [7550] = { icon = 3622199 },
    [7551] = { icon = 3622199 },
    [7549] = { icon = 3622199 },
    [7531] = { icon = 4549251 },  -- Algari Mana Oil
    [7532] = { icon = 4549251 },
    [7533] = { icon = 4549251 },
    [7534] = { icon = 4549251 },
    [7535] = { icon = 4549251 },
    [7536] = { icon = 4549251 },
    [7537] = { icon = 4549251 },
    [7529] = { icon = 4549251 },
    [7530] = { icon = 4549251 },
    [7543] = { icon = 3622195 },  -- Oil of Beledar's Grace
    [7544] = { icon = 3622195 },
    [7545] = { icon = 3622195 },
    [7601] = { icon = 5975854 },  -- Stones
    [7600] = { icon = 5975854 },
    [7599] = { icon = 5975854 },
    [7598] = { icon = 5975933 },
    [7597] = { icon = 5975933 },
    [7596] = { icon = 5975933 },
    [7595] = { icon = 5975753 },
    [7594] = { icon = 5975753 },
    [7593] = { icon = 5975753 },
    [7500] = { icon = 609896 },
    [7501] = { icon = 609896 },
    [7502] = { icon = 609896 },
    [7498] = { icon = 609897 },
    [7497] = { icon = 609897 },
    [7496] = { icon = 609897 },
    [7495] = { icon = 609892 },
    [7494] = { icon = 609892 },
    [7493] = { icon = 609892 },
    -- DF Oils (6xxx enchant IDs)
    [6381] = { icon = 4622275 },
    [6380] = { icon = 4622275 },
    [6379] = { icon = 4622275 },
    [6698] = { icon = 4622279 },
    [6697] = { icon = 4622279 },
    [6696] = { icon = 4622279 },
    [6384] = { icon = 4622274 },
    [6383] = { icon = 4622274 },
    [6382] = { icon = 4622274 },
}

---------------------------------------------------------------------------
-- UTILITY FUNCTIONS
---------------------------------------------------------------------------

local function GetSettings()
    local QUICore = _G.QuaziiUI and _G.QuaziiUI.QUICore
    if QUICore and QUICore.db and QUICore.db.profile and QUICore.db.profile.general then
        return QUICore.db.profile.general
    end
    return nil
end

-- Get icon size from settings
local function GetButtonSize()
    local settings = GetSettings()
    return (settings and settings.consumableIconSize) or DEFAULT_BUTTON_SIZE
end

-- Get/set last weapon enchant per character (saved in QUI profile)
local function GetLastWeaponEnchant()
    local settings = GetSettings()
    if settings and settings.lastWeaponEnchant then
        return settings.lastWeaponEnchant
    end
    return nil
end

local function SaveLastWeaponEnchant(enchantID, icon)
    local settings = GetSettings()
    if settings then
        settings.lastWeaponEnchant = {
            enchantID = enchantID,
            icon = icon,
        }
    end
end

local function HasWarlockInGroup()
    -- Check if player is a warlock first
    local _, playerClass = UnitClass("player")
    if playerClass == "WARLOCK" then return true end

    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then return false end

    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, numMembers do
        local unit = prefix .. i
        if UnitExists(unit) then
            local _, class = UnitClass(unit)
            if class == "WARLOCK" then
                return true
            end
        end
    end
    return false
end


local function IsDualWielding()
    local mainhand = GetInventoryItemID("player", 16)
    local offhand = GetInventoryItemID("player", 17)
    if not offhand then return false end

    -- Check if offhand is a weapon (not shield/offhand frill)
    local _, _, _, _, _, itemClassID = C_Item.GetItemInfoInstant(offhand)
    return itemClassID == 2  -- LE_ITEM_CLASS_WEAPON
end

local function FormatTimeRemaining(seconds)
    if seconds >= 3600 then
        return string.format("%dh", math.floor(seconds / 3600))
    elseif seconds >= 60 then
        return string.format("%dm", math.floor(seconds / 60))
    else
        return string.format("%ds", math.floor(seconds))
    end
end

-- Scan all player buffs once and return status for all consumable types
-- Returns: { hasFood, hasFlask, hasRune, foodData, flaskData, runeData }
local function ScanPlayerBuffs()
    local result = {
        hasFood = false,
        hasFlask = false,
        hasRune = false,
        foodData = nil,
        flaskData = nil,
        runeData = nil,
    }

    for i = 1, 40 do
        local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not auraData then break end

        -- Check food (by spell ID or icon)
        if not result.hasFood then
            if FOOD_BUFFS[auraData.spellId] or auraData.icon == 136000 then
                result.hasFood = true
                result.foodData = auraData
            end
        end

        -- Check flask
        if not result.hasFlask then
            if FLASK_BUFFS[auraData.spellId] then
                result.hasFlask = true
                result.flaskData = auraData
            end
        end

        -- Check rune
        if not result.hasRune then
            if RUNE_BUFFS[auraData.spellId] then
                result.hasRune = true
                result.runeData = auraData
            end
        end

        -- Early exit if all found
        if result.hasFood and result.hasFlask and result.hasRune then
            break
        end
    end

    return result
end

---------------------------------------------------------------------------
-- CONSUMABLES FRAME
---------------------------------------------------------------------------

local ConsumablesFrame = CreateFrame("Frame", "QUI_ConsumablesFrame", UIParent)
ConsumablesFrame:SetSize(DEFAULT_BUTTON_SIZE * 7 + BUTTON_SPACING * 6, DEFAULT_BUTTON_SIZE)
ConsumablesFrame:Hide()
ConsumablesFrame.buttons = {}

-- Close button - width set dynamically in UpdateConsumables
local closeButton = CreateFrame("Button", nil, ConsumablesFrame)
closeButton:SetSize(DEFAULT_BUTTON_SIZE * 4, 18)  -- Default for 4 icons
closeButton:SetPoint("TOP", ConsumablesFrame, "BOTTOM", 0, 0)

closeButton.bg = closeButton:CreateTexture(nil, "BACKGROUND")
closeButton.bg:SetAllPoints()
closeButton.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)

closeButton.text = closeButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
closeButton.text:SetPoint("CENTER")
closeButton.text:SetText("Close")
closeButton.text:SetTextColor(0.8, 0.8, 0.8, 1)

closeButton:SetScript("OnEnter", function(self)
    self.bg:SetColorTexture(0.25, 0.25, 0.25, 0.9)
    self.text:SetTextColor(1, 1, 1, 1)
end)
closeButton:SetScript("OnLeave", function(self)
    self.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
    self.text:SetTextColor(0.8, 0.8, 0.8, 1)
end)
closeButton:SetScript("OnClick", function()
    ConsumablesFrame:Hide()
end)

ConsumablesFrame.closeButton = closeButton

-- Create individual consumable button
local function CreateConsumableButton(parent, index, buttonType, iconID, isClickable, buttonSize)
    local button = CreateFrame("Frame", nil, parent)
    button:SetSize(buttonSize, buttonSize)
    button.buttonType = buttonType

    -- Icon texture
    button.icon = button:CreateTexture(nil, "BACKGROUND")
    button.icon:SetAllPoints()
    button.icon:SetTexture(iconID)

    -- Status overlay (checkmark or X)
    button.status = button:CreateTexture(nil, "OVERLAY")
    button.status:SetSize(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
    button.status:SetPoint("CENTER")
    button.status:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")

    -- Time remaining text (above icon)
    button.timeText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.timeText:SetPoint("BOTTOM", button, "TOP", 0, 2)
    button.timeText:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    button.timeText:SetTextColor(1, 1, 1, 1)

    -- Item count text (bottom right corner)
    button.countText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.countText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.countText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    button.countText:SetTextColor(1, 1, 1, 1)

    -- Clickable secure button (for using consumables)
    if isClickable then
        button.click = CreateFrame("Button", nil, button, "SecureActionButtonTemplate")
        button.click:SetAllPoints()
        button.click:RegisterForClicks("AnyUp", "AnyDown")
        button.click:Hide()

        -- Hover effect
        button.click:SetScript("OnEnter", function(self)
            button:SetAlpha(0.7)
        end)
        button.click:SetScript("OnLeave", function(self)
            button:SetAlpha(1)
        end)
    end

    return button
end

-- Helper functions for LibCustomGlow
local function StartButtonGlow(button)
    if LCG and button then
        -- Yellow glow effect, 8 lines, 0.25 frequency, 2 thickness
        LCG.PixelGlow_Start(button, {1, 0.8, 0, 1}, 8, 0.25, nil, 2, 0, 0, false, "_QUIConsumable")
    end
end

local function StopButtonGlow(button)
    if LCG and button then
        LCG.PixelGlow_Stop(button, "_QUIConsumable")
    end
end

-- Initialize buttons
local function InitializeButtons()
    local buttons = ConsumablesFrame.buttons
    local buttonSize = GetButtonSize()

    -- Clear any existing buttons first
    for k, button in pairs(buttons) do
        if type(button) == "table" and button.Hide then
            button:Hide()
            button:SetParent(nil)
        end
        buttons[k] = nil
    end

    -- Button definitions: {type, iconID, isClickable}
    local buttonDefs = {
        { "food", 136000, false },           -- Well Fed icon
        { "flask", 3566840, true },          -- Flask icon
        { "oilMH", 609892, true },           -- Algari Mana Oil
        { "rune", 4549102, true },           -- Augment Rune (TWW)
        { "healthstone", 538745, false },    -- Healthstone icon
        { "oilOH", 609892, true },           -- Off-hand oil (same as oilMH)
    }

    for i, def in ipairs(buttonDefs) do
        local button = CreateConsumableButton(ConsumablesFrame, i, def[1], def[2], def[3], buttonSize)
        button:SetPoint("LEFT", ConsumablesFrame, "LEFT", (i - 1) * (buttonSize + BUTTON_SPACING), 0)
        buttons[def[1]] = button
        buttons[i] = button
    end

    -- Store button size for later use
    ConsumablesFrame.buttonSize = buttonSize
end

---------------------------------------------------------------------------
-- UPDATE CONSUMABLE STATUS
---------------------------------------------------------------------------

local function UpdateConsumables()
    local settings = GetSettings()
    if not settings then return end

    local buttons = ConsumablesFrame.buttons
    local now = GetTime()
    local visibleCount = 0

    -- Reset all buttons
    for _, button in pairs(buttons) do
        if type(button) == "table" and button.icon then
            button.status:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
            button.icon:SetDesaturated(true)
            button.timeText:SetText("")
            button.countText:SetText("")
            button:Hide()
            if button.click then
                button.click:Hide()
            end
            -- Stop glow
            StopButtonGlow(button)
        end
    end

    -- Track found buffs
    local hasFood, hasFlask, hasRune = false, false, false
    local foodExpires, flaskExpires, runeExpires = 0, 0, 0

    -- Scan player buffs
    for i = 1, 40 do
        local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not auraData then break end

        local spellId = auraData.spellId
        local expires = auraData.expirationTime
        local icon = auraData.icon

        -- Food check (Well Fed icon = 136000)
        if (settings.consumableFood ~= false) and (FOOD_BUFFS[spellId] or icon == 136000) then
            hasFood = true
            foodExpires = expires
            buttons.food.status:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
            buttons.food.icon:SetDesaturated(false)
            if expires > 0 then
                buttons.food.timeText:SetText(FormatTimeRemaining(expires - now))
            end
        end

        -- Flask check
        if (settings.consumableFlask ~= false) and FLASK_BUFFS[spellId] then
            hasFlask = true
            flaskExpires = expires
            buttons.flask.status:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
            buttons.flask.icon:SetDesaturated(false)
            buttons.flask.icon:SetTexture(icon)  -- Show actual flask buff icon
            if expires > 0 then
                buttons.flask.timeText:SetText(FormatTimeRemaining(expires - now))
            end
        end

        -- Rune check
        if (settings.consumableRune ~= false) and RUNE_BUFFS[spellId] then
            hasRune = true
            runeExpires = expires
            buttons.rune.status:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
            buttons.rune.icon:SetDesaturated(false)
            if expires > 0 then
                buttons.rune.timeText:SetText(FormatTimeRemaining(expires - now))
            end
        end

    end

    -- Weapon enchant check (Main Hand)
    local hasMainHandEnchant, mainHandExpiration, _, mainHandEnchantID = GetWeaponEnchantInfo()
    if settings.consumableOilMH ~= false then
        if hasMainHandEnchant then
            buttons.oilMH.status:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
            buttons.oilMH.icon:SetDesaturated(false)
            -- Update icon to actual enchant icon
            if mainHandEnchantID and WEAPON_ENCHANTS[mainHandEnchantID] then
                local enchantIcon = WEAPON_ENCHANTS[mainHandEnchantID].icon
                buttons.oilMH.icon:SetTexture(enchantIcon)
                -- Remember for next session
                SaveLastWeaponEnchant(mainHandEnchantID, enchantIcon)
            end
            if mainHandExpiration and mainHandExpiration > 0 then
                buttons.oilMH.timeText:SetText(FormatTimeRemaining(mainHandExpiration / 1000))
            end
        else
            -- No active enchant - use remembered icon if available
            local lastEnchant = GetLastWeaponEnchant()
            if lastEnchant and lastEnchant.icon then
                buttons.oilMH.icon:SetTexture(lastEnchant.icon)
            end
        end
    end

    -- Weapon enchant check (Off Hand) - only if dual wielding
    if settings.consumableOilOH ~= false and IsDualWielding() then
        local _, _, _, _, hasOffHandEnchant, offHandExpiration, _, offHandEnchantID = GetWeaponEnchantInfo()
        if hasOffHandEnchant then
            buttons.oilOH.status:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
            buttons.oilOH.icon:SetDesaturated(false)
            -- Update icon to actual enchant icon
            if offHandEnchantID and WEAPON_ENCHANTS[offHandEnchantID] then
                buttons.oilOH.icon:SetTexture(WEAPON_ENCHANTS[offHandEnchantID].icon)
            end
            if offHandExpiration and offHandExpiration > 0 then
                buttons.oilOH.timeText:SetText(FormatTimeRemaining(offHandExpiration / 1000))
            end
        end
    end

    -- Healthstone count check
    if settings.consumableHealthstone ~= false and HasWarlockInGroup() then
        local hsCount = C_Item.GetItemCount(5512, false, true)  -- Healthstone
        local hsLockCount = C_Item.GetItemCount(224464, false, true)  -- Warlock's healthstone (TWW)
        local totalHS = (hsCount or 0) + (hsLockCount or 0)

        if totalHS > 0 then
            buttons.healthstone.status:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
            buttons.healthstone.icon:SetDesaturated(false)
            buttons.healthstone.countText:SetText(tostring(totalHS))
        else
            buttons.healthstone.countText:SetText("0")
        end
    end

    -- Setup clickable flask button if missing buff but have flask
    if not hasFlask and settings.consumableFlask ~= false and not InCombatLockdown() then
        for _, itemID in ipairs(FLASK_ITEMS) do
            local count = C_Item.GetItemCount(itemID, false, false)
            if count and count > 0 then
                local itemName = C_Item.GetItemInfo(itemID)
                if itemName and buttons.flask.click then
                    buttons.flask.click:SetAttribute("type", "macro")
                    buttons.flask.click:SetAttribute("macrotext", "/use " .. itemName)
                    buttons.flask.click:Show()
                    buttons.flask.countText:SetText(tostring(count))
                    -- Set icon to actual flask item icon
                    local texture = select(5, C_Item.GetItemInfoInstant(itemID))
                    if texture then
                        buttons.flask.icon:SetTexture(texture)
                    end
                    -- Highlight missing buff
                    StartButtonGlow(buttons.flask)
                end
                break
            end
        end
    end

    -- Setup clickable rune button if missing buff but have rune
    if not hasRune and settings.consumableRune ~= false and not InCombatLockdown() then
        for _, itemID in ipairs(RUNE_ITEMS) do
            local count = C_Item.GetItemCount(itemID, false, false)
            if count and count > 0 then
                local itemName = C_Item.GetItemInfo(itemID)
                if itemName and buttons.rune.click then
                    buttons.rune.click:SetAttribute("type", "macro")
                    buttons.rune.click:SetAttribute("macrotext", "/use " .. itemName)
                    buttons.rune.click:Show()
                    buttons.rune.countText:SetText(tostring(count))
                    -- Set icon to actual rune item icon
                    local texture = select(5, C_Item.GetItemInfoInstant(itemID))
                    if texture then
                        buttons.rune.icon:SetTexture(texture)
                    end
                    -- Highlight missing buff
                    StartButtonGlow(buttons.rune)
                end
                break
            end
        end
    end

    -- Setup clickable oil button if no enchant but have oils in bags
    if not hasMainHandEnchant and settings.consumableOilMH ~= false and not InCombatLockdown() then
        for _, itemID in ipairs(OIL_ITEMS) do
            local count = C_Item.GetItemCount(itemID, false, false)
            if count and count > 0 then
                local itemName = C_Item.GetItemInfo(itemID)
                if itemName and buttons.oilMH.click then
                    buttons.oilMH.click:SetAttribute("type", "item")
                    buttons.oilMH.click:SetAttribute("item", itemName)
                    buttons.oilMH.click:Show()
                    buttons.oilMH.countText:SetText(tostring(count))
                    -- Set icon to actual oil item icon
                    local texture = select(5, C_Item.GetItemInfoInstant(itemID))
                    if texture then
                        buttons.oilMH.icon:SetTexture(texture)
                    end
                    -- Highlight missing buff
                    StartButtonGlow(buttons.oilMH)
                end
                break
            end
        end
    end

    -- Show/hide and position buttons based on settings
    local xOffset = 0
    local buttonSize = ConsumablesFrame.buttonSize or DEFAULT_BUTTON_SIZE

    if settings.consumableFood ~= false then
        buttons.food:ClearAllPoints()
        buttons.food:SetPoint("LEFT", ConsumablesFrame, "LEFT", xOffset, 0)
        buttons.food:Show()
        xOffset = xOffset + buttonSize + BUTTON_SPACING
        visibleCount = visibleCount + 1
    end

    if settings.consumableFlask ~= false then
        buttons.flask:ClearAllPoints()
        buttons.flask:SetPoint("LEFT", ConsumablesFrame, "LEFT", xOffset, 0)
        buttons.flask:Show()
        xOffset = xOffset + buttonSize + BUTTON_SPACING
        visibleCount = visibleCount + 1
    end

    if settings.consumableOilMH ~= false then
        buttons.oilMH:ClearAllPoints()
        buttons.oilMH:SetPoint("LEFT", ConsumablesFrame, "LEFT", xOffset, 0)
        buttons.oilMH:Show()
        xOffset = xOffset + buttonSize + BUTTON_SPACING
        visibleCount = visibleCount + 1
    end

    if settings.consumableRune ~= false then
        buttons.rune:ClearAllPoints()
        buttons.rune:SetPoint("LEFT", ConsumablesFrame, "LEFT", xOffset, 0)
        buttons.rune:Show()
        xOffset = xOffset + buttonSize + BUTTON_SPACING
        visibleCount = visibleCount + 1
    end

    if settings.consumableHealthstone ~= false and HasWarlockInGroup() then
        buttons.healthstone:ClearAllPoints()
        buttons.healthstone:SetPoint("LEFT", ConsumablesFrame, "LEFT", xOffset, 0)
        buttons.healthstone:Show()
        xOffset = xOffset + buttonSize + BUTTON_SPACING
        visibleCount = visibleCount + 1
    end

    if settings.consumableOilOH ~= false and IsDualWielding() then
        buttons.oilOH:ClearAllPoints()
        buttons.oilOH:SetPoint("LEFT", ConsumablesFrame, "LEFT", xOffset, 0)
        buttons.oilOH:Show()
        xOffset = xOffset + buttonSize + BUTTON_SPACING
        visibleCount = visibleCount + 1
    end

    -- Resize frame and close button to fit visible buttons
    local frameWidth = visibleCount * buttonSize + (visibleCount - 1) * BUTTON_SPACING
    local frameHeight = buttonSize
    ConsumablesFrame:SetSize(frameWidth, frameHeight)
    if ConsumablesFrame.closeButton then
        ConsumablesFrame.closeButton:SetWidth(frameWidth)
    end
end

-- Update consumables when player buffs change (must be after UpdateConsumables is defined)
ConsumablesFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_AURA" and unit == "player" then
        UpdateConsumables()
    end
end)

ConsumablesFrame:SetScript("OnShow", function(self)
    self:RegisterUnitEvent("UNIT_AURA", "player")
end)

ConsumablesFrame:SetScript("OnHide", function(self)
    self:UnregisterEvent("UNIT_AURA")
end)

---------------------------------------------------------------------------
-- POSITIONING
---------------------------------------------------------------------------

local CLOSE_BUTTON_HEIGHT = 18

local function PositionConsumablesFrame()
    ConsumablesFrame:ClearAllPoints()

    -- Get offset from settings (default 5), plus close button height
    local settings = GetSettings()
    local userOffset = (settings and settings.consumableIconOffset) or 5
    local totalOffset = userOffset + CLOSE_BUTTON_HEIGHT + 2  -- +2 for padding

    -- Anchor to ReadyCheckFrame (it exists even if not shown yet)
    if ReadyCheckFrame then
        ConsumablesFrame:SetPoint("BOTTOM", ReadyCheckFrame, "TOP", 0, totalOffset)
        ConsumablesFrame:SetParent(ReadyCheckFrame)
        ConsumablesFrame:SetFrameStrata("DIALOG")
    else
        -- Fallback to center of screen
        ConsumablesFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
        ConsumablesFrame:SetParent(UIParent)
    end
end

---------------------------------------------------------------------------
-- INSTANCE & BUFF CHECK HELPERS
---------------------------------------------------------------------------

-- Check if player is in a dungeon instance
local function IsInDungeonInstance()
    local _, instanceType = IsInInstance()
    return instanceType == "party"
end

-- Check if player is in a raid instance
local function IsInRaidInstance()
    local _, instanceType = IsInInstance()
    return instanceType == "raid"
end

-- Check if player is in any instanced content (dungeon or raid)
local function IsInInstancedContent()
    local inInstance, instanceType = IsInInstance()
    return inInstance and (instanceType == "party" or instanceType == "raid")
end

-- Check if any enabled buffs are missing (returns true if something is missing)
local function HasMissingBuffs()
    local settings = GetSettings()
    if not settings then return false end

    -- Single scan for all buff types
    local buffs = ScanPlayerBuffs()

    -- Check food buff
    if settings.consumableFood ~= false and not buffs.hasFood then
        return true
    end

    -- Check flask buff
    if settings.consumableFlask ~= false and not buffs.hasFlask then
        return true
    end

    -- Check rune buff
    if settings.consumableRune ~= false and not buffs.hasRune then
        return true
    end

    -- Check weapon oils
    local hasMainHandEnchant, _, _, _, hasOffHandEnchant = GetWeaponEnchantInfo()
    if settings.consumableOilMH ~= false and not hasMainHandEnchant then
        return true
    end
    if settings.consumableOilOH ~= false and IsDualWielding() and not hasOffHandEnchant then
        return true
    end

    -- Check healthstones (only if warlock in group)
    if settings.consumableHealthstone ~= false and HasWarlockInGroup() then
        local hsCount = C_Item.GetItemCount(5512, false, true) + C_Item.GetItemCount(224464, false, true)
        if hsCount == 0 then return true end
    end

    return false
end

---------------------------------------------------------------------------
-- EVENT HANDLING
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

-- Show consumables popup standalone (uses saved ReadyCheck position, not parented to ReadyCheckFrame)
local function ShowConsumablesStandalone()
    InitializeButtons()
    UpdateConsumables()

    ConsumablesFrame:ClearAllPoints()
    ConsumablesFrame:SetParent(UIParent)
    ConsumablesFrame:SetFrameStrata("DIALOG")

    -- Get saved ReadyCheck position and offset
    local settings = GetSettings()
    local userOffset = (settings and settings.consumableIconOffset) or 5
    local totalOffset = userOffset + CLOSE_BUTTON_HEIGHT + 2

    local savedPos = settings and settings.readyCheckPosition
    if savedPos then
        -- Position above where ReadyCheckFrame would be
        -- ReadyCheckFrame is ~110px tall, so add half its height (~55) to get to TOP
        -- Then add totalOffset for the spacing above
        local readyCheckHalfHeight = 55
        ConsumablesFrame:SetPoint("BOTTOM", UIParent, savedPos.relativePoint, savedPos.x, savedPos.y + readyCheckHalfHeight + totalOffset)
    else
        -- Default: center of screen, slightly above middle
        ConsumablesFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    end

    ConsumablesFrame:Show()
end

local function OnReadyCheck(starter, timer)
    local settings = GetSettings()
    if not settings or settings.consumableCheckEnabled == false then return end

    -- Check if ready check trigger is enabled
    if settings.consumableOnReadyCheck == false then return end

    -- Don't show if player started the ready check and setting is on
    if settings.consumableDisableForStarter and starter == UnitName("player") then
        return
    end

    PositionConsumablesFrame()
    UpdateConsumables()
    ConsumablesFrame:Show()
end

local function OnReadyCheckFinished()
    ConsumablesFrame:Hide()

    -- Hide clickable buttons
    if not InCombatLockdown() then
        for _, button in pairs(ConsumablesFrame.buttons) do
            if type(button) == "table" and button.click then
                button.click:Hide()
            end
        end
    end
end

local function OnInstanceEnter()
    local settings = GetSettings()
    if not settings or settings.consumableCheckEnabled == false then return end

    -- Don't show in combat
    if InCombatLockdown() then return end

    -- Check dungeon trigger
    if settings.consumableOnDungeon and IsInDungeonInstance() then
        if HasMissingBuffs() then
            ShowConsumablesStandalone()
        end
        return
    end

    -- Check raid trigger
    if settings.consumableOnRaid and IsInRaidInstance() then
        if HasMissingBuffs() then
            ShowConsumablesStandalone()
        end
        return
    end
end

local function OnResurrect()
    local settings = GetSettings()
    if not settings or settings.consumableCheckEnabled == false then return end

    -- Don't show resurrect popup if not enabled
    if not settings.consumableOnResurrect then return end

    -- Don't show in combat (battle rez)
    if InCombatLockdown() then return end

    -- Only show if in instanced content
    if not IsInInstancedContent() then return end

    -- Only show if buffs are missing
    if HasMissingBuffs() then
        ShowConsumablesStandalone()
    end
end

eventFrame:RegisterEvent("READY_CHECK")
eventFrame:RegisterEvent("READY_CHECK_FINISHED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_ALIVE")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        InitializeButtons()
    elseif event == "READY_CHECK" then
        OnReadyCheck(...)
    elseif event == "READY_CHECK_FINISHED" then
        OnReadyCheckFinished()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Delay slightly to let instance info load
        C_Timer.After(1, OnInstanceEnter)
    elseif event == "PLAYER_ALIVE" then
        -- Delay slightly after resurrect
        C_Timer.After(0.5, OnResurrect)
    end
end)

---------------------------------------------------------------------------
-- COMBAT LOCKDOWN HANDLING
---------------------------------------------------------------------------

-- Hide clickable buttons when entering combat
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- Hide all clickable buttons during combat
        for _, button in pairs(ConsumablesFrame.buttons) do
            if type(button) == "table" and button.click then
                button.click:Hide()
            end
        end
    end
end)

---------------------------------------------------------------------------
-- TEST FUNCTIONS (for development)
---------------------------------------------------------------------------

_G.QUI_TestConsumableCheck = function()
    -- Use a fake name so "disable for starter" doesn't block it
    OnReadyCheck("TestPlayer", 30)
end

-- Debug instance entrance logic
_G.QUI_TestInstanceEnter = function()
    local settings = GetSettings()
    print("[QUI Debug] Instance Enter Check:")
    print("  Settings loaded:", settings and "YES" or "NO")
    if settings then
        print("  consumableCheckEnabled:", settings.consumableCheckEnabled ~= false and "YES" or "NO")
        print("  consumableOnDungeon:", settings.consumableOnDungeon and "YES" or "NO")
        print("  consumableOnRaid:", settings.consumableOnRaid and "YES" or "NO")
    end
    print("  InCombatLockdown:", InCombatLockdown() and "YES" or "NO")
    print("  IsInDungeonInstance:", IsInDungeonInstance() and "YES" or "NO")
    print("  IsInRaidInstance:", IsInRaidInstance() and "YES" or "NO")
    print("  HasMissingBuffs:", HasMissingBuffs() and "YES" or "NO")
    print("  Triggering OnInstanceEnter...")
    OnInstanceEnter()
    print("  Test complete.")
end

-- Show QUI consumables window standalone
_G.QUI_ShowConsumables = function()
    ShowConsumablesStandalone()
end

-- Hide QUI consumables window
_G.QUI_HideConsumables = function()
    ConsumablesFrame:Hide()
end

-- Refresh consumables (for live settings changes - preserves position)
_G.QuaziiUI_RefreshConsumables = function()
    if ConsumablesFrame:IsShown() then
        -- Save current position before refresh
        local point, relativeTo, relativePoint, x, y = ConsumablesFrame:GetPoint()

        InitializeButtons()
        UpdateConsumables()

        -- Restore position (don't call PositionConsumablesFrame which anchors to ReadyCheckFrame)
        ConsumablesFrame:ClearAllPoints()
        ConsumablesFrame:SetPoint(point, relativeTo, relativePoint, x, y)
    end
end

-- Reposition consumables (for offset changes - repositions relative to ReadyCheck)
_G.QuaziiUI_RepositionConsumables = function()
    if ConsumablesFrame:IsShown() then
        InitializeButtons()
        UpdateConsumables()
        -- Only reposition if anchored to ReadyCheckFrame, otherwise preserve position
        if ConsumablesFrame:GetParent() == ReadyCheckFrame then
            PositionConsumablesFrame()
        end
    end
end
