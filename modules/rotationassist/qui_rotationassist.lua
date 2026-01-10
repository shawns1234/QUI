-- qui_rotationassist.lua
-- Displays a standalone icon showing Blizzard's next recommended ability
-- Uses C_AssistedCombat API (Starter Build / Rotation Helper)

local ADDON_NAME, ns = ...

if not ns.ShouldLoadModule("rotationassist", { name = "Rotation Assist", enabled = true }) then
    return
end

local QUI = ns.QUI or {}
ns.QUI = QUI

local LSM = LibStub("LibSharedMedia-3.0")

-- Locals for performance
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local UnitCanAttack = UnitCanAttack
local UnitExists = UnitExists

-- Update intervals
local UPDATE_INTERVAL_COMBAT = 0.3
local UPDATE_INTERVAL_IDLE = 1.0

-- Icon state colors
local COLOR_USABLE = { 1, 1, 1 }
local COLOR_UNUSABLE = { 0.4, 0.4, 0.4 }
local COLOR_NO_MANA = { 0.5, 0.5, 1 }
local COLOR_OUT_OF_RANGE = { 0.8, 0.2, 0.2 }

-- Frame references
local iconFrame = nil
local isInitialized = false
local lastSpellID = nil
local inCombat = false

-- Performance: Ticker instead of OnUpdate
local updateTicker = nil

-- Cache for keybind lookup (reuse from keybinds.lua)
local spellToKeybind = {}
local lastKeybindCacheTime = 0
local KEYBIND_CACHE_INTERVAL = 1.0

-- Forward declarations
local CreateIconFrame, RefreshIconFrame, UpdateIconDisplay, UpdateVisibility

--------------------------------------------------------------------------------
-- Keybind Lookup (uses shared formatter from keybinds.lua)
--------------------------------------------------------------------------------

local function FormatKeybind(keybind)
    if QUI.FormatKeybind then
        return QUI.FormatKeybind(keybind)
    end
    return keybind -- fallback if not available
end

local function GetKeybindForSpell(spellID)
    if not spellID then return nil end

    local keybind = nil

    -- Use QUI.Keybinds if available (from keybinds.lua)
    if QUI.Keybinds and QUI.Keybinds.GetKeybindForSpell then
        keybind = QUI.Keybinds.GetKeybindForSpell(spellID)

        -- If no keybind found, try finding the BASE spell (for proc abilities)
        -- e.g., Thunder Blast -> Thunder Clap
        if not keybind then
            local ok, baseSpellID = pcall(function()
                return FindBaseSpellByID and FindBaseSpellByID(spellID)
            end)
            if ok and baseSpellID and baseSpellID ~= spellID then
                keybind = QUI.Keybinds.GetKeybindForSpell(baseSpellID)
            end
        end

        -- Also try C_Spell.GetOverrideSpell in reverse
        if not keybind then
            local ok, overrideID = pcall(function()
                return C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(spellID)
            end)
            if ok and overrideID and overrideID ~= spellID then
                keybind = QUI.Keybinds.GetKeybindForSpell(overrideID)
            end
        end

        if keybind then return keybind end
    end

    -- Fallback: Find action buttons with this spell (try base spell too)
    local baseSpellID = FindBaseSpellByID and FindBaseSpellByID(spellID) or spellID
    local slots = C_ActionBar.FindSpellActionButtons(baseSpellID)

    if slots and #slots > 0 then
        for _, slot in ipairs(slots) do
            -- Try to get keybind for this action slot
            local actionName = "ACTIONBUTTON" .. slot
            if slot > 12 and slot <= 24 then
                actionName = "ACTIONBUTTON" .. (slot - 12)
            elseif slot > 24 and slot <= 36 then
                actionName = "MULTIACTIONBAR3BUTTON" .. (slot - 24)
            elseif slot > 36 and slot <= 48 then
                actionName = "MULTIACTIONBAR4BUTTON" .. (slot - 36)
            elseif slot > 48 and slot <= 60 then
                actionName = "MULTIACTIONBAR1BUTTON" .. (slot - 48)
            elseif slot > 60 and slot <= 72 then
                actionName = "MULTIACTIONBAR2BUTTON" .. (slot - 60)
            end

            local key1 = GetBindingKey(actionName)
            if key1 then
                return FormatKeybind(key1)
            end
        end
    end

    return nil
end

--------------------------------------------------------------------------------
-- Database Access
--------------------------------------------------------------------------------

local function GetDB()
    local QUICore = _G.QuaziiUI and _G.QuaziiUI.QUICore
    if QUICore and QUICore.db and QUICore.db.profile then
        return QUICore.db.profile.rotationAssistIcon
    end
    return nil
end

--------------------------------------------------------------------------------
-- Icon Frame Creation
--------------------------------------------------------------------------------

CreateIconFrame = function()
    if iconFrame then return iconFrame end

    -- Main frame
    iconFrame = CreateFrame("Button", "QuaziiUI_RotationAssistIcon", UIParent, "BackdropTemplate")
    iconFrame:SetSize(56, 56)
    iconFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    iconFrame:SetFrameStrata("MEDIUM")
    iconFrame:SetClampedToScreen(true)
    iconFrame:EnableMouse(true)  -- Enable mouse for tooltips/interaction, but not dragging
    iconFrame:SetMovable(false)   -- Disable dragging - edit mode will enable it
    iconFrame:RegisterForDrag()   -- No drag registration - edit mode will register it

    -- Icon texture (inset by 2px default for border visibility)
    iconFrame.icon = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.icon:SetPoint("TOPLEFT", 2, -2)
    iconFrame.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    iconFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Crop edges

    -- Cooldown frame (matches icon inset)
    iconFrame.cooldown = CreateFrame("Cooldown", nil, iconFrame, "CooldownFrameTemplate")
    iconFrame.cooldown:SetPoint("TOPLEFT", 2, -2)
    iconFrame.cooldown:SetPoint("BOTTOMRIGHT", -2, 2)
    iconFrame.cooldown:SetDrawSwipe(true)
    iconFrame.cooldown:SetDrawEdge(false)
    iconFrame.cooldown:SetSwipeColor(0, 0, 0, 0.8)
    iconFrame.cooldown:SetHideCountdownNumbers(true)

    -- Keybind text
    iconFrame.keybindText = iconFrame:CreateFontString(nil, "OVERLAY")
    iconFrame.keybindText:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    iconFrame.keybindText:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -2, 2)
    iconFrame.keybindText:SetTextColor(1, 1, 1, 1)
    iconFrame.keybindText:SetShadowOffset(1, -1)
    iconFrame.keybindText:SetShadowColor(0, 0, 0, 1)

    -- Drag handlers removed - layout manager handles positioning

    -- Hide initially
    iconFrame:Hide()

    return iconFrame
end

--------------------------------------------------------------------------------
-- Icon Display Update
--------------------------------------------------------------------------------

UpdateIconDisplay = function(spellID)
    if not iconFrame then return end

    local db = GetDB()
    if not db or not db.enabled then
        iconFrame:Hide()
        return
    end

    if not spellID or spellID == 0 then
        -- No spell recommended - hide the icon entirely
        iconFrame:Hide()
        return
    end

    -- We have a spell - make sure frame is visible (respecting visibility mode)
    UpdateVisibility()

    -- Get spell texture
    local texture = C_Spell.GetSpellTexture(spellID)
    if texture then
        iconFrame.icon:SetTexture(texture)
    end

    -- Get usability state for icon tinting
    local isUsable, notEnoughMana = C_Spell.IsSpellUsable(spellID)
    local inRange = true

    -- Check range if spell has range
    local hasRange = C_Spell.SpellHasRange(spellID)
    if hasRange and UnitExists("target") then
        local rangeCheck = C_Spell.IsSpellInRange(spellID, "target")
        if rangeCheck == false then
            inRange = false
        end
    end

    -- Apply icon tint based on state
    local color
    if not inRange then
        color = COLOR_OUT_OF_RANGE
    elseif notEnoughMana then
        color = COLOR_NO_MANA
    elseif not isUsable then
        color = COLOR_UNUSABLE
    else
        color = COLOR_USABLE
    end
    iconFrame.icon:SetVertexColor(color[1], color[2], color[3], 1)

    -- Update cooldown swipe (handle secret values from Midnight API)
    if db.cooldownSwipeEnabled then
        local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
        if cooldownInfo and cooldownInfo.startTime and cooldownInfo.duration then
            -- Use pcall to safely check duration > 0 (may be secret value)
            local ok, hasDuration = pcall(function()
                return cooldownInfo.duration > 0
            end)
            if ok and hasDuration then
                -- Pass values directly to SetCooldown - it handles secret values gracefully
                iconFrame.cooldown:SetCooldown(cooldownInfo.startTime, cooldownInfo.duration)
            else
                iconFrame.cooldown:Clear()
            end
        else
            iconFrame.cooldown:Clear()
        end
        iconFrame.cooldown:Show()
    else
        iconFrame.cooldown:Hide()
    end

    -- Update keybind text
    if db.showKeybind then
        local keybind = GetKeybindForSpell(spellID)
        iconFrame.keybindText:SetText(keybind or "")
        iconFrame.keybindText:Show()
    else
        iconFrame.keybindText:Hide()
    end
end

--------------------------------------------------------------------------------
-- Visibility Management
--------------------------------------------------------------------------------

UpdateVisibility = function()
    if not iconFrame then return end

    local db = GetDB()
    if not db or not db.enabled then
        iconFrame:Hide()
        return
    end

    -- Always show in edit mode (for positioning)
    if iconFrame.editOverlay and iconFrame.editOverlay:IsShown() then
        iconFrame:Show()
        return
    end

    local shouldShow = false
    local visibility = db.visibility or "always"

    if visibility == "always" then
        shouldShow = true
    elseif visibility == "combat" then
        shouldShow = inCombat
    elseif visibility == "hostile" then
        shouldShow = UnitExists("target") and UnitCanAttack("player", "target")
    end

    if shouldShow then
        iconFrame:Show()
    else
        iconFrame:Hide()
    end
end

--------------------------------------------------------------------------------
-- Ticker-based Update (Performance: runs only when needed, not every frame)
--------------------------------------------------------------------------------

local function DoUpdate()
    local db = GetDB()
    if not db or not db.enabled then return end

    -- Check if C_AssistedCombat API is available
    if not C_AssistedCombat or not C_AssistedCombat.GetNextCastSpell then
        return
    end

    -- Get next recommended spell
    local ok, spellID = pcall(C_AssistedCombat.GetNextCastSpell, false)
    if not ok then
        spellID = nil
    end

    -- Only do full update if spell changed
    if spellID ~= lastSpellID then
        lastSpellID = spellID
        UpdateIconDisplay(spellID)
    end
end

local function StartUpdateTicker()
    -- Cancel existing ticker if any
    if updateTicker then updateTicker:Cancel() end

    local db = GetDB()
    if not db or not db.enabled then return end

    -- Use appropriate interval based on combat state
    local interval = inCombat and UPDATE_INTERVAL_COMBAT or UPDATE_INTERVAL_IDLE
    updateTicker = C_Timer.NewTicker(interval, DoUpdate)
end

local function StopUpdateTicker()
    if updateTicker then
        updateTicker:Cancel()
        updateTicker = nil
    end
end

--------------------------------------------------------------------------------
-- Frame Refresh (Apply Settings)
--------------------------------------------------------------------------------

RefreshIconFrame = function()
    -- Ensure frame exists - create it if it doesn't exist yet
    if not iconFrame then
        CreateIconFrame()
        isInitialized = true
        -- Register with layout manager after creation
        local QUI_LayoutManager = ns.QUI_LayoutManager
        if QUI_LayoutManager and iconFrame then
            local layoutConfig = QUI_LayoutManager:GetLayout(iconFrame)
            if not layoutConfig then
                    QUI_LayoutManager:RegisterFrame(iconFrame, "rotationAssist.default", "rotationAssist", {
                        parentFrame = UIParent,
                        editMode = {
                            label = "Rotation Assist Icon",
                            elementKey = "rotationAssist",
                            skipKeyboardEnable = false,
                            elementType = "rotationAssist",
                            updateCallback = function()
                                -- Refresh visibility when edit mode changes (ensures frame is shown in edit mode)
                                UpdateVisibility()
                            end,
                        },
                    })
            end
        end
    end

    local db = GetDB()
    if not db then
        if iconFrame then iconFrame:Hide() end
        return
    end

    if not db.enabled then
        if iconFrame then
            iconFrame:Hide()
        end
        StopUpdateTicker()
        return
    end

    -- Ensure ticker is running when enabled (may have been stopped)
    StartUpdateTicker()

    -- Position handled by layout manager (already registered when frame was created)
    -- If layout manager is not available, use fallback positioning
    local QUI_LayoutManager = ns.QUI_LayoutManager
    if not QUI_LayoutManager then
        -- Fallback: manual positioning if layout manager not available
        iconFrame:ClearAllPoints()
        iconFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    end

    -- Size (guard with pcall to prevent secret value crash when backdrop recalculates)
    -- SetSize triggers backdrop texture coordinate recalculation which can fail during combat
    -- Size is handled separately from layout manager (visual property, not positioning)
    local size = db.iconSize or 56
    pcall(iconFrame.SetSize, iconFrame, size, size)

    -- Frame strata
    iconFrame:SetFrameStrata(db.frameStrata or "MEDIUM")

    -- Border (uses SafeSetBackdrop to avoid secret value errors during combat)
    local inset = 0
    local QUICore = _G.QuaziiUI and _G.QuaziiUI.QUICore
    local SafeSetBackdrop = QUICore and QUICore.SafeSetBackdrop

    if db.showBorder then
        local borderColor = db.borderColor or { 0, 0, 0, 1 }
        local thickness = db.borderThickness or 2
        inset = thickness

        -- Use backdrop for border
        local backdropInfo = {
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = thickness,
        }
        -- Check if edit mode is active (green border when in edit mode)
        local isInEditMode = iconFrame.editOverlay and iconFrame.editOverlay:IsShown()
        if isInEditMode then
            -- Green border when in edit mode
            if SafeSetBackdrop then
                SafeSetBackdrop(iconFrame, backdropInfo, { 0, 1, 0, 1 })
            else
                iconFrame:SetBackdrop(backdropInfo)
                iconFrame:SetBackdropBorderColor(0, 1, 0, 1)
            end
        else
            -- Normal border color when not in edit mode
            if SafeSetBackdrop then
                SafeSetBackdrop(iconFrame, backdropInfo, borderColor)
            else
                iconFrame:SetBackdrop(backdropInfo)
                iconFrame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
            end
        end
    else
        if SafeSetBackdrop then
            SafeSetBackdrop(iconFrame, nil)
        else
            iconFrame:SetBackdrop(nil)
        end
    end

    -- Adjust icon and cooldown inset based on border
    iconFrame.icon:ClearAllPoints()
    iconFrame.icon:SetPoint("TOPLEFT", inset, -inset)
    iconFrame.icon:SetPoint("BOTTOMRIGHT", -inset, inset)
    iconFrame.cooldown:ClearAllPoints()
    iconFrame.cooldown:SetPoint("TOPLEFT", inset, -inset)
    iconFrame.cooldown:SetPoint("BOTTOMRIGHT", -inset, inset)

    -- Mouse enabled for visibility (edit mode handles dragging)
    iconFrame:EnableMouse(true)

    -- Keybind text styling
    if db.showKeybind then
        -- Get font: use keybindFont if set, otherwise fall back to general.font
        local fontName = db.keybindFont
        if not fontName then
            local QUICore = _G.QuaziiUI and _G.QuaziiUI.QUICore
            if QUICore and QUICore.db and QUICore.db.profile and QUICore.db.profile.general then
                fontName = QUICore.db.profile.general.font
            end
        end
        local fontPath = LSM:Fetch("font", fontName) or STANDARD_TEXT_FONT
        local fontSize = db.keybindSize or 13
        local outline = db.keybindOutline and "OUTLINE" or ""
        iconFrame.keybindText:SetFont(fontPath, fontSize, outline)

        local color = db.keybindColor or { 1, 1, 1, 1 }
        iconFrame.keybindText:SetTextColor(color[1], color[2], color[3], color[4] or 1)

        -- Anchor position
        local anchor = db.keybindAnchor or "BOTTOMRIGHT"
        local offsetX = db.keybindOffsetX or -2
        local offsetY = db.keybindOffsetY or 2
        iconFrame.keybindText:ClearAllPoints()
        iconFrame.keybindText:SetPoint(anchor, iconFrame, anchor, offsetX, offsetY)
    end

    -- Don't call UpdateVisibility() here - let OnUpdate show the frame
    -- only after a spell has been fetched, to avoid empty border flash
end

--------------------------------------------------------------------------------
-- Event Handling
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, function()
            if not isInitialized then
                CreateIconFrame()
                isInitialized = true
                -- Register with layout manager after creation
                local QUI_LayoutManager = ns.QUI_LayoutManager
                if QUI_LayoutManager and iconFrame then
                    local layoutConfig = QUI_LayoutManager:GetLayout(iconFrame)
                    if not layoutConfig then
                        QUI_LayoutManager:RegisterFrame(iconFrame, "rotationAssist.default", "rotationAssist", {
                            parentFrame = UIParent,
                            editMode = {
                                label = "Rotation Assist Icon",
                                elementKey = "rotationAssist",
                                skipKeyboardEnable = false,
                                elementType = "rotationAssist",
                                updateCallback = function()
                                    -- Refresh visibility when edit mode changes (ensures frame is shown in edit mode)
                                    UpdateVisibility()
                                end,
                            },
                        })
                    end
                end
            end
            local db = GetDB()
            if db and db.enabled then
                RefreshIconFrame()
                -- Start ticker for spell updates (performance: replaces OnUpdate)
                StartUpdateTicker()
            end
        end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        local db = GetDB()
        if db and db.enabled then
            UpdateVisibility()
            -- Restart ticker with idle interval (1.0s instead of 0.3s)
            StartUpdateTicker()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        local db = GetDB()
        if db and db.enabled then
            UpdateVisibility()
            -- Restart ticker with combat interval (0.3s for faster response)
            StartUpdateTicker()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdateVisibility()
        -- Force spell update on target change
        lastSpellID = nil
        DoUpdate()  -- Immediate update on target change
    end
end)

--------------------------------------------------------------------------------
-- Global Refresh Function
--------------------------------------------------------------------------------

local function RefreshRotationAssistIcon()
    RefreshIconFrame()
end

_G.QuaziiUI_RefreshRotationAssistIcon = RefreshRotationAssistIcon

--------------------------------------------------------------------------------
-- Edit Mode Integration
-- Ensure frame is visible when edit mode is enabled
--------------------------------------------------------------------------------

-- Hook into layout manager's edit mode enable to show frame
local function HookEditMode()
    local QUI_LayoutManager = ns.QUI_LayoutManager
    if not QUI_LayoutManager then return end
    
    -- Hook the EnableEditMode function to show the icon frame before enabling
    local originalEnableEditMode = QUI_LayoutManager.EnableEditMode
    if originalEnableEditMode and not QUI_LayoutManager._rotationAssistEditModeHooked then
        QUI_LayoutManager.EnableEditMode = function(self)
            -- Show the icon frame if it exists and is enabled (so edit mode can enable for it)
            if iconFrame then
                local db = GetDB()
                if db and db.enabled then
                    -- Temporarily show the frame so edit mode can enable for it
                    iconFrame:Show()
                end
            end
            -- Call original function
            return originalEnableEditMode(self)
        end
        QUI_LayoutManager._rotationAssistEditModeHooked = true
    end
end

-- Hook edit mode when frame is created
if iconFrame then
    HookEditMode()
else
    -- Hook when frame is created
    local originalCreateIconFrame = CreateIconFrame
    CreateIconFrame = function()
        local frame = originalCreateIconFrame()
        if frame then
            C_Timer.After(0, HookEditMode)
        end
        return frame
    end
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

QUI.RotationAssistIcon = {
    Refresh = RefreshRotationAssistIcon,
    GetFrame = function() return iconFrame end,
}
