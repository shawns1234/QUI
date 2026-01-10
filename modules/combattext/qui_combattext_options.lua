--[[
    qui_combattext_options.lua
    Options UI for Combat Text component
]]

local ADDON_NAME, ns = ...
local QUI = QuaziiUI
local GUI = QUI.GUI
local QUICore = ns.Addon
local C = GUI.Colors
local OptionsShared = ns.OptionsShared

-- Import constants
local PADDING = OptionsShared.CONSTANTS.PADDING
local FORM_ROW = 32
local GetDB = OptionsShared.GetDB

if not ns.IsModuleEnabled("combattext") then
    return
end

-- Build combat text section (used in General tab)
local function BuildCombatTextSection(tabContent, y)
    local db = GetDB()
    y = y or -10

    -- Combat Status Text Indicator Section
    GUI:SetSearchSection("Combat Status Text Indicator")
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
    return y
end

-- Export
local CombatTextOptions = {
    BuildCombatTextSection = BuildCombatTextSection,
}

return CombatTextOptions
