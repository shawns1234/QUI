--[[
    qui_buffbar_options.lua
    Options UI for Buff & Debuff Borders component
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

if not ns.IsModuleEnabled("buffbar") then
    return
end

-- Refresh function for buff borders
local function RefreshBuffBorders()
    if _G.QuaziiUI_RefreshBuffBorders then
        _G.QuaziiUI_RefreshBuffBorders()
    end
end

local function BuildBuffDebuffTab(tabContent)
    local db = GetDB()
    local y = -10

    -- Set search context for auto-registration
    GUI:SetSearchContext({tabIndex = 1, tabName = "General & QoL", subTabIndex = 4, subTabName = "Buff & Debuff"})

    -- Section Header
    local header = GUI:CreateSectionHeader(tabContent, "Buff & Debuff Borders")
    header:SetPoint("TOPLEFT", PADDING, y)
    y = y - header.gap

    -- Description
    local desc = GUI:CreateLabel(tabContent, "Modifies borders and font size of Blizzard default Buff and Debuff frames, normally placed beside minimap.", 11, C.textMuted)
    desc:SetPoint("TOPLEFT", PADDING, y)
    desc:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetHeight(30)
    y = y - 40

    if db and db.buffBorders then
        -- Enable Buff Borders
        local enableBuffs = GUI:CreateFormCheckbox(tabContent, "Enable Buff Borders",
            "enableBuffs", db.buffBorders, RefreshBuffBorders)
        enableBuffs:SetPoint("TOPLEFT", PADDING, y)
        enableBuffs:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Enable Debuff Borders
        local enableDebuffs = GUI:CreateFormCheckbox(tabContent, "Enable Debuff Borders",
            "enableDebuffs", db.buffBorders, RefreshBuffBorders)
        enableDebuffs:SetPoint("TOPLEFT", PADDING, y)
        enableDebuffs:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Border Size slider
        local borderSlider = GUI:CreateFormSlider(tabContent, "Border Size", 1, 5, 0.5,
            "borderSize", db.buffBorders, RefreshBuffBorders)
        borderSlider:SetPoint("TOPLEFT", PADDING, y)
        borderSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Font Size slider
        local fontSlider = GUI:CreateFormSlider(tabContent, "Font Size", 8, 20, 1,
            "fontSize", db.buffBorders, RefreshBuffBorders)
        fontSlider:SetPoint("TOPLEFT", PADDING, y)
        fontSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW
    else
        local info = GUI:CreateLabel(tabContent, "Buff/Debuff settings not available", 12, C.textMuted)
        info:SetPoint("TOPLEFT", PADDING, y)
    end

    tabContent:SetHeight(math.abs(y) + 50)
end

-- Export
local BuffBarOptions = {
    BuildBuffDebuffTab = BuildBuffDebuffTab,
}

ns.BuffBarOptions = BuffBarOptions
return BuffBarOptions
