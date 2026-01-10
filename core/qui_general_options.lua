--[[
    qui_general_options.lua
    Options UI for General tab (General & QoL page)
]]

local ADDON_NAME, ns = ...
local QUI = QuaziiUI
local GUI = QUI.GUI
local QUICore = ns.Addon
local C = GUI.Colors
local OptionsShared = ns.OptionsShared

-- Import shared utilities
local GetDB = OptionsShared.GetDB
local PADDING = OptionsShared.CONSTANTS.PADDING
local FORM_ROW = 32
local CheckCVarsMatch = OptionsShared.CheckCVarsMatch
local ApplyQuaziiFPSSettings = OptionsShared.ApplyQuaziiFPSSettings
local RestorePreviousFPSSettings = OptionsShared.RestorePreviousFPSSettings

-- Refresh callback for fonts/textures (refreshes everything that uses these defaults)
local function RefreshAll()
    -- Refresh core CDM viewers
    if QUICore and QUICore.RefreshAll then
        QUICore:RefreshAll()
    end
    -- Refresh unit frames (use global function)
    if _G.QuaziiUI_RefreshUnitFrames then
        _G.QuaziiUI_RefreshUnitFrames()
    end
    -- Refresh power bars (recreate to apply new fonts/textures)
    if ns.QUI_ResourceBars then
        if ns.QUI_ResourceBars.UpdatePrimaryBar then
            ns.QUI_ResourceBars:UpdatePrimaryBar()
        end
        if ns.QUI_ResourceBars.UpdateSecondaryBar then
            ns.QUI_ResourceBars:UpdateSecondaryBar()
        end
    end
    -- Refresh minimap/datatext
    if QUICore and QUICore.Minimap and QUICore.Minimap.Refresh then
        QUICore.Minimap:Refresh()
    end
    -- Refresh buff borders
    if _G.QuaziiUI_RefreshBuffBorders then
        _G.QuaziiUI_RefreshBuffBorders()
    end
    -- Refresh NCDM (CDM icons)
    if ns and ns.NCDM and ns.NCDM.RefreshAll then
        ns.NCDM:RefreshAll()
    end
    -- Trigger CDM layout refresh
    C_Timer.After(0.1, function()
        if QUICore and QUICore.ApplyViewerLayout then
            QUICore:ApplyViewerLayout("EssentialCooldownViewer")
            QUICore:ApplyViewerLayout("UtilityCooldownViewer")
        end
    end)
end

local function BuildGeneralTab(tabContent)
    local db = GetDB()
    local y = -10

    -- Set search context for auto-registration
    GUI:SetSearchContext({tabIndex = 1, tabName = "General & QoL", subTabIndex = 1, subTabName = "General"})

    -- UI Scale Section
    GUI:SetSearchSection("UI Scale")
    local scaleHeader = GUI:CreateSectionHeader(tabContent, "UI Scale")
    scaleHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - scaleHeader.gap

    if db and db.general then
        local scaleSlider = GUI:CreateFormSlider(tabContent, "Global UI Scale", 0.5, 2.0, 0.01,
            "uiScale", db.general, function(val)
                UIParent:SetScale(val)
                if QUICore and QUICore.UIMult then QUICore:UIMult() end
            end, { deferOnDrag = true })
        scaleSlider:SetPoint("TOPLEFT", PADDING, y)
        scaleSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW
    end

    y = y - 10

    -- Default Font Section
    GUI:SetSearchSection("Default Font Settings")
    local fontTexHeader = GUI:CreateSectionHeader(tabContent, "Default Font Settings")
    fontTexHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - fontTexHeader.gap

    local tipText = GUI:CreateLabel(tabContent, "These settings apply throughout the UI. Individual elements with their own font options will override these defaults.", 11, C.textMuted)
    tipText:SetPoint("TOPLEFT", PADDING, y)
    tipText:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    tipText:SetJustifyH("LEFT")
    y = y - 28

    if db and db.general then
        local fontList = {}
        local LSM = LibStub("LibSharedMedia-3.0", true)
        if LSM then
            for name in pairs(LSM:HashTable("font")) do
                table.insert(fontList, {value = name, text = name})
            end
            table.sort(fontList, function(a, b) return a.text < b.text end)
        else
            fontList = {{value = "Friz Quadrata TT", text = "Friz Quadrata TT"}}
        end

        local fontDropdown = GUI:CreateFormDropdown(tabContent, "Default Font", fontList, "font", db.general, RefreshAll)
        fontDropdown:SetPoint("TOPLEFT", PADDING, y)
        fontDropdown:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local outlineOptions = {
            {value = "", text = "None"},
            {value = "OUTLINE", text = "Outline"},
            {value = "THICKOUTLINE", text = "Thick Outline"},
        }
        local outlineDropdown = GUI:CreateFormDropdown(tabContent, "Font Outline", outlineOptions, "fontOutline", db.general, RefreshAll)
        outlineDropdown:SetPoint("TOPLEFT", PADDING, y)
        outlineDropdown:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW
    end

    y = y - 10

    -- Quazii Recommended FPS Settings Section
    local fpsHeader = GUI:CreateSectionHeader(tabContent, "Quazii Recommended FPS Settings")
    fpsHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - fpsHeader.gap

    local fpsDesc = GUI:CreateLabel(tabContent,
        "Apply Quazii's optimized graphics settings for competitive play. " ..
        "Your current settings are automatically saved when you click Apply - use 'Restore Previous Settings' to revert anytime. " ..
        "Caution: Clicking Apply again will overwrite your backup with these settings.",
        11, C.textMuted)
    fpsDesc:SetPoint("TOPLEFT", PADDING, y)
    fpsDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    fpsDesc:SetJustifyH("LEFT")
    fpsDesc:SetWordWrap(true)
    fpsDesc:SetHeight(30)
    y = y - 40

    local restoreFpsBtn
    local fpsStatusText

    local function UpdateFPSStatus()
        local allMatch, matched, total = CheckCVarsMatch()
        -- Some CVars can't be verified (protected/restart required), so threshold at 50+
        if matched >= 50 then
            fpsStatusText:SetText("Settings: All applied")
            fpsStatusText:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 1)
        else
            fpsStatusText:SetText(string.format("Settings: %d/%d match", matched, total))
            fpsStatusText:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)
        end
    end

    local applyFpsBtn = GUI:CreateButton(tabContent, "Apply FPS Settings", 180, 28, function()
        ApplyQuaziiFPSSettings()
        restoreFpsBtn:SetAlpha(1)
        restoreFpsBtn:Enable()
        UpdateFPSStatus()
    end)
    applyFpsBtn:SetPoint("TOPLEFT", PADDING, y)
    applyFpsBtn:SetPoint("RIGHT", tabContent, "CENTER", -5, 0)

    restoreFpsBtn = GUI:CreateButton(tabContent, "Restore Previous Settings", 180, 28, function()
        if RestorePreviousFPSSettings() then
            restoreFpsBtn:SetAlpha(0.5)
            restoreFpsBtn:Disable()
        end
        UpdateFPSStatus()
    end)
    restoreFpsBtn:SetPoint("LEFT", tabContent, "CENTER", 5, 0)
    restoreFpsBtn:SetPoint("TOP", applyFpsBtn, "TOP", 0, 0)
    restoreFpsBtn:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    y = y - 38

    fpsStatusText = GUI:CreateLabel(tabContent, "", 11, C.accent)
    fpsStatusText:SetPoint("TOPLEFT", PADDING, y)

    if not db.fpsBackup then
        restoreFpsBtn:SetAlpha(0.5)
        restoreFpsBtn:Disable()
    end

    UpdateFPSStatus()

    y = y - 22

    -- Reset Anchors Section
    GUI:SetSearchSection("Reset Anchors")
    local resetAnchorsHeader = GUI:CreateSectionHeader(tabContent, "Reset Anchors")
    resetAnchorsHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - resetAnchorsHeader.gap

    local resetAnchorsDesc = GUI:CreateLabel(tabContent,
        "Reset all unit frames, resource bars, and castbars to their default anchor positions. This will set all anchors to 'none' (manual positioning) with default offsets.",
        11, C.textMuted)
    resetAnchorsDesc:SetPoint("TOPLEFT", PADDING, y)
    resetAnchorsDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    resetAnchorsDesc:SetJustifyH("LEFT")
    resetAnchorsDesc:SetWordWrap(true)
    resetAnchorsDesc:SetHeight(30)
    y = y - 40

    local resetAnchorsBtn = GUI:CreateButton(tabContent, "Reset All Anchors", 200, 28, function()
        local QUI_Anchoring = ns.QUI_Anchoring
        if QUI_Anchoring and QUI_Anchoring.ResetAllAnchors then
            QUI_LayoutManager:ResetToDefaults()
        else
            print("|cFF56D1FFQuaziiUI|r: Anchoring system not available.")
        end
    end)
    resetAnchorsBtn:SetPoint("TOPLEFT", PADDING, y)
    y = y - 38

    -- Combat Status Text Indicator Section
    local combatTextHeader = GUI:CreateSectionHeader(tabContent, "Combat Status Text Indicator")
    combatTextHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - combatTextHeader.gap

    local combatTextDesc = GUI:CreateLabel(tabContent,
        "Displays '+Combat' or '-Combat' text on screen when entering or leaving combat. Useful for Shadowmeld skips.",
        11, C.textMuted)
    combatTextDesc:SetPoint("TOPLEFT", PADDING, y)
    combatTextDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    combatTextDesc:SetJustifyH("LEFT")
    combatTextDesc:SetWordWrap(true)
    combatTextDesc:SetHeight(15)
    y = y - 25

    -- Preview buttons
    local previewEnterBtn = GUI:CreateButton(tabContent, "Preview +Combat", 140, 28, function()
        if _G.QuaziiUI_PreviewCombatText then _G.QuaziiUI_PreviewCombatText("+Combat") end
    end)
    previewEnterBtn:SetPoint("TOPLEFT", PADDING, y)
    previewEnterBtn:SetPoint("RIGHT", tabContent, "CENTER", -5, 0)

    local previewLeaveBtn = GUI:CreateButton(tabContent, "Preview -Combat", 140, 28, function()
        if _G.QuaziiUI_PreviewCombatText then _G.QuaziiUI_PreviewCombatText("-Combat") end
    end)
    previewLeaveBtn:SetPoint("LEFT", tabContent, "CENTER", 5, 0)
    previewLeaveBtn:SetPoint("TOP", previewEnterBtn, "TOP", 0, 0)
    previewLeaveBtn:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    y = y - 38

    local combatTextDB = db.combatText
    if combatTextDB then
        local combatTextCheck = GUI:CreateFormCheckbox(tabContent, "Enable Combat Text", "enabled", combatTextDB, function(val)
            if _G.QuaziiUI_RefreshCombatText then _G.QuaziiUI_RefreshCombatText() end
        end)
        combatTextCheck:SetPoint("TOPLEFT", PADDING, y)
        combatTextCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local displayTimeSlider = GUI:CreateFormSlider(tabContent, "Display Time (sec)", 0.3, 3.0, 0.1, "displayTime", combatTextDB, function()
            if _G.QuaziiUI_RefreshCombatText then _G.QuaziiUI_RefreshCombatText() end
        end)
        displayTimeSlider:SetPoint("TOPLEFT", PADDING, y)
        displayTimeSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local fadeTimeSlider = GUI:CreateFormSlider(tabContent, "Fade Duration (sec)", 0.1, 1.0, 0.05, "fadeTime", combatTextDB, function()
            if _G.QuaziiUI_RefreshCombatText then _G.QuaziiUI_RefreshCombatText() end
        end)
        fadeTimeSlider:SetPoint("TOPLEFT", PADDING, y)
        fadeTimeSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local fontSizeSlider = GUI:CreateFormSlider(tabContent, "Font Size", 12, 48, 1, "fontSize", combatTextDB, function()
            if _G.QuaziiUI_RefreshCombatText then _G.QuaziiUI_RefreshCombatText() end
        end)
        fontSizeSlider:SetPoint("TOPLEFT", PADDING, y)
        fontSizeSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local xOffsetSlider = GUI:CreateFormSlider(tabContent, "X Position Offset", -2000, 2000, 1, "xOffset", combatTextDB, function()
            if _G.QuaziiUI_RefreshCombatText then _G.QuaziiUI_RefreshCombatText() end
        end)
        xOffsetSlider:SetPoint("TOPLEFT", PADDING, y)
        xOffsetSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local yOffsetSlider = GUI:CreateFormSlider(tabContent, "Y Position Offset", -2000, 2000, 1, "yOffset", combatTextDB, function()
            if _G.QuaziiUI_RefreshCombatText then _G.QuaziiUI_RefreshCombatText() end
        end)
        yOffsetSlider:SetPoint("TOPLEFT", PADDING, y)
        yOffsetSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local enterColorPicker = GUI:CreateFormColorPicker(tabContent, "+Combat Text Color", "enterCombatColor", combatTextDB, function()
            if _G.QuaziiUI_RefreshCombatText then _G.QuaziiUI_RefreshCombatText() end
        end)
        enterColorPicker:SetPoint("TOPLEFT", PADDING, y)
        enterColorPicker:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local leaveColorPicker = GUI:CreateFormColorPicker(tabContent, "-Combat Text Color", "leaveCombatColor", combatTextDB, function()
            if _G.QuaziiUI_RefreshCombatText then _G.QuaziiUI_RefreshCombatText() end
        end)
        leaveColorPicker:SetPoint("TOPLEFT", PADDING, y)
        leaveColorPicker:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW
    end

    y = y - 10

    -- Automation Section
    local autoHeader = GUI:CreateSectionHeader(tabContent, "Automation")
    autoHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - autoHeader.gap

    local keystoneCheck = GUI:CreateFormCheckbox(tabContent, "Auto Insert M+ Keys", "autoInsertKey", db.general, nil)
    keystoneCheck:SetPoint("TOPLEFT", PADDING, y)
    keystoneCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    y = y - FORM_ROW

    local sellJunkCheck = GUI:CreateFormCheckbox(tabContent, "Sell Gray Items", "sellJunk", db.general, nil)
    sellJunkCheck:SetPoint("TOPLEFT", PADDING, y)
    sellJunkCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    y = y - FORM_ROW

    local repairOptions = {
        {value = "off", text = "Off"},
        {value = "personal", text = "Personal Gold"},
        {value = "guild", text = "Guild Bank First"},
    }
    local repairDropdown = GUI:CreateFormDropdown(tabContent, "Auto Repair", repairOptions, "autoRepair", db.general, nil)
    repairDropdown:SetPoint("TOPLEFT", PADDING, y)
    repairDropdown:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    y = y - FORM_ROW

    local autoRoleCheck = GUI:CreateFormCheckbox(tabContent, "Auto Accept Role Check", "autoRoleAccept", db.general, nil)
    autoRoleCheck:SetPoint("TOPLEFT", PADDING, y)
    autoRoleCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    y = y - FORM_ROW

    local inviteOptions = {
        {value = "off", text = "Off"},
        {value = "all", text = "All Invites"},
        {value = "friends", text = "Friends Only"},
        {value = "guild", text = "Guild Only"},
        {value = "both", text = "Friends & Guild"},
    }
    local inviteDropdown = GUI:CreateFormDropdown(tabContent, "Auto Accept Invites", inviteOptions, "autoAcceptInvites", db.general, nil)
    inviteDropdown:SetPoint("TOPLEFT", PADDING, y)
    inviteDropdown:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    y = y - FORM_ROW

    local autoAcceptQuestCheck = GUI:CreateFormCheckbox(tabContent, "Auto Accept Quests", "autoAcceptQuest", db.general, nil)
    autoAcceptQuestCheck:SetPoint("TOPLEFT", PADDING, y)
    autoAcceptQuestCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    y = y - FORM_ROW

    local autoTurnInCheck = GUI:CreateFormCheckbox(tabContent, "Auto Turn-In Quests", "autoTurnInQuest", db.general, nil)
    autoTurnInCheck:SetPoint("TOPLEFT", PADDING, y)
    autoTurnInCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    y = y - FORM_ROW

    local questShiftCheck = GUI:CreateFormCheckbox(tabContent, "Shift Pauses Accept & Turn-In", "questHoldShift", db.general, nil)
    questShiftCheck:SetPoint("TOPLEFT", PADDING, y)
    questShiftCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    y = y - FORM_ROW

    local fastLootCheck = GUI:CreateFormCheckbox(tabContent, "Faster Auto Loot", "fastAutoLoot", db.general, function(enabled)
        if enabled then
            SetCVar("autoLootDefault", "1")
        end
    end)
    fastLootCheck:SetPoint("TOPLEFT", PADDING, y)
    fastLootCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    y = y - FORM_ROW

    local fastLootDesc = GUI:CreateLabel(tabContent, "Instantly loots all items. Enables WoW's Auto Loot setting automatically.", 11, C.textMuted)
    fastLootDesc:SetPoint("TOPLEFT", PADDING, y + 4)
    fastLootDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    fastLootDesc:SetJustifyH("LEFT")
    y = y - 16

    local autoGossipCheck = GUI:CreateFormCheckbox(tabContent, "Auto-Select Single Gossip Option", "autoSelectGossip", db.general, nil)
    autoGossipCheck:SetPoint("TOPLEFT", PADDING, y)
    autoGossipCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    y = y - FORM_ROW

    y = y - 10

    -- Quick Salvage Section
    local quickSalvageHeader = GUI:CreateSectionHeader(tabContent, "Quick Salvage")
    quickSalvageHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - quickSalvageHeader.gap

    local quickSalvageDesc = GUI:CreateLabel(tabContent,
        "Mill, prospect, or disenchant items with a single click using a modifier key. Requires the corresponding profession.",
        11, C.textMuted)
    quickSalvageDesc:SetPoint("TOPLEFT", PADDING, y)
    quickSalvageDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    quickSalvageDesc:SetJustifyH("LEFT")
    quickSalvageDesc:SetWordWrap(true)
    quickSalvageDesc:SetHeight(20)
    y = y - 30

    -- Ensure quickSalvage settings exist
    if not db.general.quickSalvage then
        db.general.quickSalvage = { enabled = false, modifier = "ALT" }
    end
    local qsDB = db.general.quickSalvage

    local qsEnableCheck = GUI:CreateFormCheckbox(tabContent, "Enable Quick Salvage", "enabled", qsDB, function()
        if _G.QuaziiUI_RefreshQuickSalvage then _G.QuaziiUI_RefreshQuickSalvage() end
    end)
    qsEnableCheck:SetPoint("TOPLEFT", PADDING, y)
    qsEnableCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    y = y - FORM_ROW

    local modifierOptions = {
        {value = "ALT", text = "Alt"},
        {value = "ALTCTRL", text = "Alt + Ctrl"},
        {value = "ALTSHIFT", text = "Alt + Shift"},
    }
    local qsModifierDropdown = GUI:CreateFormDropdown(tabContent, "Modifier Key", modifierOptions, "modifier", qsDB, function()
        if _G.QuaziiUI_RefreshQuickSalvage then _G.QuaziiUI_RefreshQuickSalvage() end
    end)
    qsModifierDropdown:SetPoint("TOPLEFT", PADDING, y)
    qsModifierDropdown:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    y = y - FORM_ROW

    local qsActionsDesc = GUI:CreateLabel(tabContent,
        "Milling: Herbs (5+ stack)  |  Prospecting: Ores (5+ stack)  |  Disenchanting: Green+ gear",
        11, C.textMuted)
    qsActionsDesc:SetPoint("TOPLEFT", PADDING, y)
    qsActionsDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    qsActionsDesc:SetJustifyH("LEFT")
    qsActionsDesc:SetWordWrap(true)
    qsActionsDesc:SetHeight(20)
    y = y - 30

    y = y - 10

    -- Others Section
    local othersHeader = GUI:CreateSectionHeader(tabContent, "Others")
    othersHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - othersHeader.gap

    local minimapBtnDB = db.minimapButton
    if minimapBtnDB then
        local showMinimapIconCheck = GUI:CreateFormCheckbox(tabContent, "Hide QUI Minimap Icon", "hide", minimapBtnDB, function(dbVal)
            local LibDBIcon = LibStub("LibDBIcon-1.0", true)
            if LibDBIcon then
                if dbVal then
                    LibDBIcon:Hide("QuaziiUI")
                else
                    LibDBIcon:Show("QuaziiUI")
                end
            end
        end)
        showMinimapIconCheck:SetPoint("TOPLEFT", PADDING, y)
        showMinimapIconCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW
    end

    local panelAlphaSlider = GUI:CreateFormSlider(tabContent, "QUI Panel Transparency", 0.3, 1.0, 0.01, "configPanelAlpha", db, function(val)
        local mainFrame = GUI.MainFrame
        if mainFrame then
            local bgColor = GUI.Colors.bg
            mainFrame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], val)
        end
    end)
    panelAlphaSlider:SetPoint("TOPLEFT", PADDING, y)
    panelAlphaSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    y = y - FORM_ROW

    tabContent:SetHeight(math.abs(y) + 50)
end

-- Create full page wrapper
local function CreateGeneralQoLPage(parent)
    local scroll, content = OptionsShared.CreateScrollableContent(parent)
    BuildGeneralTab(content)
end

-- Export
local GeneralOptions = {
    BuildGeneralTab = BuildGeneralTab,
    CreateGeneralQoLPage = CreateGeneralQoLPage,
}

ns.GeneralOptions = GeneralOptions

-- Register with Options Page Registry
if ns.OptionsPageRegistry then
    ns.OptionsPageRegistry:RegisterSimplePage("general", "General & QoL", CreateGeneralQoLPage, 10)
end

return GeneralOptions
