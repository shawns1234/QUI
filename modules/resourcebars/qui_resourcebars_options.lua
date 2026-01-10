--[[
    QUI Resource Bars Options
    Options UI for Resource Bars module
    Handles configuration for primary and secondary class resource bars
]]

local ADDON_NAME, ns = ...

if not ns.IsModuleEnabled("resourcebars") then
    return
end

local QUI = QuaziiUI
local GUI = QUI.GUI
local QUICore = ns.Addon
local C = GUI.Colors
local OptionsShared = ns.OptionsShared

-- Import shared utilities
local GetDB = OptionsShared.GetDB
local CreateScrollableContent = OptionsShared.CreateScrollableContent
local GetTextureList = OptionsShared.GetTextureList

-- Reference to resource bars module
local QUI_ResourceBars = ns.QUI_ResourceBars

---------------------------------------------------------------------------
-- CREATE RESOURCE BARS OPTIONS PAGE
---------------------------------------------------------------------------
local function CreateResourceBarsPage(parent)
    local scroll, content = CreateScrollableContent(parent)
    
    local db = GetDB()
    if not db then return scroll, content end

    -- Set search context for widget auto-registration
    GUI:SetSearchContext({tabIndex = 1, tabName = "Resource Bars"})

    -- Ensure powerBar settings exist
    if not db.powerBar then db.powerBar = {} end
    if not db.secondaryPowerBar then db.secondaryPowerBar = {} end

    -- Ensure all fields exist with defaults
    local primary = db.powerBar
    if primary.enabled == nil then primary.enabled = true end
    if primary.width == nil then primary.width = 310 end
    if primary.height == nil then primary.height = 8 end
    if primary.offsetX == nil then primary.offsetX = 0 end
    if primary.offsetY == nil then primary.offsetY = 25 end
    if primary.texture == nil then primary.texture = "Solid" end
    if primary.colorMode == nil then primary.colorMode = "power" end
    if primary.usePowerColor == nil then primary.usePowerColor = true end
    if primary.useClassColor == nil then primary.useClassColor = false end
    if primary.useCustomColor == nil then primary.useCustomColor = false end
    if primary.customColor == nil then primary.customColor = {0.2, 0.6, 1.0, 1} end
    if primary.bgColor == nil then primary.bgColor = {0.1, 0.1, 0.1, 0.8} end
    if primary.showText == nil then primary.showText = true end
    if primary.showPercent == nil then primary.showPercent = true end
    if primary.textSize == nil then primary.textSize = 14 end
    if primary.textX == nil then primary.textX = 0 end
    if primary.textY == nil then primary.textY = 2 end
    if primary.borderSize == nil then primary.borderSize = 1 end
    if primary.orientation == nil then primary.orientation = "AUTO" end

    local secondary = db.secondaryPowerBar
    if secondary.enabled == nil then secondary.enabled = true end
    if secondary.autoAttach == nil then secondary.autoAttach = true end
    if secondary.width == nil then secondary.width = 310 end
    if secondary.height == nil then secondary.height = 8 end
    if secondary.lockedBaseX == nil then secondary.lockedBaseX = 0 end
    if secondary.lockedBaseY == nil then secondary.lockedBaseY = 0 end
    if secondary.offsetX == nil then secondary.offsetX = 0 end
    if secondary.offsetY == nil then secondary.offsetY = 0 end
    if secondary.texture == nil then secondary.texture = "Solid" end
    if secondary.colorMode == nil then secondary.colorMode = "power" end
    if secondary.usePowerColor == nil then secondary.usePowerColor = true end
    if secondary.useClassColor == nil then secondary.useClassColor = false end
    if secondary.useCustomColor == nil then secondary.useCustomColor = false end
    if secondary.customColor == nil then secondary.customColor = {1.0, 0.8, 0.2, 1} end
    if secondary.bgColor == nil then secondary.bgColor = {0.1, 0.1, 0.1, 0.8} end
    if secondary.showText == nil then secondary.showText = true end
    if secondary.showPercent == nil then secondary.showPercent = false end
    if secondary.showFragmentedPowerBarText == nil then secondary.showFragmentedPowerBarText = true end
    if secondary.textSize == nil then secondary.textSize = 14 end
    if secondary.textX == nil then secondary.textX = 0 end
    if secondary.textY == nil then secondary.textY = 2 end
    if secondary.borderSize == nil then secondary.borderSize = 1 end
    if secondary.orientation == nil then secondary.orientation = "AUTO" end

    -- Callback to refresh power bars
    local function RefreshPowerBars()
        if QUI_ResourceBars then
            if QUI_ResourceBars.UpdatePrimaryBar then
                QUI_ResourceBars:UpdatePrimaryBar()
            end
            if QUI_ResourceBars.UpdateSecondaryBar then
                QUI_ResourceBars:UpdateSecondaryBar()
            end
        end
    end

    local PAD = 10
    local CONTENT_PAD = OptionsShared.CONSTANTS.CONTENT_PAD or 6  -- Use CONTENT_PAD for nested sections to align with NESTED_INSET
    local y = -10
    local FORM_ROW = 32

    -- =====================================================
    -- GENERAL SETTINGS (Collapsible)
    -- =====================================================
    local generalSection, generalContent, y = OptionsShared.CreateCollapsibleSection(content, "General", y, PAD, false, nil)
    local generalY = 0

    local enablePrimary = GUI:CreateFormToggle(generalContent, "Enable Primary Class Resource Bar", "enabled", primary, RefreshPowerBars)
    generalY = OptionsShared.AddFormControl(generalContent, enablePrimary, generalY, PAD, FORM_ROW)

    local enableSecondary = GUI:CreateFormToggle(generalContent, "Enable Secondary Class Resource Bar", "enabled", secondary, RefreshPowerBars)
    generalY = OptionsShared.AddFormControl(generalContent, enableSecondary, generalY, PAD, FORM_ROW)

    local standalonePrimary = GUI:CreateFormToggle(generalContent, "Primary Standalone Mode", "standaloneMode", primary, RefreshPowerBars)
    generalY = OptionsShared.AddFormControl(generalContent, standalonePrimary, generalY, PAD, FORM_ROW)

    local standaloneSecondary = GUI:CreateFormToggle(generalContent, "Secondary Standalone Mode", "standaloneMode", secondary, RefreshPowerBars)
    generalY = OptionsShared.AddFormControl(generalContent, standaloneSecondary, generalY, PAD, FORM_ROW)

    local standaloneDesc, generalY = OptionsShared.AddFormNote(
        generalContent,
        "Standalone Mode: Bar won't fade or hide with CDM visibility. Use if you don't use Essential/Utility cooldown displays.",
        generalY,
        PAD
    )

    local unthrottledToggle = GUI:CreateFormToggle(generalContent, "Unthrottled CPU Use", "unthrottledCPU", primary, RefreshPowerBars)
    generalY = OptionsShared.AddFormControl(generalContent, unthrottledToggle, generalY, PAD, FORM_ROW)

    local unthrottledDesc, generalY = OptionsShared.AddFormNote(
        generalContent,
        "Remove throttle on the number of updates per second. Toggle on for smoother updates, but higher CPU Usage.",
        generalY,
        PAD
    )

    -- Update section height
    generalContent:SetHeight(math.abs(generalY) + 4)
    generalSection:UpdateHeight()

    -- =====================================================
    -- PRIMARY POWER BAR SECTION (Collapsible)
    -- =====================================================
    local primarySection, primaryContent, y = OptionsShared.CreateCollapsibleSection(content, "Primary Class Resource Bar", y, PAD, false, generalSection)
    
    -- =====================================================
    -- PRIMARY - GENERAL (Nested Section)
    -- =====================================================
    local primaryGeneralSection, primaryGeneralContent, primaryY = OptionsShared.CreateCollapsibleSection(primaryContent, "General", 0, PAD, false, nil)
    primaryY = 0

    local primaryDesc = GUI:CreateLabel(primaryGeneralContent, "Customize individual resource colors in the Resource Colors section at the bottom. Applied when 'Use Resource Type Color' is enabled.", 11, C.textMuted)
    primaryDesc:SetPoint("TOPLEFT", CONTENT_PAD, primaryY)
    primaryDesc:SetPoint("RIGHT", primaryGeneralContent, "RIGHT", -CONTENT_PAD, 0)
    primaryDesc:SetJustifyH("LEFT")
    primaryY = primaryY - 20

    local primaryWarning = GUI:CreateLabel(primaryGeneralContent, "Designed for horizontal layouts used by most players. Vertical mode requires extra setup (row offsets, orientation toggles).", 11, C.warning)
    primaryWarning:SetPoint("TOPLEFT", CONTENT_PAD, primaryY)
    primaryWarning:SetPoint("RIGHT", primaryGeneralContent, "RIGHT", -CONTENT_PAD, 0)
    primaryWarning:SetJustifyH("LEFT")
    primaryY = primaryY - 20

    -- Color options
    local customColorPickerPrimary

    local powerColorPrimary = GUI:CreateFormCheckbox(primaryGeneralContent, "Use Resource Type Color", "usePowerColor", primary, function()
        if primary.usePowerColor then
            primary.useClassColor = false
            primary.useCustomColor = false
            primary.colorMode = "power"
        else
            if not primary.useClassColor and not primary.useCustomColor then
                primary.usePowerColor = true
            end
        end
        if customColorPickerPrimary then
            customColorPickerPrimary:SetEnabled(primary.useCustomColor)
        end
        RefreshPowerBars()
    end)
    primaryY = OptionsShared.AddFormControl(primaryGeneralContent, powerColorPrimary, primaryY, CONTENT_PAD, FORM_ROW)

    local resourceColorDescPrimary = GUI:CreateLabel(primaryGeneralContent, "Uses per-resource colors from the Resource Colors section below.", 11)
    resourceColorDescPrimary:SetPoint("TOPLEFT", CONTENT_PAD, primaryY + 4)
    resourceColorDescPrimary:SetPoint("RIGHT", primaryGeneralContent, "RIGHT", -CONTENT_PAD, 0)
    resourceColorDescPrimary:SetJustifyH("LEFT")
    resourceColorDescPrimary:SetTextColor(0.6, 0.6, 0.6)
    primaryY = primaryY - FORM_ROW

    local classColorPrimary = GUI:CreateFormCheckbox(primaryGeneralContent, "Use Class Color", "useClassColor", primary, function()
        if primary.useClassColor then
            primary.usePowerColor = false
            primary.useCustomColor = false
            primary.colorMode = "class"
        else
            if not primary.usePowerColor and not primary.useCustomColor then
                primary.usePowerColor = true
            end
        end
        if customColorPickerPrimary then
            customColorPickerPrimary:SetEnabled(primary.useCustomColor)
        end
        RefreshPowerBars()
    end)
    primaryY = OptionsShared.AddFormControl(primaryGeneralContent, classColorPrimary, primaryY, CONTENT_PAD, FORM_ROW)

    local bgColorPrimary = GUI:CreateFormColorPicker(primaryGeneralContent, "Background Color", "bgColor", primary, RefreshPowerBars)
    primaryY = OptionsShared.AddFormControl(primaryGeneralContent, bgColorPrimary, primaryY, CONTENT_PAD, FORM_ROW)

    local customColorOverridePrimary = GUI:CreateFormCheckbox(primaryGeneralContent, "Custom Color Override", "useCustomColor", primary, function()
        if primary.useCustomColor then
            primary.usePowerColor = false
            primary.useClassColor = false
            primary.colorMode = "custom"
        else
            if not primary.usePowerColor and not primary.useClassColor then
                primary.usePowerColor = true
            end
        end
        if customColorPickerPrimary then
            customColorPickerPrimary:SetEnabled(primary.useCustomColor)
        end
        RefreshPowerBars()
    end)
    primaryY = OptionsShared.AddFormControl(primaryGeneralContent, customColorOverridePrimary, primaryY, CONTENT_PAD, FORM_ROW)

    customColorPickerPrimary = GUI:CreateFormColorPicker(primaryGeneralContent, "Custom Color", "customColor", primary, RefreshPowerBars)
    customColorPickerPrimary:SetEnabled(primary.useCustomColor)
    primaryY = OptionsShared.AddFormControl(primaryGeneralContent, customColorPickerPrimary, primaryY, CONTENT_PAD, FORM_ROW)

    -- Text display options
    local showTextPrimary = GUI:CreateFormCheckbox(primaryGeneralContent, "Show Number", "showText", primary, RefreshPowerBars)
    primaryY = OptionsShared.AddFormControl(primaryGeneralContent, showTextPrimary, primaryY, CONTENT_PAD, FORM_ROW)

    local showPercentPrimary = GUI:CreateFormCheckbox(primaryGeneralContent, "Show as Percent", "showPercent", primary, RefreshPowerBars)
    primaryY = OptionsShared.AddFormControl(primaryGeneralContent, showPercentPrimary, primaryY, CONTENT_PAD, FORM_ROW)

    -- Tick marks
    local showTicksPrimary = GUI:CreateFormCheckbox(primaryGeneralContent, "Show Tick Marks", "showTicks", primary, RefreshPowerBars)
    primaryY = OptionsShared.AddFormControl(primaryGeneralContent, showTicksPrimary, primaryY, CONTENT_PAD, FORM_ROW)

    local tickThicknessPrimary = GUI:CreateFormSlider(primaryGeneralContent, "Tick Thickness", 1, 4, 1, "tickThickness", primary, RefreshPowerBars)
    primaryY = OptionsShared.AddFormControl(primaryGeneralContent, tickThicknessPrimary, primaryY, CONTENT_PAD, FORM_ROW)

    local tickColorPrimary = GUI:CreateFormColorPicker(primaryGeneralContent, "Tick Color", "tickColor", primary, RefreshPowerBars)
    primaryY = OptionsShared.AddFormControl(primaryGeneralContent, tickColorPrimary, primaryY, CONTENT_PAD, FORM_ROW)

    local borderPrimary = GUI:CreateFormSlider(primaryGeneralContent, "Border Size", 0, 8, 1, "borderSize", primary, RefreshPowerBars)
    primaryY = OptionsShared.AddFormControl(primaryGeneralContent, borderPrimary, primaryY, CONTENT_PAD, FORM_ROW)

    -- Text sliders
    local textSizePrimary = GUI:CreateFormSlider(primaryGeneralContent, "Text Size", 8, 50, 1, "textSize", primary, RefreshPowerBars)
    primaryY = OptionsShared.AddFormControl(primaryGeneralContent, textSizePrimary, primaryY, CONTENT_PAD, FORM_ROW)

    local textXPrimary = GUI:CreateFormSlider(primaryGeneralContent, "Text X Offset", -500, 500, 1, "textX", primary, RefreshPowerBars)
    primaryY = OptionsShared.AddFormControl(primaryGeneralContent, textXPrimary, primaryY, CONTENT_PAD, FORM_ROW)

    local textYPrimary = GUI:CreateFormSlider(primaryGeneralContent, "Text Y Offset", -500, 500, 1, "textY", primary, RefreshPowerBars)
    primaryY = OptionsShared.AddFormControl(primaryGeneralContent, textYPrimary, primaryY, CONTENT_PAD, FORM_ROW)

    -- Text color settings
    local textCustomColorPrimary

    local textUseClassColorPrimary = GUI:CreateFormCheckbox(primaryGeneralContent, "Use Class Color for Text", "textUseClassColor", primary, function()
        if textCustomColorPrimary then
            textCustomColorPrimary:SetEnabled(not primary.textUseClassColor)
        end
        RefreshPowerBars()
    end)
    primaryY = OptionsShared.AddFormControl(primaryGeneralContent, textUseClassColorPrimary, primaryY, CONTENT_PAD, FORM_ROW)

    textCustomColorPrimary = GUI:CreateFormColorPicker(primaryGeneralContent, "Custom Text Color", "textCustomColor", primary, RefreshPowerBars)
    textCustomColorPrimary:SetEnabled(not primary.textUseClassColor)
    primaryY = OptionsShared.AddFormControl(primaryGeneralContent, textCustomColorPrimary, primaryY, CONTENT_PAD, FORM_ROW)

    local texturePrimary = GUI:CreateFormDropdown(primaryGeneralContent, "Bar Texture", GetTextureList(), "texture", primary, RefreshPowerBars)
    primaryY = OptionsShared.AddFormControl(primaryGeneralContent, texturePrimary, primaryY, CONTENT_PAD, FORM_ROW)

    -- Update General section height
    primaryGeneralContent:SetHeight(math.abs(primaryY) + 4)
    primaryGeneralSection:UpdateHeight()

    -- =====================================================
    -- PRIMARY - LAYOUT (Nested Section)
    -- =====================================================
    local primaryLayoutSection
    if ns.QUI_LayoutControl_Options then
        local function OnAnchorChange()
            RefreshPowerBars()
        end

        local bar = QUI_ResourceBars and QUI_ResourceBars:GetPrimaryBar()
        -- Create as nested section inside primaryContent
        primaryLayoutSection, _, _ = ns.QUI_LayoutControl_Options:CreateLayoutControl(
                primaryContent, bar, 0, PAD, FORM_ROW, OnAnchorChange, {
                    previousSection = primaryGeneralSection,
                    sectionTitle = "Layout",
                    anchorKey = "anchorTo",
                    maxAnchors = 2,
                    excludeSelf = "primary"
                }
        )
    end

    -- Update primary section height (will be handled by nested section tracking)
    primarySection:UpdateHeight()

    -- =====================================================
    -- SECONDARY POWER BAR SECTION (Collapsible)
    -- =====================================================
    local secondarySection, secondaryContent, y = OptionsShared.CreateCollapsibleSection(content, "Secondary Class Resource Bar", y, PAD, false, primarySection)
    
    -- =====================================================
    -- SECONDARY - GENERAL (Nested Section)
    -- =====================================================
    local secondaryGeneralSection, secondaryGeneralContent, secondaryY = OptionsShared.CreateCollapsibleSection(secondaryContent, "General", 0, PAD, false, nil)
    secondaryY = 0

    -- Color options
    local customColorPickerSecondary

    local powerColorSecondary = GUI:CreateFormCheckbox(secondaryGeneralContent, "Use Resource Type Color", "usePowerColor", secondary, function()
        if secondary.usePowerColor then
            secondary.useClassColor = false
            secondary.useCustomColor = false
            secondary.colorMode = "power"
        else
            if not secondary.useClassColor and not secondary.useCustomColor then
                secondary.usePowerColor = true
            end
        end
        if customColorPickerSecondary then
            customColorPickerSecondary:SetEnabled(secondary.useCustomColor)
        end
        RefreshPowerBars()
    end)
    secondaryY = OptionsShared.AddFormControl(secondaryGeneralContent, powerColorSecondary, secondaryY, CONTENT_PAD, FORM_ROW)

    local resourceColorDescSecondary = GUI:CreateLabel(secondaryGeneralContent, "Uses per-resource colors from the Resource Colors section below.", 11)
    resourceColorDescSecondary:SetPoint("TOPLEFT", CONTENT_PAD, secondaryY + 4)
    resourceColorDescSecondary:SetPoint("RIGHT", secondaryGeneralContent, "RIGHT", -CONTENT_PAD, 0)
    resourceColorDescSecondary:SetJustifyH("LEFT")
    resourceColorDescSecondary:SetTextColor(0.6, 0.6, 0.6)
    secondaryY = secondaryY - FORM_ROW

    local classColorSecondary = GUI:CreateFormCheckbox(secondaryGeneralContent, "Use Class Color", "useClassColor", secondary, function()
        if secondary.useClassColor then
            secondary.usePowerColor = false
            secondary.useCustomColor = false
            secondary.colorMode = "class"
        else
            if not secondary.usePowerColor and not secondary.useCustomColor then
                secondary.usePowerColor = true
            end
        end
        if customColorPickerSecondary then
            customColorPickerSecondary:SetEnabled(secondary.useCustomColor)
        end
        RefreshPowerBars()
    end)
    secondaryY = OptionsShared.AddFormControl(secondaryGeneralContent, classColorSecondary, secondaryY, CONTENT_PAD, FORM_ROW)

    local bgColorSecondary = GUI:CreateFormColorPicker(secondaryGeneralContent, "Background Color", "bgColor", secondary, RefreshPowerBars)
    secondaryY = OptionsShared.AddFormControl(secondaryGeneralContent, bgColorSecondary, secondaryY, CONTENT_PAD, FORM_ROW)

    local customColorOverrideSecondary = GUI:CreateFormCheckbox(secondaryGeneralContent, "Custom Color Override", "useCustomColor", secondary, function()
        if secondary.useCustomColor then
            secondary.usePowerColor = false
            secondary.useClassColor = false
            secondary.colorMode = "custom"
        else
            if not secondary.usePowerColor and not secondary.useClassColor then
                secondary.usePowerColor = true
            end
        end
        if customColorPickerSecondary then
            customColorPickerSecondary:SetEnabled(secondary.useCustomColor)
        end
        RefreshPowerBars()
    end)
    secondaryY = OptionsShared.AddFormControl(secondaryGeneralContent, customColorOverrideSecondary, secondaryY, CONTENT_PAD, FORM_ROW)

    customColorPickerSecondary = GUI:CreateFormColorPicker(secondaryGeneralContent, "Custom Color", "customColor", secondary, RefreshPowerBars)
    customColorPickerSecondary:SetEnabled(secondary.useCustomColor)
    secondaryY = OptionsShared.AddFormControl(secondaryGeneralContent, customColorPickerSecondary, secondaryY, CONTENT_PAD, FORM_ROW)

    -- Text display options
    local showTextSecondary = GUI:CreateFormCheckbox(secondaryGeneralContent, "Show Number", "showText", secondary, RefreshPowerBars)
    secondaryY = OptionsShared.AddFormControl(secondaryGeneralContent, showTextSecondary, secondaryY, CONTENT_PAD, FORM_ROW)

    local showPercentSecondary = GUI:CreateFormCheckbox(secondaryGeneralContent, "Show as Percent", "showPercent", secondary, RefreshPowerBars)
    secondaryY = OptionsShared.AddFormControl(secondaryGeneralContent, showPercentSecondary, secondaryY, CONTENT_PAD, FORM_ROW)

    local showRuneTextSecondary = GUI:CreateFormCheckbox(secondaryGeneralContent, "Show Rune CD Text (DKs)", "showFragmentedPowerBarText", secondary, RefreshPowerBars)
    local _, playerClass = UnitClass("player")
    showRuneTextSecondary:SetEnabled(playerClass == "DEATHKNIGHT")
    secondaryY = OptionsShared.AddFormControl(secondaryGeneralContent, showRuneTextSecondary, secondaryY, CONTENT_PAD, FORM_ROW)

    -- Tick marks
    local showTicksSecondary = GUI:CreateFormCheckbox(secondaryGeneralContent, "Show Tick Marks", "showTicks", secondary, RefreshPowerBars)
    secondaryY = OptionsShared.AddFormControl(secondaryGeneralContent, showTicksSecondary, secondaryY, CONTENT_PAD, FORM_ROW)

    local tickThicknessSecondary = GUI:CreateFormSlider(secondaryGeneralContent, "Tick Thickness", 1, 4, 1, "tickThickness", secondary, RefreshPowerBars)
    secondaryY = OptionsShared.AddFormControl(secondaryGeneralContent, tickThicknessSecondary, secondaryY, CONTENT_PAD, FORM_ROW)

    local tickColorSecondary = GUI:CreateFormColorPicker(secondaryGeneralContent, "Tick Color", "tickColor", secondary, RefreshPowerBars)
    secondaryY = OptionsShared.AddFormControl(secondaryGeneralContent, tickColorSecondary, secondaryY, CONTENT_PAD, FORM_ROW)

    local borderSecondary = GUI:CreateFormSlider(secondaryGeneralContent, "Border Size", 0, 8, 1, "borderSize", secondary, RefreshPowerBars)
    secondaryY = OptionsShared.AddFormControl(secondaryGeneralContent, borderSecondary, secondaryY, CONTENT_PAD, FORM_ROW)

    -- Text sliders
    local textSizeSecondary = GUI:CreateFormSlider(secondaryGeneralContent, "Text Size", 8, 50, 1, "textSize", secondary, RefreshPowerBars)
    secondaryY = OptionsShared.AddFormControl(secondaryGeneralContent, textSizeSecondary, secondaryY, CONTENT_PAD, FORM_ROW)

    local textXSecondary = GUI:CreateFormSlider(secondaryGeneralContent, "Text X Offset", -500, 500, 1, "textX", secondary, RefreshPowerBars)
    secondaryY = OptionsShared.AddFormControl(secondaryGeneralContent, textXSecondary, secondaryY, CONTENT_PAD, FORM_ROW)

    local textYSecondary = GUI:CreateFormSlider(secondaryGeneralContent, "Text Y Offset", -500, 500, 1, "textY", secondary, RefreshPowerBars)
    secondaryY = OptionsShared.AddFormControl(secondaryGeneralContent, textYSecondary, secondaryY, CONTENT_PAD, FORM_ROW)

    -- Text color settings
    local textCustomColorSecondary

    local textUseClassColorSecondary = GUI:CreateFormCheckbox(secondaryGeneralContent, "Use Class Color for Text", "textUseClassColor", secondary, function()
        if textCustomColorSecondary then
            textCustomColorSecondary:SetEnabled(not secondary.textUseClassColor)
        end
        RefreshPowerBars()
    end)
    secondaryY = OptionsShared.AddFormControl(secondaryGeneralContent, textUseClassColorSecondary, secondaryY, CONTENT_PAD, FORM_ROW)

    textCustomColorSecondary = GUI:CreateFormColorPicker(secondaryGeneralContent, "Custom Text Color", "textCustomColor", secondary, RefreshPowerBars)
    textCustomColorSecondary:SetEnabled(not secondary.textUseClassColor)
    secondaryY = OptionsShared.AddFormControl(secondaryGeneralContent, textCustomColorSecondary, secondaryY, CONTENT_PAD, FORM_ROW)

    local textureSecondary = GUI:CreateFormDropdown(secondaryGeneralContent, "Bar Texture", GetTextureList(), "texture", secondary, RefreshPowerBars)
    secondaryY = OptionsShared.AddFormControl(secondaryGeneralContent, textureSecondary, secondaryY, CONTENT_PAD, FORM_ROW)

    -- Update General section height
    secondaryGeneralContent:SetHeight(math.abs(secondaryY) + 4)
    secondaryGeneralSection:UpdateHeight()

    -- =====================================================
    -- SECONDARY - LAYOUT (Nested Section)
    -- =====================================================
    local secondaryLayoutSection
    if ns.QUI_LayoutControl_Options then
        local function OnAnchorChange()
            RefreshPowerBars()
        end

        local bar = QUI_ResourceBars and QUI_ResourceBars:GetSecondaryBar()
        -- Create as nested section inside secondaryContent
        secondaryLayoutSection, _, _ = ns.QUI_LayoutControl_Options:CreateLayoutControl(
                secondaryContent, bar, 0, PAD, FORM_ROW, OnAnchorChange, {
                    previousSection = secondaryGeneralSection,
                    sectionTitle = "Layout",
                    anchorKey = "anchorTo",
                    maxAnchors = 2,
                    excludeSelf = "secondary"
                }
        )
    end

    -- Update secondary section height (will be handled by nested section tracking)
    secondarySection:UpdateHeight()

    -- =====================================================
    -- RESOURCE COLORS (Collapsible)
    -- =====================================================
    local powerColorsSection, powerColorsContent, y = OptionsShared.CreateCollapsibleSection(content, "Resource Colors", y, PAD, false, secondarySection)
    local powerColorsY = 0

    -- Get powerColors DB table
    local pc = db.powerColors
    if not pc then
        db.powerColors = {}
        pc = db.powerColors
    end

    -- Default power colors (used for Reset button)
    local defaultPowerColors = {
        rage = { 1.00, 0.00, 0.00, 1 },
        energy = { 1.00, 1.00, 0.00, 1 },
        mana = { 0.00, 0.00, 1.00, 1 },
        focus = { 1.00, 0.50, 0.25, 1 },
        runicPower = { 0.00, 0.82, 1.00, 1 },
        fury = { 0.79, 0.26, 0.99, 1 },
        insanity = { 0.40, 0.00, 0.80, 1 },
        maelstrom = { 0.00, 0.50, 1.00, 1 },
        lunarPower = { 0.30, 0.52, 0.90, 1 },
        holyPower = { 0.95, 0.90, 0.60, 1 },
        chi = { 0.00, 1.00, 0.59, 1 },
        comboPoints = { 1.00, 0.96, 0.41, 1 },
        soulShards = { 0.58, 0.51, 0.79, 1 },
        arcaneCharges = { 0.10, 0.10, 0.98, 1 },
        essence = { 0.20, 0.58, 0.50, 1 },
        stagger = { 0.00, 1.00, 0.59, 1 },
        soulFragments = { 0.64, 0.19, 0.79, 1 },
        runes = { 0.77, 0.12, 0.23, 1 },
        bloodRunes = { 0.77, 0.12, 0.23, 1 },
        frostRunes = { 0.00, 0.82, 1.00, 1 },
        unholyRunes = { 0.00, 0.80, 0.00, 1 },
    }

    -- Initialize defaults if missing
    for key, value in pairs(defaultPowerColors) do
        if pc[key] == nil then pc[key] = {value[1], value[2], value[3], value[4]} end
    end

    -- Store widget references for Reset button
    local powerColorWidgets = {}

    -- =====================================================
    -- RESET BUTTON (Non-collapsible section wrapper)
    -- =====================================================
    -- Create a section wrapper with hidden header and non-collapsible
    -- This allows the reset button to participate in section positioning without a visible header
    local resetSection, resetContent, powerColorsY = OptionsShared.CreateCollapsibleSection(
        powerColorsContent, "", powerColorsY, PAD, true, nil, {
            hideHeader = true,
            nonCollapsible = true
        }
    )
    local resetY = 0

    -- Reset to Defaults button
    local resetPowerColorsContainer = CreateFrame("Frame", nil, resetContent)
    resetPowerColorsContainer:SetHeight(FORM_ROW)
    resetPowerColorsContainer:SetPoint("TOPLEFT", PAD, resetY)
    resetPowerColorsContainer:SetPoint("RIGHT", resetContent, "RIGHT", -PAD, 0)

    local resetPowerColorsLabel = resetPowerColorsContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resetPowerColorsLabel:SetPoint("LEFT", 0, 0)
    resetPowerColorsLabel:SetText("Reset Colors")
    resetPowerColorsLabel:SetTextColor(C.text[1], C.text[2], C.text[3], 1)

    local resetPowerColorsBtn = CreateFrame("Button", nil, resetPowerColorsContainer, "BackdropTemplate")
    resetPowerColorsBtn:SetSize(140, 24)
    resetPowerColorsBtn:SetPoint("LEFT", resetPowerColorsContainer, "LEFT", 180, 0)
    resetPowerColorsBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    resetPowerColorsBtn:SetBackdropColor(0.15, 0.15, 0.15, 1)
    resetPowerColorsBtn:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)

    local resetPowerColorsText = resetPowerColorsBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resetPowerColorsText:SetPoint("CENTER")
    resetPowerColorsText:SetText("Reset to Defaults")
    resetPowerColorsText:SetTextColor(C.text[1], C.text[2], C.text[3], 1)

    resetPowerColorsBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    end)
    resetPowerColorsBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end)
    resetPowerColorsBtn:SetScript("OnClick", function()
        for key, value in pairs(defaultPowerColors) do
            pc[key] = {value[1], value[2], value[3], value[4]}
        end
        -- Refresh color swatches
        for _, widget in ipairs(powerColorWidgets) do
            if widget.swatch and pc[widget.dbKey] then
                local col = pc[widget.dbKey]
                widget.swatch:SetBackdropColor(col[1], col[2], col[3], col[4] or 1)
            end
        end
        RefreshPowerBars()
        print("|cFF56D1FFQuaziiUI:|r Resource colors reset to defaults.")
    end)
    resetY = resetY - FORM_ROW

    -- Update reset section height
    resetContent:SetHeight(math.abs(resetY) + 4)
    resetSection:UpdateHeight()

    -- =====================================================
    -- SUB-SECTION: Core Resources (Nested Collapsible)
    -- =====================================================
    local coreSection, coreContent, powerColorsY = OptionsShared.CreateCollapsibleSection(powerColorsContent, "Core Resources", powerColorsY, PAD, false, resetSection)
    local coreY = 0

    local rageColor = GUI:CreateFormColorPicker(coreContent, "Rage", "rage", pc, RefreshPowerBars)
    rageColor.dbKey = "rage"
    table.insert(powerColorWidgets, rageColor)
    coreY = OptionsShared.AddFormControl(coreContent, rageColor, coreY, PAD, FORM_ROW)

    local energyColor = GUI:CreateFormColorPicker(coreContent, "Energy", "energy", pc, RefreshPowerBars)
    energyColor.dbKey = "energy"
    table.insert(powerColorWidgets, energyColor)
    coreY = OptionsShared.AddFormControl(coreContent, energyColor, coreY, PAD, FORM_ROW)

    local manaColor = GUI:CreateFormColorPicker(coreContent, "Mana", "mana", pc, RefreshPowerBars)
    manaColor.dbKey = "mana"
    table.insert(powerColorWidgets, manaColor)
    coreY = OptionsShared.AddFormControl(coreContent, manaColor, coreY, PAD, FORM_ROW)

    local focusColor = GUI:CreateFormColorPicker(coreContent, "Focus", "focus", pc, RefreshPowerBars)
    focusColor.dbKey = "focus"
    table.insert(powerColorWidgets, focusColor)
    coreY = OptionsShared.AddFormControl(coreContent, focusColor, coreY, PAD, FORM_ROW)

    local runicPowerColor = GUI:CreateFormColorPicker(coreContent, "Runic Power", "runicPower", pc, RefreshPowerBars)
    runicPowerColor.dbKey = "runicPower"
    table.insert(powerColorWidgets, runicPowerColor)
    coreY = OptionsShared.AddFormControl(coreContent, runicPowerColor, coreY, PAD, FORM_ROW)

    local furyColor = GUI:CreateFormColorPicker(coreContent, "Fury", "fury", pc, RefreshPowerBars)
    furyColor.dbKey = "fury"
    table.insert(powerColorWidgets, furyColor)
    coreY = OptionsShared.AddFormControl(coreContent, furyColor, coreY, PAD, FORM_ROW)

    local insanityColor = GUI:CreateFormColorPicker(coreContent, "Insanity", "insanity", pc, RefreshPowerBars)
    insanityColor.dbKey = "insanity"
    table.insert(powerColorWidgets, insanityColor)
    coreY = OptionsShared.AddFormControl(coreContent, insanityColor, coreY, PAD, FORM_ROW)

    local maelstromColor = GUI:CreateFormColorPicker(coreContent, "Maelstrom", "maelstrom", pc, RefreshPowerBars)
    maelstromColor.dbKey = "maelstrom"
    table.insert(powerColorWidgets, maelstromColor)
    coreY = OptionsShared.AddFormControl(coreContent, maelstromColor, coreY, PAD, FORM_ROW)

    local lunarPowerColor = GUI:CreateFormColorPicker(coreContent, "Astral Power", "lunarPower", pc, RefreshPowerBars)
    lunarPowerColor.dbKey = "lunarPower"
    table.insert(powerColorWidgets, lunarPowerColor)
    coreY = OptionsShared.AddFormControl(coreContent, lunarPowerColor, coreY, PAD, FORM_ROW)

    -- Update section height
    coreContent:SetHeight(math.abs(coreY) + 4)
    coreSection:UpdateHeight()

    -- =====================================================
    -- SUB-SECTION: Builder Resources (Nested Collapsible)
    -- =====================================================
    local builderSection, builderContent, powerColorsY = OptionsShared.CreateCollapsibleSection(powerColorsContent, "Builder Resources", powerColorsY, PAD, false, coreSection)
    local builderY = 0

    local holyPowerColor = GUI:CreateFormColorPicker(builderContent, "Holy Power", "holyPower", pc, RefreshPowerBars)
    holyPowerColor.dbKey = "holyPower"
    table.insert(powerColorWidgets, holyPowerColor)
    builderY = OptionsShared.AddFormControl(builderContent, holyPowerColor, builderY, PAD, FORM_ROW)

    local chiColor = GUI:CreateFormColorPicker(builderContent, "Chi", "chi", pc, RefreshPowerBars)
    chiColor.dbKey = "chi"
    table.insert(powerColorWidgets, chiColor)
    builderY = OptionsShared.AddFormControl(builderContent, chiColor, builderY, PAD, FORM_ROW)

    local comboPointsColor = GUI:CreateFormColorPicker(builderContent, "Combo Points", "comboPoints", pc, RefreshPowerBars)
    comboPointsColor.dbKey = "comboPoints"
    table.insert(powerColorWidgets, comboPointsColor)
    builderY = OptionsShared.AddFormControl(builderContent, comboPointsColor, builderY, PAD, FORM_ROW)

    local soulShardsColor = GUI:CreateFormColorPicker(builderContent, "Soul Shards", "soulShards", pc, RefreshPowerBars)
    soulShardsColor.dbKey = "soulShards"
    table.insert(powerColorWidgets, soulShardsColor)
    builderY = OptionsShared.AddFormControl(builderContent, soulShardsColor, builderY, PAD, FORM_ROW)

    local arcaneChargesColor = GUI:CreateFormColorPicker(builderContent, "Arcane Charges", "arcaneCharges", pc, RefreshPowerBars)
    arcaneChargesColor.dbKey = "arcaneCharges"
    table.insert(powerColorWidgets, arcaneChargesColor)
    builderY = OptionsShared.AddFormControl(builderContent, arcaneChargesColor, builderY, PAD, FORM_ROW)

    local essenceColor = GUI:CreateFormColorPicker(builderContent, "Essence", "essence", pc, RefreshPowerBars)
    essenceColor.dbKey = "essence"
    table.insert(powerColorWidgets, essenceColor)
    builderY = OptionsShared.AddFormControl(builderContent, essenceColor, builderY, PAD, FORM_ROW)

    -- Update section height
    builderContent:SetHeight(math.abs(builderY) + 4)
    builderSection:UpdateHeight()

    -- =====================================================
    -- SUB-SECTION: Specialized Resources (Nested Collapsible)
    -- =====================================================
    local specialSection, specialContent, powerColorsY = OptionsShared.CreateCollapsibleSection(powerColorsContent, "Specialized Resources", powerColorsY, PAD, false, builderSection)
    local specialY = 0

    local staggerColor = GUI:CreateFormColorPicker(specialContent, "Stagger", "stagger", pc, RefreshPowerBars)
    staggerColor.dbKey = "stagger"
    table.insert(powerColorWidgets, staggerColor)
    specialY = OptionsShared.AddFormControl(specialContent, staggerColor, specialY, PAD, FORM_ROW)

    local soulFragmentsColor = GUI:CreateFormColorPicker(specialContent, "Soul Fragments", "soulFragments", pc, RefreshPowerBars)
    soulFragmentsColor.dbKey = "soulFragments"
    table.insert(powerColorWidgets, soulFragmentsColor)
    specialY = OptionsShared.AddFormControl(specialContent, soulFragmentsColor, specialY, PAD, FORM_ROW)

    local runesColor = GUI:CreateFormColorPicker(specialContent, "Runes (Generic)", "runes", pc, RefreshPowerBars)
    runesColor.dbKey = "runes"
    table.insert(powerColorWidgets, runesColor)
    specialY = OptionsShared.AddFormControl(specialContent, runesColor, specialY, PAD, FORM_ROW)

    local bloodRunesColor = GUI:CreateFormColorPicker(specialContent, "Blood Runes", "bloodRunes", pc, RefreshPowerBars)
    bloodRunesColor.dbKey = "bloodRunes"
    table.insert(powerColorWidgets, bloodRunesColor)
    specialY = OptionsShared.AddFormControl(specialContent, bloodRunesColor, specialY, PAD, FORM_ROW)

    local frostRunesColor = GUI:CreateFormColorPicker(specialContent, "Frost Runes", "frostRunes", pc, RefreshPowerBars)
    frostRunesColor.dbKey = "frostRunes"
    table.insert(powerColorWidgets, frostRunesColor)
    specialY = OptionsShared.AddFormControl(specialContent, frostRunesColor, specialY, PAD, FORM_ROW)

    local unholyRunesColor = GUI:CreateFormColorPicker(specialContent, "Unholy Runes", "unholyRunes", pc, RefreshPowerBars)
    unholyRunesColor.dbKey = "unholyRunes"
    table.insert(powerColorWidgets, unholyRunesColor)
    specialY = OptionsShared.AddFormControl(specialContent, unholyRunesColor, specialY, PAD, FORM_ROW)

    -- Update section height
    specialContent:SetHeight(math.abs(specialY) + 4)
    specialSection:UpdateHeight()

    -- Update power colors section height
    powerColorsContent:SetHeight(math.abs(powerColorsY) + 4)
    powerColorsSection:UpdateHeight()

    return scroll, content
end

-- Export the function
ns.ResourceBarsOptions = { CreateResourceBarsPage = CreateResourceBarsPage }

-- Register with Options Page Registry
if ns.OptionsPageRegistry then
    ns.OptionsPageRegistry:RegisterSimplePage("resourcebars", "Resource Bars", CreateResourceBarsPage, 50)
end

return ns.ResourceBarsOptions
