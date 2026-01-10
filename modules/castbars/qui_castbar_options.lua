--[[
    QuaziiUI Castbar Options
    Extracted from qui_options.lua for better organization
    Builds the castbar options section for unit frame tabs
]]

local ADDON_NAME, ns = ...
local QUI = QuaziiUI
local GUI = QUI.GUI
local C = GUI.Colors
local OptionsShared = ns.OptionsShared or {}

-- Reference to main options file for helper functions
local mainOptions = ns.QUI_Options or {}

---------------------------------------------------------------------------
-- BUILD CASTBAR OPTIONS SECTION
-- Parameters:
--   tabContent: The parent frame to add widgets to
--   unitKey: The unit key ("player", "target", etc.)
--   y: Current y position (will be updated and returned)
--   PAD: Padding constant
--   FORM_ROW: Form row height constant
--   RefreshUnit: Callback function to refresh the unit frame
--   GetTextureList: Function to get texture list
--   NINE_POINT_ANCHOR_OPTIONS: Constant for anchor options
--   GetUFDB: Function to get unit frames database
--   GetDB: Function to get main database
---------------------------------------------------------------------------
local function BuildCastbarOptions(tabContent, unitKey, y, PAD, FORM_ROW, RefreshUnit, GetTextureList, NINE_POINT_ANCHOR_OPTIONS, GetUFDB, GetDB)
    local ufdb = GetUFDB()
    if not ufdb or not ufdb[unitKey] then
        return y
    end
    
    local unitDB = ufdb[unitKey]
    local db = GetDB()
    
    -- CASTBAR section (for player, target, targettarget, focus, boss)
    if unitKey == "player" or unitKey == "target" or unitKey == "targettarget" or unitKey == "focus" or unitKey == "boss" then
        -- Note: Header is now created by the parent (unitframes_options) as a nested expandable panel
        -- This function now receives the castbar section's content as the parent
        
        if not unitDB.castbar then
            unitDB.castbar = { enabled = true, width = 250, height = 25, offsetX = 0, offsetY = -25, fontSize = 12, iconSize = 25, iconScale = 1.0, color = {1, 0.7, 0, 1}, bgColor = {0.149, 0.149, 0.149, 1}, borderSize = 1, iconBorderSize = 2, texture = "Solid" }
        end
        local castDB = unitDB.castbar
        if not castDB.fontSize then castDB.fontSize = 12 end
        if not castDB.iconSize then castDB.iconSize = 25 end
        if not castDB.iconScale then castDB.iconScale = 1.0 end
        if not castDB.height then castDB.height = 25 end
        if not castDB.color then
            castDB.color = {1, 0.7, 0, 1}
        elseif not castDB.color[4] or castDB.color[4] == 0 then
            castDB.color[4] = 1
        end
        if castDB.bgColor == nil then
            castDB.bgColor = {0.149, 0.149, 0.149, 1}  -- #262626
        end
        if castDB.borderSize == nil then
            castDB.borderSize = 1
        end
        if castDB.texture == nil then
            castDB.texture = "Solid"
        end
        if castDB.useClassColor == nil then
            castDB.useClassColor = false
        end
        -- Migration is now handled centrally by the anchoring system via MigrateAnchorConfig()
        -- Castbar-specific migrations (lockedToEssential, etc.) can be added to centralized migration if needed

        local unitDisplayNames = {
            player = "Player Frame",
            target = "Target Frame",
            targettarget = "ToT Frame",
            focus = "Focus Frame",
            boss = "Boss Frame",
        }
        local frameDisplayName = unitDisplayNames[unitKey] or "Unit Frame"

        -- ========================================
        -- GENERAL SETTINGS (Collapsible)
        -- ========================================
        local generalSection, generalContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "General", y, PAD, false, nil)
        local generalY = 0

        local castEnable = GUI:CreateFormCheckbox(generalContent, "Enable Castbar", "enabled", castDB, RefreshUnit)
        generalY = OptionsShared.AddFormControl(generalContent, castEnable, generalY, PAD, FORM_ROW)

        local castShowIcon = GUI:CreateFormCheckbox(generalContent, "Show Spell Icon", "showIcon", castDB, RefreshUnit)
        generalY = OptionsShared.AddFormControl(generalContent, castShowIcon, generalY, PAD, FORM_ROW)

        -- Use Class Color toggle (player only)
        local castWidgetRefs = {}
        if unitKey == "player" then
            local castUseClassColor = GUI:CreateFormCheckbox(generalContent, "Use Class Color", "useClassColor", castDB, function()
                RefreshUnit()
                if castWidgetRefs.colorPicker then
                    castWidgetRefs.colorPicker:SetEnabled(not castDB.useClassColor)
                end
            end)
            generalY = OptionsShared.AddFormControl(generalContent, castUseClassColor, generalY, PAD, FORM_ROW)
        end

        local castColorPicker = GUI:CreateFormColorPicker(generalContent, "Castbar Color", "color", castDB, RefreshUnit)
        if unitKey == "player" then
            castWidgetRefs.colorPicker = castColorPicker
            castColorPicker:SetEnabled(not castDB.useClassColor)
        end
        generalY = OptionsShared.AddFormControl(generalContent, castColorPicker, generalY, PAD, FORM_ROW)

        local castBgColorPicker = GUI:CreateFormColorPicker(generalContent, "Background Color", "bgColor", castDB, RefreshUnit)
        generalY = OptionsShared.AddFormControl(generalContent, castBgColorPicker, generalY, PAD, FORM_ROW)

        local castTextureDropdown = GUI:CreateFormDropdown(generalContent, "Bar Texture", GetTextureList(), "texture", castDB, RefreshUnit)
        generalY = OptionsShared.AddFormControl(generalContent, castTextureDropdown, generalY, PAD, FORM_ROW)

        local castBorderSlider = GUI:CreateFormSlider(generalContent, "Border Size", 0, 5, 1, "borderSize", castDB, RefreshUnit)
        generalY = OptionsShared.AddFormControl(generalContent, castBorderSlider, generalY, PAD, FORM_ROW)

        local iconSizeSlider = GUI:CreateFormSlider(generalContent, "Icon Size", 8, 80, 1, "iconSize", castDB, RefreshUnit)
        generalY = OptionsShared.AddFormControl(generalContent, iconSizeSlider, generalY, PAD, FORM_ROW)
        
        -- Update section height
        generalContent:SetHeight(math.abs(generalY) + 4)
        generalSection:UpdateHeight()

        -- ========================================
        -- LAYOUT (Collapsible)
        -- ========================================
        -- Initialize defaults if needed
        if castDB.anchor == nil then castDB.anchor = "screen" end
        
        -- Migration is now handled centrally by the anchoring system via MigrateAnchorConfig()
        
        -- Initialize anchors array if not exists
        if not castDB.anchors then
            -- Default anchor points for castbars
            castDB.anchors = {
                {source = "BOTTOMLEFT", target = "BOTTOMLEFT"}
            }
        end
        
        -- Initialize offsetX/offsetY if not exists
        if castDB.offsetX == nil then castDB.offsetX = 0 end
        if castDB.offsetY == nil then castDB.offsetY = -25 end

        -- Use CreateLayoutControl to create all layout UI components in one call
        -- Layout Manager automatically applies position/size changes via ApplyLayout
        if ns.QUI_LayoutControl_Options then
            -- Get castbar frame from unit frames module
            local QUI_UF = ns.QUI_UF or (ns.QUI_Castbar and ns.QUI_Castbar.unitFramesModule)
            local castbarFrame = nil
            if QUI_UF and QUI_UF.castbars then
                castbarFrame = QUI_UF.castbars[unitKey]
            end
            
            -- Optional: Only use OnLayoutChange if frame has internal elements that need repositioning
            -- For simple frames, Layout Manager handles everything automatically
            local function OnLayoutChange()
                -- Layout Manager already applies position/size changes automatically
                -- Only add refresh logic here if frame has internal child elements that need repositioning
                -- when size changes (non-destructively, not recreating the frame)
            end
            
            local layoutSection, layoutContent, newY, controls = ns.QUI_LayoutControl_Options:CreateLayoutControl(
                tabContent, castbarFrame, y, PAD, FORM_ROW, OnLayoutChange, {
                    previousSection = generalSection,
                    offsetMin = -500,
                    offsetMax = 500,
                    widthMin = 0,
                    widthMax = 500,
                    heightMin = 0,
                    heightMax = 500,
                }
            )
            y = newY  -- Update main y position for next control
        end

        -- ========================================
        -- CASTBAR PREVIEW (Collapsible)
        -- ========================================
        local previewSection, previewContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Castbar Preview", y, PAD, false, layoutSection)
        local previewY = 0
        
        local castPreviewContainer = CreateFrame("Frame", nil, previewContent)
        castPreviewContainer:SetHeight(FORM_ROW)
        castPreviewContainer:SetPoint("TOPLEFT", PAD, previewY)
        castPreviewContainer:SetPoint("RIGHT", previewContent, "RIGHT", -PAD, 0)

        local castPreviewLabel = castPreviewContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        castPreviewLabel:SetPoint("LEFT", 0, 0)
        castPreviewLabel:SetText("Enable Preview")
        castPreviewLabel:SetTextColor(C.text[1], C.text[2], C.text[3], 1)

        -- Toggle track (pill-shaped, matches CreateFormToggle)
        local castPreviewTrack = CreateFrame("Button", nil, castPreviewContainer, "BackdropTemplate")
        castPreviewTrack:SetSize(40, 20)
        castPreviewTrack:SetPoint("LEFT", castPreviewContainer, "LEFT", 180, 0)
        castPreviewTrack:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})

        -- Thumb (sliding circle)
        local castPreviewThumb = CreateFrame("Frame", nil, castPreviewTrack, "BackdropTemplate")
        castPreviewThumb:SetSize(16, 16)
        castPreviewThumb:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
        castPreviewThumb:SetBackdropColor(0.95, 0.95, 0.95, 1)
        castPreviewThumb:SetBackdropBorderColor(0.85, 0.85, 0.85, 1)
        castPreviewThumb:SetFrameLevel(castPreviewTrack:GetFrameLevel() + 1)

        -- Initialize preview state in database (doesn't persist across reloads)
        if castDB.previewMode == nil then
            castDB.previewMode = false
        end

        local function UpdateCastPreviewToggle(on)
            if on then
                castPreviewTrack:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], 1)
                castPreviewTrack:SetBackdropBorderColor(C.accent[1]*0.8, C.accent[2]*0.8, C.accent[3]*0.8, 1)
                castPreviewThumb:ClearAllPoints()
                castPreviewThumb:SetPoint("RIGHT", castPreviewTrack, "RIGHT", -2, 0)
            else
                castPreviewTrack:SetBackdropColor(0.15, 0.18, 0.22, 1)
                castPreviewTrack:SetBackdropBorderColor(0.12, 0.14, 0.18, 1)
                castPreviewThumb:ClearAllPoints()
                castPreviewThumb:SetPoint("LEFT", castPreviewTrack, "LEFT", 2, 0)
            end
        end
        UpdateCastPreviewToggle(castDB.previewMode)

        castPreviewTrack:SetScript("OnClick", function()
            castDB.previewMode = not castDB.previewMode
            UpdateCastPreviewToggle(castDB.previewMode)
            -- Enable castbar if preview is enabled (so it can be displayed)
            if castDB.previewMode and not castDB.enabled then
                castDB.enabled = true
                -- Update the checkbox if it exists
                if castEnable then
                    castEnable:SetChecked(true)
                end
            end
            -- Refresh to recreate castbar with/without preview content
            RefreshUnit()
        end)
        previewY = previewY - FORM_ROW
        
        -- Update preview section height
        previewContent:SetHeight(math.abs(previewY) + 4)
        previewSection:UpdateHeight()

        -- ========================================
        -- COPY SETTINGS (Collapsible)
        -- ========================================
        local copySection, copyContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Copy Settings", y, PAD, false, previewSection)
        local copyY = 0

        -- Copy Settings From dropdown
        local castbarCopyOptions = {}
        local castbarUnits = {
            {key = "player", text = "Player"},
            {key = "target", text = "Target"},
            {key = "targettarget", text = "ToT"},
            {key = "focus", text = "Focus"},
            {key = "boss", text = "Boss"},
        }
        for _, unit in ipairs(castbarUnits) do
            if unit.key ~= unitKey then
                table.insert(castbarCopyOptions, {value = unit.key, text = unit.text})
            end
        end

        local castCopyWrapper = { selected = castbarCopyOptions[1] and castbarCopyOptions[1].value or nil }
        local castCopyRow = CreateFrame("Frame", nil, copyContent)
        castCopyRow:SetHeight(FORM_ROW)
        castCopyRow:SetPoint("TOPLEFT", PAD, copyY)
        castCopyRow:SetPoint("RIGHT", copyContent, "RIGHT", -PAD, 0)

        -- Helper to copy castbar settings from one unit to another
        local function CopyCastbarSettings(sourceDB, targetDB)
            if not sourceDB or not targetDB then return end
            local keys = {"width", "height", "offsetX", "offsetY", "fontSize", "borderSize", "maxLength", "texture", "showIcon", "enabled", "anchor", "iconAnchor", "iconSpacing", "spellTextAnchor", "spellTextOffsetX", "spellTextOffsetY", "timeTextAnchor", "timeTextOffsetX", "timeTextOffsetY", "showSpellText", "showTimeText", "useClassColor", "empoweredStageColors", "empoweredFillColors"}
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
            if sourceDB.empoweredStageColors then
                targetDB.empoweredStageColors = {}
                for i = 1, 4 do
                    if sourceDB.empoweredStageColors[i] then
                        targetDB.empoweredStageColors[i] = {
                            sourceDB.empoweredStageColors[i][1],
                            sourceDB.empoweredStageColors[i][2],
                            sourceDB.empoweredStageColors[i][3],
                            sourceDB.empoweredStageColors[i][4]
                        }
                    end
                end
            end
            if sourceDB.empoweredFillColors then
                targetDB.empoweredFillColors = {}
                for i = 1, 4 do
                    if sourceDB.empoweredFillColors[i] then
                        targetDB.empoweredFillColors[i] = {
                            sourceDB.empoweredFillColors[i][1],
                            sourceDB.empoweredFillColors[i][2],
                            sourceDB.empoweredFillColors[i][3],
                            sourceDB.empoweredFillColors[i][4]
                        }
                    end
                end
            end
        end

        local castCopyApplyBtn = GUI:CreateButton(castCopyRow, "Apply", 60, 24, function()
            if castCopyWrapper.selected then
                local sourceUnitDB = db.quiUnitFrames and db.quiUnitFrames[castCopyWrapper.selected]
                if sourceUnitDB and sourceUnitDB.castbar then
                    CopyCastbarSettings(sourceUnitDB.castbar, castDB)
                    RefreshUnit()
                end
            end
        end)
        castCopyApplyBtn:SetPoint("RIGHT", castCopyRow, "RIGHT", 0, 2)

        local castCopyDropdown = GUI:CreateFormDropdown(castCopyRow, "Copy Settings From", castbarCopyOptions, "selected", castCopyWrapper, nil)
        castCopyDropdown:SetPoint("TOPLEFT", 0, 0)
        castCopyDropdown:SetPoint("RIGHT", castCopyApplyBtn, "LEFT", -8, 0)
        y = y - FORM_ROW

        -- Width/Height/Offset controls are now provided by the layout manager via CreateAnchorControls above
        -- No need to create them separately here
        -- Icon Size has been moved to General section

        -- ========================================
        -- TEXT & DISPLAY (Collapsible)
        -- ========================================
        local textSection, textContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Text & Display", y, PAD, false, copySection)
        local textY = 0

        local castFontSizeSlider = GUI:CreateFormSlider(textContent, "Font Size", 8, 24, 1, "fontSize", castDB, RefreshUnit)
        textY = OptionsShared.AddFormControl(textContent, castFontSizeSlider, textY, PAD, FORM_ROW)

        local castMaxLengthSlider = GUI:CreateFormSlider(textContent, "Max Length (0=none)", 0, 30, 1, "maxLength", castDB, RefreshUnit)
        textY = OptionsShared.AddFormControl(textContent, castMaxLengthSlider, textY, PAD, FORM_ROW)
        
        -- Update section height
        textContent:SetHeight(math.abs(textY) + 4)
        textSection:UpdateHeight()

        -- ========================================
        -- ELEMENT POSITIONING (Collapsible)
        -- ========================================
        local elementSection, elementContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Element Positioning", y, PAD, false, textSection)
        
        -- Create a non-expanding wrapper frame for all element positioning controls
        local elementWrapper = CreateFrame("Frame", nil, elementContent)
        elementWrapper:SetPoint("TOPLEFT", elementContent, "TOPLEFT", 0, 0)
        elementWrapper:SetPoint("TOPRIGHT", elementContent, "TOPRIGHT", 0, 0)
        -- Height will be set after all controls are added
        
        local elementY = 0

        -- Initialize element settings
        if castDB.iconAnchor == nil then castDB.iconAnchor = "LEFT" end
        if castDB.iconSpacing == nil then castDB.iconSpacing = 0 end
        if castDB.showIcon == nil then castDB.showIcon = true end
        
        if castDB.spellTextAnchor == nil then castDB.spellTextAnchor = "LEFT" end
        if castDB.spellTextOffsetX == nil then castDB.spellTextOffsetX = 4 end
        if castDB.spellTextOffsetY == nil then castDB.spellTextOffsetY = 0 end
        if castDB.showSpellText == nil then castDB.showSpellText = true end
        
        if castDB.timeTextAnchor == nil then castDB.timeTextAnchor = "RIGHT" end
        if castDB.timeTextOffsetX == nil then castDB.timeTextOffsetX = -4 end
        if castDB.timeTextOffsetY == nil then castDB.timeTextOffsetY = 0 end
        if castDB.showTimeText == nil then castDB.showTimeText = true end

        -- Icon settings
        if NINE_POINT_ANCHOR_OPTIONS then
            local iconAnchorDropdown = GUI:CreateFormDropdown(elementWrapper, "Icon Anchor", NINE_POINT_ANCHOR_OPTIONS, "iconAnchor", castDB, RefreshUnit)
            elementY = OptionsShared.AddFormControl(elementWrapper, iconAnchorDropdown, elementY, PAD, FORM_ROW)
        end

        local iconVisibilityToggle = GUI:CreateFormToggle(elementWrapper, "Show Icon", "showIcon", castDB, RefreshUnit)
        elementY = OptionsShared.AddFormControl(elementWrapper, iconVisibilityToggle, elementY, PAD, FORM_ROW)

        local iconSpacingSlider = GUI:CreateFormSlider(elementWrapper, "Icon Spacing", -50, 50, 1, "iconSpacing", castDB, RefreshUnit)
        elementY = OptionsShared.AddFormControl(elementWrapper, iconSpacingSlider, elementY, PAD, FORM_ROW)

        local iconBorderSizeSlider = GUI:CreateFormSlider(elementWrapper, "Icon Border Size", 0, 5, 0.1, "iconBorderSize", castDB, RefreshUnit)
        elementY = OptionsShared.AddFormControl(elementWrapper, iconBorderSizeSlider, elementY, PAD, FORM_ROW)

        local iconScaleSlider = GUI:CreateFormSlider(elementWrapper, "Icon Scale", 0.5, 2.0, 0.1, "iconScale", castDB, RefreshUnit)
        elementY = OptionsShared.AddFormControl(elementWrapper, iconScaleSlider, elementY, PAD, FORM_ROW)

        -- Spell text settings
        if NINE_POINT_ANCHOR_OPTIONS then
            local spellTextAnchorDropdown = GUI:CreateFormDropdown(elementWrapper, "Spell Text Anchor", NINE_POINT_ANCHOR_OPTIONS, "spellTextAnchor", castDB, RefreshUnit)
            elementY = OptionsShared.AddFormControl(elementWrapper, spellTextAnchorDropdown, elementY, PAD, FORM_ROW)
        end

        local spellTextVisibilityToggle = GUI:CreateFormToggle(elementWrapper, "Show Spell Text", "showSpellText", castDB, RefreshUnit)
        elementY = OptionsShared.AddFormControl(elementWrapper, spellTextVisibilityToggle, elementY, PAD, FORM_ROW)

        local spellTextOffsetXSlider = GUI:CreateFormSlider(elementWrapper, "Spell Text X Offset", -200, 200, 1, "spellTextOffsetX", castDB, RefreshUnit)
        elementY = OptionsShared.AddFormControl(elementWrapper, spellTextOffsetXSlider, elementY, PAD, FORM_ROW)

        local spellTextOffsetYSlider = GUI:CreateFormSlider(elementWrapper, "Spell Text Y Offset", -200, 200, 1, "spellTextOffsetY", castDB, RefreshUnit)
        elementY = OptionsShared.AddFormControl(elementWrapper, spellTextOffsetYSlider, elementY, PAD, FORM_ROW)

        -- Time text settings
        if NINE_POINT_ANCHOR_OPTIONS then
            local timeTextAnchorDropdown = GUI:CreateFormDropdown(elementWrapper, "Time Text Anchor", NINE_POINT_ANCHOR_OPTIONS, "timeTextAnchor", castDB, RefreshUnit)
            elementY = OptionsShared.AddFormControl(elementWrapper, timeTextAnchorDropdown, elementY, PAD, FORM_ROW)
        end

        local timeTextVisibilityToggle = GUI:CreateFormToggle(elementWrapper, "Show Time Text", "showTimeText", castDB, RefreshUnit)
        elementY = OptionsShared.AddFormControl(elementWrapper, timeTextVisibilityToggle, elementY, PAD, FORM_ROW)

        local timeTextOffsetXSlider = GUI:CreateFormSlider(elementWrapper, "Time Text X Offset", -200, 200, 1, "timeTextOffsetX", castDB, RefreshUnit)
        elementY = OptionsShared.AddFormControl(elementWrapper, timeTextOffsetXSlider, elementY, PAD, FORM_ROW)

        local timeTextOffsetYSlider = GUI:CreateFormSlider(elementWrapper, "Time Text Y Offset", -200, 200, 1, "timeTextOffsetY", castDB, RefreshUnit)
        elementY = OptionsShared.AddFormControl(elementWrapper, timeTextOffsetYSlider, elementY, PAD, FORM_ROW)

        -- Hide time text on empowered (player only)
        if unitKey == "player" then
            if castDB.hideTimeTextOnEmpowered == nil then castDB.hideTimeTextOnEmpowered = false end
            
            local hideTimeTextOnEmpoweredToggle = GUI:CreateFormToggle(elementWrapper, "Hide Time Text on Empowered", "hideTimeTextOnEmpowered", castDB, RefreshUnit)
            elementY = OptionsShared.AddFormControl(elementWrapper, hideTimeTextOnEmpoweredToggle, elementY, PAD, FORM_ROW)
        end

        -- Empowered level text settings (player only)
        if unitKey == "player" then
            if castDB.empoweredLevelTextAnchor == nil then castDB.empoweredLevelTextAnchor = "CENTER" end
            if castDB.empoweredLevelTextOffsetX == nil then castDB.empoweredLevelTextOffsetX = 0 end
            if castDB.empoweredLevelTextOffsetY == nil then castDB.empoweredLevelTextOffsetY = 0 end
            if castDB.showEmpoweredLevel == nil then castDB.showEmpoweredLevel = false end
            
            if NINE_POINT_ANCHOR_OPTIONS then
                local empoweredLevelTextAnchorDropdown = GUI:CreateFormDropdown(elementWrapper, "Empowered Level Text Anchor", NINE_POINT_ANCHOR_OPTIONS, "empoweredLevelTextAnchor", castDB, RefreshUnit)
                elementY = OptionsShared.AddFormControl(elementWrapper, empoweredLevelTextAnchorDropdown, elementY, PAD, FORM_ROW)
            end

            local empoweredLevelTextVisibilityToggle = GUI:CreateFormToggle(elementWrapper, "Show Empowered Level", "showEmpoweredLevel", castDB, RefreshUnit)
            elementY = OptionsShared.AddFormControl(elementWrapper, empoweredLevelTextVisibilityToggle, elementY, PAD, FORM_ROW)

            local empoweredLevelTextOffsetXSlider = GUI:CreateFormSlider(elementWrapper, "Empowered Level Text X Offset", -200, 200, 1, "empoweredLevelTextOffsetX", castDB, RefreshUnit)
            elementY = OptionsShared.AddFormControl(elementWrapper, empoweredLevelTextOffsetXSlider, elementY, PAD, FORM_ROW)

            local empoweredLevelTextOffsetYSlider = GUI:CreateFormSlider(elementWrapper, "Empowered Level Text Y Offset", -200, 200, 1, "empoweredLevelTextOffsetY", castDB, RefreshUnit)
            elementY = OptionsShared.AddFormControl(elementWrapper, empoweredLevelTextOffsetYSlider, elementY, PAD, FORM_ROW)
            
            -- Empowered color overrides section (collapsible, nested inside element section)
            local empoweredColorsSection, empoweredColorsContent, elementY = OptionsShared.CreateCollapsibleSection(elementWrapper, "Empowered Color Overrides", elementY, PAD, false)
            
            -- Function to update wrapper and parent section heights
            local function UpdateWrapperHeights()
                C_Timer.After(0.05, function()
                    -- Calculate height: distance to nested section start + nested section height
                    local nestedSectionHeight = 0
                    if empoweredColorsSection and empoweredColorsSection:IsShown() then
                        nestedSectionHeight = empoweredColorsSection:GetHeight() or 0
                    end
                    
                    -- elementY is negative (Y position from top), so math.abs gives distance from top
                    -- Add the nested section's height to get total height needed
                    local distanceToNestedSection = math.abs(elementY)
                    local totalHeight = distanceToNestedSection + nestedSectionHeight
                    
                    -- Also check actual bottom position as verification
                    local wrapperTop = elementWrapper:GetTop()
                    local actualBottom = 0
                    if wrapperTop then
                        for i = 1, elementWrapper:GetNumChildren() do
                            local child = select(i, elementWrapper:GetChildren())
                            if child and child:IsShown() then
                                local childBottom = child:GetBottom()
                                if childBottom then
                                    local distanceFromTop = wrapperTop - childBottom
                                    if distanceFromTop > actualBottom then
                                        actualBottom = distanceFromTop
                                    end
                                end
                            end
                        end
                    end
                    
                    -- Use the larger of calculated or actual bottom position
                    local wrapperHeight = math.max(totalHeight, actualBottom) + 4
                    elementWrapper:SetHeight(wrapperHeight)
                    elementContent:SetHeight(wrapperHeight)
                    if elementSection.UpdateHeight then
                        elementSection:UpdateHeight()
                    end
                end)
            end
            
            -- Hook nested section's UpdateHeight to also update wrapper and parent section
            local originalNestedUpdateHeight = empoweredColorsSection.UpdateHeight
            empoweredColorsSection.UpdateHeight = function(self)
                if originalNestedUpdateHeight then originalNestedUpdateHeight(self) end
                UpdateWrapperHeights()
            end
            
            -- Hook nested section's expand/collapse to update wrapper and parent section
            local originalOnExpandChanged = empoweredColorsSection.OnExpandChanged
            empoweredColorsSection.OnExpandChanged = function(isExpanded)
                if originalOnExpandChanged then originalOnExpandChanged(isExpanded) end
                -- Update wrapper heights when section expands/collapses
                UpdateWrapperHeights()
            end
            
            local empoweredY = 0
            
            -- Initialize color arrays if needed with default values from constants
            if not castDB.empoweredStageColors then castDB.empoweredStageColors = {} end
            if not castDB.empoweredFillColors then castDB.empoweredFillColors = {} end
            
            -- Get default colors from castbar module
            local QUI_Castbar = ns.QUI_Castbar
            local defaultStageColors = QUI_Castbar and QUI_Castbar.STAGE_COLORS or {}
            local defaultFillColors = QUI_Castbar and QUI_Castbar.STAGE_FILL_COLORS or {}
            
            -- Store color picker references for reset functionality
            local stageColorPickers = {}
            local fillColorPickers = {}
            
            -- Stage colors (background overlays)
            local stageColorLabel = GUI:CreateLabel(empoweredColorsContent, "Stage Colors (Background Overlays)", 11, C.textMuted)
            stageColorLabel:SetPoint("TOPLEFT", PAD, empoweredY)
            empoweredY = empoweredY - 20
            
            for i = 1, 5 do
                if not castDB.empoweredStageColors[i] and defaultStageColors[i] then
                    castDB.empoweredStageColors[i] = {defaultStageColors[i][1], defaultStageColors[i][2], defaultStageColors[i][3], defaultStageColors[i][4]}
                end
                local stageColorPicker = GUI:CreateFormColorPicker(empoweredColorsContent, "Stage " .. i .. " Color", i, castDB.empoweredStageColors, RefreshUnit)
                empoweredY = OptionsShared.AddFormControl(empoweredColorsContent, stageColorPicker, empoweredY, PAD, FORM_ROW)
                stageColorPickers[i] = stageColorPicker
            end
            
            empoweredY = empoweredY - 10
            
            -- Fill colors (status bar fill)
            local fillColorLabel = GUI:CreateLabel(empoweredColorsContent, "Fill Colors (Status Bar Fill)", 11, C.textMuted)
            fillColorLabel:SetPoint("TOPLEFT", PAD, empoweredY)
            empoweredY = empoweredY - 20
            
            for i = 1, 5 do
                if not castDB.empoweredFillColors[i] and defaultFillColors[i] then
                    castDB.empoweredFillColors[i] = {defaultFillColors[i][1], defaultFillColors[i][2], defaultFillColors[i][3], defaultFillColors[i][4]}
                end
                local fillColorPicker = GUI:CreateFormColorPicker(empoweredColorsContent, "Fill " .. i .. " Color", i, castDB.empoweredFillColors, RefreshUnit)
                empoweredY = OptionsShared.AddFormControl(empoweredColorsContent, fillColorPicker, empoweredY, PAD, FORM_ROW)
                fillColorPickers[i] = fillColorPicker
            end
            
            empoweredY = empoweredY - 10
            
            -- Reset button
            local resetContainer = CreateFrame("Frame", nil, empoweredColorsContent)
            resetContainer:SetHeight(FORM_ROW)
            resetContainer:SetPoint("TOPLEFT", PAD, empoweredY)
            resetContainer:SetPoint("RIGHT", empoweredColorsContent, "RIGHT", -PAD, 0)
            
            local resetLabel = resetContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            resetLabel:SetPoint("LEFT", 0, 0)
            resetLabel:SetText("Reset Empowered Colors")
            resetLabel:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
            
            local resetBtn = CreateFrame("Button", nil, resetContainer, "BackdropTemplate")
            resetBtn:SetSize(140, 24)
            resetBtn:SetPoint("LEFT", resetContainer, "LEFT", 180, 0)
            resetBtn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            resetBtn:SetBackdropColor(0.15, 0.15, 0.15, 1)
            resetBtn:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
            
            local resetBtnText = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            resetBtnText:SetPoint("CENTER")
            resetBtnText:SetText("Reset to Defaults")
            resetBtnText:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
            
            resetBtn:SetScript("OnEnter", function(self)
                self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
            end)
            resetBtn:SetScript("OnLeave", function(self)
                self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
            end)
            resetBtn:SetScript("OnClick", function()
                -- Reset stage colors
                for i = 1, 5 do
                    if defaultStageColors[i] then
                        castDB.empoweredStageColors[i] = {defaultStageColors[i][1], defaultStageColors[i][2], defaultStageColors[i][3], defaultStageColors[i][4]}
                        if stageColorPickers[i] and stageColorPickers[i].swatch then
                            stageColorPickers[i].swatch:SetBackdropColor(defaultStageColors[i][1], defaultStageColors[i][2], defaultStageColors[i][3], defaultStageColors[i][4])
                        end
                    end
                end
                
                -- Reset fill colors
                for i = 1, 5 do
                    if defaultFillColors[i] then
                        castDB.empoweredFillColors[i] = {defaultFillColors[i][1], defaultFillColors[i][2], defaultFillColors[i][3], defaultFillColors[i][4]}
                        if fillColorPickers[i] and fillColorPickers[i].swatch then
                            fillColorPickers[i].swatch:SetBackdropColor(defaultFillColors[i][1], defaultFillColors[i][2], defaultFillColors[i][3], defaultFillColors[i][4])
                        end
                    end
                end
                
                RefreshUnit()
            end)
            
            empoweredY = empoweredY - FORM_ROW
            
            -- Update empowered colors section height
            empoweredColorsContent:SetHeight(math.abs(empoweredY) + 4)
            empoweredColorsSection:UpdateHeight()
        end
        
        -- Function to update wrapper and section heights
        local function UpdateElementHeights()
            -- Calculate wrapper height based on actual content (including nested sections)
            -- Find the bottom-most child to ensure all content is included
            local wrapperTop = elementWrapper:GetTop()
            local bottomMost = 0
            if wrapperTop then
                for i = 1, elementWrapper:GetNumChildren() do
                    local child = select(i, elementWrapper:GetChildren())
                    if child and child:IsShown() then
                        local childBottom = child:GetBottom()
                        if childBottom then
                            local distanceFromTop = wrapperTop - childBottom
                            if distanceFromTop > bottomMost then
                                bottomMost = distanceFromTop
                            end
                        end
                    end
                end
            end
            
            -- Use calculated height or fall back to elementY-based calculation
            local wrapperHeight = bottomMost > 0 and (bottomMost + 4) or (math.abs(elementY) + 4)
            elementWrapper:SetHeight(wrapperHeight)
            elementContent:SetHeight(wrapperHeight)
            elementSection:UpdateHeight()
        end
        
        -- Update heights immediately and also after a short delay to ensure nested sections are calculated
        UpdateElementHeights()
        C_Timer.After(0.1, UpdateElementHeights)

    end
    
    return y
end

-- Export the function
ns.QUI_CastbarOptions = {
    BuildCastbarOptions = BuildCastbarOptions
}

