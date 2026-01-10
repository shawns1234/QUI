--[[
    qui_cdkeybinds_options.lua
    Options UI for CDM Keybind & Rotation component
]]

local ADDON_NAME, ns = ...
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
local CreateCollapsibleSection = OptionsShared.CreateCollapsibleSection

local function CreateCDKeybindsPage(parent)
    -- Check if module is enabled before building content
    if not ns.IsModuleEnabled("ncdm") then
        local emptyLabel = GUI:CreateLabel(parent, "NCDM module is disabled.", 14, GUI.Colors.textMuted)
        emptyLabel:SetPoint("CENTER", parent, "CENTER", 0, 0)
        return
    end
    
    local scroll, content = CreateScrollableContent(parent)
    local db = GetDB()
    local y = -10
    local FORM_ROW = 32

    -- Set search context for auto-registration
    GUI:SetSearchContext({tabIndex = 8, tabName = "CDM Keybind & Rotation"})

    -- Refresh function for keybinds
    local function RefreshKeybinds()
        if _G.QuaziiUI_RefreshKeybinds then
            _G.QuaziiUI_RefreshKeybinds()
        end
    end

    -- Refresh function for rotation helper
    local function RefreshRotationHelper()
        if _G.QuaziiUI_RefreshRotationHelper then
            _G.QuaziiUI_RefreshRotationHelper()
        end
    end
    
    if db and db.viewers then
        local essentialViewer = db.viewers.EssentialCooldownViewer
        local utilityViewer = db.viewers.UtilityCooldownViewer
        
        -- =====================================================
        -- ESSENTIAL KEYBIND DISPLAY (Collapsible)
        -- =====================================================
        local essentialSection, essentialContent, y = CreateCollapsibleSection(content, "Essential Keybind Display", y, PADDING, false, nil)
        local essentialY = 0

        local essentialShowCheck = GUI:CreateFormCheckbox(essentialContent, "Show Keybinds", "showKeybinds", essentialViewer, RefreshKeybinds)
        essentialY = AddFormControl(essentialContent, essentialShowCheck, essentialY, CONTENT_PAD, FORM_ROW)

        local essentialSizeSlider = GUI:CreateFormSlider(essentialContent, "Keybind Text Size", 6, 18, 1, "keybindTextSize", essentialViewer, RefreshKeybinds)
        essentialY = AddFormControl(essentialContent, essentialSizeSlider, essentialY, CONTENT_PAD, FORM_ROW)

        local essentialColorPicker = GUI:CreateFormColorPicker(essentialContent, "Keybind Text Color", "keybindTextColor", essentialViewer, RefreshKeybinds)
        essentialY = AddFormControl(essentialContent, essentialColorPicker, essentialY, CONTENT_PAD, FORM_ROW)

        local essentialOffsetXSlider = GUI:CreateFormSlider(essentialContent, "Horizontal Offset", -20, 20, 1, "keybindOffsetX", essentialViewer, RefreshKeybinds)
        essentialY = AddFormControl(essentialContent, essentialOffsetXSlider, essentialY, CONTENT_PAD, FORM_ROW)

        local essentialOffsetYSlider = GUI:CreateFormSlider(essentialContent, "Vertical Offset", -20, 20, 1, "keybindOffsetY", essentialViewer, RefreshKeybinds)
        essentialY = AddFormControl(essentialContent, essentialOffsetYSlider, essentialY, CONTENT_PAD, FORM_ROW)

        -- Update section height
        essentialContent:SetHeight(math.abs(essentialY) + 4)
        essentialSection:UpdateHeight()
        
        -- =====================================================
        -- UTILITY KEYBIND DISPLAY (Collapsible)
        -- =====================================================
        local utilitySection, utilityContent, y = CreateCollapsibleSection(content, "Utility Keybind Display", y, PADDING, false, essentialSection)
        local utilityY = 0

        local utilityShowCheck = GUI:CreateFormCheckbox(utilityContent, "Show Keybinds", "showKeybinds", utilityViewer, RefreshKeybinds)
        utilityY = AddFormControl(utilityContent, utilityShowCheck, utilityY, CONTENT_PAD, FORM_ROW)

        local utilitySizeSlider = GUI:CreateFormSlider(utilityContent, "Keybind Text Size", 6, 18, 1, "keybindTextSize", utilityViewer, RefreshKeybinds)
        utilityY = AddFormControl(utilityContent, utilitySizeSlider, utilityY, CONTENT_PAD, FORM_ROW)

        local utilityColorPicker = GUI:CreateFormColorPicker(utilityContent, "Keybind Text Color", "keybindTextColor", utilityViewer, RefreshKeybinds)
        utilityY = AddFormControl(utilityContent, utilityColorPicker, utilityY, CONTENT_PAD, FORM_ROW)

        local utilityOffsetXSlider = GUI:CreateFormSlider(utilityContent, "Horizontal Offset", -20, 20, 1, "keybindOffsetX", utilityViewer, RefreshKeybinds)
        utilityY = AddFormControl(utilityContent, utilityOffsetXSlider, utilityY, CONTENT_PAD, FORM_ROW)

        local utilityOffsetYSlider = GUI:CreateFormSlider(utilityContent, "Vertical Offset", -20, 20, 1, "keybindOffsetY", utilityViewer, RefreshKeybinds)
        utilityY = AddFormControl(utilityContent, utilityOffsetYSlider, utilityY, CONTENT_PAD, FORM_ROW)

        -- Update section height
        utilityContent:SetHeight(math.abs(utilityY) + 4)
        utilitySection:UpdateHeight()
        
        -- =====================================================
        -- CUSTOM TRACKER KEYBIND DISPLAYS (Collapsible)
        -- =====================================================
        -- Get custom tracker keybind settings from DB
        local ctKeybindDB = db and db.customTrackers and db.customTrackers.keybinds
        if not ctKeybindDB and db and db.customTrackers then
            -- Initialize defaults if missing
            db.customTrackers.keybinds = {
                showKeybinds = false,
                keybindTextSize = 10,
                keybindTextColor = { 1, 0.82, 0, 1 },
                keybindOffsetX = 2,
                keybindOffsetY = -2,
            }
            ctKeybindDB = db.customTrackers.keybinds
        end

        -- Refresh function for custom tracker keybinds
        local function RefreshCustomTrackerKeybinds()
            if _G.QuaziiUI_RefreshCustomTrackerKeybinds then
                _G.QuaziiUI_RefreshCustomTrackerKeybinds()
            end
        end

        local ctSection = nil
        if ctKeybindDB then
            ctSection, ctContent, y = CreateCollapsibleSection(content, "Custom Tracker Keybind Displays", y, PADDING, false, utilitySection)
            local ctY = 0

            local ctKeybindInfo = GUI:CreateLabel(ctContent, "Shows keybinds on Custom Item/Spell bar icons. Settings apply globally to all custom tracker bars.", 11, C.textMuted)
            ctKeybindInfo:SetPoint("TOPLEFT", CONTENT_PAD, ctY)
            ctKeybindInfo:SetPoint("RIGHT", ctContent, "RIGHT", -CONTENT_PAD, 0)
            ctKeybindInfo:SetJustifyH("LEFT")
            ctY = ctY - 20

            local ctShowCheck = GUI:CreateFormCheckbox(ctContent, "Show Keybinds", "showKeybinds", ctKeybindDB, RefreshCustomTrackerKeybinds)
            ctY = AddFormControl(ctContent, ctShowCheck, ctY, CONTENT_PAD, FORM_ROW)

            local ctSizeSlider = GUI:CreateFormSlider(ctContent, "Keybind Text Size", 6, 18, 1, "keybindTextSize", ctKeybindDB, RefreshCustomTrackerKeybinds)
            ctY = AddFormControl(ctContent, ctSizeSlider, ctY, CONTENT_PAD, FORM_ROW)

            local ctColorPicker = GUI:CreateFormColorPicker(ctContent, "Keybind Text Color", "keybindTextColor", ctKeybindDB, RefreshCustomTrackerKeybinds)
            ctY = AddFormControl(ctContent, ctColorPicker, ctY, CONTENT_PAD, FORM_ROW)

            local ctOffsetXSlider = GUI:CreateFormSlider(ctContent, "Horizontal Offset", -20, 20, 1, "keybindOffsetX", ctKeybindDB, RefreshCustomTrackerKeybinds)
            ctY = AddFormControl(ctContent, ctOffsetXSlider, ctY, CONTENT_PAD, FORM_ROW)

            local ctOffsetYSlider = GUI:CreateFormSlider(ctContent, "Vertical Offset", -20, 20, 1, "keybindOffsetY", ctKeybindDB, RefreshCustomTrackerKeybinds)
            ctY = AddFormControl(ctContent, ctOffsetYSlider, ctY, CONTENT_PAD, FORM_ROW)

            -- Update section height
            ctContent:SetHeight(math.abs(ctY) + 4)
            ctSection:UpdateHeight()
        end

        -- =====================================================
        -- ROTATION HELPER OVERLAY (Collapsible)
        -- =====================================================
        -- Chain to ctSection if it exists, otherwise chain to utilitySection
        local previousSectionForRotation = ctSection or utilitySection
        local rotationSection, rotationContent, y = CreateCollapsibleSection(content, "Rotation Helper Overlay", y, PADDING, false, previousSectionForRotation)
        local rotationY = 0

        local rotationInfo = GUI:CreateLabel(rotationContent, "Shows a border on the CDM icon recommended by Blizzard's Assisted Combat (Starter Build). Requires 'Starter Build' to be enabled in Game Menu > Options > Gameplay > Combat.", 11, C.textMuted)
        rotationInfo:SetPoint("TOPLEFT", CONTENT_PAD, rotationY)
        rotationInfo:SetPoint("RIGHT", rotationContent, "RIGHT", -CONTENT_PAD, 0)
        rotationInfo:SetJustifyH("LEFT")
        rotationY = rotationY - 20

        local essentialRotationCheck = GUI:CreateFormCheckbox(rotationContent, "Show on Essential CDM", "showRotationHelper", essentialViewer, RefreshRotationHelper)
        rotationY = AddFormControl(rotationContent, essentialRotationCheck, rotationY, CONTENT_PAD, FORM_ROW)

        local utilityRotationCheck = GUI:CreateFormCheckbox(rotationContent, "Show on Utility CDM", "showRotationHelper", utilityViewer, RefreshRotationHelper)
        rotationY = AddFormControl(rotationContent, utilityRotationCheck, rotationY, CONTENT_PAD, FORM_ROW)

        local essentialRotationColor = GUI:CreateFormColorPicker(rotationContent, "Essential Border Color", "rotationHelperColor", essentialViewer, RefreshRotationHelper)
        rotationY = AddFormControl(rotationContent, essentialRotationColor, rotationY, CONTENT_PAD, FORM_ROW)

        local utilityRotationColor = GUI:CreateFormColorPicker(rotationContent, "Utility Border Color", "rotationHelperColor", utilityViewer, RefreshRotationHelper)
        rotationY = AddFormControl(rotationContent, utilityRotationColor, rotationY, CONTENT_PAD, FORM_ROW)

        local essentialThicknessSlider = GUI:CreateFormSlider(rotationContent, "Essential Border Thickness", 1, 6, 1, "rotationHelperThickness", essentialViewer, RefreshRotationHelper)
        rotationY = AddFormControl(rotationContent, essentialThicknessSlider, rotationY, CONTENT_PAD, FORM_ROW)

        local utilityThicknessSlider = GUI:CreateFormSlider(rotationContent, "Utility Border Thickness", 1, 6, 1, "rotationHelperThickness", utilityViewer, RefreshRotationHelper)
        rotationY = AddFormControl(rotationContent, utilityThicknessSlider, rotationY, CONTENT_PAD, FORM_ROW)

        -- Update section height
        rotationContent:SetHeight(math.abs(rotationY) + 4)
        rotationSection:UpdateHeight()
    else
        y = y - 10
        local noDataLabel = GUI:CreateLabel(content, "Keybind settings not available - database not loaded", 12, C.textMuted)
        noDataLabel:SetPoint("TOPLEFT", PADDING, y)
    end
    
    content:SetHeight(math.abs(y) + 50)
end


-- Export the function
ns.CDKeybindsOptions = { CreateCDKeybindsPage = CreateCDKeybindsPage }

-- Register with Options Page Registry as composed page
if ns.OptionsPageRegistry then
    -- Register as composed page
    ns.OptionsPageRegistry:RegisterComposedPage("cdkeybinds", "CDM Keybind & Rotation", 80)
    -- Add the keybinds page as the first sub-tab
    ns.OptionsPageRegistry:AddSubTab("cdkeybinds", {
        name = "Keybinds",
        builder = CreateCDKeybindsPage,
        order = 10,
    })
end

return ns.CDKeybindsOptions
