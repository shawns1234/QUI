--[[
    qui_unitframes_options.lua
    Options UI for Unit Frames component
    Includes player, target, pet, focus, target-of-target, and boss frame options
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
local GetTextureList = OptionsShared.GetTextureList

local function CreateUnitFramesPage(parent)
    -- Check if module is enabled before building content
    if not ns.IsModuleEnabled("unitframes") then
        local emptyLabel = GUI:CreateLabel(parent, "Unit Frames module is disabled.", 14, GUI.Colors.textMuted)
        emptyLabel:SetPoint("CENTER", parent, "CENTER", 0, 0)
        return
    end
    
    local scroll, content = CreateScrollableContent(parent)
    local db = GetDB()
    
    -- Get the new unit frames database
    local function GetUFDB()
        return db and db.quiUnitFrames
    end
    
    -- Refresh function for new unit frames
    local function RefreshNewUF()
        -- Defer refresh to prevent script timeout when opening tab
        C_Timer.After(0, function()
            if _G.QuaziiUI_RefreshUnitFrames then
                _G.QuaziiUI_RefreshUnitFrames()
            end
        end)
    end
    
    -- Build the General tab content
    local function BuildGeneralTab(tabContent)
        local y = -10
        local PAD = 10
        local FORM_ROW = 32
        local ufdb = GetUFDB()

        -- Set search context for auto-registration
        GUI:SetSearchContext({tabIndex = 2, tabName = "Single Frames & Castbars", subTabIndex = 1, subTabName = "General"})

        if not ufdb then
            local info = GUI:CreateLabel(tabContent, "Unit frame settings not available - database not loaded", 12, C.textMuted)
            info:SetPoint("TOPLEFT", PAD, y)
            tabContent:SetHeight(100)
            return
        end

        -- Use the main profile general settings (not ufdb.general)
        local general = db.general
        if not general then
            db.general = {}
            general = db.general
        end

        -- Enable checkbox
        local enableCheck = GUI:CreateFormCheckbox(tabContent, "Enable Unitframes (Req. Reload)", "enabled", ufdb, RefreshNewUF)
        enableCheck:SetPoint("TOPLEFT", PAD, y)
        enableCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        -- EDIT MODE section
        local editSection, editContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Positioning", y, PAD, false)
        local editY = 0

        local editDesc = GUI:CreateLabel(editContent, "Toggle Edit Mode to drag and reposition unit frames. Or use /qui editmode", 11, C.textMuted)
        editDesc:SetPoint("TOPLEFT", PAD, editY)
        editDesc:SetPoint("RIGHT", editContent, "RIGHT", -PAD, 0)
        editDesc:SetJustifyH("LEFT")
        editY = editY - 24

        -- Edit Mode button (form style)
        local editContainer = CreateFrame("Frame", nil, editContent)
        editContainer:SetHeight(FORM_ROW)
        editContainer:SetPoint("TOPLEFT", PAD, editY)
        editContainer:SetPoint("RIGHT", editContent, "RIGHT", -PAD, 0)

        local editLabel = editContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        editLabel:SetPoint("LEFT", 0, 0)
        editLabel:SetText("Edit Mode")
        editLabel:SetTextColor(C.text[1], C.text[2], C.text[3], 1)

        local editModeBtn = CreateFrame("Button", nil, editContainer, "BackdropTemplate")
        editModeBtn:SetSize(120, 24)
        editModeBtn:SetPoint("LEFT", editContainer, "LEFT", 180, 0)
        editModeBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        editModeBtn:SetBackdropColor(0.15, 0.15, 0.15, 1)
        editModeBtn:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)

        local editBtnText = editModeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        editBtnText:SetPoint("CENTER")
        editBtnText:SetText("Toggle")
        editBtnText:SetTextColor(C.text[1], C.text[2], C.text[3], 1)

        editModeBtn:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
        end)
        editModeBtn:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
        end)
        editModeBtn:SetScript("OnClick", function()
            if _G.QuaziiUI_ToggleUnitFrameEditMode then
                _G.QuaziiUI_ToggleUnitFrameEditMode()
            end
        end)
        editY = editY - FORM_ROW - 10
        editContent:SetHeight(math.abs(editY) + 4)
        editSection:UpdateHeight()

        -- Store widget refs for BOTH sections (bidirectional conditional disable)
        local defaultWidgets = {}
        local darkModeWidgets = {}

        -- Helper to update enable states based on dark mode toggle
        local function UpdateDarkModeWidgetStates()
            local darkModeOn = general.darkMode
            -- Default widgets: enabled when dark mode OFF
            if defaultWidgets.healthColor then defaultWidgets.healthColor:SetEnabled(not darkModeOn) end
            if defaultWidgets.bgColor then defaultWidgets.bgColor:SetEnabled(not darkModeOn) end
            if defaultWidgets.opacity then defaultWidgets.opacity:SetEnabled(not darkModeOn) end
            -- Darkmode widgets: enabled when dark mode ON
            if darkModeWidgets.healthColor then darkModeWidgets.healthColor:SetEnabled(darkModeOn) end
            if darkModeWidgets.bgColor then darkModeWidgets.bgColor:SetEnabled(darkModeOn) end
            if darkModeWidgets.opacity then darkModeWidgets.opacity:SetEnabled(darkModeOn) end
        end

        -- DEFAULT UNITFRAME COLORS section
        local defaultSection, defaultContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Default Unitframe Colors", y, PAD, false, editSection)
        local defaultY = 0

        local defaultDesc = GUI:CreateLabel(defaultContent, "Colors and opacity applied to unit frames when Dark Mode is disabled.", 11, C.textMuted)
        defaultDesc:SetPoint("TOPLEFT", PAD, defaultY)
        defaultDesc:SetPoint("RIGHT", defaultContent, "RIGHT", -PAD, 0)
        defaultDesc:SetJustifyH("LEFT")
        defaultY = defaultY - 24

        -- Use Class Colors toggle (greys out Default Health Color when ON)
        local defUseClassColor = GUI:CreateFormCheckbox(defaultContent, "Use Class Colors", "defaultUseClassColor", general, function()
            RefreshNewUF()
            -- Grey out health color picker when class colors is enabled
            if defaultWidgets.healthColor then
                defaultWidgets.healthColor:SetEnabled(not general.defaultUseClassColor)
            end
        end)
        defUseClassColor:SetPoint("TOPLEFT", PAD, defaultY)
        defUseClassColor:SetPoint("RIGHT", defaultContent, "RIGHT", -PAD, 0)
        defaultWidgets.useClassColor = defUseClassColor
        defaultY = defaultY - FORM_ROW

        -- Default Health Color (greyed out when Use Class Colors is ON)
        local defHealthColor = GUI:CreateFormColorPicker(defaultContent, "Default Health Color", "defaultHealthColor", general, RefreshNewUF, { noAlpha = true })
        defHealthColor:SetPoint("TOPLEFT", PAD, defaultY)
        defHealthColor:SetPoint("RIGHT", defaultContent, "RIGHT", -PAD, 0)
        defaultWidgets.healthColor = defHealthColor
        defHealthColor:SetEnabled(not general.defaultUseClassColor)  -- Initial state
        defaultY = defaultY - FORM_ROW

        -- Default Background Color
        local defBgColor = GUI:CreateFormColorPicker(defaultContent, "Default Background Color", "defaultBgColor", general, RefreshNewUF, { noAlpha = true })
        defBgColor:SetPoint("TOPLEFT", PAD, defaultY)
        defBgColor:SetPoint("RIGHT", defaultContent, "RIGHT", -PAD, 0)
        defaultWidgets.bgColor = defBgColor
        defaultY = defaultY - FORM_ROW

        -- Default Opacity
        local defOpacity = GUI:CreateFormSlider(defaultContent, "Default Opacity", 0.1, 1.0, 0.01, "defaultOpacity", general, RefreshNewUF)
        defOpacity:SetPoint("TOPLEFT", PAD, defaultY)
        defOpacity:SetPoint("RIGHT", defaultContent, "RIGHT", -PAD, 0)
        defaultWidgets.opacity = defOpacity
        defaultY = defaultY - FORM_ROW - 10
        defaultContent:SetHeight(math.abs(defaultY) + 4)
        defaultSection:UpdateHeight()

        -- DARK MODE section
        local darkSection, darkContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Darkmode For Unitframes", y, PAD, false, defaultSection)
        local darkY = 0

        local darkDesc = GUI:CreateLabel(darkContent, "Instantly applies dark flat colors to all unit frame health bars.", 11, C.textMuted)
        darkDesc:SetPoint("TOPLEFT", PAD, darkY)
        darkDesc:SetPoint("RIGHT", darkContent, "RIGHT", -PAD, 0)
        darkDesc:SetJustifyH("LEFT")
        darkY = darkY - 24

        local darkEnable = GUI:CreateFormCheckbox(darkContent, "Enable Dark Mode", "darkMode", general, function()
            RefreshNewUF()
            UpdateDarkModeWidgetStates()
        end)
        darkEnable:SetPoint("TOPLEFT", PAD, darkY)
        darkEnable:SetPoint("RIGHT", darkContent, "RIGHT", -PAD, 0)
        darkY = darkY - FORM_ROW

        -- Darkmode Health Color (no alpha - pure RGB)
        local healthColor = GUI:CreateFormColorPicker(darkContent, "Darkmode Health Color", "darkModeHealthColor", general, RefreshNewUF, { noAlpha = true })
        healthColor:SetPoint("TOPLEFT", PAD, darkY)
        healthColor:SetPoint("RIGHT", darkContent, "RIGHT", -PAD, 0)
        darkModeWidgets.healthColor = healthColor
        darkY = darkY - FORM_ROW

        -- Darkmode Background Color (no alpha - pure RGB)
        local bgColor = GUI:CreateFormColorPicker(darkContent, "Darkmode Background Color", "darkModeBgColor", general, RefreshNewUF, { noAlpha = true })
        bgColor:SetPoint("TOPLEFT", PAD, darkY)
        bgColor:SetPoint("RIGHT", darkContent, "RIGHT", -PAD, 0)
        darkModeWidgets.bgColor = bgColor
        darkY = darkY - FORM_ROW

        -- Darkmode Opacity slider (0.1 to 1.0, step 0.01)
        local opacitySlider = GUI:CreateFormSlider(darkContent, "Darkmode Opacity", 0.1, 1.0, 0.01, "darkModeOpacity", general, RefreshNewUF)
        opacitySlider:SetPoint("TOPLEFT", PAD, darkY)
        opacitySlider:SetPoint("RIGHT", darkContent, "RIGHT", -PAD, 0)
        darkModeWidgets.opacity = opacitySlider
        darkY = darkY - FORM_ROW - 10
        darkContent:SetHeight(math.abs(darkY) + 4)
        darkSection:UpdateHeight()

        -- Set initial enable/disable states for both sections
        UpdateDarkModeWidgetStates()

        -- MASTER TEXT COLOR OVERRIDES section
        local textSection, textContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Text Class Color/React Color Overrides (Recommended For Dark Mode)", y, PAD, false, darkSection)
        local textY = 0

        local textDesc = GUI:CreateLabel(textContent, "Apply class/reaction color to text across ALL unit frames. When enabled, master toggles override individual frame settings.", 11, C.textMuted)
        textDesc:SetPoint("TOPLEFT", PAD, textY)
        textDesc:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textDesc:SetJustifyH("LEFT")
        textDesc:SetWordWrap(true)
        textDesc:SetHeight(30)
        textY = textY - 40

        local masterNameText = GUI:CreateFormCheckbox(textContent, "Color ALL Name Text", "masterColorNameText", general, RefreshNewUF)
        masterNameText:SetPoint("TOPLEFT", PAD, textY)
        masterNameText:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local masterHealthText = GUI:CreateFormCheckbox(textContent, "Color ALL Health Text", "masterColorHealthText", general, RefreshNewUF)
        masterHealthText:SetPoint("TOPLEFT", PAD, textY)
        masterHealthText:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local masterPowerText = GUI:CreateFormCheckbox(textContent, "Color ALL Power Text", "masterColorPowerText", general, RefreshNewUF)
        masterPowerText:SetPoint("TOPLEFT", PAD, textY)
        masterPowerText:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local masterCastbarText = GUI:CreateFormCheckbox(textContent, "Color ALL Castbar Text", "masterColorCastbarText", general, RefreshNewUF)
        masterCastbarText:SetPoint("TOPLEFT", PAD, textY)
        masterCastbarText:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local masterToTText = GUI:CreateFormCheckbox(textContent, "Color ALL ToT Text", "masterColorToTText", general, RefreshNewUF)
        masterToTText:SetPoint("TOPLEFT", PAD, textY)
        masterToTText:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW
        textContent:SetHeight(math.abs(textY) + 4)
        textSection:UpdateHeight()

        -- TOOLTIPS SECTION
        local tooltipSection, tooltipContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Tooltips on QUI Unitframes", y, PAD, false, textSection)
        local tooltipY = 0

        local tooltipCheck = GUI:CreateFormCheckbox(tooltipContent, "Show Tooltip for Unitframes", "showTooltips", ufdb.general, RefreshNewUF)
        tooltipCheck:SetPoint("TOPLEFT", PAD, tooltipY)
        tooltipCheck:SetPoint("RIGHT", tooltipContent, "RIGHT", -PAD, 0)
        tooltipY = tooltipY - FORM_ROW
        tooltipContent:SetHeight(math.abs(tooltipY) + 4)
        tooltipSection:UpdateHeight()

        -- Smoother Updates section
        local smoothSection, smoothContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Smoother Updates", y, PAD, false, tooltipSection)
        local smoothY = 0

        local smoothDesc = GUI:CreateLabel(smoothContent, "Target, Focus, and Boss castbars are throttled to 60 FPS for CPU efficiency. Enable this option if you prefer maximum smoothness and don't mind the extra CPU usage.", 11, C.textMuted)
        smoothDesc:SetPoint("TOPLEFT", PAD, smoothY)
        smoothDesc:SetPoint("RIGHT", smoothContent, "RIGHT", -PAD, 0)
        smoothDesc:SetJustifyH("LEFT")
        smoothY = smoothY - 24

        local smoothCheck = GUI:CreateFormCheckbox(smoothContent, "Smoother Animation", "smootherAnimation", ufdb.general, RefreshNewUF)
        smoothCheck:SetPoint("TOPLEFT", PAD, smoothY)
        smoothCheck:SetPoint("RIGHT", smoothContent, "RIGHT", -PAD, 0)
        smoothY = smoothY - FORM_ROW
        smoothContent:SetHeight(math.abs(smoothY) + 4)
        smoothSection:UpdateHeight()

        -- Hostility Color Customization section
        local hostilitySection, hostilityContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Hostility Color Customization", y, PAD, false, smoothSection)
        local hostilityY = 0

        local hostilityDesc = GUI:CreateLabel(hostilityContent, "Customize the colors used for hostile, neutral, and friendly NPCs on unit frames that have 'Use Hostility Color' enabled.", 11, C.textMuted)
        hostilityDesc:SetPoint("TOPLEFT", PAD, hostilityY)
        hostilityDesc:SetPoint("RIGHT", hostilityContent, "RIGHT", -PAD, 0)
        hostilityDesc:SetJustifyH("LEFT")
        hostilityY = hostilityY - 24

        local hostileColor = GUI:CreateFormColorPicker(hostilityContent, "Hostile Color", "hostilityColorHostile", ufdb.general, RefreshNewUF, { noAlpha = true })
        hostileColor:SetPoint("TOPLEFT", PAD, hostilityY)
        hostileColor:SetPoint("RIGHT", hostilityContent, "RIGHT", -PAD, 0)
        hostilityY = hostilityY - FORM_ROW

        local neutralColor = GUI:CreateFormColorPicker(hostilityContent, "Neutral Color", "hostilityColorNeutral", ufdb.general, RefreshNewUF, { noAlpha = true })
        neutralColor:SetPoint("TOPLEFT", PAD, hostilityY)
        neutralColor:SetPoint("RIGHT", hostilityContent, "RIGHT", -PAD, 0)
        hostilityY = hostilityY - FORM_ROW

        local friendlyColor = GUI:CreateFormColorPicker(hostilityContent, "Friendly Color", "hostilityColorFriendly", ufdb.general, RefreshNewUF, { noAlpha = true })
        friendlyColor:SetPoint("TOPLEFT", PAD, hostilityY)
        friendlyColor:SetPoint("RIGHT", hostilityContent, "RIGHT", -PAD, 0)
        hostilityY = hostilityY - FORM_ROW
        hostilityContent:SetHeight(math.abs(hostilityY) + 4)
        hostilitySection:UpdateHeight()

        -- Use the scroll content's automatic height calculation
        if tabContent.UpdateHeight then
            C_Timer.After(0.1, function()
                tabContent:UpdateHeight()
            end)
        else
            -- Fallback: set height manually
            tabContent:SetHeight(math.abs(y) + 20)
        end
    end
    
    -- Build unit-specific tab content (Player, Target, etc.)
    local function BuildUnitTab(tabContent, unitKey)
        local y = -10
        local PAD = 10
        local FORM_ROW = 32
        local ufdb = GetUFDB()

        -- Set search context for widget auto-registration (dynamic based on unitKey)
        local unitSubTabs = {
            player = {index = 2, name = "Player"},
            target = {index = 3, name = "Target"},
            targettarget = {index = 4, name = "ToT"},
            pet = {index = 5, name = "Pet"},
            focus = {index = 6, name = "Focus"},
            boss = {index = 7, name = "Boss"},
        }
        local subTabInfo = unitSubTabs[unitKey] or {index = 2, name = unitKey}
        GUI:SetSearchContext({tabIndex = 2, tabName = "Single Frames & Castbars", subTabIndex = subTabInfo.index, subTabName = subTabInfo.name})

        if not ufdb or not ufdb[unitKey] then
            local info = GUI:CreateLabel(tabContent, "Unit frame settings not available for " .. unitKey, 12, C.textMuted)
            info:SetPoint("TOPLEFT", PAD, y)
            tabContent:SetHeight(100)
            return
        end

        local unitDB = ufdb[unitKey]

        -- Refresh function for this specific unit
        local function RefreshUnit()
            RefreshNewUF()
            -- Preview state is now in database, CreateCastbar will handle it
        end

        -- Refresh function specifically for aura settings
        local function RefreshAuras()
            RefreshNewUF()
            -- Refresh aura preview if active (re-render with new settings)
            local QUI_UF = ns.QUI_UnitFrames
            if QUI_UF and QUI_UF.auraPreviewMode then
                if QUI_UF.auraPreviewMode[unitKey .. "_debuff"] then
                    _G.QuaziiUI_ShowAuraPreview(unitKey, "debuff")
                end
                if QUI_UF.auraPreviewMode[unitKey .. "_buff"] then
                    _G.QuaziiUI_ShowAuraPreview(unitKey, "buff")
                end
            end
            -- Refresh real auras if not in preview mode
            if _G.QuaziiUI_RefreshAuras then
                _G.QuaziiUI_RefreshAuras(unitKey)
            end
        end

        -- Preview button row (form style)
        local previewContainer = CreateFrame("Frame", nil, tabContent)
        previewContainer:SetHeight(FORM_ROW)
        previewContainer:SetPoint("TOPLEFT", PAD, y)
        previewContainer:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)

        local previewLabel = previewContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        previewLabel:SetPoint("LEFT", 0, 0)
        previewLabel:SetText("Frame Preview")
        previewLabel:SetTextColor(C.text[1], C.text[2], C.text[3], 1)

        -- Toggle track (pill-shaped, matches CreateFormToggle)
        local previewTrack = CreateFrame("Button", nil, previewContainer, "BackdropTemplate")
        previewTrack:SetSize(40, 20)
        previewTrack:SetPoint("LEFT", previewContainer, "LEFT", 180, 0)
        previewTrack:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})

        -- Thumb (sliding circle)
        local previewThumb = CreateFrame("Frame", nil, previewTrack, "BackdropTemplate")
        previewThumb:SetSize(16, 16)
        previewThumb:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
        previewThumb:SetBackdropColor(0.95, 0.95, 0.95, 1)
        previewThumb:SetBackdropBorderColor(0.85, 0.85, 0.85, 1)
        previewThumb:SetFrameLevel(previewTrack:GetFrameLevel() + 1)

        -- Initialize state (preview defaults to off when panel opens)
        local isPreviewOn = false
        local function UpdatePreviewToggle(on)
            if on then
                previewTrack:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], 1)
                previewTrack:SetBackdropBorderColor(C.accent[1]*0.8, C.accent[2]*0.8, C.accent[3]*0.8, 1)
                previewThumb:ClearAllPoints()
                previewThumb:SetPoint("RIGHT", previewTrack, "RIGHT", -2, 0)
            else
                previewTrack:SetBackdropColor(0.15, 0.18, 0.22, 1)
                previewTrack:SetBackdropBorderColor(0.12, 0.14, 0.18, 1)
                previewThumb:ClearAllPoints()
                previewThumb:SetPoint("LEFT", previewTrack, "LEFT", 2, 0)
            end
        end
        UpdatePreviewToggle(isPreviewOn)

        previewTrack:SetScript("OnClick", function()
            isPreviewOn = not isPreviewOn
            UpdatePreviewToggle(isPreviewOn)
            if isPreviewOn then
                if _G.QuaziiUI_ShowUnitFramePreview then _G.QuaziiUI_ShowUnitFramePreview(unitKey) end
            else
                if _G.QuaziiUI_HideUnitFramePreview then _G.QuaziiUI_HideUnitFramePreview(unitKey) end
            end
        end)
        y = y - FORM_ROW

        -- Enable checkbox (requires reload)
        local displayNames = {targettarget = "Target of Target"}
        local frameName = displayNames[unitKey] or unitKey:gsub("^%l", string.upper)
        local enableCheck = GUI:CreateFormCheckbox(tabContent, "Enable " .. frameName .. " Frame", "enabled", unitDB, function()
            GUI:ShowConfirmation({
                title = "Reload UI?",
                message = "Enabling or disabling unit frames requires a UI reload to take effect.",
                acceptText = "Reload",
                cancelText = "Later",
                onAccept = function() QuaziiUI:SafeReload() end,
            })
        end)
        enableCheck:SetPoint("TOPLEFT", PAD, y)
        enableCheck:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW
        
        -- Boss frames get spacing slider (not handled by layout system)
        if unitKey == "boss" then
            local spacingSlider = GUI:CreateFormSlider(tabContent, "Spacing", 0, 100, 1, "spacing", unitDB, RefreshUnit)
            spacingSlider:SetPoint("TOPLEFT", PAD, y)
            spacingSlider:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
            y = y - FORM_ROW
        end

        -- Initialize defaults if needed
        if unitDB.anchorTo == nil then unitDB.anchorTo = "none" end
        
        -- Migration is now handled centrally by the anchoring system via MigrateAnchorConfig()
        -- anchorGap/anchorYOffset migration can be added to centralized migration if needed
        
        -- Initialize anchors array if not exists
        if not unitDB.anchors then
            -- Default anchor points based on unit frame type
            local defaultSource, defaultTarget
            if unitKey == "player" then
                defaultSource = "TOPLEFT"
                defaultTarget = "TOPLEFT"
            elseif unitKey == "target" then
                defaultSource = "TOPRIGHT"
                defaultTarget = "TOPRIGHT"
            else
                -- For other frames (pet, focus, targettarget, boss), default to TOPLEFT
                defaultSource = "TOPLEFT"
                defaultTarget = "TOPLEFT"
            end
            unitDB.anchors = {
                {source = defaultSource, target = defaultTarget}
            }
        end
        
        -- Initialize offsetX/offsetY if not exists
        if unitDB.offsetX == nil then unitDB.offsetX = 10 end
        if unitDB.offsetY == nil then unitDB.offsetY = 0 end

        -- Use CreateLayoutControl to create all layout UI components in one call
        -- Width/height sliders update the layout system directly (no callbacks needed)
        -- The layout system automatically applies changes to frames
        local layoutSection
        if ns.QUI_LayoutControl_Options then
            -- Anchoring system handles all updates automatically - no callbacks needed
            local function OnAnchorChange()
                RefreshUnit()
            end

            local QUI_UF = ns.QUI_UnitFrames
            local frame = QUI_UF and QUI_UF.frames and QUI_UF.frames[unitKey] or nil
            layoutSection, _, y = ns.QUI_LayoutControl_Options:CreateLayoutControl(
                tabContent, frame, y, PAD, FORM_ROW, OnAnchorChange, {
                    previousSection = generalSection,
                    anchorKey = "anchorTo",
                    maxAnchors = 2,
                    excludeSelf = unitKey,
                    widthMin = 100,
                    widthMax = 500,
                    heightMin = 20,
                    heightMax = 100
                }
            )
        end
        
        -- COLORS section
        local colorSection, colorContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Health Bar Colors", y, PAD, false, layoutSection)
        local colorY = 0

        -- Texture dropdown (inside Health Bar Colors section)
        local textureDropdown = GUI:CreateFormDropdown(colorContent, "Bar Texture", GetTextureList(), "texture", unitDB, RefreshUnit)
        textureDropdown:SetPoint("TOPLEFT", PAD, colorY)
        textureDropdown:SetPoint("RIGHT", colorContent, "RIGHT", -PAD, 0)
        colorY = colorY - FORM_ROW

        -- Helper text explaining color priority (only for frames with hostility option)
        if unitKey ~= "player" then
            local colorDesc = GUI:CreateLabel(colorContent, "Class color for players, hostility color for NPCs. Custom color is the fallback.", 11, C.textMuted)
            colorDesc:SetPoint("TOPLEFT", PAD, colorY)
            colorDesc:SetPoint("RIGHT", colorContent, "RIGHT", -PAD, 0)
            colorDesc:SetJustifyH("LEFT")
            colorY = colorY - 24
        end

        -- Store custom color reference for conditional disable
        local customColor = nil

        local classColorCheck = GUI:CreateFormCheckbox(colorContent, "Use Class Color", "useClassColor", unitDB, RefreshUnit)
        classColorCheck:SetPoint("TOPLEFT", PAD, colorY)
        classColorCheck:SetPoint("RIGHT", colorContent, "RIGHT", -PAD, 0)
        colorY = colorY - FORM_ROW

        -- Hostility Color checkbox (for frames that can show varied unit types)
        if unitKey == "target" or unitKey == "focus" or unitKey == "targettarget" or unitKey == "pet" or unitKey == "boss" then
            local hostilityColorCheck = GUI:CreateFormCheckbox(colorContent, "Use Hostility Color", "useHostilityColor", unitDB, function()
                RefreshUnit()
                -- Disable custom color when hostility is ON (covers all units)
                if customColor then
                    customColor:SetEnabled(not unitDB.useHostilityColor)
                end
            end)
            hostilityColorCheck:SetPoint("TOPLEFT", PAD, colorY)
            hostilityColorCheck:SetPoint("RIGHT", colorContent, "RIGHT", -PAD, 0)
            colorY = colorY - FORM_ROW
        end

        customColor = GUI:CreateFormColorPicker(colorContent, "Custom Color", "customHealthColor", unitDB, RefreshUnit)
        customColor:SetPoint("TOPLEFT", PAD, colorY)
        customColor:SetPoint("RIGHT", colorContent, "RIGHT", -PAD, 0)
        -- Set initial enabled state based on hostility setting
        if unitKey == "target" or unitKey == "focus" or unitKey == "targettarget" or unitKey == "pet" or unitKey == "boss" then
            customColor:SetEnabled(not unitDB.useHostilityColor)
        end
        colorY = colorY - FORM_ROW
        colorContent:SetHeight(math.abs(colorY) + 4)
        colorSection:UpdateHeight()

        -- ABSORB INDICATOR section
        local absorbSection, absorbContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Absorb Indicator", y, PAD, false, colorSection)
        local absorbY = 0

        if not unitDB.absorbs then
            unitDB.absorbs = {
                enabled = true,
                color = { 0.2, 0.8, 0.8 },
                opacity = 0.7,
            }
        end

        local absorbCheck = GUI:CreateFormCheckbox(absorbContent, "Show Absorb Shields", "enabled", unitDB.absorbs, RefreshUnit)
        absorbCheck:SetPoint("TOPLEFT", PAD, absorbY)
        absorbCheck:SetPoint("RIGHT", absorbContent, "RIGHT", -PAD, 0)
        absorbY = absorbY - FORM_ROW

        local absorbOpacity = GUI:CreateFormSlider(absorbContent, "Opacity", 0, 1, 0.05, "opacity", unitDB.absorbs, RefreshUnit)
        absorbOpacity:SetPoint("TOPLEFT", PAD, absorbY)
        absorbOpacity:SetPoint("RIGHT", absorbContent, "RIGHT", -PAD, 0)
        absorbY = absorbY - FORM_ROW

        local absorbColor = GUI:CreateFormColorPicker(absorbContent, "Absorb Color", "color", unitDB.absorbs, RefreshUnit)
        absorbColor:SetPoint("TOPLEFT", PAD, absorbY)
        absorbColor:SetPoint("RIGHT", absorbContent, "RIGHT", -PAD, 0)
        absorbY = absorbY - FORM_ROW
        absorbContent:SetHeight(math.abs(absorbY) + 4)
        absorbSection:UpdateHeight()

        -- Anchor options for text positioning (defined locally in BuildUnitTab)
        local anchorOptions = {
            {value = "TOPLEFT", text = "Top Left"},
            {value = "TOP", text = "Top Center"},
            {value = "TOPRIGHT", text = "Top Right"},
            {value = "LEFT", text = "Center Left"},
            {value = "CENTER", text = "Center"},
            {value = "RIGHT", text = "Center Right"},
            {value = "BOTTOMLEFT", text = "Bottom Left"},
            {value = "BOTTOM", text = "Bottom Center"},
            {value = "BOTTOMRIGHT", text = "Bottom Right"},
        }

        -- NAME TEXT section
        local nameSection, nameContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Name Text", y, PAD, false, absorbSection)
        local nameY = 0

        local showNameCheck = GUI:CreateFormCheckbox(nameContent, "Show Name", "showName", unitDB, RefreshUnit)
        showNameCheck:SetPoint("TOPLEFT", PAD, nameY)
        showNameCheck:SetPoint("RIGHT", nameContent, "RIGHT", -PAD, 0)
        nameY = nameY - FORM_ROW

        local nameSizeSlider = GUI:CreateFormSlider(nameContent, "Font Size", 8, 24, 1, "nameFontSize", unitDB, RefreshUnit)
        nameSizeSlider:SetPoint("TOPLEFT", PAD, nameY)
        nameSizeSlider:SetPoint("RIGHT", nameContent, "RIGHT", -PAD, 0)
        nameY = nameY - FORM_ROW

        local nameColorPicker = GUI:CreateFormColorPicker(nameContent, "Custom Name Text Color", "nameTextColor", unitDB, RefreshUnit)
        nameColorPicker:SetPoint("TOPLEFT", PAD, nameY)
        nameColorPicker:SetPoint("RIGHT", nameContent, "RIGHT", -PAD, 0)
        nameY = nameY - FORM_ROW

        local nameAnchorDropdown = GUI:CreateFormDropdown(nameContent, "Anchor", anchorOptions, "nameAnchor", unitDB, RefreshUnit)
        nameAnchorDropdown:SetPoint("TOPLEFT", PAD, nameY)
        nameAnchorDropdown:SetPoint("RIGHT", nameContent, "RIGHT", -PAD, 0)
        nameY = nameY - FORM_ROW

        local nameXSlider = GUI:CreateFormSlider(nameContent, "X Offset", -100, 100, 1, "nameOffsetX", unitDB, RefreshUnit)
        nameXSlider:SetPoint("TOPLEFT", PAD, nameY)
        nameXSlider:SetPoint("RIGHT", nameContent, "RIGHT", -PAD, 0)
        nameY = nameY - FORM_ROW

        local nameYSlider = GUI:CreateFormSlider(nameContent, "Y Offset", -50, 50, 1, "nameOffsetY", unitDB, RefreshUnit)
        nameYSlider:SetPoint("TOPLEFT", PAD, nameY)
        nameYSlider:SetPoint("RIGHT", nameContent, "RIGHT", -PAD, 0)
        nameY = nameY - FORM_ROW

        local nameTruncSlider = GUI:CreateFormSlider(nameContent, "Max Length (0=none)", 0, 30, 1, "maxNameLength", unitDB, RefreshUnit)
        nameTruncSlider:SetPoint("TOPLEFT", PAD, nameY)
        nameTruncSlider:SetPoint("RIGHT", nameContent, "RIGHT", -PAD, 0)
        nameY = nameY - FORM_ROW
        nameContent:SetHeight(math.abs(nameY) + 4)
        nameSection:UpdateHeight()

        -- TARGET OF TARGET TEXT section (target only)
        local totSection
        if unitKey == "target" then
            totSection, totContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Target Of Target Text", y, PAD, false, nameSection)
            local totY = 0

            local totCheck = GUI:CreateFormCheckbox(totContent, "Show Inline Target-of-Target", "showInlineToT", unitDB, RefreshUnit)
            totCheck:SetPoint("TOPLEFT", PAD, totY)
            totCheck:SetPoint("RIGHT", totContent, "RIGHT", -PAD, 0)
            totY = totY - FORM_ROW

            local totSepOptions = {
                {value = " >> ", text = ">>"},
                {value = " > ", text = ">"},
                {value = " - ", text = "-"},
                {value = " | ", text = "|"},
                {value = " -> ", text = "->"},
                {value = " —> ", text = "—>"},
                {value = " >>> ", text = ">>>"},
            }
            local totSepDropdown = GUI:CreateFormDropdown(totContent, "ToT Separator", totSepOptions, "totSeparator", unitDB, RefreshUnit)
            totSepDropdown:SetPoint("TOPLEFT", PAD, totY)
            totSepDropdown:SetPoint("RIGHT", totContent, "RIGHT", -PAD, 0)
            totY = totY - FORM_ROW

            -- Store reference for enable/disable logic
            local totDividerWidgets = {}

            -- Toggle: Color Divider By Class/React
            local totDividerClassCheck = GUI:CreateFormCheckbox(totContent, "Color Divider By Class/React", "totDividerUseClassColor", unitDB, function()
                RefreshUnit()
                -- Disable custom color picker when class color is enabled
                if totDividerWidgets.customColor then
                    totDividerWidgets.customColor:SetEnabled(not unitDB.totDividerUseClassColor)
                end
            end)
            totDividerClassCheck:SetPoint("TOPLEFT", PAD, totY)
            totDividerClassCheck:SetPoint("RIGHT", totContent, "RIGHT", -PAD, 0)
            totY = totY - FORM_ROW

            -- Color Picker: Custom Divider Color (disabled when class color toggle is ON)
            local totDividerColor = GUI:CreateFormColorPicker(totContent, "Custom Divider Color", "totDividerColor", unitDB, RefreshUnit)
            totDividerColor:SetPoint("TOPLEFT", PAD, totY)
            totDividerColor:SetPoint("RIGHT", totContent, "RIGHT", -PAD, 0)
            totDividerWidgets.customColor = totDividerColor
            totDividerColor:SetEnabled(not unitDB.totDividerUseClassColor)  -- Initial state
            totY = totY - FORM_ROW

            local totCharLimitSlider = GUI:CreateFormSlider(totContent, "ToT Name Character Limit", 0, 100, 1, "totNameCharLimit", unitDB, RefreshUnit)
            totCharLimitSlider:SetPoint("TOPLEFT", PAD, totY)
            totCharLimitSlider:SetPoint("RIGHT", totContent, "RIGHT", -PAD, 0)
            totY = totY - FORM_ROW
            totContent:SetHeight(math.abs(totY) + 4)
            totSection:UpdateHeight()
        end

        -- HEALTH TEXT section
        local healthSection, healthContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Health Text", y, PAD, false, totSection or nameSection)
        local healthY = 0

        local showHealthCheck = GUI:CreateFormCheckbox(healthContent, "Show Health", "showHealth", unitDB, RefreshUnit)
        showHealthCheck:SetPoint("TOPLEFT", PAD, healthY)
        showHealthCheck:SetPoint("RIGHT", healthContent, "RIGHT", -PAD, 0)
        healthY = healthY - FORM_ROW

        local healthStyleOptions = {
            {value = "percent", text = "Percent Only (75%)"},
            {value = "absolute", text = "Value Only (45.2k)"},
            {value = "both", text = "Value | Percent"},
            {value = "both_reverse", text = "Percent | Value"},
        }
        local healthStyleDropdown = GUI:CreateFormDropdown(healthContent, "Display Style", healthStyleOptions, "healthDisplayStyle", unitDB, RefreshUnit)
        healthStyleDropdown:SetPoint("TOPLEFT", PAD, healthY)
        healthStyleDropdown:SetPoint("RIGHT", healthContent, "RIGHT", -PAD, 0)
        healthY = healthY - FORM_ROW

        local healthDividerOptions = {
            {value = " | ", text = "|  (pipe)"},
            {value = " - ", text = "-  (dash)"},
            {value = " / ", text = "/  (slash)"},
            {value = " • ", text = "•  (dot)"},
        }
        local healthDividerDropdown = GUI:CreateFormDropdown(healthContent, "Divider", healthDividerOptions, "healthDivider", unitDB, RefreshUnit)
        healthDividerDropdown:SetPoint("TOPLEFT", PAD, healthY)
        healthDividerDropdown:SetPoint("RIGHT", healthContent, "RIGHT", -PAD, 0)
        healthY = healthY - FORM_ROW

        local healthTextColorPicker = GUI:CreateFormColorPicker(healthContent, "Custom Health Text Color", "healthTextColor", unitDB, RefreshUnit)
        healthTextColorPicker:SetPoint("TOPLEFT", PAD, healthY)
        healthTextColorPicker:SetPoint("RIGHT", healthContent, "RIGHT", -PAD, 0)
        healthY = healthY - FORM_ROW

        local healthSizeSlider = GUI:CreateFormSlider(healthContent, "Font Size", 8, 24, 1, "healthFontSize", unitDB, RefreshUnit)
        healthSizeSlider:SetPoint("TOPLEFT", PAD, healthY)
        healthSizeSlider:SetPoint("RIGHT", healthContent, "RIGHT", -PAD, 0)
        healthY = healthY - FORM_ROW

        local healthAnchorDropdown = GUI:CreateFormDropdown(healthContent, "Anchor", anchorOptions, "healthAnchor", unitDB, RefreshUnit)
        healthAnchorDropdown:SetPoint("TOPLEFT", PAD, healthY)
        healthAnchorDropdown:SetPoint("RIGHT", healthContent, "RIGHT", -PAD, 0)
        healthY = healthY - FORM_ROW

        local healthXSlider = GUI:CreateFormSlider(healthContent, "X Offset", -100, 100, 1, "healthOffsetX", unitDB, RefreshUnit)
        healthXSlider:SetPoint("TOPLEFT", PAD, healthY)
        healthXSlider:SetPoint("RIGHT", healthContent, "RIGHT", -PAD, 0)
        healthY = healthY - FORM_ROW

        local healthYSlider = GUI:CreateFormSlider(healthContent, "Y Offset", -50, 50, 1, "healthOffsetY", unitDB, RefreshUnit)
        healthYSlider:SetPoint("TOPLEFT", PAD, healthY)
        healthYSlider:SetPoint("RIGHT", healthContent, "RIGHT", -PAD, 0)
        healthY = healthY - FORM_ROW
        healthContent:SetHeight(math.abs(healthY) + 4)
        healthSection:UpdateHeight()

        -- POWER BAR section
        local powerSection, powerContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Power Bar", y, PAD, false, healthSection)
        local powerY = 0

        local showPowerCheck = GUI:CreateFormCheckbox(powerContent, "Show Power Bar", "showPowerBar", unitDB, RefreshUnit)
        showPowerCheck:SetPoint("TOPLEFT", PAD, powerY)
        showPowerCheck:SetPoint("RIGHT", powerContent, "RIGHT", -PAD, 0)
        powerY = powerY - FORM_ROW

        local powerHeightSlider = GUI:CreateFormSlider(powerContent, "Power Bar Height", 1, 20, 1, "powerBarHeight", unitDB, RefreshUnit)
        powerHeightSlider:SetPoint("TOPLEFT", PAD, powerY)
        powerHeightSlider:SetPoint("RIGHT", powerContent, "RIGHT", -PAD, 0)
        powerY = powerY - FORM_ROW

        local powerBorderCheck = GUI:CreateFormCheckbox(powerContent, "Power Bar Border", "powerBarBorder", unitDB, RefreshUnit)
        powerBorderCheck:SetPoint("TOPLEFT", PAD, powerY)
        powerBorderCheck:SetPoint("RIGHT", powerContent, "RIGHT", -PAD, 0)
        powerY = powerY - FORM_ROW

        local powerBarColorPicker  -- Forward declare for closure

        local powerBarUsePowerColor = GUI:CreateFormCheckbox(powerContent, "Use Power Type Color", "powerBarUsePowerColor", unitDB, function()
            RefreshUnit()
            -- Grey out color picker when power type color is enabled
            if powerBarColorPicker then
                powerBarColorPicker:SetEnabled(not unitDB.powerBarUsePowerColor)
            end
        end)
        powerBarUsePowerColor:SetPoint("TOPLEFT", PAD, powerY)
        powerBarUsePowerColor:SetPoint("RIGHT", powerContent, "RIGHT", -PAD, 0)
        powerY = powerY - FORM_ROW

        powerBarColorPicker = GUI:CreateFormColorPicker(powerContent, "Custom Bar Color", "powerBarColor", unitDB, RefreshUnit)
        powerBarColorPicker:SetPoint("TOPLEFT", PAD, powerY)
        powerBarColorPicker:SetPoint("RIGHT", powerContent, "RIGHT", -PAD, 0)
        -- Set initial state (greyed out if power type color is enabled)
        powerBarColorPicker:SetEnabled(not unitDB.powerBarUsePowerColor)
        powerY = powerY - FORM_ROW
        powerContent:SetHeight(math.abs(powerY) + 4)
        powerSection:UpdateHeight()

        -- POWER TEXT section
        local powerTextSection, powerTextContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Power Text", y, PAD, false, powerSection)
        local powerTextY = 0

        local showPowerTextCheck = GUI:CreateFormCheckbox(powerTextContent, "Show Power Text", "showPowerText", unitDB, RefreshUnit)
        showPowerTextCheck:SetPoint("TOPLEFT", PAD, powerTextY)
        showPowerTextCheck:SetPoint("RIGHT", powerTextContent, "RIGHT", -PAD, 0)
        powerTextY = powerTextY - FORM_ROW

        local powerTextFormatOptions = {
            {value = "percent", text = "Percent (75%)"},
            {value = "current", text = "Current (12.5k)"},
            {value = "both", text = "Both (12.5k | 75%)"},
        }
        local powerTextFormatDropdown = GUI:CreateFormDropdown(powerTextContent, "Display Format", powerTextFormatOptions, "powerTextFormat", unitDB, RefreshUnit)
        powerTextFormatDropdown:SetPoint("TOPLEFT", PAD, powerTextY)
        powerTextFormatDropdown:SetPoint("RIGHT", powerTextContent, "RIGHT", -PAD, 0)
        powerTextY = powerTextY - FORM_ROW

        local powerTextColorPicker  -- Forward declare for closure

        local powerTextUsePowerColor = GUI:CreateFormCheckbox(powerTextContent, "Use Power Type Color", "powerTextUsePowerColor", unitDB, function()
            RefreshUnit()
            if powerTextColorPicker then
                powerTextColorPicker:SetEnabled(not unitDB.powerTextUsePowerColor)
            end
        end)
        powerTextUsePowerColor:SetPoint("TOPLEFT", PAD, powerTextY)
        powerTextUsePowerColor:SetPoint("RIGHT", powerTextContent, "RIGHT", -PAD, 0)
        powerTextY = powerTextY - FORM_ROW

        powerTextColorPicker = GUI:CreateFormColorPicker(powerTextContent, "Custom Power Text Color", "powerTextColor", unitDB, RefreshUnit)
        powerTextColorPicker:SetPoint("TOPLEFT", PAD, powerTextY)
        powerTextColorPicker:SetPoint("RIGHT", powerTextContent, "RIGHT", -PAD, 0)
        powerTextColorPicker:SetEnabled(not unitDB.powerTextUsePowerColor)
        powerTextY = powerTextY - FORM_ROW

        local powerTextSizeSlider = GUI:CreateFormSlider(powerTextContent, "Font Size", 8, 24, 1, "powerTextFontSize", unitDB, RefreshUnit)
        powerTextSizeSlider:SetPoint("TOPLEFT", PAD, powerTextY)
        powerTextSizeSlider:SetPoint("RIGHT", powerTextContent, "RIGHT", -PAD, 0)
        powerTextY = powerTextY - FORM_ROW

        local powerTextAnchorDropdown = GUI:CreateFormDropdown(powerTextContent, "Anchor", anchorOptions, "powerTextAnchor", unitDB, RefreshUnit)
        powerTextAnchorDropdown:SetPoint("TOPLEFT", PAD, powerTextY)
        powerTextAnchorDropdown:SetPoint("RIGHT", powerTextContent, "RIGHT", -PAD, 0)
        powerTextY = powerTextY - FORM_ROW

        local powerTextXSlider = GUI:CreateFormSlider(powerTextContent, "X Offset", -100, 100, 1, "powerTextOffsetX", unitDB, RefreshUnit)
        powerTextXSlider:SetPoint("TOPLEFT", PAD, powerTextY)
        powerTextXSlider:SetPoint("RIGHT", powerTextContent, "RIGHT", -PAD, 0)
        powerTextY = powerTextY - FORM_ROW

        local powerTextYSlider = GUI:CreateFormSlider(powerTextContent, "Y Offset", -50, 50, 1, "powerTextOffsetY", unitDB, RefreshUnit)
        powerTextYSlider:SetPoint("TOPLEFT", PAD, powerTextY)
        powerTextYSlider:SetPoint("RIGHT", powerTextContent, "RIGHT", -PAD, 0)
        powerTextY = powerTextY - FORM_ROW
        powerTextContent:SetHeight(math.abs(powerTextY) + 4)
        powerTextSection:UpdateHeight()

        -- Helper to copy castbar settings from one unit to another
        local function CopyCastbarSettings(sourceDB, targetDB)
            if not sourceDB or not targetDB then return end
            local keys = {"width", "height", "offsetX", "offsetY", "fontSize", "borderSize", "maxLength", "texture", "showIcon", "enabled"}
            for _, key in ipairs(keys) do
                if sourceDB[key] ~= nil then
                    targetDB[key] = sourceDB[key]
                end
            end
            if sourceDB.color then
                targetDB.color = {sourceDB.color[1], sourceDB.color[2], sourceDB.color[3], sourceDB.color[4]}
            end
            if sourceDB.bgColor then
                targetDB.bgColor = {sourceDB.bgColor[1], sourceDB.bgColor[2], sourceDB.bgColor[3], sourceDB.bgColor[4]}
            end
        end

        -- CASTBAR section (for player, target, targettarget, focus, boss)
        local castbarSection
        if unitKey == "player" or unitKey == "target" or unitKey == "targettarget" or unitKey == "focus" or unitKey == "boss" then
            -- Create castbar as a nested expandable panel
            castbarSection, castbarContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Castbar", y, PAD, false, powerTextSection)
            
            -- Use dedicated castbar options module (now nested inside castbar section)
            if ns.QUI_CastbarOptions and ns.QUI_CastbarOptions.BuildCastbarOptions then
                local castbarY = ns.QUI_CastbarOptions.BuildCastbarOptions(castbarContent, unitKey, 0, PAD, FORM_ROW, RefreshUnit, GetTextureList, NINE_POINT_ANCHOR_OPTIONS, GetUFDB, GetDB)
                
                -- Update castbar section height after all content is added
                if castbarY then
                    castbarContent:SetHeight(math.abs(castbarY) + 4)
                end
                C_Timer.After(0, function()
                    castbarSection:UpdateHeight()
                end)
            end
        end

        -- Declare aura sections outside conditional block so they're accessible later
        local debuffSection, buffSection

        -- Aura settings (all single unit frames)
        if unitKey == "player" or unitKey == "target" or unitKey == "focus"
           or unitKey == "pet" or unitKey == "targettarget" or unitKey == "boss" then
            if not unitDB.auras then unitDB.auras = {} end
            local auraDB = unitDB.auras
            if auraDB.showBuffs == nil then auraDB.showBuffs = false end
            if auraDB.showDebuffs == nil then auraDB.showDebuffs = false end
            if auraDB.iconSize == nil then auraDB.iconSize = 22 end
            if auraDB.buffIconSize == nil then auraDB.buffIconSize = 22 end
            if auraDB.debuffAnchor == nil then auraDB.debuffAnchor = "TOPLEFT" end
            if auraDB.debuffGrow == nil then auraDB.debuffGrow = "RIGHT" end
            if auraDB.debuffOffsetX == nil then auraDB.debuffOffsetX = 0 end
            if auraDB.debuffOffsetY == nil then auraDB.debuffOffsetY = 2 end
            if auraDB.buffAnchor == nil then auraDB.buffAnchor = "BOTTOMLEFT" end
            if auraDB.buffGrow == nil then auraDB.buffGrow = "RIGHT" end
            if auraDB.buffOffsetX == nil then auraDB.buffOffsetX = 0 end
            if auraDB.buffOffsetY == nil then auraDB.buffOffsetY = -2 end
            if auraDB.debuffMaxIcons == nil then auraDB.debuffMaxIcons = 16 end
            if auraDB.buffMaxIcons == nil then auraDB.buffMaxIcons = 16 end

            local auraAnchorOptions = {
                {value = "TOPLEFT", text = "Top Left"},
                {value = "TOPRIGHT", text = "Top Right"},
                {value = "BOTTOMLEFT", text = "Bottom Left"},
                {value = "BOTTOMRIGHT", text = "Bottom Right"},
            }
            local growOptions = {
                {value = "LEFT", text = "Left"},
                {value = "RIGHT", text = "Right"},
                {value = "UP", text = "Up"},
                {value = "DOWN", text = "Down"},
            }
            local ninePointAnchorOptions = {
                {value = "TOPLEFT", text = "Top Left"},
                {value = "TOP", text = "Top"},
                {value = "TOPRIGHT", text = "Top Right"},
                {value = "LEFT", text = "Left"},
                {value = "CENTER", text = "Center"},
                {value = "RIGHT", text = "Right"},
                {value = "BOTTOMLEFT", text = "Bottom Left"},
                {value = "BOTTOM", text = "Bottom"},
                {value = "BOTTOMRIGHT", text = "Bottom Right"},
            }

            -- === DEBUFF ICONS SECTION ===
            -- Determine previous section (castbar comes after power text section)
            local debuffPrevSection = castbarSection or powerTextSection
            debuffSection, debuffContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Debuff Icons", y, PAD, false, debuffPrevSection)
            local debuffY = 0

            local showDebuffsCheck = GUI:CreateFormCheckbox(debuffContent, "Show Debuffs", "showDebuffs", auraDB, RefreshAuras)
            showDebuffsCheck:SetPoint("TOPLEFT", PAD, debuffY)
            showDebuffsCheck:SetPoint("RIGHT", debuffContent, "RIGHT", -PAD, 0)
            debuffY = debuffY - FORM_ROW

            -- Debuff Preview toggle (pill-shaped, matches Castbar Preview style)
            local debuffPreviewContainer = CreateFrame("Frame", nil, debuffContent)
            debuffPreviewContainer:SetHeight(FORM_ROW)
            debuffPreviewContainer:SetPoint("TOPLEFT", PAD, debuffY)
            debuffPreviewContainer:SetPoint("RIGHT", debuffContent, "RIGHT", -PAD, 0)

            local debuffPreviewLabel = debuffPreviewContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            debuffPreviewLabel:SetPoint("LEFT", 0, 0)
            debuffPreviewLabel:SetText("Debuff Preview")
            debuffPreviewLabel:SetTextColor(C.text[1], C.text[2], C.text[3], 1)

            local debuffPreviewTrack = CreateFrame("Button", nil, debuffPreviewContainer, "BackdropTemplate")
            debuffPreviewTrack:SetSize(40, 20)
            debuffPreviewTrack:SetPoint("LEFT", debuffPreviewContainer, "LEFT", 180, 0)
            debuffPreviewTrack:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})

            local debuffPreviewThumb = CreateFrame("Frame", nil, debuffPreviewTrack, "BackdropTemplate")
            debuffPreviewThumb:SetSize(16, 16)
            debuffPreviewThumb:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
            debuffPreviewThumb:SetBackdropColor(0.95, 0.95, 0.95, 1)
            debuffPreviewThumb:SetBackdropBorderColor(0.85, 0.85, 0.85, 1)
            debuffPreviewThumb:SetFrameLevel(debuffPreviewTrack:GetFrameLevel() + 1)

            local isDebuffPreviewOn = false
            local function UpdateDebuffPreviewToggle(on)
                if on then
                    debuffPreviewTrack:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], 1)
                    debuffPreviewTrack:SetBackdropBorderColor(C.accent[1]*0.8, C.accent[2]*0.8, C.accent[3]*0.8, 1)
                    debuffPreviewThumb:ClearAllPoints()
                    debuffPreviewThumb:SetPoint("RIGHT", debuffPreviewTrack, "RIGHT", -2, 0)
                else
                    debuffPreviewTrack:SetBackdropColor(0.15, 0.18, 0.22, 1)
                    debuffPreviewTrack:SetBackdropBorderColor(0.12, 0.14, 0.18, 1)
                    debuffPreviewThumb:ClearAllPoints()
                    debuffPreviewThumb:SetPoint("LEFT", debuffPreviewTrack, "LEFT", 2, 0)
                end
            end
            UpdateDebuffPreviewToggle(isDebuffPreviewOn)

            debuffPreviewTrack:SetScript("OnClick", function()
                isDebuffPreviewOn = not isDebuffPreviewOn
                UpdateDebuffPreviewToggle(isDebuffPreviewOn)
                if isDebuffPreviewOn then
                    if _G.QuaziiUI_ShowAuraPreview then
                        _G.QuaziiUI_ShowAuraPreview(unitKey, "debuff")
                    end
                else
                    if _G.QuaziiUI_HideAuraPreview then
                        _G.QuaziiUI_HideAuraPreview(unitKey, "debuff")
                    end
                end
            end)
            debuffY = debuffY - FORM_ROW

            local auraIconSize = GUI:CreateFormSlider(debuffContent, "Icon Size", 12, 50, 1, "iconSize", auraDB, RefreshAuras)
            auraIconSize:SetPoint("TOPLEFT", PAD, debuffY)
            auraIconSize:SetPoint("RIGHT", debuffContent, "RIGHT", -PAD, 0)
            debuffY = debuffY - FORM_ROW

            local debuffAnchorDrop = GUI:CreateFormDropdown(debuffContent, "Anchor", auraAnchorOptions, "debuffAnchor", auraDB, RefreshAuras)
            debuffAnchorDrop:SetPoint("TOPLEFT", PAD, debuffY)
            debuffAnchorDrop:SetPoint("RIGHT", debuffContent, "RIGHT", -PAD, 0)
            debuffY = debuffY - FORM_ROW

            local debuffGrowDrop = GUI:CreateFormDropdown(debuffContent, "Grow Direction", growOptions, "debuffGrow", auraDB, RefreshAuras)
            debuffGrowDrop:SetPoint("TOPLEFT", PAD, debuffY)
            debuffGrowDrop:SetPoint("RIGHT", debuffContent, "RIGHT", -PAD, 0)
            debuffY = debuffY - FORM_ROW

            local debuffMaxSlider = GUI:CreateFormSlider(debuffContent, "Max Icons", 1, 32, 1, "debuffMaxIcons", auraDB, RefreshAuras)
            debuffMaxSlider:SetPoint("TOPLEFT", PAD, debuffY)
            debuffMaxSlider:SetPoint("RIGHT", debuffContent, "RIGHT", -PAD, 0)
            debuffY = debuffY - FORM_ROW

            local debuffXSlider = GUI:CreateFormSlider(debuffContent, "X Offset", -100, 100, 1, "debuffOffsetX", auraDB, RefreshAuras)
            debuffXSlider:SetPoint("TOPLEFT", PAD, debuffY)
            debuffXSlider:SetPoint("RIGHT", debuffContent, "RIGHT", -PAD, 0)
            debuffY = debuffY - FORM_ROW

            local debuffYSlider = GUI:CreateFormSlider(debuffContent, "Y Offset", -100, 100, 1, "debuffOffsetY", auraDB, RefreshAuras)
            debuffYSlider:SetPoint("TOPLEFT", PAD, debuffY)
            debuffYSlider:SetPoint("RIGHT", debuffContent, "RIGHT", -PAD, 0)
            debuffY = debuffY - FORM_ROW

            -- Debuff-specific text customization
            -- Note: Duration text removed - secret value API prevents display on enemy targets in combat
            if unitKey == "target" or unitKey == "player" or unitKey == "focus" or unitKey == "targettarget" or unitKey == "boss" then
                -- Initialize debuff-specific defaults
                if auraDB.debuffSpacing == nil then auraDB.debuffSpacing = 2 end
                if auraDB.debuffShowStack == nil then auraDB.debuffShowStack = true end
                if auraDB.debuffStackSize == nil then auraDB.debuffStackSize = 10 end
                if auraDB.debuffStackAnchor == nil then auraDB.debuffStackAnchor = "BOTTOMRIGHT" end
                if auraDB.debuffStackOffsetX == nil then auraDB.debuffStackOffsetX = -1 end
                if auraDB.debuffStackOffsetY == nil then auraDB.debuffStackOffsetY = 1 end
                if auraDB.debuffStackColor == nil then auraDB.debuffStackColor = {1, 1, 1, 1} end

                local debuffSpacingSlider = GUI:CreateFormSlider(debuffContent, "Spacing", 0, 10, 1, "debuffSpacing", auraDB, RefreshAuras)
                debuffSpacingSlider:SetPoint("TOPLEFT", PAD, debuffY)
                debuffSpacingSlider:SetPoint("RIGHT", debuffContent, "RIGHT", -PAD, 0)
                debuffY = debuffY - FORM_ROW

                local debuffShowStackCheck = GUI:CreateFormCheckbox(debuffContent, "Stack Show", "debuffShowStack", auraDB, RefreshAuras)
                debuffShowStackCheck:SetPoint("TOPLEFT", PAD, debuffY)
                debuffShowStackCheck:SetPoint("RIGHT", debuffContent, "RIGHT", -PAD, 0)
                debuffY = debuffY - FORM_ROW

                local debuffStackSizeSlider = GUI:CreateFormSlider(debuffContent, "Stack Size", 8, 24, 1, "debuffStackSize", auraDB, RefreshAuras)
                debuffStackSizeSlider:SetPoint("TOPLEFT", PAD, debuffY)
                debuffStackSizeSlider:SetPoint("RIGHT", debuffContent, "RIGHT", -PAD, 0)
                debuffY = debuffY - FORM_ROW

                local debuffStackAnchorDD = GUI:CreateFormDropdown(debuffContent, "Stack Anchor", ninePointAnchorOptions, "debuffStackAnchor", auraDB, RefreshAuras)
                debuffStackAnchorDD:SetPoint("TOPLEFT", PAD, debuffY)
                debuffStackAnchorDD:SetPoint("RIGHT", debuffContent, "RIGHT", -PAD, 0)
                debuffY = debuffY - FORM_ROW

                local debuffStackXSlider = GUI:CreateFormSlider(debuffContent, "Stack X Offset", -20, 20, 1, "debuffStackOffsetX", auraDB, RefreshAuras)
                debuffStackXSlider:SetPoint("TOPLEFT", PAD, debuffY)
                debuffStackXSlider:SetPoint("RIGHT", debuffContent, "RIGHT", -PAD, 0)
                debuffY = debuffY - FORM_ROW

                local debuffStackYSlider = GUI:CreateFormSlider(debuffContent, "Stack Y Offset", -20, 20, 1, "debuffStackOffsetY", auraDB, RefreshAuras)
                debuffStackYSlider:SetPoint("TOPLEFT", PAD, debuffY)
                debuffStackYSlider:SetPoint("RIGHT", debuffContent, "RIGHT", -PAD, 0)
                debuffY = debuffY - FORM_ROW

                local debuffStackColorPicker = GUI:CreateFormColorPicker(debuffContent, "Stack Color", "debuffStackColor", auraDB, RefreshAuras)
                debuffStackColorPicker:SetPoint("TOPLEFT", PAD, debuffY)
                debuffStackColorPicker:SetPoint("RIGHT", debuffContent, "RIGHT", -PAD, 0)
                debuffY = debuffY - FORM_ROW
            end
            debuffContent:SetHeight(math.abs(debuffY) + 4)
            debuffSection:UpdateHeight()

            -- === BUFF ICONS SECTION ===
            buffSection, buffContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Buff Icons", y, PAD, false, debuffSection)
            local buffY = 0

            local showBuffsCheck = GUI:CreateFormCheckbox(buffContent, "Show Buffs", "showBuffs", auraDB, RefreshAuras)
            showBuffsCheck:SetPoint("TOPLEFT", PAD, buffY)
            showBuffsCheck:SetPoint("RIGHT", buffContent, "RIGHT", -PAD, 0)
            buffY = buffY - FORM_ROW

            -- Buff Preview toggle (pill-shaped, matches Castbar Preview style)
            local buffPreviewContainer = CreateFrame("Frame", nil, buffContent)
            buffPreviewContainer:SetHeight(FORM_ROW)
            buffPreviewContainer:SetPoint("TOPLEFT", PAD, buffY)
            buffPreviewContainer:SetPoint("RIGHT", buffContent, "RIGHT", -PAD, 0)

            local buffPreviewLabel = buffPreviewContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            buffPreviewLabel:SetPoint("LEFT", 0, 0)
            buffPreviewLabel:SetText("Buff Preview")
            buffPreviewLabel:SetTextColor(C.text[1], C.text[2], C.text[3], 1)

            local buffPreviewTrack = CreateFrame("Button", nil, buffPreviewContainer, "BackdropTemplate")
            buffPreviewTrack:SetSize(40, 20)
            buffPreviewTrack:SetPoint("LEFT", buffPreviewContainer, "LEFT", 180, 0)
            buffPreviewTrack:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})

            local buffPreviewThumb = CreateFrame("Frame", nil, buffPreviewTrack, "BackdropTemplate")
            buffPreviewThumb:SetSize(16, 16)
            buffPreviewThumb:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
            buffPreviewThumb:SetBackdropColor(0.95, 0.95, 0.95, 1)
            buffPreviewThumb:SetBackdropBorderColor(0.85, 0.85, 0.85, 1)
            buffPreviewThumb:SetFrameLevel(buffPreviewTrack:GetFrameLevel() + 1)

            local isBuffPreviewOn = false
            local function UpdateBuffPreviewToggle(on)
                if on then
                    buffPreviewTrack:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], 1)
                    buffPreviewTrack:SetBackdropBorderColor(C.accent[1]*0.8, C.accent[2]*0.8, C.accent[3]*0.8, 1)
                    buffPreviewThumb:ClearAllPoints()
                    buffPreviewThumb:SetPoint("RIGHT", buffPreviewTrack, "RIGHT", -2, 0)
                else
                    buffPreviewTrack:SetBackdropColor(0.15, 0.18, 0.22, 1)
                    buffPreviewTrack:SetBackdropBorderColor(0.12, 0.14, 0.18, 1)
                    buffPreviewThumb:ClearAllPoints()
                    buffPreviewThumb:SetPoint("LEFT", buffPreviewTrack, "LEFT", 2, 0)
                end
            end
            UpdateBuffPreviewToggle(isBuffPreviewOn)

            buffPreviewTrack:SetScript("OnClick", function()
                isBuffPreviewOn = not isBuffPreviewOn
                UpdateBuffPreviewToggle(isBuffPreviewOn)
                if isBuffPreviewOn then
                    if _G.QuaziiUI_ShowAuraPreview then
                        _G.QuaziiUI_ShowAuraPreview(unitKey, "buff")
                    end
                else
                    if _G.QuaziiUI_HideAuraPreview then
                        _G.QuaziiUI_HideAuraPreview(unitKey, "buff")
                    end
                end
            end)
            buffY = buffY - FORM_ROW

            local buffIconSize = GUI:CreateFormSlider(buffContent, "Icon Size", 12, 50, 1, "buffIconSize", auraDB, RefreshAuras)
            buffIconSize:SetPoint("TOPLEFT", PAD, buffY)
            buffIconSize:SetPoint("RIGHT", buffContent, "RIGHT", -PAD, 0)
            buffY = buffY - FORM_ROW

            local buffAnchorDrop = GUI:CreateFormDropdown(buffContent, "Anchor", auraAnchorOptions, "buffAnchor", auraDB, RefreshAuras)
            buffAnchorDrop:SetPoint("TOPLEFT", PAD, buffY)
            buffAnchorDrop:SetPoint("RIGHT", buffContent, "RIGHT", -PAD, 0)
            buffY = buffY - FORM_ROW

            local buffGrowDrop = GUI:CreateFormDropdown(buffContent, "Grow Direction", growOptions, "buffGrow", auraDB, RefreshAuras)
            buffGrowDrop:SetPoint("TOPLEFT", PAD, buffY)
            buffGrowDrop:SetPoint("RIGHT", buffContent, "RIGHT", -PAD, 0)
            buffY = buffY - FORM_ROW

            local buffMaxSlider = GUI:CreateFormSlider(buffContent, "Max Icons", 1, 32, 1, "buffMaxIcons", auraDB, RefreshAuras)
            buffMaxSlider:SetPoint("TOPLEFT", PAD, buffY)
            buffMaxSlider:SetPoint("RIGHT", buffContent, "RIGHT", -PAD, 0)
            buffY = buffY - FORM_ROW

            local buffXSlider = GUI:CreateFormSlider(buffContent, "X Offset", -100, 100, 1, "buffOffsetX", auraDB, RefreshAuras)
            buffXSlider:SetPoint("TOPLEFT", PAD, buffY)
            buffXSlider:SetPoint("RIGHT", buffContent, "RIGHT", -PAD, 0)
            buffY = buffY - FORM_ROW

            local buffYSlider = GUI:CreateFormSlider(buffContent, "Y Offset", -100, 100, 1, "buffOffsetY", auraDB, RefreshAuras)
            buffYSlider:SetPoint("TOPLEFT", PAD, buffY)
            buffYSlider:SetPoint("RIGHT", buffContent, "RIGHT", -PAD, 0)
            buffY = buffY - FORM_ROW

            -- Buff-specific text customization
            -- Note: Duration text removed - secret value API prevents display on enemy targets in combat
            if unitKey == "target" or unitKey == "player" or unitKey == "focus" or unitKey == "targettarget" or unitKey == "boss" then
                -- Initialize buff-specific defaults
                if auraDB.buffSpacing == nil then auraDB.buffSpacing = 2 end
                if auraDB.buffShowStack == nil then auraDB.buffShowStack = true end
                if auraDB.buffStackSize == nil then auraDB.buffStackSize = 10 end
                if auraDB.buffStackAnchor == nil then auraDB.buffStackAnchor = "BOTTOMRIGHT" end
                if auraDB.buffStackOffsetX == nil then auraDB.buffStackOffsetX = -1 end
                if auraDB.buffStackOffsetY == nil then auraDB.buffStackOffsetY = 1 end
                if auraDB.buffStackColor == nil then auraDB.buffStackColor = {1, 1, 1, 1} end

                local buffSpacingSlider = GUI:CreateFormSlider(buffContent, "Spacing", 0, 10, 1, "buffSpacing", auraDB, RefreshAuras)
                buffSpacingSlider:SetPoint("TOPLEFT", PAD, buffY)
                buffSpacingSlider:SetPoint("RIGHT", buffContent, "RIGHT", -PAD, 0)
                buffY = buffY - FORM_ROW

                local buffShowStackCheck = GUI:CreateFormCheckbox(buffContent, "Stack Show", "buffShowStack", auraDB, RefreshAuras)
                buffShowStackCheck:SetPoint("TOPLEFT", PAD, buffY)
                buffShowStackCheck:SetPoint("RIGHT", buffContent, "RIGHT", -PAD, 0)
                buffY = buffY - FORM_ROW

                local buffStackSizeSlider = GUI:CreateFormSlider(buffContent, "Stack Size", 8, 24, 1, "buffStackSize", auraDB, RefreshAuras)
                buffStackSizeSlider:SetPoint("TOPLEFT", PAD, buffY)
                buffStackSizeSlider:SetPoint("RIGHT", buffContent, "RIGHT", -PAD, 0)
                buffY = buffY - FORM_ROW

                local buffStackAnchorDD = GUI:CreateFormDropdown(buffContent, "Stack Anchor", ninePointAnchorOptions, "buffStackAnchor", auraDB, RefreshAuras)
                buffStackAnchorDD:SetPoint("TOPLEFT", PAD, buffY)
                buffStackAnchorDD:SetPoint("RIGHT", buffContent, "RIGHT", -PAD, 0)
                buffY = buffY - FORM_ROW

                local buffStackXSlider = GUI:CreateFormSlider(buffContent, "Stack X Offset", -20, 20, 1, "buffStackOffsetX", auraDB, RefreshAuras)
                buffStackXSlider:SetPoint("TOPLEFT", PAD, buffY)
                buffStackXSlider:SetPoint("RIGHT", buffContent, "RIGHT", -PAD, 0)
                buffY = buffY - FORM_ROW

                local buffStackYSlider = GUI:CreateFormSlider(buffContent, "Stack Y Offset", -20, 20, 1, "buffStackOffsetY", auraDB, RefreshAuras)
                buffStackYSlider:SetPoint("TOPLEFT", PAD, buffY)
                buffStackYSlider:SetPoint("RIGHT", buffContent, "RIGHT", -PAD, 0)
                buffY = buffY - FORM_ROW

                local buffStackColorPicker = GUI:CreateFormColorPicker(buffContent, "Stack Color", "buffStackColor", auraDB, RefreshAuras)
                buffStackColorPicker:SetPoint("TOPLEFT", PAD, buffY)
                buffStackColorPicker:SetPoint("RIGHT", buffContent, "RIGHT", -PAD, 0)
                buffY = buffY - FORM_ROW
            end
            buffContent:SetHeight(math.abs(buffY) + 4)
            buffSection:UpdateHeight()
        end

        -- Track the last section before Target Marker for proper chaining
        local lastSectionBeforeMarker = nil
        
        -- STATUS INDICATORS section (player only)
        local indicatorsSection
        local stanceSection
        if unitKey == "player" then
            -- Determine previous section
            local indicatorsPrevSection = buffSection or castbarSection or powerTextSection
            indicatorsSection, indicatorsContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Status Indicators", y, PAD, false, indicatorsPrevSection)
            local indicatorsY = 0

            -- Ensure indicators table exists
            if not unitDB.indicators then
                unitDB.indicators = {
                    rested = { enabled = true, size = 16, anchor = "TOPLEFT", offsetX = -2, offsetY = 2 },
                    combat = { enabled = false, size = 16, anchor = "TOPLEFT", offsetX = -2, offsetY = 2 },
                }
            end

            -- Rested indicator
            local restedDesc = GUI:CreateLabel(indicatorsContent, "Rested: Shows when in a rested area (disabled by default).", 11, C.textMuted)
            restedDesc:SetPoint("TOPLEFT", PAD, indicatorsY)
            restedDesc:SetPoint("RIGHT", indicatorsContent, "RIGHT", -PAD, 0)
            restedDesc:SetJustifyH("LEFT")
            indicatorsY = indicatorsY - 20

            local restedCheck = GUI:CreateFormCheckbox(indicatorsContent, "Enable Rested Indicator", "enabled", unitDB.indicators.rested, RefreshUnit)
            restedCheck:SetPoint("TOPLEFT", PAD, indicatorsY)
            restedCheck:SetPoint("RIGHT", indicatorsContent, "RIGHT", -PAD, 0)
            indicatorsY = indicatorsY - FORM_ROW

            local restedSizeSlider = GUI:CreateFormSlider(indicatorsContent, "Rested Icon Size", 8, 32, 1, "size", unitDB.indicators.rested, RefreshUnit)
            restedSizeSlider:SetPoint("TOPLEFT", PAD, indicatorsY)
            restedSizeSlider:SetPoint("RIGHT", indicatorsContent, "RIGHT", -PAD, 0)
            indicatorsY = indicatorsY - FORM_ROW

            local restedAnchorDrop = GUI:CreateFormDropdown(indicatorsContent, "Rested Anchor", anchorOptions, "anchor", unitDB.indicators.rested, RefreshUnit)
            restedAnchorDrop:SetPoint("TOPLEFT", PAD, indicatorsY)
            restedAnchorDrop:SetPoint("RIGHT", indicatorsContent, "RIGHT", -PAD, 0)
            indicatorsY = indicatorsY - FORM_ROW

            local restedXSlider = GUI:CreateFormSlider(indicatorsContent, "Rested X Offset", -50, 50, 1, "offsetX", unitDB.indicators.rested, RefreshUnit)
            restedXSlider:SetPoint("TOPLEFT", PAD, indicatorsY)
            restedXSlider:SetPoint("RIGHT", indicatorsContent, "RIGHT", -PAD, 0)
            indicatorsY = indicatorsY - FORM_ROW

            local restedYSlider = GUI:CreateFormSlider(indicatorsContent, "Rested Y Offset", -50, 50, 1, "offsetY", unitDB.indicators.rested, RefreshUnit)
            restedYSlider:SetPoint("TOPLEFT", PAD, indicatorsY)
            restedYSlider:SetPoint("RIGHT", indicatorsContent, "RIGHT", -PAD, 0)
            indicatorsY = indicatorsY - FORM_ROW

            -- Combat indicator
            local combatDesc = GUI:CreateLabel(indicatorsContent, "Combat: Shows during combat (disabled by default).", 11, C.textMuted)
            combatDesc:SetPoint("TOPLEFT", PAD, indicatorsY)
            combatDesc:SetPoint("RIGHT", indicatorsContent, "RIGHT", -PAD, 0)
            combatDesc:SetJustifyH("LEFT")
            indicatorsY = indicatorsY - 20

            local combatCheck = GUI:CreateFormCheckbox(indicatorsContent, "Enable Combat Indicator", "enabled", unitDB.indicators.combat, RefreshUnit)
            combatCheck:SetPoint("TOPLEFT", PAD, indicatorsY)
            combatCheck:SetPoint("RIGHT", indicatorsContent, "RIGHT", -PAD, 0)
            indicatorsY = indicatorsY - FORM_ROW

            local combatSizeSlider = GUI:CreateFormSlider(indicatorsContent, "Combat Icon Size", 8, 32, 1, "size", unitDB.indicators.combat, RefreshUnit)
            combatSizeSlider:SetPoint("TOPLEFT", PAD, indicatorsY)
            combatSizeSlider:SetPoint("RIGHT", indicatorsContent, "RIGHT", -PAD, 0)
            indicatorsY = indicatorsY - FORM_ROW

            local combatAnchorDrop = GUI:CreateFormDropdown(indicatorsContent, "Combat Anchor", anchorOptions, "anchor", unitDB.indicators.combat, RefreshUnit)
            combatAnchorDrop:SetPoint("TOPLEFT", PAD, indicatorsY)
            combatAnchorDrop:SetPoint("RIGHT", indicatorsContent, "RIGHT", -PAD, 0)
            indicatorsY = indicatorsY - FORM_ROW

            local combatXSlider = GUI:CreateFormSlider(indicatorsContent, "Combat X Offset", -50, 50, 1, "offsetX", unitDB.indicators.combat, RefreshUnit)
            combatXSlider:SetPoint("TOPLEFT", PAD, indicatorsY)
            combatXSlider:SetPoint("RIGHT", indicatorsContent, "RIGHT", -PAD, 0)
            indicatorsY = indicatorsY - FORM_ROW

            local combatYSlider = GUI:CreateFormSlider(indicatorsContent, "Combat Y Offset", -50, 50, 1, "offsetY", unitDB.indicators.combat, RefreshUnit)
            combatYSlider:SetPoint("TOPLEFT", PAD, indicatorsY)
            combatYSlider:SetPoint("RIGHT", indicatorsContent, "RIGHT", -PAD, 0)
            indicatorsY = indicatorsY - FORM_ROW
            indicatorsContent:SetHeight(math.abs(indicatorsY) + 4)
            indicatorsSection:UpdateHeight()

            -- ═══════════════════════════════════════════════════════════════
            -- STANCE/FORM TEXT SECTION (player only)
            -- ═══════════════════════════════════════════════════════════════
            stanceSection, stanceContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Stance / Form Text", y, PAD, false, indicatorsSection)
            local stanceY = 0

            -- Ensure stance table exists
            if not unitDB.indicators.stance then
                unitDB.indicators.stance = {
                    enabled = false,
                    fontSize = 12,
                    anchor = "BOTTOM",
                    offsetX = 0,
                    offsetY = -2,
                    useClassColor = true,
                    customColor = { 1, 1, 1, 1 },
                    showIcon = false,
                    iconSize = 14,
                    iconOffsetX = -2,
                }
            end

            local stanceDesc = GUI:CreateLabel(stanceContent, "Displays current stance, form, or aura (e.g. Bear Form, Battle Stance, Devotion Aura).", 11, C.textMuted)
            stanceDesc:SetPoint("TOPLEFT", PAD, stanceY)
            stanceDesc:SetPoint("RIGHT", stanceContent, "RIGHT", -PAD, 0)
            stanceDesc:SetJustifyH("LEFT")
            stanceY = stanceY - 20

            local stanceCheck = GUI:CreateFormCheckbox(stanceContent, "Show Stance/Form Text", "enabled", unitDB.indicators.stance, RefreshUnit)
            stanceCheck:SetPoint("TOPLEFT", PAD, stanceY)
            stanceCheck:SetPoint("RIGHT", stanceContent, "RIGHT", -PAD, 0)
            stanceY = stanceY - FORM_ROW

            local stanceFontSize = GUI:CreateFormSlider(stanceContent, "Font Size", 8, 24, 1, "fontSize", unitDB.indicators.stance, RefreshUnit)
            stanceFontSize:SetPoint("TOPLEFT", PAD, stanceY)
            stanceFontSize:SetPoint("RIGHT", stanceContent, "RIGHT", -PAD, 0)
            stanceY = stanceY - FORM_ROW

            local stanceAnchorDrop = GUI:CreateFormDropdown(stanceContent, "Anchor", anchorOptions, "anchor", unitDB.indicators.stance, RefreshUnit)
            stanceAnchorDrop:SetPoint("TOPLEFT", PAD, stanceY)
            stanceAnchorDrop:SetPoint("RIGHT", stanceContent, "RIGHT", -PAD, 0)
            stanceY = stanceY - FORM_ROW

            local stanceXSlider = GUI:CreateFormSlider(stanceContent, "X Offset", -100, 100, 1, "offsetX", unitDB.indicators.stance, RefreshUnit)
            stanceXSlider:SetPoint("TOPLEFT", PAD, stanceY)
            stanceXSlider:SetPoint("RIGHT", stanceContent, "RIGHT", -PAD, 0)
            stanceY = stanceY - FORM_ROW

            local stanceYSlider = GUI:CreateFormSlider(stanceContent, "Y Offset", -100, 100, 1, "offsetY", unitDB.indicators.stance, RefreshUnit)
            stanceYSlider:SetPoint("TOPLEFT", PAD, stanceY)
            stanceYSlider:SetPoint("RIGHT", stanceContent, "RIGHT", -PAD, 0)
            stanceY = stanceY - FORM_ROW

            local stanceClassColor = GUI:CreateFormCheckbox(stanceContent, "Use Class Color", "useClassColor", unitDB.indicators.stance, RefreshUnit)
            stanceClassColor:SetPoint("TOPLEFT", PAD, stanceY)
            stanceClassColor:SetPoint("RIGHT", stanceContent, "RIGHT", -PAD, 0)
            stanceY = stanceY - FORM_ROW

            local stanceCustomColor = GUI:CreateFormColorPicker(stanceContent, "Custom Color", "customColor", unitDB.indicators.stance, RefreshUnit)
            stanceCustomColor:SetPoint("TOPLEFT", PAD, stanceY)
            stanceCustomColor:SetPoint("RIGHT", stanceContent, "RIGHT", -PAD, 0)
            stanceY = stanceY - FORM_ROW

            local stanceShowIcon = GUI:CreateFormCheckbox(stanceContent, "Show Icon", "showIcon", unitDB.indicators.stance, RefreshUnit)
            stanceShowIcon:SetPoint("TOPLEFT", PAD, stanceY)
            stanceShowIcon:SetPoint("RIGHT", stanceContent, "RIGHT", -PAD, 0)
            stanceY = stanceY - FORM_ROW

            local stanceIconSize = GUI:CreateFormSlider(stanceContent, "Icon Size", 8, 32, 1, "iconSize", unitDB.indicators.stance, RefreshUnit)
            stanceIconSize:SetPoint("TOPLEFT", PAD, stanceY)
            stanceIconSize:SetPoint("RIGHT", stanceContent, "RIGHT", -PAD, 0)
            stanceY = stanceY - FORM_ROW

            local stanceIconOffsetX = GUI:CreateFormSlider(stanceContent, "Icon X Offset", -20, 20, 1, "iconOffsetX", unitDB.indicators.stance, RefreshUnit)
            stanceIconOffsetX:SetPoint("TOPLEFT", PAD, stanceY)
            stanceIconOffsetX:SetPoint("RIGHT", stanceContent, "RIGHT", -PAD, 0)
            stanceY = stanceY - FORM_ROW
            stanceContent:SetHeight(math.abs(stanceY) + 4)
            stanceSection:UpdateHeight()
            
            -- For player, the last section before Target Marker is Stance
            lastSectionBeforeMarker = stanceSection
        end

        -- TARGET MARKER section (all unit frames)
        -- Determine previous section based on what actually exists
        local markerPrevSection = lastSectionBeforeMarker
        if not markerPrevSection then
            -- For non-player units, find the last section that exists
            if buffSection then
                markerPrevSection = buffSection
            elseif castbarSection then
                markerPrevSection = castbarSection
            elseif powerTextSection then
                markerPrevSection = powerTextSection
            else
                markerPrevSection = colorSection
            end
        end
        local markerSection, markerContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Target Marker", y, PAD, false, markerPrevSection)
        local markerY = 0

        -- Ensure targetMarker table exists
        if not unitDB.targetMarker then
            unitDB.targetMarker = { enabled = false, size = 20, anchor = "TOP", xOffset = 0, yOffset = 8 }
        end

        local markerDesc = GUI:CreateLabel(markerContent, "Shows raid target markers (skull, cross, diamond, etc.) on the unit frame.", 11, C.textMuted)
        markerDesc:SetPoint("TOPLEFT", PAD, markerY)
        markerDesc:SetPoint("RIGHT", markerContent, "RIGHT", -PAD, 0)
        markerDesc:SetJustifyH("LEFT")
        markerY = markerY - 20

        local markerCheck = GUI:CreateFormCheckbox(markerContent, "Show Target Marker", "enabled", unitDB.targetMarker, RefreshUnit)
        markerCheck:SetPoint("TOPLEFT", PAD, markerY)
        markerCheck:SetPoint("RIGHT", markerContent, "RIGHT", -PAD, 0)
        markerY = markerY - FORM_ROW

        local markerSizeSlider = GUI:CreateFormSlider(markerContent, "Marker Size", 8, 48, 1, "size", unitDB.targetMarker, RefreshUnit)
        markerSizeSlider:SetPoint("TOPLEFT", PAD, markerY)
        markerSizeSlider:SetPoint("RIGHT", markerContent, "RIGHT", -PAD, 0)
        markerY = markerY - FORM_ROW

        local markerAnchorDrop = GUI:CreateFormDropdown(markerContent, "Anchor To", anchorOptions, "anchor", unitDB.targetMarker, RefreshUnit)
        markerAnchorDrop:SetPoint("TOPLEFT", PAD, markerY)
        markerAnchorDrop:SetPoint("RIGHT", markerContent, "RIGHT", -PAD, 0)
        markerY = markerY - FORM_ROW

        local markerXSlider = GUI:CreateFormSlider(markerContent, "X Offset", -100, 100, 1, "xOffset", unitDB.targetMarker, RefreshUnit)
        markerXSlider:SetPoint("TOPLEFT", PAD, markerY)
        markerXSlider:SetPoint("RIGHT", markerContent, "RIGHT", -PAD, 0)
        markerY = markerY - FORM_ROW

        local markerYSlider = GUI:CreateFormSlider(markerContent, "Y Offset", -100, 100, 1, "yOffset", unitDB.targetMarker, RefreshUnit)
        markerYSlider:SetPoint("TOPLEFT", PAD, markerY)
        markerYSlider:SetPoint("RIGHT", markerContent, "RIGHT", -PAD, 0)
        markerY = markerY - FORM_ROW
        markerContent:SetHeight(math.abs(markerY) + 4)
        markerSection:UpdateHeight()

        -- Ensure all sections have updated their heights first
        -- Then use the scroll content's automatic height calculation
        C_Timer.After(0.05, function()
            -- Update all section heights first
            local allSections = {
                layoutSection, colorSection, absorbSection, nameSection, totSection,
                healthSection, powerSection, powerTextSection, castbarSection,
                debuffSection, buffSection, indicatorsSection, stanceSection, markerSection
            }
            
            for _, section in ipairs(allSections) do
                if section and section.UpdateHeight then
                    section:UpdateHeight()
                end
            end
        end)
        
        -- Then update the scroll content height
        if tabContent.UpdateHeight then
            C_Timer.After(0.15, function()
                tabContent:UpdateHeight()
            end)
        else
            -- Fallback: calculate manually by finding the bottom-most section
            C_Timer.After(0.15, function()
                local contentTop = tabContent:GetTop()
                local bottomMost = 0
                
                -- Check all sections to find the bottom-most one
                local allSections = {
                    layoutSection, colorSection, absorbSection, nameSection, totSection,
                    healthSection, powerSection, powerTextSection, castbarSection,
                    debuffSection, buffSection, indicatorsSection, stanceSection, markerSection
                }
                
                for _, section in ipairs(allSections) do
                    if section and section:IsShown() then
                        local sectionBottom = section:GetBottom()
                        if sectionBottom and contentTop then
                            local distanceFromTop = contentTop - sectionBottom
                            if distanceFromTop > bottomMost then
                                bottomMost = distanceFromTop
                            end
                        end
                    end
                end
                
                if bottomMost > 0 then
                    tabContent:SetHeight(bottomMost + 30)
                else
                    -- Fallback to y position
                    tabContent:SetHeight(math.abs(y) + 30)
                end
            end)
        end
    end
    
    -- Create sub-tabs
    local subTabs = GUI:CreateSubTabs(content, {
        {name = "General", builder = BuildGeneralTab},
        {name = "Player", builder = function(c) BuildUnitTab(c, "player") end},
        {name = "Target", builder = function(c) BuildUnitTab(c, "target") end},
        {name = "ToT", builder = function(c) BuildUnitTab(c, "targettarget") end},
        {name = "Pet", builder = function(c) BuildUnitTab(c, "pet") end},
        {name = "Focus", builder = function(c) BuildUnitTab(c, "focus") end},
        {name = "Boss", builder = function(c) BuildUnitTab(c, "boss") end},
    })
    subTabs:SetPoint("TOPLEFT", 5, -5)
    subTabs:SetPoint("TOPRIGHT", -5, -5)
    subTabs:SetHeight(600)
    
    content:SetHeight(650)
end


-- Export the function
ns.UnitFramesOptions = { CreateUnitFramesPage = CreateUnitFramesPage }

-- Register with Options Page Registry
if ns.OptionsPageRegistry then
    ns.OptionsPageRegistry:RegisterSimplePage("unitframes", "Single Frames & Castbars", CreateUnitFramesPage, 20)
end

return ns.UnitFramesOptions
