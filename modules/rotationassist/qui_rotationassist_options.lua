--[[
    qui_rotationassist_options.lua
    Options UI for Rotation Assist module
    Displays a standalone icon showing Blizzard's next recommended ability
]]

local ADDON_NAME, ns = ...

if not ns.IsModuleEnabled("rotationassist") then
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
local PADDING = OptionsShared.CONSTANTS.PADDING
local CONTENT_PAD = OptionsShared.CONSTANTS.CONTENT_PAD or 6
local AddFormControl = OptionsShared.AddFormControl
local AddFormNote = OptionsShared.AddFormNote
local CreateCollapsibleSection = OptionsShared.CreateCollapsibleSection

---------------------------------------------------------------------------
-- CREATE ROTATION ASSIST OPTIONS PAGE
---------------------------------------------------------------------------
local function CreateRotationAssistPage(parent)
    local scroll, content = CreateScrollableContent(parent)
    
    local db = GetDB()
    if not db then return scroll, content end

    -- Set search context for widget auto-registration
    GUI:SetSearchContext({tabIndex = 1, tabName = "Rotation Assist"})

    -- Ensure rotationAssistIcon settings exist
    if not db.rotationAssistIcon then 
        db.rotationAssistIcon = {} 
    end

    local raiDB = db.rotationAssistIcon

    -- Ensure all fields exist with defaults
    if raiDB.enabled == nil then raiDB.enabled = false end
    if raiDB.iconSize == nil then raiDB.iconSize = 56 end
    if raiDB.visibility == nil then raiDB.visibility = "always" end
    if raiDB.frameStrata == nil then raiDB.frameStrata = "MEDIUM" end
    if raiDB.showBorder == nil then raiDB.showBorder = true end
    if raiDB.borderThickness == nil then raiDB.borderThickness = 2 end
    if raiDB.borderColor == nil then raiDB.borderColor = { 0, 0, 0, 1 } end
    if raiDB.cooldownSwipeEnabled == nil then raiDB.cooldownSwipeEnabled = true end
    if raiDB.showKeybind == nil then raiDB.showKeybind = true end
    if raiDB.keybindFont == nil then raiDB.keybindFont = nil end
    if raiDB.keybindSize == nil then raiDB.keybindSize = 13 end
    if raiDB.keybindColor == nil then raiDB.keybindColor = { 1, 1, 1, 1 } end
    if raiDB.keybindOutline == nil then raiDB.keybindOutline = true end
    if raiDB.keybindAnchor == nil then raiDB.keybindAnchor = "BOTTOMRIGHT" end
    if raiDB.keybindOffsetX == nil then raiDB.keybindOffsetX = -2 end
    if raiDB.keybindOffsetY == nil then raiDB.keybindOffsetY = 2 end

    -- Callback to refresh rotation assist icon
    local function RefreshRAI()
        if _G.QuaziiUI_RefreshRotationAssistIcon then
            _G.QuaziiUI_RefreshRotationAssistIcon()
        end
    end

    local PAD = 10
    local FORM_ROW = 32
    local y = -10

    -- =====================================================
    -- GENERAL SETTINGS (Collapsible)
    -- =====================================================
    local generalSection, generalContent, y = CreateCollapsibleSection(content, "General", y, PAD, true, nil)
    local generalY = 0

    local infoText = GUI:CreateLabel(generalContent, "Displays a standalone movable icon showing Blizzard's next recommended ability.", 11, C.textMuted)
    infoText:SetPoint("TOPLEFT", CONTENT_PAD, generalY)
    infoText:SetPoint("RIGHT", generalContent, "RIGHT", -CONTENT_PAD, 0)
    infoText:SetJustifyH("LEFT")
    generalY = generalY - 18

    local infoText2 = GUI:CreateLabel(generalContent, "Requires 'Starter Build' to be enabled in Game Menu > Options > Gameplay > Combat.", 11, C.textMuted)
    infoText2:SetPoint("TOPLEFT", CONTENT_PAD, generalY)
    infoText2:SetPoint("RIGHT", generalContent, "RIGHT", -CONTENT_PAD, 0)
    infoText2:SetJustifyH("LEFT")
    generalY = generalY - 30

    local enableToggle = GUI:CreateFormToggle(generalContent, "Enable", "enabled", raiDB, RefreshRAI)
    generalY = AddFormControl(generalContent, enableToggle, generalY, CONTENT_PAD, FORM_ROW)

    local visibilityOptions = {
        { value = "always", text = "Always" },
        { value = "combat", text = "In Combat" },
        { value = "hostile", text = "Hostile Target" },
    }
    local visibilityDropdown = GUI:CreateFormDropdown(generalContent, "Visibility", visibilityOptions, "visibility", raiDB, RefreshRAI)
    generalY = AddFormControl(generalContent, visibilityDropdown, generalY, CONTENT_PAD, FORM_ROW)

    local strataOptions = {
        { value = "LOW", text = "Low" },
        { value = "MEDIUM", text = "Medium" },
        { value = "HIGH", text = "High" },
        { value = "DIALOG", text = "Dialog" },
    }
    local strataDropdown = GUI:CreateFormDropdown(generalContent, "Frame Strata", strataOptions, "frameStrata", raiDB, RefreshRAI)
    generalY = AddFormControl(generalContent, strataDropdown, generalY, CONTENT_PAD, FORM_ROW)

    -- Update section height
    generalContent:SetHeight(math.abs(generalY) + 4)
    generalSection:UpdateHeight()

    -- =====================================================
    -- APPEARANCE SETTINGS (Collapsible)
    -- =====================================================
    local appearanceSection, appearanceContent, y = CreateCollapsibleSection(content, "Appearance", y, PAD, false, generalSection)
    local appearanceY = 0

    local sizeSlider = GUI:CreateFormSlider(appearanceContent, "Icon Size", 16, 400, 1, "iconSize", raiDB, RefreshRAI)
    appearanceY = AddFormControl(appearanceContent, sizeSlider, appearanceY, CONTENT_PAD, FORM_ROW)

    local borderToggle = GUI:CreateFormToggle(appearanceContent, "Show Border", "showBorder", raiDB, RefreshRAI)
    appearanceY = AddFormControl(appearanceContent, borderToggle, appearanceY, CONTENT_PAD, FORM_ROW)

    local borderWidthSlider = GUI:CreateFormSlider(appearanceContent, "Border Thickness", 0, 15, 1, "borderThickness", raiDB, RefreshRAI)
    appearanceY = AddFormControl(appearanceContent, borderWidthSlider, appearanceY, CONTENT_PAD, FORM_ROW)

    local borderColorPicker = GUI:CreateFormColorPicker(appearanceContent, "Border Color", "borderColor", raiDB, RefreshRAI)
    appearanceY = AddFormControl(appearanceContent, borderColorPicker, appearanceY, CONTENT_PAD, FORM_ROW)

    local cooldownSwipeToggle = GUI:CreateFormToggle(appearanceContent, "Cooldown Swipe", "cooldownSwipeEnabled", raiDB, RefreshRAI)
    appearanceY = AddFormControl(appearanceContent, cooldownSwipeToggle, appearanceY, CONTENT_PAD, FORM_ROW)

    -- Update section height
    appearanceContent:SetHeight(math.abs(appearanceY) + 4)
    appearanceSection:UpdateHeight()

    -- =====================================================
    -- KEYBIND SETTINGS (Collapsible)
    -- =====================================================
    local keybindSection, keybindContent, y = CreateCollapsibleSection(content, "Keybind Display", y, PAD, false, appearanceSection)
    local keybindY = 0

    local showKeybindToggle = GUI:CreateFormToggle(keybindContent, "Show Keybind", "showKeybind", raiDB, RefreshRAI)
    keybindY = AddFormControl(keybindContent, showKeybindToggle, keybindY, CONTENT_PAD, FORM_ROW)

    local keybindColorPicker = GUI:CreateFormColorPicker(keybindContent, "Keybind Color", "keybindColor", raiDB, RefreshRAI)
    keybindY = AddFormControl(keybindContent, keybindColorPicker, keybindY, CONTENT_PAD, FORM_ROW)

    local anchorOptions = {
        { value = "TOPLEFT", text = "Top Left" },
        { value = "TOPRIGHT", text = "Top Right" },
        { value = "BOTTOMLEFT", text = "Bottom Left" },
        { value = "BOTTOMRIGHT", text = "Bottom Right" },
        { value = "CENTER", text = "Center" },
    }
    local keybindAnchorDropdown = GUI:CreateFormDropdown(keybindContent, "Keybind Anchor", anchorOptions, "keybindAnchor", raiDB, RefreshRAI)
    keybindY = AddFormControl(keybindContent, keybindAnchorDropdown, keybindY, CONTENT_PAD, FORM_ROW)

    local keybindSizeSlider = GUI:CreateFormSlider(keybindContent, "Keybind Size", 6, 48, 1, "keybindSize", raiDB, RefreshRAI)
    keybindY = AddFormControl(keybindContent, keybindSizeSlider, keybindY, CONTENT_PAD, FORM_ROW)

    local keybindOffsetXSlider = GUI:CreateFormSlider(keybindContent, "Keybind X Offset", -50, 50, 1, "keybindOffsetX", raiDB, RefreshRAI)
    keybindY = AddFormControl(keybindContent, keybindOffsetXSlider, keybindY, CONTENT_PAD, FORM_ROW)

    local keybindOffsetYSlider = GUI:CreateFormSlider(keybindContent, "Keybind Y Offset", -50, 50, 1, "keybindOffsetY", raiDB, RefreshRAI)
    keybindY = AddFormControl(keybindContent, keybindOffsetYSlider, keybindY, CONTENT_PAD, FORM_ROW)

    -- Update section height
    keybindContent:SetHeight(math.abs(keybindY) + 4)
    keybindSection:UpdateHeight()

    -- =====================================================
    -- POSITIONING SECTION (Collapsible)
    -- =====================================================
    local positioningSection = nil
    if ns.QUI_LayoutControl_Options then
        -- Ensure the icon frame exists and is registered with layout manager
        local iconFrame = QUI.RotationAssistIcon and QUI.RotationAssistIcon.GetFrame and QUI.RotationAssistIcon.GetFrame()
        
        -- If frame doesn't exist yet, create it by calling refresh
        if not iconFrame then
            RefreshRAI()
            iconFrame = QUI.RotationAssistIcon and QUI.RotationAssistIcon.GetFrame and QUI.RotationAssistIcon.GetFrame()
        end
        
        -- Ensure frame is registered with layout manager
        if iconFrame then
            local QUI_LayoutManager = ns.QUI_LayoutManager
            if QUI_LayoutManager then
                local layoutConfig = QUI_LayoutManager:GetLayout(iconFrame)
                if not layoutConfig then
                    -- Register with layout manager if not already registered
                    QUI_LayoutManager:RegisterFrame(iconFrame, "rotationAssist.default", "rotationAssist", {
                        parentFrame = UIParent,
                        editMode = {
                            label = "Rotation Assist Icon",
                            elementKey = "rotationAssist",
                            skipKeyboardEnable = false,
                            elementType = "rotationAssist",
                            updateCallback = function()
                                -- Refresh visibility when edit mode changes
                                if QUI.RotationAssistIcon and QUI.RotationAssistIcon.Refresh then
                                    QUI.RotationAssistIcon:Refresh()
                                end
                            end,
                        },
                    })
                end
            end
            
            local function OnLayoutChange()
                -- Refresh the icon frame when layout changes
                RefreshRAI()
            end
            
            positioningSection, positioningContent, y = ns.QUI_LayoutControl_Options:CreateLayoutControl(
                content, iconFrame, y, PAD, FORM_ROW, OnLayoutChange, {
                    sectionTitle = "Positioning",
                    previousSection = keybindSection,
                    showAnchoring = true,   -- Show anchor controls
                    showOffset = true,      -- Show offset controls
                    showSize = false,       -- Size is handled separately (iconSize setting)
                    showPresets = true,     -- Show preset buttons
                    isExpandedByDefault = false,
                }
            )
        end
    end

    return scroll, content
end

---------------------------------------------------------------------------
-- REGISTER OPTIONS PAGE AS SUB-TAB
---------------------------------------------------------------------------
if ns.OptionsPageRegistry then
    -- Add as sub-tab to CDM Keybind & Rotation
    ns.OptionsPageRegistry:AddSubTab("cdkeybinds", {
        name = "Rotation Assist",
        builder = CreateRotationAssistPage,
        order = 20,
    })
end
