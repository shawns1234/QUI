--[[
    qui_minimap_options.lua
    Options UI for Minimap component
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
local CreateScrollableContent = OptionsShared.CreateScrollableContent
local CreateCollapsibleSection = OptionsShared.CreateCollapsibleSection

-- Refresh callbacks
local function RefreshMinimap()
    if QUICore and QUICore.Minimap and QUICore.Minimap.Refresh then
        QUICore.Minimap:Refresh()
    end
end

local function RefreshUIHider()
    if _G.QuaziiUI_RefreshUIHider then
        _G.QuaziiUI_RefreshUIHider()
    end
end

-- Build minimap tab
local function BuildMinimapTab(tabContent)
    local db = GetDB()
    local y = -10
    local PAD = 10

    -- Set search context for auto-registration
    GUI:SetSearchContext({tabIndex = 3, tabName = "Minimap & Datatext", subTabIndex = 1, subTabName = "Minimap"})

    -- Early return if database not ready
    if not db then
        local errorLabel = GUI:CreateLabel(tabContent, "Database not ready. Please /reload.", 12, {1, 0.3, 0.3, 1})
        errorLabel:SetPoint("TOPLEFT", PAD, y)
        tabContent:SetHeight(50)
        return
    end

    -- Ensure minimap table exists
    if not db.minimap then
        db.minimap = {}
    end
    local mm = db.minimap

    -- SECTION 1: General
    local generalSection, generalContent, y = CreateCollapsibleSection(tabContent, "General", y, PAD, false, nil)
    local generalY = 0

    local enableCheck = GUI:CreateFormCheckbox(generalContent, "Enable QUI Minimap", "enabled", mm, RefreshMinimap)
    enableCheck:SetPoint("TOPLEFT", PAD, generalY)
    enableCheck:SetPoint("RIGHT", generalContent, "RIGHT", -PAD, 0)
    generalY = generalY - FORM_ROW

    -- Lock/dragging is now handled by Edit Mode via the layout manager
    -- Removed lock checkbox - positioning is controlled through Edit Mode

    local sizeSlider = GUI:CreateFormSlider(generalContent, "Map Dimensions (Pixels)", 120, 380, 1, "size", mm, RefreshMinimap)
    sizeSlider:SetPoint("TOPLEFT", PAD, generalY)
    sizeSlider:SetPoint("RIGHT", generalContent, "RIGHT", -PAD, 0)
    generalY = generalY - FORM_ROW

    local scaleSlider = GUI:CreateFormSlider(generalContent, "Minimap Scale", 0.5, 2.0, 0.01, "scale", mm, RefreshMinimap, { deferOnDrag = true })
    scaleSlider:SetPoint("TOPLEFT", PAD, generalY)
    scaleSlider:SetPoint("RIGHT", generalContent, "RIGHT", -PAD, 0)
    generalY = generalY - FORM_ROW

    local scaleDesc = GUI:CreateLabel(generalContent, "Scales minimap and datatext panel together without changing base pixel size.", 11, C.textMuted)
    scaleDesc:SetPoint("TOPLEFT", PAD, generalY + 4)
    scaleDesc:SetPoint("RIGHT", generalContent, "RIGHT", -PAD, 0)
    scaleDesc:SetJustifyH("LEFT")
    generalY = generalY - 20

    generalContent:SetHeight(math.abs(generalY) + 4)
    generalSection:UpdateHeight()

    -- SECTION 2: Frame Styling
    local styleSection, styleContent, y = CreateCollapsibleSection(tabContent, "Frame Styling", y, PAD, false, generalSection)
    local styleY = 0

    local borderSlider = GUI:CreateFormSlider(styleContent, "Border Size", 1, 16, 1, "borderSize", mm, RefreshMinimap)
    borderSlider:SetPoint("TOPLEFT", PAD, styleY)
    borderSlider:SetPoint("RIGHT", styleContent, "RIGHT", -PAD, 0)
    styleY = styleY - FORM_ROW

    local borderColor = GUI:CreateFormColorPicker(styleContent, "Custom Border Color", "borderColor", mm, RefreshMinimap)
    borderColor:SetPoint("TOPLEFT", PAD, styleY)
    borderColor:SetPoint("RIGHT", styleContent, "RIGHT", -PAD, 0)
    styleY = styleY - FORM_ROW

    local classBorderCheck = GUI:CreateFormCheckbox(styleContent, "Use Class Color for Edge", "useClassColorBorder", mm, RefreshMinimap)
    classBorderCheck:SetPoint("TOPLEFT", PAD, styleY)
    classBorderCheck:SetPoint("RIGHT", styleContent, "RIGHT", -PAD, 0)
    styleY = styleY - FORM_ROW

    styleContent:SetHeight(math.abs(styleY) + 4)
    styleSection:UpdateHeight()

    -- SECTION 3: Hide Minimap Elements
    local hideSection, hideContent, y = CreateCollapsibleSection(tabContent, "Hide Minimap Elements", y, PAD, false, styleSection)
    local hideY = 0

    local hideMail = GUI:CreateFormCheckboxInverted(hideContent, "Hide Mail (reload after)", "showMail", mm, RefreshMinimap)
    hideMail:SetPoint("TOPLEFT", PAD, hideY)
    hideMail:SetPoint("RIGHT", hideContent, "RIGHT", -PAD, 0)
    hideY = hideY - FORM_ROW

    local hideTracking = GUI:CreateFormCheckboxInverted(hideContent, "Hide Tracking", "showTracking", mm, RefreshMinimap)
    hideTracking:SetPoint("TOPLEFT", PAD, hideY)
    hideTracking:SetPoint("RIGHT", hideContent, "RIGHT", -PAD, 0)
    hideY = hideY - FORM_ROW

    local hideDifficulty = GUI:CreateFormCheckboxInverted(hideContent, "Hide Difficulty", "showDifficulty", mm, RefreshMinimap)
    hideDifficulty:SetPoint("TOPLEFT", PAD, hideY)
    hideDifficulty:SetPoint("RIGHT", hideContent, "RIGHT", -PAD, 0)
    hideY = hideY - FORM_ROW

    local hideExpansion = GUI:CreateFormCheckboxInverted(hideContent, "Hide Progress Report", "showMissions", mm, RefreshMinimap)
    hideExpansion:SetPoint("TOPLEFT", PAD, hideY)
    hideExpansion:SetPoint("RIGHT", hideContent, "RIGHT", -PAD, 0)
    hideY = hideY - FORM_ROW

    local hideBorder = GUI:CreateFormCheckbox(hideContent, "Hide Border (Top)", "hideMinimapBorder", db.uiHider, RefreshUIHider)
    hideBorder:SetPoint("TOPLEFT", PAD, hideY)
    hideBorder:SetPoint("RIGHT", hideContent, "RIGHT", -PAD, 0)
    hideY = hideY - FORM_ROW

    local hideClock = GUI:CreateFormCheckbox(hideContent, "Hide Clock Button", "hideTimeManager", db.uiHider, RefreshUIHider)
    hideClock:SetPoint("TOPLEFT", PAD, hideY)
    hideClock:SetPoint("RIGHT", hideContent, "RIGHT", -PAD, 0)
    hideY = hideY - FORM_ROW

    local hideCalendar = GUI:CreateFormCheckbox(hideContent, "Hide Calendar Button", "hideGameTime", db.uiHider, RefreshUIHider)
    hideCalendar:SetPoint("TOPLEFT", PAD, hideY)
    hideCalendar:SetPoint("RIGHT", hideContent, "RIGHT", -PAD, 0)
    hideY = hideY - FORM_ROW

    local hideZoneText = GUI:CreateFormCheckbox(hideContent, "Hide Zone Text (Native)", "hideMinimapZoneText", db.uiHider, RefreshUIHider)
    hideZoneText:SetPoint("TOPLEFT", PAD, hideY)
    hideZoneText:SetPoint("RIGHT", hideContent, "RIGHT", -PAD, 0)
    hideY = hideY - FORM_ROW

    local hideZoom = GUI:CreateFormCheckboxInverted(hideContent, "Hide Zoom Buttons", "showZoomButtons", mm, RefreshMinimap)
    hideZoom:SetPoint("TOPLEFT", PAD, hideY)
    hideZoom:SetPoint("RIGHT", hideContent, "RIGHT", -PAD, 0)
    hideY = hideY - FORM_ROW

    hideContent:SetHeight(math.abs(hideY) + 4)
    hideSection:UpdateHeight()

    -- SECTION 4: Zone Label
    local zoneSection, zoneContent, y = CreateCollapsibleSection(tabContent, "Zone Label", y, PAD, false, hideSection)
    local zoneY = 0

    local showZoneCheck = GUI:CreateFormCheckbox(zoneContent, "Show Zone Label", "showZoneText", mm, RefreshMinimap)
    showZoneCheck:SetPoint("TOPLEFT", PAD, zoneY)
    showZoneCheck:SetPoint("RIGHT", zoneContent, "RIGHT", -PAD, 0)
    zoneY = zoneY - FORM_ROW

    if mm.zoneTextConfig then
        local zoneOffsetX = GUI:CreateFormSlider(zoneContent, "Horizontal Offset", -150, 150, 1, "offsetX", mm.zoneTextConfig, RefreshMinimap)
        zoneOffsetX:SetPoint("TOPLEFT", PAD, zoneY)
        zoneOffsetX:SetPoint("RIGHT", zoneContent, "RIGHT", -PAD, 0)
        zoneY = zoneY - FORM_ROW

        local zoneOffsetY = GUI:CreateFormSlider(zoneContent, "Vertical Offset", -150, 150, 1, "offsetY", mm.zoneTextConfig, RefreshMinimap)
        zoneOffsetY:SetPoint("TOPLEFT", PAD, zoneY)
        zoneOffsetY:SetPoint("RIGHT", zoneContent, "RIGHT", -PAD, 0)
        zoneY = zoneY - FORM_ROW

        local zoneSize = GUI:CreateFormSlider(zoneContent, "Label Size", 8, 20, 1, "fontSize", mm.zoneTextConfig, RefreshMinimap)
        zoneSize:SetPoint("TOPLEFT", PAD, zoneY)
        zoneSize:SetPoint("RIGHT", zoneContent, "RIGHT", -PAD, 0)
        zoneY = zoneY - FORM_ROW

        local zoneAllCaps = GUI:CreateFormCheckbox(zoneContent, "Uppercase Text", "allCaps", mm.zoneTextConfig, RefreshMinimap)
        zoneAllCaps:SetPoint("TOPLEFT", PAD, zoneY)
        zoneAllCaps:SetPoint("RIGHT", zoneContent, "RIGHT", -PAD, 0)
        zoneY = zoneY - FORM_ROW

        local zoneClassColor = GUI:CreateFormCheckbox(zoneContent, "Use Class Color", "useClassColor", mm.zoneTextConfig, RefreshMinimap)
        zoneClassColor:SetPoint("TOPLEFT", PAD, zoneY)
        zoneClassColor:SetPoint("RIGHT", zoneContent, "RIGHT", -PAD, 0)
        zoneY = zoneY - FORM_ROW
    end

    zoneContent:SetHeight(math.abs(zoneY) + 4)
    zoneSection:UpdateHeight()

    -- SECTION 5: Dungeon Eye (LFG Queue Button)
    GUI:SetSearchSection("Dungeon Eye")
    local eyeSection, eyeContent, y = CreateCollapsibleSection(tabContent, "Dungeon Eye (LFG Queue)", y, PAD, false, zoneSection)
    local eyeY = 0

    local eyeDesc = GUI:CreateLabel(eyeContent, "When enabled, the queue eye automatically appears on the minimap when you join a queue.", 11, C.textMuted)
    eyeDesc:SetPoint("TOPLEFT", PAD, eyeY)
    eyeDesc:SetPoint("RIGHT", eyeContent, "RIGHT", -PAD, 0)
    eyeDesc:SetJustifyH("LEFT")
    eyeY = eyeY - 20

    if not mm.dungeonEye then
        mm.dungeonEye = {
            enabled = true,
            corner = "BOTTOMLEFT",
            scale = 0.6,
            offsetX = 0,
            offsetY = 0,
        }
    end
    local eye = mm.dungeonEye

    local eyeEnable = GUI:CreateFormCheckbox(eyeContent, "Enable Dungeon Eye", "enabled", eye, RefreshMinimap)
    eyeEnable:SetPoint("TOPLEFT", PAD, eyeY)
    eyeEnable:SetPoint("RIGHT", eyeContent, "RIGHT", -PAD, 0)
    eyeY = eyeY - FORM_ROW

    local cornerOptions = {
        {value = "TOPRIGHT", text = "Top Right"},
        {value = "TOPLEFT", text = "Top Left"},
        {value = "BOTTOMRIGHT", text = "Bottom Right"},
        {value = "BOTTOMLEFT", text = "Bottom Left"},
    }
    local eyeCorner = GUI:CreateFormDropdown(eyeContent, "Corner Position", cornerOptions, "corner", eye, RefreshMinimap)
    eyeCorner:SetPoint("TOPLEFT", PAD, eyeY)
    eyeCorner:SetPoint("RIGHT", eyeContent, "RIGHT", -PAD, 0)
    eyeY = eyeY - FORM_ROW

    local eyeScale = GUI:CreateFormSlider(eyeContent, "Icon Scale", 0.1, 2.0, 0.1, "scale", eye, RefreshMinimap)
    eyeScale:SetPoint("TOPLEFT", PAD, eyeY)
    eyeScale:SetPoint("RIGHT", eyeContent, "RIGHT", -PAD, 0)
    eyeY = eyeY - FORM_ROW

    local eyeOffsetX = GUI:CreateFormSlider(eyeContent, "X Offset", -30, 30, 1, "offsetX", eye, RefreshMinimap)
    eyeOffsetX:SetPoint("TOPLEFT", PAD, eyeY)
    eyeOffsetX:SetPoint("RIGHT", eyeContent, "RIGHT", -PAD, 0)
    eyeY = eyeY - FORM_ROW

    local eyeOffsetY = GUI:CreateFormSlider(eyeContent, "Y Offset", -30, 30, 1, "offsetY", eye, RefreshMinimap)
    eyeOffsetY:SetPoint("TOPLEFT", PAD, eyeY)
    eyeOffsetY:SetPoint("RIGHT", eyeContent, "RIGHT", -PAD, 0)
    eyeY = eyeY - FORM_ROW

    eyeContent:SetHeight(math.abs(eyeY) + 4)
    eyeSection:UpdateHeight()

    -- SECTION 6: Layout (Positioning)
    GUI:SetSearchSection("Layout")
    if ns.QUI_LayoutControl_Options and ns.QUI_LayoutManager then
        -- Get Minimap frame
        local minimapFrame = Minimap
        
        -- Only create layout controls if frame is registered with layout manager
        local layoutConfig = ns.QUI_LayoutManager:GetLayout(minimapFrame)
        if layoutConfig then
            local function OnLayoutChange()
                -- Layout Manager automatically applies position/size changes
                -- Just refresh minimap to ensure all elements update correctly
                RefreshMinimap()
            end

            -- Create layout control section
            local layoutSection, layoutContent, newY, controls = ns.QUI_LayoutControl_Options:CreateLayoutControl(
                tabContent, minimapFrame, y, PAD, FORM_ROW, OnLayoutChange, {
                    previousSection = eyeSection,
                    sectionTitle = "Layout",
                    offsetMin = -2000,
                    offsetMax = 2000,
                    widthMin = 0,
                    widthMax = 0,  -- Minimap size is controlled by "Map Dimensions" slider, not layout width
                    heightMin = 0,
                    heightMax = 0,  -- Minimap size is controlled by "Map Dimensions" slider, not layout height
                    showSize = false,  -- Hide size controls since minimap uses its own size setting
                }
            )
            
            -- Update y position for final tab height calculation
            if newY then
                y = newY
            end
        end
    end

    tabContent:SetHeight(math.abs(y) + 50)
end

-- Create full page wrapper
local function CreateMinimapPage(parent)
    local scroll, content = CreateScrollableContent(parent)
    BuildMinimapTab(content)
end

-- Export
local MinimapOptions = {
    BuildMinimapTab = BuildMinimapTab,
    CreateMinimapPage = CreateMinimapPage,
}

ns.MinimapOptions = MinimapOptions

-- Register with Options Page Registry as composed page
if ns.OptionsPageRegistry then
    -- Register as composed page
    ns.OptionsPageRegistry:RegisterComposedPage("minimap", "Minimap & Datatext", 30)
    -- Add the minimap page as the first sub-tab
    ns.OptionsPageRegistry:AddSubTab("minimap", {
        name = "Minimap",
        builder = BuildMinimapTab,
        order = 10,
    })
end

return MinimapOptions
