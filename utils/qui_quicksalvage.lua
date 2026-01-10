local addonName, ns = ...

---------------------------------------------------------------------------
-- QUICK SALVAGE: One-click Milling, Prospecting, Disenchanting
---------------------------------------------------------------------------

local QuickSalvage = {}
ns.QuickSalvage = QuickSalvage

-- Spell IDs for profession actions
local SPELL_DISENCHANT = 13262
local SPELL_MILLING = 51005
local SPELL_PROSPECTING = 31252

-- Item class constants
local ITEM_CLASS_TRADESKILL = 7  -- Trade Goods
local ITEM_SUBCLASS_HERB = 9     -- Herbs
local ITEM_SUBCLASS_ORE = 7      -- Metal & Stone

-- Colors for different actions
local COLORS = {
    disenchant = CreateColor(0.7, 0.3, 0.9),  -- Purple
    milling = CreateColor(0.3, 0.8, 0.3),     -- Green
    prospecting = CreateColor(1.0, 0.6, 0.2), -- Orange
}

-- Current modifier setting
local currentModifier = "ALT"

local IsPlayerSpell = C_SpellBook.IsSpellKnown or IsPlayerSpell

---------------------------------------------------------------------------
-- HELPER: Get settings
---------------------------------------------------------------------------
local function GetSettings()
    local QUICore = _G.QuaziiUI and _G.QuaziiUI.QUICore
    if QUICore and QUICore.db and QUICore.db.profile and QUICore.db.profile.general then
        return QUICore.db.profile.general.quickSalvage
    end
    return nil
end

---------------------------------------------------------------------------
-- HELPER: Check if player has the profession spell
---------------------------------------------------------------------------
local function PlayerHasSpell(spellID)
    return IsPlayerSpell(spellID)
end

---------------------------------------------------------------------------
-- HELPER: Check modifier state
---------------------------------------------------------------------------
local function IsModifierActive()
    if not IsAltKeyDown() then return false end

    if currentModifier == "ALTCTRL" then
        return IsControlKeyDown()
    elseif currentModifier == "ALTSHIFT" then
        return IsShiftKeyDown()
    else -- "ALT"
        return not IsControlKeyDown() and not IsShiftKeyDown()
    end
end

---------------------------------------------------------------------------
-- HELPER: Determine if item is salvageable and what action to use
---------------------------------------------------------------------------
local function GetSalvageInfo(itemID, stackCount)
    if not itemID then return nil end

    -- Get item info
    local _, _, itemQuality, _, _, _, itemSubType, _, _, _, _, itemClassID, itemSubClassID = C_Item.GetItemInfo(itemID)

    if not itemClassID then return nil end

    -- Check for Trade Goods (herbs/ores)
    if itemClassID == ITEM_CLASS_TRADESKILL then
        -- Herbs -> Milling (requires 5 stack)
        if itemSubClassID == ITEM_SUBCLASS_HERB then
            if stackCount and stackCount >= 5 then
                if PlayerHasSpell(SPELL_MILLING) then
                    return SPELL_MILLING, COLORS.milling, "milling", 5
                end
            else
                return nil, nil, "milling", 5, true -- needsMore = true
            end
        end

        -- Ores -> Prospecting (requires 5 stack)
        if itemSubClassID == ITEM_SUBCLASS_ORE then
            if stackCount and stackCount >= 5 then
                if PlayerHasSpell(SPELL_PROSPECTING) then
                    return SPELL_PROSPECTING, COLORS.prospecting, "prospecting", 5
                end
            else
                return nil, nil, "prospecting", 5, true -- needsMore = true
            end
        end
    end

    -- Check for Armor/Weapons -> Disenchanting (green+ quality)
    local itemClassID2 = select(12, C_Item.GetItemInfo(itemID))
    if itemClassID2 == Enum.ItemClass.Armor or itemClassID2 == Enum.ItemClass.Weapon then
        if itemQuality and itemQuality >= Enum.ItemQuality.Uncommon then
            -- Check if item is disenchantable (not cosmetic, not bound to another player, etc.)
            if C_Item.IsCosmeticItem and C_Item.IsCosmeticItem(itemID) then
                return nil
            end
            if PlayerHasSpell(SPELL_DISENCHANT) then
                return SPELL_DISENCHANT, COLORS.disenchant, "disenchant"
            end
        end
    end

    return nil
end

---------------------------------------------------------------------------
-- CREATE SECURE BUTTON
---------------------------------------------------------------------------
local TEMPLATES = {
    'SecureActionButtonTemplate',
    'SecureHandlerAttributeTemplate',
    'SecureHandlerEnterLeaveTemplate',
}

local SalvageButton = CreateFrame("Button", "QuaziiUI_QuickSalvageButton", UIParent, table.concat(TEMPLATES, ','))
SalvageButton:SetFrameStrata("TOOLTIP")
SalvageButton:EnableMouse(true)
SalvageButton:RegisterForClicks("AnyUp", "AnyDown")
SalvageButton:Hide()

-- Store references
SalvageButton.spellID = nil
SalvageButton.itemLink = nil

---------------------------------------------------------------------------
-- GLOW ANIMATION (Retail)
---------------------------------------------------------------------------
local Glow = SalvageButton:CreateTexture(nil, 'ARTWORK')
Glow:SetPoint('CENTER')
Glow:SetAtlas('UI-HUD-ActionBar-Proc-Loop-Flipbook')
Glow:SetDesaturated(true)

local Animation = SalvageButton:CreateAnimationGroup()
Animation:SetLooping('REPEAT')

local FlipBook = Animation:CreateAnimation('FlipBook')
FlipBook:SetTarget(Glow)
FlipBook:SetDuration(1)
FlipBook:SetFlipBookColumns(5)
FlipBook:SetFlipBookRows(6)
FlipBook:SetFlipBookFrames(30)

local function SetGlowColor(color)
    if color then
        Glow:SetVertexColor(color:GetRGB())
    end

    -- Adjust glow size to button size
    local width, height = SalvageButton:GetSize()
    Glow:SetSize(width * 1.4, height * 1.4)
end

SalvageButton:HookScript('OnShow', function()
    Animation:Play()
end)

SalvageButton:HookScript('OnHide', function()
    Animation:Stop()
end)

---------------------------------------------------------------------------
-- TOOLTIP
---------------------------------------------------------------------------
local function ShowTooltip(self)
    local right = self:GetRight()
    local screenWidth = GetScreenWidth()

    -- Default to right anchor if we can't determine position
    if right and screenWidth and right >= screenWidth / 2 then
        GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
    else
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
    end

    local bagID = self:GetAttribute('target-bag')
    local slotID = self:GetAttribute('target-slot')

    if self.itemLink then
        GameTooltip:SetHyperlink(self.itemLink)
    elseif bagID and slotID then
        GameTooltip:SetBagItem(bagID, slotID)
    else
        return -- Can't show tooltip without valid data
    end

    -- Add hint text
    if self.spellID then
        local spellName = C_Spell.GetSpellName(self.spellID)
        if spellName then
            GameTooltip:AddLine(' ')
            GameTooltip:AddLine('|A:NPE_LeftClick:18:18|a |cff0090ff' .. spellName .. '|r', 1, 1, 1)
        end
    end

    GameTooltip:Show()
end

SalvageButton:HookScript('OnEnter', ShowTooltip)
SalvageButton:HookScript('OnLeave', GameTooltip_Hide)

---------------------------------------------------------------------------
-- APPLY SPELL ACTION
---------------------------------------------------------------------------
local MACRO_SALVAGE = '/run C_TradeSkillUI.CraftSalvage(%d, 1, ItemLocation:CreateFromBagAndSlot(%d, %d))'

function SalvageButton:ApplySpell(bagID, slotID, itemLink, spellID, color)
    self:SetAttribute('target-bag', bagID)
    self:SetAttribute('target-slot', slotID)
    self.itemLink = itemLink
    self.spellID = spellID

    -- Determine the correct type prefix based on modifier
    local typePrefix
    if currentModifier == "ALTCTRL" then
        typePrefix = "alt-ctrl-"
    elseif currentModifier == "ALTSHIFT" then
        typePrefix = "alt-shift-"
    else
        typePrefix = "alt-"
    end

    -- Check if spell is in spellbook (for direct spell casting)
    local spellSlot = FindSpellBookSlotBySpellID and FindSpellBookSlotBySpellID(spellID)

    if spellSlot then
        -- Use direct spell casting
        self:SetAttribute(typePrefix .. 'type1', 'spell')
        self:SetAttribute(typePrefix .. 'spell1', spellID)
        self:SetAttribute('type1', 'spell')
        self:SetAttribute('spell', spellID)
    else
        -- Use macro for salvage API (modern professions)
        local macroText = MACRO_SALVAGE:format(spellID, bagID, slotID)
        self:SetAttribute(typePrefix .. 'type1', 'macro')
        self:SetAttribute(typePrefix .. 'macrotext1', macroText)
        self:SetAttribute('type1', 'macro')
        self:SetAttribute('macrotext', macroText)
    end

    self:Show()
    SetGlowColor(color)
end

---------------------------------------------------------------------------
-- UPDATE ATTRIBUTE DRIVER
---------------------------------------------------------------------------
function SalvageButton:UpdateAttributeDriver()
    -- RegisterStateDriver is protected and cannot be called in combat
    if InCombatLockdown() then return end

    local settings = GetSettings()
    if not settings or not settings.enabled then
        RegisterStateDriver(self, 'visibility', 'hide')
        return
    end

    currentModifier = settings.modifier or "ALT"

    if currentModifier == "ALTCTRL" then
        RegisterStateDriver(self, 'visibility', '[mod:alt,mod:ctrl] show; hide')
    elseif currentModifier == "ALTSHIFT" then
        RegisterStateDriver(self, 'visibility', '[mod:alt,mod:shift] show; hide')
    else
        RegisterStateDriver(self, 'visibility', '[mod:alt] show; hide')
    end
end

-- Re-anchor when shown
SalvageButton:HookScript('OnShow', function(self)
    local owner = GameTooltip:GetOwner()
    if owner then
        local left, bottom, width, height = owner:GetScaledRect()
        if left and bottom and width and height then
            local scaleMultiplier = 1 / UIParent:GetScale()
            self:ClearAllPoints()
            self:SetPoint('BOTTOMLEFT', left * scaleMultiplier, bottom * scaleMultiplier)
            self:SetSize(width * scaleMultiplier, height * scaleMultiplier)
        end
    end
end)

-- Set attribute to trigger EnterLeave driver
SalvageButton:HookScript('OnShow', function(self)
    self:SetAttribute('_entered', true)
end)

-- Use EnterLeave to securely deactivate when the mouse leaves the item
SalvageButton:SetAttribute('_onleave', 'self:ClearAllPoints();self:Hide()')

-- Use attribute driver to securely deactivate when the modifier key is released
SalvageButton:SetAttribute('_onattributechanged', [[
    if name == 'visibility' and value == 'hide' and self:IsShown() then
        self:ClearAllPoints()
        self:Hide()
    end
]])

-- Reset attributes when hidden
SalvageButton:HookScript('OnHide', function(self)
    self.itemLink = nil
    self.spellID = nil
    if not InCombatLockdown() then
        self:SetAttribute('target-bag', nil)
        self:SetAttribute('target-slot', nil)
        self:SetAttribute('_entered', false)
        -- Clear action attributes
        self:SetAttribute('type1', nil)
        self:SetAttribute('spell', nil)
        self:SetAttribute('macrotext', nil)
        -- Clear modifier-specific attributes
        self:SetAttribute('alt-type1', nil)
        self:SetAttribute('alt-spell1', nil)
        self:SetAttribute('alt-macrotext1', nil)
        self:SetAttribute('alt-ctrl-type1', nil)
        self:SetAttribute('alt-ctrl-spell1', nil)
        self:SetAttribute('alt-ctrl-macrotext1', nil)
        self:SetAttribute('alt-shift-type1', nil)
        self:SetAttribute('alt-shift-spell1', nil)
        self:SetAttribute('alt-shift-macrotext1', nil)
    end
end)

---------------------------------------------------------------------------
-- TOOLTIP HOOK
---------------------------------------------------------------------------
local ERR_COLOR = CreateColor(1, 0.125, 0.125)

local function TooltipHelp(msg, color)
    GameTooltip:AddLine(' ')
    GameTooltip:AddLine(msg, color and color:GetRGB())
    GameTooltip:Show()
end

local function OnTooltipSetItem(tooltip, data)
    -- Skip if disabled or in combat
    local settings = GetSettings()
    if not settings or not settings.enabled then return end
    if InCombatLockdown() then return end

    -- Skip our own tooltips
    if tooltip:GetOwner() == SalvageButton then return end

    -- Skip if modifier not active
    if not IsModifierActive() then return end

    -- Skip if in Auction House or vehicle
    if (AuctionFrame or AuctionHouseFrame) and (AuctionFrame or AuctionHouseFrame):IsVisible() then return end
    if UnitHasVehicleUI and UnitHasVehicleUI('player') then return end

    -- Get item info from tooltip data
    local itemID, itemLink
    if data and data.id then
        itemID = data.id
        itemLink = data.hyperlink
    else
        -- Fallback for older tooltip API
        local _, link = tooltip:GetItem()
        if link then
            itemLink = link
            itemID = C_Item.GetItemIDForItemInfo(link)
        end
    end

    if not itemID then return end

    -- Get owner (bag slot) info
    local owner = tooltip:GetOwner()
    if not owner then return end

    local bagID, slotID, stackCount

    if owner.GetSlotAndBagID then
        slotID, bagID = owner:GetSlotAndBagID()
        if bagID and slotID then
            local itemInfo = C_Container.GetContainerItemInfo(bagID, slotID)
            if itemInfo then
                stackCount = itemInfo.stackCount
            end
        end
    elseif owner.GetBagID and owner.GetID then
        bagID = owner:GetBagID()
        slotID = owner:GetID()
        if bagID and slotID then
            local itemInfo = C_Container.GetContainerItemInfo(bagID, slotID)
            if itemInfo then
                stackCount = itemInfo.stackCount
            end
        end
    end

    if not bagID or not slotID then return end

    -- Check if salvageable
    local spellID, color, actionType, requiredStack, needsMore = GetSalvageInfo(itemID, stackCount)

    if needsMore then
        local itemName = C_Item.GetItemNameByID(itemID) or "item"
        TooltipHelp(SPELL_FAILED_NEED_MORE_ITEMS:format(requiredStack, itemName), ERR_COLOR)
        return
    end

    if spellID then
        -- Check if player has the spell
        if not PlayerHasSpell(spellID) then
            local spellName = C_Spell.GetSpellName(spellID)
            TooltipHelp(ERR_USE_LOCKED_WITH_SPELL_S:format(spellName or "Unknown"), ERR_COLOR)
            return
        end

        -- Apply the salvage action
        SalvageButton:ApplySpell(bagID, slotID, itemLink, spellID, color)
    end
end

---------------------------------------------------------------------------
-- EVENT HANDLING
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")

-- Register events
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "BAG_UPDATE_DELAYED" then
        if SalvageButton:IsShown() and not InCombatLockdown() then
            SalvageButton:Hide()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Initial setup with delay
        C_Timer.After(1, function()
            SalvageButton:UpdateAttributeDriver()
        end)
    elseif event == "MODIFIER_STATE_CHANGED" then
        if SalvageButton:IsShown() then
            ShowTooltip(SalvageButton)

            -- Hide if wrong modifier combo
            if not IsModifierActive() and not InCombatLockdown() then
                SalvageButton:Hide()
            end
        elseif GameTooltip:IsShown() and IsModifierActive() then
            -- Re-trigger tooltip hook when modifier pressed
            local owner = GameTooltip:GetOwner()
            if owner and owner:IsMouseOver() then
                if owner.GetSlotAndBagID then
                    local slotID, bagID = owner:GetSlotAndBagID()
                    if bagID and slotID then
                        local itemInfo = C_Container.GetContainerItemInfo(bagID, slotID)
                        if itemInfo and itemInfo.hyperlink then
                            local itemID = C_Item.GetItemIDForItemInfo(itemInfo.hyperlink)
                            if itemID then
                                local spellID, color, actionType, requiredStack, needsMore = GetSalvageInfo(itemID, itemInfo.stackCount)
                                if spellID and not needsMore then
                                    SalvageButton:ApplySpell(bagID, slotID, itemInfo.hyperlink, spellID, color)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- TOOLTIP HOOK REGISTRATION
---------------------------------------------------------------------------
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipSetItem)

---------------------------------------------------------------------------
-- GLOBAL REFRESH FUNCTION
---------------------------------------------------------------------------
function _G.QuaziiUI_RefreshQuickSalvage()
    if not InCombatLockdown() then
        SalvageButton:UpdateAttributeDriver()
    end
end

-- Export for other modules
QuickSalvage.Button = SalvageButton
QuickSalvage.Refresh = _G.QuaziiUI_RefreshQuickSalvage
