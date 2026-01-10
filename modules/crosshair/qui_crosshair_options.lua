--[[
    qui_crosshair_options.lua
    Options UI for Crosshair and Reticle components
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

if not ns.IsModuleEnabled("crosshair") then
    return
end

-- Refresh callbacks
local function RefreshCrosshair()
    if _G.QuaziiUI_RefreshCrosshair then
        _G.QuaziiUI_RefreshCrosshair()
    end
end

local function RefreshReticle()
    if _G.QuaziiUI_RefreshReticle then
        _G.QuaziiUI_RefreshReticle()
    end
end

-- Build crosshair tab (Cursor & Crosshair sub-tab)
local function BuildCrosshairTab(tabContent)
    local db = GetDB()
    local y = -10

    -- Set search context for auto-registration
    GUI:SetSearchContext({tabIndex = 1, tabName = "General & QoL", subTabIndex = 3, subTabName = "Cursor & Crosshair"})

    -- ========== CURSOR RING SECTION (before crosshair) ==========
    local cursorHeader = GUI:CreateSectionHeader(tabContent, "Cursor Ring")
    cursorHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - cursorHeader.gap

    if db and db.reticle then
        local cr = db.reticle

        local enableCheck = GUI:CreateFormCheckbox(tabContent, "Enable Reticle", "enabled", cr, RefreshReticle)
        enableCheck:SetPoint("TOPLEFT", PADDING, y)
        enableCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Reticle Style dropdown
        local reticleOptions = {
            {value = "dot", text = "Dot"},
            {value = "cross", text = "Cross"},
            {value = "chevron", text = "Chevron"},
            {value = "diamond", text = "Diamond"},
        }
        local reticleDropdown = GUI:CreateFormDropdown(tabContent, "Reticle Style", reticleOptions, "reticleStyle", cr, RefreshReticle)
        reticleDropdown:SetPoint("TOPLEFT", PADDING, y)
        reticleDropdown:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local reticleSizeSlider = GUI:CreateFormSlider(tabContent, "Reticle Size", 4, 20, 1, "reticleSize", cr, RefreshReticle)
        reticleSizeSlider:SetPoint("TOPLEFT", PADDING, y)
        reticleSizeSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- Ring Style dropdown
        local ringStyleOptions = {
            {value = "thin", text = "Thin"},
            {value = "standard", text = "Standard"},
            {value = "thick", text = "Thick"},
            {value = "solid", text = "Solid"},
        }
        local ringStyleDropdown = GUI:CreateFormDropdown(tabContent, "Ring Style", ringStyleOptions, "ringStyle", cr, RefreshReticle)
        ringStyleDropdown:SetPoint("TOPLEFT", PADDING, y)
        ringStyleDropdown:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local ringSizeSlider = GUI:CreateFormSlider(tabContent, "Ring Size", 20, 80, 1, "ringSize", cr, RefreshReticle)
        ringSizeSlider:SetPoint("TOPLEFT", PADDING, y)
        ringSizeSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local classColorCheck = GUI:CreateFormCheckbox(tabContent, "Use Class Color", "useClassColor", cr, RefreshReticle)
        classColorCheck:SetPoint("TOPLEFT", PADDING, y)
        classColorCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local customColorPicker = GUI:CreateFormColorPicker(tabContent, "Custom Color", "customColor", cr, RefreshReticle)
        customColorPicker:SetPoint("TOPLEFT", PADDING, y)
        customColorPicker:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local combatAlphaSlider = GUI:CreateFormSlider(tabContent, "Combat Opacity", 0, 1, 0.05, "inCombatAlpha", cr, RefreshReticle)
        combatAlphaSlider:SetPoint("TOPLEFT", PADDING, y)
        combatAlphaSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local oocAlphaSlider = GUI:CreateFormSlider(tabContent, "Out-of-Combat Opacity", 0, 1, 0.05, "outCombatAlpha", cr, RefreshReticle)
        oocAlphaSlider:SetPoint("TOPLEFT", PADDING, y)
        oocAlphaSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local hideOOCCheck = GUI:CreateFormCheckbox(tabContent, "Hide Outside Combat", "hideOutOfCombat", cr, RefreshReticle)
        hideOOCCheck:SetPoint("TOPLEFT", PADDING, y)
        hideOOCCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        -- GCD Settings sub-section
        y = y - 10  -- Extra spacing before sub-section
        local gcdLabel = GUI:CreateLabel(tabContent, "GCD Settings", 12, C.accent)
        gcdLabel:SetPoint("TOPLEFT", PADDING, y)
        y = y - 20

        local gcdEnableCheck = GUI:CreateFormCheckbox(tabContent, "Enable GCD Swipe", "gcdEnabled", cr, RefreshReticle)
        gcdEnableCheck:SetPoint("TOPLEFT", PADDING, y)
        gcdEnableCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local gcdFadeSlider = GUI:CreateFormSlider(tabContent, "Ring Fade During GCD", 0, 1, 0.05, "gcdFadeRing", cr, RefreshReticle)
        gcdFadeSlider:SetPoint("TOPLEFT", PADDING, y)
        gcdFadeSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local gcdReverseCheck = GUI:CreateFormCheckbox(tabContent, "Reverse Swipe", "gcdReverse", cr, RefreshReticle)
        gcdReverseCheck:SetPoint("TOPLEFT", PADDING, y)
        gcdReverseCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local rightClickCheck = GUI:CreateFormCheckbox(tabContent, "Hide on Right-Click", "hideOnRightClick", cr, RefreshReticle)
        rightClickCheck:SetPoint("TOPLEFT", PADDING, y)
        rightClickCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local cursorTipText = GUI:CreateLabel(tabContent, "Note that cursor replacements consume some CPU resources due to continuous tracking. Negligible on modern CPUs.", 11, C.textMuted)
        cursorTipText:SetPoint("TOPLEFT", PADDING, y)
        cursorTipText:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        cursorTipText:SetJustifyH("LEFT")
        cursorTipText:SetWordWrap(true)
        y = y - 40
    end

    y = y - 20  -- Spacing between sections

    -- ========== QUI CROSSHAIR SECTION ==========
    local crossHeader = GUI:CreateSectionHeader(tabContent, "QUI Crosshair")
    crossHeader:SetPoint("TOPLEFT", PADDING, y)
    y = y - crossHeader.gap

    if db and db.crosshair then
        local ch = db.crosshair

        local enableCheck = GUI:CreateFormCheckbox(tabContent, "Show Crosshair", "enabled", ch, RefreshCrosshair)
        enableCheck:SetPoint("TOPLEFT", PADDING, y)
        enableCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local combatCheck = GUI:CreateFormCheckbox(tabContent, "Combat Only", "onlyInCombat", ch, RefreshCrosshair)
        combatCheck:SetPoint("TOPLEFT", PADDING, y)
        combatCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        if not ch.lineColor then
            ch.lineColor = { ch.r or 0.286, ch.g or 0.929, ch.b or 1, ch.a or 1 }
        end
        local crossColor = GUI:CreateFormColorPicker(tabContent, "Crosshair Color", "lineColor", ch, function()
            ch.r, ch.g, ch.b, ch.a = ch.lineColor[1], ch.lineColor[2], ch.lineColor[3], ch.lineColor[4]
            RefreshCrosshair()
        end)
        crossColor:SetPoint("TOPLEFT", PADDING, y)
        crossColor:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        if not ch.borderColorTable then
            ch.borderColorTable = { ch.borderR or 0, ch.borderG or 0, ch.borderB or 0, ch.borderA or 1 }
        end
        local borderColor = GUI:CreateFormColorPicker(tabContent, "Outline Color", "borderColorTable", ch, function()
            ch.borderR, ch.borderG, ch.borderB, ch.borderA = ch.borderColorTable[1], ch.borderColorTable[2], ch.borderColorTable[3], ch.borderColorTable[4]
            RefreshCrosshair()
        end)
        borderColor:SetPoint("TOPLEFT", PADDING, y)
        borderColor:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local sizeSlider = GUI:CreateFormSlider(tabContent, "Length", 5, 50, 1, "size", ch, RefreshCrosshair)
        sizeSlider:SetPoint("TOPLEFT", PADDING, y)
        sizeSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local thickSlider = GUI:CreateFormSlider(tabContent, "Thickness", 1, 10, 1, "thickness", ch, RefreshCrosshair)
        thickSlider:SetPoint("TOPLEFT", PADDING, y)
        thickSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local borderSlider = GUI:CreateFormSlider(tabContent, "Outline Size", 0, 5, 1, "borderSize", ch, RefreshCrosshair)
        borderSlider:SetPoint("TOPLEFT", PADDING, y)
        borderSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local strataOptions = {
            {value = "BACKGROUND", text = "Background"},
            {value = "LOW", text = "Low"},
            {value = "MEDIUM", text = "Medium"},
            {value = "HIGH", text = "High"},
            {value = "DIALOG", text = "Dialog"},
        }
        local strataDropdown = GUI:CreateFormDropdown(tabContent, "Frame Strata", strataOptions, "strata", ch, RefreshCrosshair)
        strataDropdown:SetPoint("TOPLEFT", PADDING, y)
        strataDropdown:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local xOffsetSlider = GUI:CreateFormSlider(tabContent, "X-Offset", -500, 500, 1, "offsetX", ch, RefreshCrosshair)
        xOffsetSlider:SetPoint("TOPLEFT", PADDING, y)
        xOffsetSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW

        local yOffsetSlider = GUI:CreateFormSlider(tabContent, "Y-Offset", -500, 500, 1, "offsetY", ch, RefreshCrosshair)
        yOffsetSlider:SetPoint("TOPLEFT", PADDING, y)
        yOffsetSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW
    end

    tabContent:SetHeight(math.abs(y) + 50)
end

-- Export
local CrosshairOptions = {
    BuildCrosshairTab = BuildCrosshairTab,
}

return CrosshairOptions
