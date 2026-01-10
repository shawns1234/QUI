--[[
    qui_ncdm_options.lua
    Options UI for NCDM (Non-Combat Display Manager) component
    Includes Essential, Utility, Buff, and Class Resource Bar options
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

if not ns.IsModuleEnabled("ncdm") then
    return
end

-- Refresh callback for NCDM changes
local function RefreshNCDM()
    -- Trigger the layout engine
    if _G.QuaziiUI_RefreshNCDM then
        _G.QuaziiUI_RefreshNCDM()
    end
end

-- Initialize NCDM defaults for existing profiles that don't have them
local function EnsureNCDMDefaults(db)
    if not db then return end

    -- Default row settings
    local defaultRow = {
        iconCount = 4,
        iconSize = 50,
        borderSize = 2,
        shape = "square",
        zoom = 0,
        padding = -8,
        yOffset = 0,
    }

    -- Ensure ncdm table exists
    if not db.ncdm then
        db.ncdm = {}
    end

    -- Ensure essential exists
    if not db.ncdm.essential then
        db.ncdm.essential = {
            enabled = true,
            -- Anchoring defaults are now handled by qui_anchoring_defaults.lua via RegisterAnchoredFrame
            -- The anchoring system will automatically apply defaults when frameType="customTrackers" and frameKey="essential" are provided
        }
    end
    -- Note: Anchoring defaults (anchorTo, anchors, offsetX, offsetY) are now handled by the anchoring system
    -- No need to manually set them here - RegisterAnchoredFrame will apply defaults from qui_anchoring_defaults.lua
    for i = 1, 3 do
        local rowKey = "row" .. i
        if not db.ncdm.essential[rowKey] then
            db.ncdm.essential[rowKey] = {}
            for k, v in pairs(defaultRow) do
                db.ncdm.essential[rowKey][k] = v
            end
            -- Row 3 disabled by default
            if i == 3 then
                db.ncdm.essential[rowKey].iconCount = 0
            end
        end
    end

    -- Ensure utility exists
    if not db.ncdm.utility then
        db.ncdm.utility = {
            enabled = true,
            -- Anchoring defaults are now handled by qui_anchoring_defaults.lua via RegisterAnchoredFrame
            -- The anchoring system will automatically apply defaults when frameType="customTrackers" and frameKey="utility" are provided
        }
    end
    -- Note: Anchoring defaults (anchorTo, anchors, offsetX, offsetY) are now handled by the anchoring system
    -- No need to manually set them here - RegisterAnchoredFrame will apply defaults from qui_anchoring_defaults.lua
    for i = 1, 3 do
        local rowKey = "row" .. i
        if not db.ncdm.utility[rowKey] then
            db.ncdm.utility[rowKey] = {}
            for k, v in pairs(defaultRow) do
                db.ncdm.utility[rowKey][k] = v
            end
            db.ncdm.utility[rowKey].iconSize = 42
            db.ncdm.utility[rowKey].iconCount = 6
            db.ncdm.utility[rowKey].zoom = 0.08
            -- Row 3 disabled by default
            if i == 3 then
                db.ncdm.utility[rowKey].iconCount = 0
            end
        end
    end

    -- Ensure buff exists
    if not db.ncdm.buff then
        db.ncdm.buff = {
            enabled = true,
            -- Anchoring defaults are now handled by qui_anchoring_defaults.lua via RegisterAnchoredFrame
            -- Note: Buff viewer may not be registered with anchoring system yet, but defaults can be added if needed
        }
    end
    -- Note: Anchoring defaults (anchorTo, anchors, offsetX, offsetY) are now handled by the anchoring system
    -- No need to manually set them here - RegisterAnchoredFrame will apply defaults from qui_anchoring_defaults.lua
end

local function CreateCDMSetupPage(parent)
    -- Check if module is enabled before building content
    if not ns.IsModuleEnabled("ncdm") then
        local emptyLabel = GUI:CreateLabel(parent, "NCDM module is disabled.", 14, GUI.Colors.textMuted)
        emptyLabel:SetPoint("CENTER", parent, "CENTER", 0, 0)
        return
    end
    
    local scroll, content = CreateScrollableContent(parent)
    local db = GetDB()

    -- Ensure NCDM tables exist for this profile
    EnsureNCDMDefaults(db)

    -- Helper to copy all settings from one row to another
    local function CopyRowSettings(sourceRow, targetRow)
        if not sourceRow or not targetRow then return end

        -- Copy all numeric and string settings
        local keys = {"iconCount", "iconSize", "borderSize", "shape", "zoom", "padding", "yOffset",
                      "durationSize", "durationOffsetX", "durationOffsetY", "durationAnchor",
                      "stackSize", "stackOffsetX", "stackOffsetY", "stackAnchor"}
        for _, key in ipairs(keys) do
            if sourceRow[key] ~= nil then
                targetRow[key] = sourceRow[key]
            end
        end

        -- Copy color tables (deep copy)
        if sourceRow.durationTextColor then
            targetRow.durationTextColor = {sourceRow.durationTextColor[1], sourceRow.durationTextColor[2], sourceRow.durationTextColor[3], sourceRow.durationTextColor[4]}
        end
        if sourceRow.stackTextColor then
            targetRow.stackTextColor = {sourceRow.stackTextColor[1], sourceRow.stackTextColor[2], sourceRow.stackTextColor[3], sourceRow.stackTextColor[4]}
        end
    end

    -- Helper to build a single row's settings (form layout - single column)
    -- trackerData is the parent table (e.g., db.ncdm.essential) containing row1, row2, row3
    -- Returns: section frame (for positioning next section)
    local function BuildRowSettings(parentContent, rowNum, rowData, trackerName, trackerData, rebuildCallback, previousSection)
        local PAD = 10
        local CONTENT_PAD = OptionsShared.CONSTANTS.CONTENT_PAD or 6
        local FORM_ROW = 32

        -- Ensure offset and text size defaults exist
        if rowData.xOffset == nil then rowData.xOffset = 0 end
        if rowData.durationSize == nil then rowData.durationSize = 14 end
        if rowData.durationOffsetX == nil then rowData.durationOffsetX = 0 end
        if rowData.durationOffsetY == nil then rowData.durationOffsetY = 0 end
        if rowData.durationTextColor == nil then rowData.durationTextColor = {1, 1, 1, 1} end
        if rowData.durationAnchor == nil then rowData.durationAnchor = "CENTER" end
        if rowData.stackSize == nil then rowData.stackSize = 14 end
        if rowData.stackOffsetX == nil then rowData.stackOffsetX = 0 end
        if rowData.stackOffsetY == nil then rowData.stackOffsetY = 0 end
        if rowData.stackTextColor == nil then rowData.stackTextColor = {1, 1, 1, 1} end
        if rowData.stackAnchor == nil then rowData.stackAnchor = "BOTTOMRIGHT" end

        -- Create collapsible section for this row
        local rowSection, rowContent = OptionsShared.CreateCollapsibleSection(
            parentContent,
            string.format("Row %d Configuration", rowNum),
            0,
            PAD,
            false,
            previousSection
        )
        local rowY = 0

        -- Icon settings
        local countSlider = GUI:CreateFormSlider(rowContent, "Icons in Row", 0, 20, 1, "iconCount", rowData, RefreshNCDM)
        rowY = OptionsShared.AddFormControl(rowContent, countSlider, rowY, CONTENT_PAD, FORM_ROW)

        local borderSlider = GUI:CreateFormSlider(rowContent, "Border Size", 0, 5, 1, "borderSize", rowData, RefreshNCDM)
        rowY = OptionsShared.AddFormControl(rowContent, borderSlider, rowY, CONTENT_PAD, FORM_ROW)

        local borderColorPicker = GUI:CreateFormColorPicker(rowContent, "Border Color", "borderColorTable", rowData, RefreshNCDM)
        rowY = OptionsShared.AddFormControl(rowContent, borderColorPicker, rowY, CONTENT_PAD, FORM_ROW)

        local zoomSlider = GUI:CreateFormSlider(rowContent, "Icon Zoom", 0, 0.2, 0.01, "zoom", rowData, RefreshNCDM)
        rowY = OptionsShared.AddFormControl(rowContent, zoomSlider, rowY, CONTENT_PAD, FORM_ROW)

        local paddingSlider = GUI:CreateFormSlider(rowContent, "Padding", -20, 20, 1, "padding", rowData, RefreshNCDM)
        rowY = OptionsShared.AddFormControl(rowContent, paddingSlider, rowY, CONTENT_PAD, FORM_ROW)

        local yOffsetSlider = GUI:CreateFormSlider(rowContent, "Row Y-Offset", -500, 500, 1, "yOffset", rowData, RefreshNCDM)
        rowY = OptionsShared.AddFormControl(rowContent, yOffsetSlider, rowY, CONTENT_PAD, FORM_ROW)

        local xOffsetSlider = GUI:CreateFormSlider(rowContent, "Row X-Offset", -500, 500, 1, "xOffset", rowData, RefreshNCDM)
        rowY = OptionsShared.AddFormControl(rowContent, xOffsetSlider, rowY, CONTENT_PAD, FORM_ROW)

        local anchorOptions = {
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

        local durationSlider = GUI:CreateFormSlider(rowContent, "Duration Text Size", 8, 50, 1, "durationSize", rowData, RefreshNCDM)
        rowY = OptionsShared.AddFormControl(rowContent, durationSlider, rowY, CONTENT_PAD, FORM_ROW)

        local durationAnchorDD = GUI:CreateFormDropdown(rowContent, "Anchor Duration To", anchorOptions, "durationAnchor", rowData, RefreshNCDM)
        rowY = OptionsShared.AddFormControl(rowContent, durationAnchorDD, rowY, CONTENT_PAD, FORM_ROW)

        local durationXSlider = GUI:CreateFormSlider(rowContent, "Duration X-Offset", -80, 80, 1, "durationOffsetX", rowData, RefreshNCDM)
        rowY = OptionsShared.AddFormControl(rowContent, durationXSlider, rowY, CONTENT_PAD, FORM_ROW)

        local durationYSlider = GUI:CreateFormSlider(rowContent, "Duration Y-Offset", -80, 80, 1, "durationOffsetY", rowData, RefreshNCDM)
        rowY = OptionsShared.AddFormControl(rowContent, durationYSlider, rowY, CONTENT_PAD, FORM_ROW)

        local durationColorPicker = GUI:CreateFormColorPicker(rowContent, "Duration Text Color", "durationTextColor", rowData, RefreshNCDM)
        rowY = OptionsShared.AddFormControl(rowContent, durationColorPicker, rowY, CONTENT_PAD, FORM_ROW)

        local stackSlider = GUI:CreateFormSlider(rowContent, "Stack Text Size", 8, 50, 1, "stackSize", rowData, RefreshNCDM)
        rowY = OptionsShared.AddFormControl(rowContent, stackSlider, rowY, CONTENT_PAD, FORM_ROW)

        local stackAnchorDD = GUI:CreateFormDropdown(rowContent, "Anchor Stack To", anchorOptions, "stackAnchor", rowData, RefreshNCDM)
        rowY = OptionsShared.AddFormControl(rowContent, stackAnchorDD, rowY, CONTENT_PAD, FORM_ROW)

        local stackXSlider = GUI:CreateFormSlider(rowContent, "Stack X-Offset", -80, 80, 1, "stackOffsetX", rowData, RefreshNCDM)
        rowY = OptionsShared.AddFormControl(rowContent, stackXSlider, rowY, CONTENT_PAD, FORM_ROW)

        local stackYSlider = GUI:CreateFormSlider(rowContent, "Stack Y-Offset", -80, 80, 1, "stackOffsetY", rowData, RefreshNCDM)
        rowY = OptionsShared.AddFormControl(rowContent, stackYSlider, rowY, CONTENT_PAD, FORM_ROW)

        local stackColorPicker = GUI:CreateFormColorPicker(rowContent, "Stack Text Color", "stackTextColor", rowData, RefreshNCDM)
        rowY = OptionsShared.AddFormControl(rowContent, stackColorPicker, rowY, CONTENT_PAD, FORM_ROW)

        local shapeSlider = GUI:CreateFormSlider(rowContent, "Icon Shape", 1.0, 2.0, 0.01, "aspectRatioCrop", rowData, RefreshNCDM)
        rowY = OptionsShared.AddFormControl(rowContent, shapeSlider, rowY, CONTENT_PAD, FORM_ROW)

        local shapeTip, rowY = OptionsShared.AddFormNote(
            rowContent,
            "Higher values imply flatter icons.",
            rowY,
            CONTENT_PAD
        )

        -- Copy from dropdown (if trackerData is provided)
        if trackerData then
            local copyOptions = {}
            for i = 1, 3 do
                if i ~= rowNum then
                    table.insert(copyOptions, {value = "row" .. i, text = "Row " .. i})
                end
            end

            -- Copy Settings From - using form dropdown with Apply button
            local copyWrapper = { selected = copyOptions[1] and copyOptions[1].value or nil }
            local copyRow = CreateFrame("Frame", nil, rowContent)
            copyRow:SetHeight(FORM_ROW)
            copyRow:SetPoint("TOPLEFT", CONTENT_PAD, rowY)
            copyRow:SetPoint("RIGHT", rowContent, "RIGHT", -CONTENT_PAD, 0)

            local applyBtn = GUI:CreateButton(copyRow, "Apply", 60, 24, function()
                if copyWrapper.selected and trackerData[copyWrapper.selected] then
                    CopyRowSettings(trackerData[copyWrapper.selected], rowData)
                    RefreshNCDM()
                    if rebuildCallback then rebuildCallback() end
                end
            end)
            applyBtn:SetPoint("RIGHT", copyRow, "RIGHT", 0, 2)

            local copyDropdown = GUI:CreateFormDropdown(copyRow, "Copy Settings From", copyOptions, "selected", copyWrapper, nil)
            copyDropdown:SetPoint("TOPLEFT", 0, 0)
            copyDropdown:SetPoint("RIGHT", applyBtn, "LEFT", -8, 0)

            rowY = rowY - FORM_ROW
        end

        -- Update section height
        rowContent:SetHeight(math.abs(rowY) + 4)
        rowSection:UpdateHeight()

        return rowSection
    end

    -- Build Essential sub-tab
    local function BuildEssentialTab(tabContent)
        local PAD = 10
        local CONTENT_PAD = OptionsShared.CONSTANTS.CONTENT_PAD or 6
        local y = -10
        local FORM_ROW = 32

        -- Set search context for auto-registration
        GUI:SetSearchContext({tabIndex = 6, tabName = "CDM Setup & Class Bars", subTabIndex = 1, subTabName = "Essential"})

        if db and db.ncdm and db.ncdm.essential then
            local ess = db.ncdm.essential

            -- Rebuild callback to refresh the tab after copying
            local function rebuildEssential()
                -- Clear and rebuild the tab content
                for _, child in pairs({tabContent:GetChildren()}) do
                    child:Hide()
                    child:SetParent(nil)
                end
                for _, region in pairs({tabContent:GetRegions()}) do
                    region:Hide()
                end
                BuildEssentialTab(tabContent)
            end

            -- General Settings Section
            local generalSection, generalContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "General", y, PAD, false, nil)
            local generalY = 0

            local enableCheck = GUI:CreateFormCheckbox(generalContent, "Enable Essential Cooldowns Display", "enabled", ess, RefreshNCDM)
            generalY = OptionsShared.AddFormControl(generalContent, enableCheck, generalY, PAD, FORM_ROW)

            -- Layout Direction dropdown
            ess.layoutDirection = ess.layoutDirection or "HORIZONTAL"
            local directionOptions = {
                {value = "HORIZONTAL", text = "Horizontal"},
                {value = "VERTICAL", text = "Vertical"},
            }
            local directionDropdown = GUI:CreateFormDropdown(generalContent, "Layout Direction", directionOptions, "layoutDirection", ess, RefreshNCDM)
            generalY = OptionsShared.AddFormControl(generalContent, directionDropdown, generalY, PAD, FORM_ROW)

            -- Update General section height (add extra space for dropdown menu when expanded)
            -- Dropdown menu has maxHeight of 100, so add that plus some padding
            generalContent:SetHeight(math.abs(generalY) + 4 + 110)
            generalSection:UpdateHeight()

            -- Anchoring section
            local layoutSection = nil
            if ns.QUI_LayoutControl_Options then
                local function UpdateEssentialAnchoring()
                    -- UpdateLayout already calls ApplyLayout for offset/anchor changes
                    -- The layout system automatically updates frames anchored to this frame
                    -- No need for RefreshNCDM() or UpdateAllFrames() - they cause stuttering
                end

                local viewer = _G.EssentialCooldownViewer
                layoutSection, layoutContent, y = ns.QUI_LayoutControl_Options:CreateLayoutControl(
                        tabContent, viewer, y, PAD, FORM_ROW, UpdateEssentialAnchoring, {
                            anchorKey = "anchorTo",
                            maxAnchors = 2,
                            excludeSelf = "essential",
                            showSize = false
                        }
                )
            end

            -- Row sections
            local previousRowSection = layoutSection or generalSection
            if ess.row1 then
                previousRowSection = BuildRowSettings(tabContent, 1, ess.row1, "Essential", ess, rebuildEssential, previousRowSection)
            end

            if ess.row2 then
                previousRowSection = BuildRowSettings(tabContent, 2, ess.row2, "Essential", ess, rebuildEssential, previousRowSection)
            end

            if ess.row3 then
                previousRowSection = BuildRowSettings(tabContent, 3, ess.row3, "Essential", ess, rebuildEssential, previousRowSection)
            end
        else
            local info = GUI:CreateLabel(tabContent, "NCDM Essential settings not found. Please reload UI.", 12, C.accentLight)
            info:SetPoint("TOPLEFT", PAD, y)
        end
    end

    -- Build Utility sub-tab
    local function BuildUtilityTab(tabContent)
        local PAD = 10
        local CONTENT_PAD = OptionsShared.CONSTANTS.CONTENT_PAD or 6
        local y = -10
        local FORM_ROW = 32

        -- Set search context for auto-registration
        GUI:SetSearchContext({tabIndex = 6, tabName = "CDM Setup & Class Bars", subTabIndex = 2, subTabName = "Utility"})

        if db and db.ncdm and db.ncdm.utility then
            local util = db.ncdm.utility

            -- Rebuild callback to refresh the tab after copying
            local function rebuildUtility()
                -- Clear and rebuild the tab content
                for _, child in pairs({tabContent:GetChildren()}) do
                    child:Hide()
                    child:SetParent(nil)
                end
                for _, region in pairs({tabContent:GetRegions()}) do
                    region:Hide()
                end
                BuildUtilityTab(tabContent)
            end

            -- General Settings Section
            local generalSection, generalContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "General", y, PAD, false, nil)
            local generalY = 0

            local enableCheck = GUI:CreateFormCheckbox(generalContent, "Enable Utility Cooldowns Display", "enabled", util, RefreshNCDM)
            generalY = OptionsShared.AddFormControl(generalContent, enableCheck, generalY, PAD, FORM_ROW)

            -- Layout Direction dropdown
            util.layoutDirection = util.layoutDirection or "HORIZONTAL"
            local directionOptions = {
                {value = "HORIZONTAL", text = "Horizontal"},
                {value = "VERTICAL", text = "Vertical"},
            }
            local directionDropdown = GUI:CreateFormDropdown(generalContent, "Layout Direction", directionOptions, "layoutDirection", util, RefreshNCDM)
            generalY = OptionsShared.AddFormControl(generalContent, directionDropdown, generalY, PAD, FORM_ROW)

            local hintText, generalY = OptionsShared.AddFormNote(
                generalContent,
                "Tip: Set Icon Size to 100% in Edit Mode for best results.",
                generalY,
                PAD
            )

            -- Update General section height (add extra space for dropdown menu when expanded)
            -- Dropdown menu has maxHeight of 100, so add that plus some padding
            generalContent:SetHeight(math.abs(generalY) + 4 + 110)
            generalSection:UpdateHeight()

            -- Anchoring section
            local layoutSection = nil
            if ns.QUI_LayoutControl_Options then
                local function UpdateUtilityAnchoring()
                    -- UpdateLayout already calls ApplyLayout for offset/anchor changes
                    -- The layout system automatically updates frames anchored to this frame
                    -- No need for RefreshNCDM() or UpdateAllFrames() - they cause stuttering
                end

                local viewer = _G.UtilityCooldownViewer
                layoutSection, layoutContent, y = ns.QUI_LayoutControl_Options:CreateLayoutControl(
                        tabContent, viewer, y, PAD, FORM_ROW, UpdateUtilityAnchoring, {
                            anchorKey = "anchorTo",
                            maxAnchors = 2,
                            excludeSelf = "utility",
                            showSize = false
                        }
                )
            end

            -- Row sections
            local previousRowSection = layoutSection or generalSection
            if util.row1 then
                previousRowSection = BuildRowSettings(tabContent, 1, util.row1, "Utility", util, rebuildUtility, previousRowSection)
            end

            if util.row2 then
                previousRowSection = BuildRowSettings(tabContent, 2, util.row2, "Utility", util, rebuildUtility, previousRowSection)
            end

            if util.row3 then
                previousRowSection = BuildRowSettings(tabContent, 3, util.row3, "Utility", util, rebuildUtility, previousRowSection)
            end
        else
            local info = GUI:CreateLabel(tabContent, "NCDM Utility settings not found. Please reload UI.", 12, C.accentLight)
            info:SetPoint("TOPLEFT", PAD, y)
        end
    end

    -- Build Buff sub-tab with customization options
    local function BuildBuffTab(tabContent)
        local PAD = 10
        local CONTENT_PAD = OptionsShared.CONSTANTS.CONTENT_PAD or 6
        local y = -10
        local FORM_ROW = 32

        -- Set search context for widget auto-registration
        GUI:SetSearchContext({tabIndex = 6, tabName = "CDM Setup & Class Bars", subTabIndex = 3, subTabName = "Buff"})

        -- Ensure buff settings exist with all required fields
        if not db.ncdm then db.ncdm = {} end
        if not db.ncdm.buff then db.ncdm.buff = {} end

        -- Ensure all fields exist with defaults
        local buffData = db.ncdm.buff
        if buffData.enabled == nil then buffData.enabled = true end
        if buffData.iconSize == nil then buffData.iconSize = 42 end
        if buffData.borderSize == nil then buffData.borderSize = 2 end
        if buffData.shape == nil then buffData.shape = "square" end  -- DEPRECATED
        if buffData.aspectRatioCrop == nil then buffData.aspectRatioCrop = 1.0 end
        if buffData.growthDirection == nil then buffData.growthDirection = "CENTERED_HORIZONTAL" end
        if buffData.zoom == nil then buffData.zoom = 0 end
        if buffData.padding == nil then buffData.padding = 0 end
        if buffData.durationSize == nil then buffData.durationSize = 12 end
        if buffData.stackSize == nil then buffData.stackSize = 12 end

        -- Callback to refresh buff bar
        local function RefreshBuff()
            if _G.QuaziiUI_RefreshBuffBar then
                _G.QuaziiUI_RefreshBuffBar()
            end
        end

        -- =====================================================
        -- BUFF ICON SETTINGS SECTION (Collapsible)
        -- =====================================================
        local buffIconSection, buffIconContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Buff Icon Settings", y, PAD, false, nil)
        local buffIconY = 0

        local enableCb = GUI:CreateFormCheckbox(buffIconContent, "Enable Buff Icon Styling", "enabled", buffData, RefreshBuff)
        buffIconY = OptionsShared.AddFormControl(buffIconContent, enableCb, buffIconY, CONTENT_PAD, FORM_ROW)

        local borderSlider = GUI:CreateFormSlider(buffIconContent, "Border Size", 0, 8, 1, "borderSize", buffData, RefreshBuff)
        buffIconY = OptionsShared.AddFormControl(buffIconContent, borderSlider, buffIconY, CONTENT_PAD, FORM_ROW)

        local zoomSlider = GUI:CreateFormSlider(buffIconContent, "Icon Zoom", 0, 0.2, 0.01, "zoom", buffData, RefreshBuff)
        buffIconY = OptionsShared.AddFormControl(buffIconContent, zoomSlider, buffIconY, CONTENT_PAD, FORM_ROW)

        local paddingSlider = GUI:CreateFormSlider(buffIconContent, "Icon Padding", -20, 20, 1, "padding", buffData, RefreshBuff)
        buffIconY = OptionsShared.AddFormControl(buffIconContent, paddingSlider, buffIconY, CONTENT_PAD, FORM_ROW)

        local durationSlider = GUI:CreateFormSlider(buffIconContent, "Duration Size", 8, 50, 1, "durationSize", buffData, RefreshBuff)
        buffIconY = OptionsShared.AddFormControl(buffIconContent, durationSlider, buffIconY, CONTENT_PAD, FORM_ROW)

        local anchorOptions = {
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

        local durationAnchorDD = GUI:CreateFormDropdown(buffIconContent, "Anchor Duration To", anchorOptions, "durationAnchor", buffData, RefreshBuff)
        buffIconY = OptionsShared.AddFormControl(buffIconContent, durationAnchorDD, buffIconY, CONTENT_PAD, FORM_ROW)

        local durationXSlider = GUI:CreateFormSlider(buffIconContent, "Duration X Offset", -20, 20, 1, "durationOffsetX", buffData, RefreshBuff)
        buffIconY = OptionsShared.AddFormControl(buffIconContent, durationXSlider, buffIconY, CONTENT_PAD, FORM_ROW)

        local durationYSlider = GUI:CreateFormSlider(buffIconContent, "Duration Y Offset", -20, 20, 1, "durationOffsetY", buffData, RefreshBuff)
        buffIconY = OptionsShared.AddFormControl(buffIconContent, durationYSlider, buffIconY, CONTENT_PAD, FORM_ROW)

        local stackSlider = GUI:CreateFormSlider(buffIconContent, "Stack Size", 8, 50, 1, "stackSize", buffData, RefreshBuff)
        buffIconY = OptionsShared.AddFormControl(buffIconContent, stackSlider, buffIconY, CONTENT_PAD, FORM_ROW)

        local stackAnchorDD = GUI:CreateFormDropdown(buffIconContent, "Anchor Stack To", anchorOptions, "stackAnchor", buffData, RefreshBuff)
        buffIconY = OptionsShared.AddFormControl(buffIconContent, stackAnchorDD, buffIconY, CONTENT_PAD, FORM_ROW)

        local stackXSlider = GUI:CreateFormSlider(buffIconContent, "Stack X Offset", -20, 20, 1, "stackOffsetX", buffData, RefreshBuff)
        buffIconY = OptionsShared.AddFormControl(buffIconContent, stackXSlider, buffIconY, CONTENT_PAD, FORM_ROW)

        local stackYSlider = GUI:CreateFormSlider(buffIconContent, "Stack Y Offset", -20, 20, 1, "stackOffsetY", buffData, RefreshBuff)
        buffIconY = OptionsShared.AddFormControl(buffIconContent, stackYSlider, buffIconY, CONTENT_PAD, FORM_ROW)

        local growthDropdown = GUI:CreateFormDropdown(buffIconContent, "Growth Direction", {
            {value = "CENTERED_HORIZONTAL", text = "Centered"},
            {value = "UP", text = "Grow Up"},
            {value = "DOWN", text = "Grow Down"},
        }, "growthDirection", buffData, RefreshBuff)
        buffIconY = OptionsShared.AddFormControl(buffIconContent, growthDropdown, buffIconY, CONTENT_PAD, FORM_ROW)

        local shapeSlider = GUI:CreateFormSlider(buffIconContent, "Icon Shape", 1.0, 2.0, 0.01, "aspectRatioCrop", buffData, RefreshBuff)
        buffIconY = OptionsShared.AddFormControl(buffIconContent, shapeSlider, buffIconY, CONTENT_PAD, FORM_ROW)

        local shapeTip, buffIconY = OptionsShared.AddFormNote(
            buffIconContent,
            "Higher values imply flatter icons.",
            buffIconY,
            CONTENT_PAD
        )

        local info, buffIconY = OptionsShared.AddFormNote(
            buffIconContent,
            "Position the Buff Icons using Edit Mode (Esc > Edit Mode).",
            buffIconY,
            CONTENT_PAD
        )

        -- Anchoring section for Buff Icon Viewer (nested section)
        if ns.QUI_LayoutControl_Options then
            local function UpdateBuffAnchoring()
                -- UpdateLayout already calls ApplyLayout for offset/anchor changes
                -- The layout system automatically updates frames anchored to this frame
                -- No need for RefreshBuff() or UpdateAllFrames() - they cause stuttering
            end

            local viewer = _G.BuffIconCooldownViewer
            local layoutSection, layoutContent, buffIconY = ns.QUI_LayoutControl_Options:CreateLayoutControl(
                    buffIconContent, viewer, buffIconY, CONTENT_PAD, FORM_ROW, UpdateBuffAnchoring, {
                        anchorKey = "anchorTo",
                        maxAnchors = 2,
                        excludeSelf = "buffIcon",
                        dropdownLabel = "Anchor To (Icon Viewer)",
                        showSize = false
                    }
            )
        end

        -- Update Buff Icon section height
        buffIconContent:SetHeight(math.abs(buffIconY) + 4)
        buffIconSection:UpdateHeight()

        -- =====================================================
        -- TRACKED BAR SECTION (Collapsible)
        -- =====================================================

        -- Ensure trackedBar settings exist with defaults
        if not db.ncdm.trackedBar then db.ncdm.trackedBar = {} end
        local trackedData = db.ncdm.trackedBar
        if trackedData.enabled == nil then trackedData.enabled = true end
        if trackedData.hideIcon == nil then trackedData.hideIcon = false end
        if trackedData.barHeight == nil then trackedData.barHeight = 24 end
        if trackedData.texture == nil then trackedData.texture = "Quazii v5" end
        if trackedData.useClassColor == nil then trackedData.useClassColor = true end
        if trackedData.barColor == nil then trackedData.barColor = {0.204, 0.827, 0.6, 1} end
        if trackedData.borderSize == nil then trackedData.borderSize = 1 end
        if trackedData.bgOpacity == nil then trackedData.bgOpacity = 0.7 end
        if trackedData.textSize == nil then trackedData.textSize = 12 end
        if trackedData.spacing == nil then trackedData.spacing = 4 end
        if trackedData.growUp == nil then trackedData.growUp = true end

        local trackedSection, trackedContent, y = OptionsShared.CreateCollapsibleSection(tabContent, "Tracked Bar", y, PAD, false, buffIconSection)
        local trackedY = 0

        local trackedDesc, trackedY = OptionsShared.AddFormNote(
            trackedContent,
            "Controls the appearance of buff duration bars for spells under 'Tracked Bars' of your CDM. Hint: Most players will opt to display buffs via the Buff Icon section above.",
            trackedY,
            CONTENT_PAD
        )

        local trackedEnable = GUI:CreateFormCheckbox(trackedContent, "Enable Tracked Bar Styling", "enabled", trackedData, RefreshBuff)
        trackedY = OptionsShared.AddFormControl(trackedContent, trackedEnable, trackedY, CONTENT_PAD, FORM_ROW)

        local hideIconCheck = GUI:CreateFormCheckbox(trackedContent, "Hide Icon", "hideIcon", trackedData, RefreshBuff)
        trackedY = OptionsShared.AddFormControl(trackedContent, hideIconCheck, trackedY, CONTENT_PAD, FORM_ROW)

        local textureDropdown = GUI:CreateFormDropdown(trackedContent, "Bar Texture", GetTextureList(), "texture", trackedData, RefreshBuff)
        trackedY = OptionsShared.AddFormControl(trackedContent, textureDropdown, trackedY, CONTENT_PAD, FORM_ROW)

        local growthDropdown = GUI:CreateFormDropdown(trackedContent, "Growth Direction", {
            {value = true, text = "Up"},
            {value = false, text = "Down"},
        }, "growUp", trackedData, RefreshBuff)
        trackedY = OptionsShared.AddFormControl(trackedContent, growthDropdown, trackedY, CONTENT_PAD, FORM_ROW)

        local classColorCheck = GUI:CreateFormCheckbox(trackedContent, "Use Class Color", "useClassColor", trackedData, RefreshBuff)
        trackedY = OptionsShared.AddFormControl(trackedContent, classColorCheck, trackedY, CONTENT_PAD, FORM_ROW)

        local barColorPicker = GUI:CreateFormColorPicker(trackedContent, "Bar Color (Fallback)", "barColor", trackedData, RefreshBuff)
        trackedY = OptionsShared.AddFormControl(trackedContent, barColorPicker, trackedY, CONTENT_PAD, FORM_ROW)

        local trackedBorderSlider = GUI:CreateFormSlider(trackedContent, "Border Size", 0, 4, 1, "borderSize", trackedData, RefreshBuff)
        trackedY = OptionsShared.AddFormControl(trackedContent, trackedBorderSlider, trackedY, CONTENT_PAD, FORM_ROW)

        local bgOpacitySlider = GUI:CreateFormSlider(trackedContent, "Background Opacity", 0, 1, 0.1, "bgOpacity", trackedData, RefreshBuff)
        trackedY = OptionsShared.AddFormControl(trackedContent, bgOpacitySlider, trackedY, CONTENT_PAD, FORM_ROW)

        local trackedTextSlider = GUI:CreateFormSlider(trackedContent, "Text Size", 8, 24, 1, "textSize", trackedData, RefreshBuff)
        trackedY = OptionsShared.AddFormControl(trackedContent, trackedTextSlider, trackedY, CONTENT_PAD, FORM_ROW)

        local spacingSlider = GUI:CreateFormSlider(trackedContent, "Bar Spacing", 0, 20, 1, "spacing", trackedData, RefreshBuff)
        trackedY = OptionsShared.AddFormControl(trackedContent, spacingSlider, trackedY, CONTENT_PAD, FORM_ROW)

        -- Anchoring section
        if ns.QUI_LayoutControl_Options then
            local function OnTrackedBarAnchorChange()
                -- Update width slider state when anchor changes
                if trackedData._updateWidthSlider then
                    trackedData._updateWidthSlider()
                end
                -- UpdateLayout already calls ApplyLayout for offset/anchor changes
                -- The layout system automatically updates frames anchored to this frame
                -- No need for RefreshBuff() or UpdateAllFrames() - they cause stuttering
            end

            local viewer = _G.BuffBarCooldownViewer
            local layoutSection, layoutContent, trackedY = ns.QUI_LayoutControl_Options:CreateLayoutControl(
                    trackedContent, viewer, trackedY, CONTENT_PAD, FORM_ROW, OnTrackedBarAnchorChange, {
                        anchorKey = "anchorTo",
                        maxAnchors = 2,
                        excludeSelf = "trackedBar",
                        showSize = false
                    }
            )
        end

        -- Update Tracked Bar section height
        trackedContent:SetHeight(math.abs(trackedY) + 4)
        trackedSection:UpdateHeight()
    end

    -- Build Powerbar sub-tab (moved to resourcebars module)
    -- Removed: BuildPowerbarTab function - now in modules/resourcebars/qui_resourcebars_options.lua
    --[[
    local function BuildPowerbarTab(tabContent)
        local PAD = 10
        local y = -10

        -- Set search context for widget auto-registration
        -- GUI:SetSearchContext({tabIndex = 6, tabName = "CDM Setup & Class Bars", subTabIndex = 4, subTabName = "Class Resource Bar"})

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
        if primary.colorMode == nil then primary.colorMode = "power" end  -- "power", "class", or "custom"
        if primary.usePowerColor == nil then primary.usePowerColor = true end  -- Default to power type color
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
        if secondary.colorMode == nil then secondary.colorMode = "power" end  -- "power", "class", or "custom"
        if secondary.usePowerColor == nil then secondary.usePowerColor = true end  -- Default to power type color
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
            if _G.QuaziiUI and _G.QuaziiUI.QUICore then
                local QUICore = _G.QuaziiUI.QUICore
                if QUICore.UpdatePowerBar then QUICore:UpdatePowerBar() end
                if QUICore.UpdateSecondaryPowerBar then QUICore:UpdateSecondaryPowerBar() end
            end
        end

        -- Get texture options from LSM
        local function GetTextureOptions()
            local options = {}
            local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
            if LSM then
                local textures = LSM:HashTable("statusbar")
                for name, _ in pairs(textures) do
                    table.insert(options, {value = name, text = name})
                end
                table.sort(options, function(a, b) return a.text < b.text end)
            else
                options = {
                    {value = "Quazii", text = "Quazii"},
                    {value = "Smooth", text = "Smooth"},
                    {value = "Flat", text = "Flat"},
                }
            end
            return options
        end

        local FORM_ROW = 32

        -- =====================================================
        -- GENERAL SETTINGS
        -- =====================================================
        local generalHeader = GUI:CreateSectionHeader(tabContent, "General")
        generalHeader:SetPoint("TOPLEFT", PAD, y)
        y = y - generalHeader.gap

        -- Enable toggles
        local enablePrimary = GUI:CreateFormToggle(tabContent, "Enable Primary Class Resource Bar", "enabled", primary, RefreshPowerBars)
        enablePrimary:SetPoint("TOPLEFT", PAD, y)
        enablePrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local enableSecondary = GUI:CreateFormToggle(tabContent, "Enable Secondary Class Resource Bar", "enabled", secondary, RefreshPowerBars)
        enableSecondary:SetPoint("TOPLEFT", PAD, y)
        enableSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        -- Standalone toggles
        local standalonePrimary = GUI:CreateFormToggle(tabContent, "Primary Standalone Mode", "standaloneMode", primary, RefreshPowerBars)
        standalonePrimary:SetPoint("TOPLEFT", PAD, y)
        standalonePrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local standaloneSecondary = GUI:CreateFormToggle(tabContent, "Secondary Standalone Mode", "standaloneMode", secondary, RefreshPowerBars)
        standaloneSecondary:SetPoint("TOPLEFT", PAD, y)
        standaloneSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local standaloneDesc = GUI:CreateLabel(tabContent, "Standalone Mode: Bar won't fade or hide with CDM visibility. Use if you don't use Essential/Utility cooldown displays.", 11, C.textMuted)
        standaloneDesc:SetPoint("TOPLEFT", PAD, y)
        standaloneDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        standaloneDesc:SetJustifyH("LEFT")
        y = y - 25

        -- Unthrottled CPU Use toggle (affects both primary and secondary)
        local unthrottledToggle = GUI:CreateFormToggle(tabContent, "Unthrottled CPU Use", "unthrottledCPU", primary, RefreshPowerBars)
        unthrottledToggle:SetPoint("TOPLEFT", PAD, y)
        unthrottledToggle:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local unthrottledDesc = GUI:CreateLabel(tabContent, "Remove throttle on the number of updates per second. Toggle on for smoother updates, but higher CPU Usage.", 11, C.textMuted)
        unthrottledDesc:SetPoint("TOPLEFT", PAD, y)
        unthrottledDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        unthrottledDesc:SetJustifyH("LEFT")
        y = y - 25

        -- Spacer before Primary section
        y = y - 10

        -- =====================================================
        -- PRIMARY POWER BAR SECTION
        -- =====================================================
        local primaryHeader = GUI:CreateSectionHeader(tabContent, "Primary Class Resource Bar")
        primaryHeader:SetPoint("TOPLEFT", PAD, y)
        y = y - primaryHeader.gap

        local primaryDesc = GUI:CreateLabel(tabContent, "Customize individual resource colors in the Resource Colors section at the bottom. Applied when 'Use Resource Type Color' is enabled.", 11, C.textMuted)
        primaryDesc:SetPoint("TOPLEFT", PAD, y)
        primaryDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        primaryDesc:SetJustifyH("LEFT")
        y = y - 20

        local primaryWarning = GUI:CreateLabel(tabContent, "Designed for horizontal layouts used by most players. Vertical mode requires extra setup (row offsets, orientation toggles).", 11, C.warning)
        primaryWarning:SetPoint("TOPLEFT", PAD, y)
        primaryWarning:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        primaryWarning:SetJustifyH("LEFT")
        y = y - 20

        -- Orientation dropdown
        local orientationOptions = {
            {value = "HORIZONTAL", text = "Horizontal"},
            {value = "VERTICAL", text = "Vertical"},
        }
        local orientationPrimary = GUI:CreateFormDropdown(tabContent, "Orientation", orientationOptions, "orientation", primary, RefreshPowerBars)
        orientationPrimary:SetPoint("TOPLEFT", PAD, y)
        orientationPrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        -- Color options (form style) - radio-button behavior: clicking one turns off the others
        local customColorPickerPrimary

        local powerColorPrimary = GUI:CreateFormCheckbox(tabContent, "Use Resource Type Color", "usePowerColor", primary, function()
            if primary.usePowerColor then
                primary.useClassColor = false
                primary.useCustomColor = false
                primary.colorMode = "power"
            else
                -- Fallback: if turning off and nothing else is on, re-enable this
                if not primary.useClassColor and not primary.useCustomColor then
                    primary.usePowerColor = true
                end
            end
            if customColorPickerPrimary then
                customColorPickerPrimary:SetEnabled(primary.useCustomColor)
            end
            RefreshPowerBars()
        end)
        powerColorPrimary:SetPoint("TOPLEFT", PAD, y)
        powerColorPrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local resourceColorDescPrimary = GUI:CreateLabel(tabContent, "Uses per-resource colors from the Resource Colors section below.", 11)
        resourceColorDescPrimary:SetPoint("TOPLEFT", PAD, y + 4)
        resourceColorDescPrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        resourceColorDescPrimary:SetJustifyH("LEFT")
        resourceColorDescPrimary:SetTextColor(0.6, 0.6, 0.6)
        y = y - FORM_ROW

        local classColorPrimary = GUI:CreateFormCheckbox(tabContent, "Use Class Color", "useClassColor", primary, function()
            if primary.useClassColor then
                primary.usePowerColor = false
                primary.useCustomColor = false
                primary.colorMode = "class"
            else
                -- Fallback: if turning off and nothing else is on, enable Resource Type Color
                if not primary.usePowerColor and not primary.useCustomColor then
                    primary.usePowerColor = true
                end
            end
            if customColorPickerPrimary then
                customColorPickerPrimary:SetEnabled(primary.useCustomColor)
            end
            RefreshPowerBars()
        end)
        classColorPrimary:SetPoint("TOPLEFT", PAD, y)
        classColorPrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local bgColorPrimary = GUI:CreateFormColorPicker(tabContent, "Background Color", "bgColor", primary, RefreshPowerBars)
        bgColorPrimary:SetPoint("TOPLEFT", PAD, y)
        bgColorPrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local customColorOverridePrimary = GUI:CreateFormCheckbox(tabContent, "Custom Color Override", "useCustomColor", primary, function()
            if primary.useCustomColor then
                primary.usePowerColor = false
                primary.useClassColor = false
                primary.colorMode = "custom"
            else
                -- Fallback: if turning off and nothing else is on, enable Resource Type Color
                if not primary.usePowerColor and not primary.useClassColor then
                    primary.usePowerColor = true
                end
            end
            if customColorPickerPrimary then
                customColorPickerPrimary:SetEnabled(primary.useCustomColor)
            end
            RefreshPowerBars()
        end)
        customColorOverridePrimary:SetPoint("TOPLEFT", PAD, y)
        customColorOverridePrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        customColorPickerPrimary = GUI:CreateFormColorPicker(tabContent, "Custom Color", "customColor", primary, RefreshPowerBars)
        customColorPickerPrimary:SetPoint("TOPLEFT", PAD, y)
        customColorPickerPrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        customColorPickerPrimary:SetEnabled(primary.useCustomColor)
        y = y - FORM_ROW

        -- Text display options
        local showTextPrimary = GUI:CreateFormCheckbox(tabContent, "Show Number", "showText", primary, RefreshPowerBars)
        showTextPrimary:SetPoint("TOPLEFT", PAD, y)
        showTextPrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local showPercentPrimary = GUI:CreateFormCheckbox(tabContent, "Show as Percent", "showPercent", primary, RefreshPowerBars)
        showPercentPrimary:SetPoint("TOPLEFT", PAD, y)
        showPercentPrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        -- Tick marks
        local showTicksPrimary = GUI:CreateFormCheckbox(tabContent, "Show Tick Marks", "showTicks", primary, RefreshPowerBars)
        showTicksPrimary:SetPoint("TOPLEFT", PAD, y)
        showTicksPrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local tickThicknessPrimary = GUI:CreateFormSlider(tabContent, "Tick Thickness", 1, 4, 1, "tickThickness", primary, RefreshPowerBars)
        tickThicknessPrimary:SetPoint("TOPLEFT", PAD, y)
        tickThicknessPrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local tickColorPrimary = GUI:CreateFormColorPicker(tabContent, "Tick Color", "tickColor", primary, RefreshPowerBars)
        tickColorPrimary:SetPoint("TOPLEFT", PAD, y)
        tickColorPrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local borderPrimary = GUI:CreateFormSlider(tabContent, "Border Size", 0, 8, 1, "borderSize", primary, RefreshPowerBars)
        borderPrimary:SetPoint("TOPLEFT", PAD, y)
        borderPrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        -- Frame Anchoring section (using anchoring system)
        if ns.QUI_LayoutControl_Options then
            local function OnAnchorChange()
                RefreshPowerBars()
            end

            local bar = QUICore and QUICore.powerBar
            local layoutSection, layoutContent, y = ns.QUI_LayoutControl_Options:CreateLayoutControl(
                    tabContent, bar, y, PAD, FORM_ROW, OnAnchorChange, {
                        sectionTitle = "Frame Anchoring",
                        anchorKey = "anchorTo",
                        maxAnchors = 2,
                        excludeSelf = "primary"
                    }
            )
        end  -- End Frame Anchoring section

        -- Text sliders
        local textSizePrimary = GUI:CreateFormSlider(tabContent, "Text Size", 8, 50, 1, "textSize", primary, RefreshPowerBars)
        textSizePrimary:SetPoint("TOPLEFT", PAD, y)
        textSizePrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local textXPrimary = GUI:CreateFormSlider(tabContent, "Text X Offset", -500, 500, 1, "textX", primary, RefreshPowerBars)
        textXPrimary:SetPoint("TOPLEFT", PAD, y)
        textXPrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local textYPrimary = GUI:CreateFormSlider(tabContent, "Text Y Offset", -500, 500, 1, "textY", primary, RefreshPowerBars)
        textYPrimary:SetPoint("TOPLEFT", PAD, y)
        textYPrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        -- Text color settings
        local textCustomColorPrimary  -- Forward declare for mutual reference

        local textUseClassColorPrimary = GUI:CreateFormCheckbox(tabContent, "Use Class Color for Text", "textUseClassColor", primary, function()
            if textCustomColorPrimary then
                textCustomColorPrimary:SetEnabled(not primary.textUseClassColor)
            end
            RefreshPowerBars()
        end)
        textUseClassColorPrimary:SetPoint("TOPLEFT", PAD, y)
        textUseClassColorPrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        textCustomColorPrimary = GUI:CreateFormColorPicker(tabContent, "Custom Text Color", "textCustomColor", primary, RefreshPowerBars)
        textCustomColorPrimary:SetPoint("TOPLEFT", PAD, y)
        textCustomColorPrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        textCustomColorPrimary:SetEnabled(not primary.textUseClassColor)  -- Initial state
        y = y - FORM_ROW

        local texturePrimary = GUI:CreateFormDropdown(tabContent, "Bar Texture", GetTextureList(), "texture", primary, RefreshPowerBars)
        texturePrimary:SetPoint("TOPLEFT", PAD, y)
        texturePrimary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        -- Spacer between sections
        y = y - 15

        -- =====================================================
        -- SECONDARY POWER BAR SECTION
        -- =====================================================
        local secondaryHeader = GUI:CreateSectionHeader(tabContent, "Secondary Class Resource Bar")
        secondaryHeader:SetPoint("TOPLEFT", PAD, y)
        y = y - secondaryHeader.gap

        local secondaryDesc = GUI:CreateLabel(tabContent, "Customize individual resource colors in the Resource Colors section at the bottom. Applied when 'Use Resource Type Color' is enabled.", 11, C.textMuted)
        secondaryDesc:SetPoint("TOPLEFT", PAD, y)
        secondaryDesc:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        secondaryDesc:SetJustifyH("LEFT")
        y = y - 20

        local secondaryWarning = GUI:CreateLabel(tabContent, "Designed for horizontal layouts used by most players. Vertical mode requires extra setup (row offsets, orientation toggles).", 11, C.warning)
        secondaryWarning:SetPoint("TOPLEFT", PAD, y)
        secondaryWarning:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        secondaryWarning:SetJustifyH("LEFT")
        y = y - 20

        -- Orientation dropdown
        local orientationOptionsSecondary = {
            {value = "HORIZONTAL", text = "Horizontal"},
            {value = "VERTICAL", text = "Vertical"},
        }
        local orientationSecondary = GUI:CreateFormDropdown(tabContent, "Orientation", orientationOptionsSecondary, "orientation", secondary, RefreshPowerBars)
        orientationSecondary:SetPoint("TOPLEFT", PAD, y)
        orientationSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        -- Color options (form style) - radio-button behavior: clicking one turns off the others
        local customColorPickerSecondary

        local powerColorSecondary = GUI:CreateFormCheckbox(tabContent, "Use Resource Type Color", "usePowerColor", secondary, function()
            if secondary.usePowerColor then
                secondary.useClassColor = false
                secondary.useCustomColor = false
                secondary.colorMode = "power"
            else
                -- Fallback: if turning off and nothing else is on, re-enable this
                if not secondary.useClassColor and not secondary.useCustomColor then
                    secondary.usePowerColor = true
                end
            end
            if customColorPickerSecondary then
                customColorPickerSecondary:SetEnabled(secondary.useCustomColor)
            end
            RefreshPowerBars()
        end)
        powerColorSecondary:SetPoint("TOPLEFT", PAD, y)
        powerColorSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local resourceColorDescSecondary = GUI:CreateLabel(tabContent, "Uses per-resource colors from the Resource Colors section below.", 11)
        resourceColorDescSecondary:SetPoint("TOPLEFT", PAD, y + 4)
        resourceColorDescSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        resourceColorDescSecondary:SetJustifyH("LEFT")
        resourceColorDescSecondary:SetTextColor(0.6, 0.6, 0.6)
        y = y - FORM_ROW

        local classColorSecondary = GUI:CreateFormCheckbox(tabContent, "Use Class Color", "useClassColor", secondary, function()
            if secondary.useClassColor then
                secondary.usePowerColor = false
                secondary.useCustomColor = false
                secondary.colorMode = "class"
            else
                -- Fallback: if turning off and nothing else is on, enable Resource Type Color
                if not secondary.usePowerColor and not secondary.useCustomColor then
                    secondary.usePowerColor = true
                end
            end
            if customColorPickerSecondary then
                customColorPickerSecondary:SetEnabled(secondary.useCustomColor)
            end
            RefreshPowerBars()
        end)
        classColorSecondary:SetPoint("TOPLEFT", PAD, y)
        classColorSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local bgColorSecondary = GUI:CreateFormColorPicker(tabContent, "Background Color", "bgColor", secondary, RefreshPowerBars)
        bgColorSecondary:SetPoint("TOPLEFT", PAD, y)
        bgColorSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local customColorOverrideSecondary = GUI:CreateFormCheckbox(tabContent, "Custom Color Override", "useCustomColor", secondary, function()
            if secondary.useCustomColor then
                secondary.usePowerColor = false
                secondary.useClassColor = false
                secondary.colorMode = "custom"
            else
                -- Fallback: if turning off and nothing else is on, enable Resource Type Color
                if not secondary.usePowerColor and not secondary.useClassColor then
                    secondary.usePowerColor = true
                end
            end
            if customColorPickerSecondary then
                customColorPickerSecondary:SetEnabled(secondary.useCustomColor)
            end
            RefreshPowerBars()
        end)
        customColorOverrideSecondary:SetPoint("TOPLEFT", PAD, y)
        customColorOverrideSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        customColorPickerSecondary = GUI:CreateFormColorPicker(tabContent, "Custom Color", "customColor", secondary, RefreshPowerBars)
        customColorPickerSecondary:SetPoint("TOPLEFT", PAD, y)
        customColorPickerSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        customColorPickerSecondary:SetEnabled(secondary.useCustomColor)
        y = y - FORM_ROW

        -- Text display options
        local showTextSecondary = GUI:CreateFormCheckbox(tabContent, "Show Number", "showText", secondary, RefreshPowerBars)
        showTextSecondary:SetPoint("TOPLEFT", PAD, y)
        showTextSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local showPercentSecondary = GUI:CreateFormCheckbox(tabContent, "Show as Percent", "showPercent", secondary, RefreshPowerBars)
        showPercentSecondary:SetPoint("TOPLEFT", PAD, y)
        showPercentSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local showRuneTextSecondary = GUI:CreateFormCheckbox(tabContent, "Show Rune CD Text (DKs)", "showFragmentedPowerBarText", secondary, RefreshPowerBars)
        showRuneTextSecondary:SetPoint("TOPLEFT", PAD, y)
        showRuneTextSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        local _, playerClass = UnitClass("player")
        showRuneTextSecondary:SetEnabled(playerClass == "DEATHKNIGHT")
        y = y - FORM_ROW

        -- Tick marks
        local showTicksSecondary = GUI:CreateFormCheckbox(tabContent, "Show Tick Marks", "showTicks", secondary, RefreshPowerBars)
        showTicksSecondary:SetPoint("TOPLEFT", PAD, y)
        showTicksSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local tickThicknessSecondary = GUI:CreateFormSlider(tabContent, "Tick Thickness", 1, 4, 1, "tickThickness", secondary, RefreshPowerBars)
        tickThicknessSecondary:SetPoint("TOPLEFT", PAD, y)
        tickThicknessSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local tickColorSecondary = GUI:CreateFormColorPicker(tabContent, "Tick Color", "tickColor", secondary, RefreshPowerBars)
        tickColorSecondary:SetPoint("TOPLEFT", PAD, y)
        tickColorSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local borderSecondary = GUI:CreateFormSlider(tabContent, "Border Size", 0, 8, 1, "borderSize", secondary, RefreshPowerBars)
        borderSecondary:SetPoint("TOPLEFT", PAD, y)
        borderSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        -- Frame Anchoring section (using anchoring system)
        if ns.QUI_LayoutControl_Options then
            local function OnAnchorChange()
                RefreshPowerBars()
            end

            local bar = QUICore and QUICore.secondaryPowerBar
            local layoutSection, layoutContent, y = ns.QUI_LayoutControl_Options:CreateLayoutControl(
                    tabContent, bar, y, PAD, FORM_ROW, OnAnchorChange, {
                        sectionTitle = "Frame Anchoring",
                        anchorKey = "anchorTo",
                        maxAnchors = 2,
                        excludeSelf = "secondary"
                    }
            )
        end  -- End Frame Anchoring section

        -- Text sliders
        local textSizeSecondary = GUI:CreateFormSlider(tabContent, "Text Size", 8, 50, 1, "textSize", secondary, RefreshPowerBars)
        textSizeSecondary:SetPoint("TOPLEFT", PAD, y)
        textSizeSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local textXSecondary = GUI:CreateFormSlider(tabContent, "Text X Offset", -500, 500, 1, "textX", secondary, RefreshPowerBars)
        textXSecondary:SetPoint("TOPLEFT", PAD, y)
        textXSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        local textYSecondary = GUI:CreateFormSlider(tabContent, "Text Y Offset", -500, 500, 1, "textY", secondary, RefreshPowerBars)
        textYSecondary:SetPoint("TOPLEFT", PAD, y)
        textYSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        -- Text color settings
        local textCustomColorSecondary  -- Forward declare for mutual reference

        local textUseClassColorSecondary = GUI:CreateFormCheckbox(tabContent, "Use Class Color for Text", "textUseClassColor", secondary, function()
            if textCustomColorSecondary then
                textCustomColorSecondary:SetEnabled(not secondary.textUseClassColor)
            end
            RefreshPowerBars()
        end)
        textUseClassColorSecondary:SetPoint("TOPLEFT", PAD, y)
        textUseClassColorSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        textCustomColorSecondary = GUI:CreateFormColorPicker(tabContent, "Custom Text Color", "textCustomColor", secondary, RefreshPowerBars)
        textCustomColorSecondary:SetPoint("TOPLEFT", PAD, y)
        textCustomColorSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        textCustomColorSecondary:SetEnabled(not secondary.textUseClassColor)  -- Initial state
        y = y - FORM_ROW

        local textureSecondary = GUI:CreateFormDropdown(tabContent, "Bar Texture", GetTextureList(), "texture", secondary, RefreshPowerBars)
        textureSecondary:SetPoint("TOPLEFT", PAD, y)
        textureSecondary:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - FORM_ROW

        -- =====================================================
        -- POWER COLORS (Global - affects both bars)
        -- =====================================================
        y = y - 20  -- Spacer between sections

        local powerColorsHeader = GUI:CreateSectionHeader(tabContent, "Reset Resource Bar Colors To Default")
        powerColorsHeader:SetPoint("TOPLEFT", PAD, y)
        y = y - powerColorsHeader.gap

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

        -- Reset to Defaults button
        local resetPowerColorsContainer = CreateFrame("Frame", nil, tabContent)
        resetPowerColorsContainer:SetHeight(FORM_ROW)
        resetPowerColorsContainer:SetPoint("TOPLEFT", PAD, y)
        resetPowerColorsContainer:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)

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
        y = y - FORM_ROW

        -- =====================================================
        -- SUB-SECTION: Core Resources
        -- =====================================================
        y = y - 8
        local coreHeader = GUI:CreateSectionHeader(tabContent, "Bar Colors for Core Resources")
        coreHeader:SetPoint("TOPLEFT", PAD, y)
        y = y - coreHeader.gap

        local rageColor = GUI:CreateFormColorPicker(tabContent, "Rage", "rage", pc, RefreshPowerBars)
        rageColor:SetPoint("TOPLEFT", PAD, y)
        rageColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        rageColor.dbKey = "rage"
        table.insert(powerColorWidgets, rageColor)
        y = y - FORM_ROW

        local energyColor = GUI:CreateFormColorPicker(tabContent, "Energy", "energy", pc, RefreshPowerBars)
        energyColor:SetPoint("TOPLEFT", PAD, y)
        energyColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        energyColor.dbKey = "energy"
        table.insert(powerColorWidgets, energyColor)
        y = y - FORM_ROW

        local manaColor = GUI:CreateFormColorPicker(tabContent, "Mana", "mana", pc, RefreshPowerBars)
        manaColor:SetPoint("TOPLEFT", PAD, y)
        manaColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        manaColor.dbKey = "mana"
        table.insert(powerColorWidgets, manaColor)
        y = y - FORM_ROW

        local focusColor = GUI:CreateFormColorPicker(tabContent, "Focus", "focus", pc, RefreshPowerBars)
        focusColor:SetPoint("TOPLEFT", PAD, y)
        focusColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        focusColor.dbKey = "focus"
        table.insert(powerColorWidgets, focusColor)
        y = y - FORM_ROW

        local runicPowerColor = GUI:CreateFormColorPicker(tabContent, "Runic Power", "runicPower", pc, RefreshPowerBars)
        runicPowerColor:SetPoint("TOPLEFT", PAD, y)
        runicPowerColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        runicPowerColor.dbKey = "runicPower"
        table.insert(powerColorWidgets, runicPowerColor)
        y = y - FORM_ROW

        local furyColor = GUI:CreateFormColorPicker(tabContent, "Fury", "fury", pc, RefreshPowerBars)
        furyColor:SetPoint("TOPLEFT", PAD, y)
        furyColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        furyColor.dbKey = "fury"
        table.insert(powerColorWidgets, furyColor)
        y = y - FORM_ROW

        local insanityColor = GUI:CreateFormColorPicker(tabContent, "Insanity", "insanity", pc, RefreshPowerBars)
        insanityColor:SetPoint("TOPLEFT", PAD, y)
        insanityColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        insanityColor.dbKey = "insanity"
        table.insert(powerColorWidgets, insanityColor)
        y = y - FORM_ROW

        local maelstromColor = GUI:CreateFormColorPicker(tabContent, "Maelstrom", "maelstrom", pc, RefreshPowerBars)
        maelstromColor:SetPoint("TOPLEFT", PAD, y)
        maelstromColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        maelstromColor.dbKey = "maelstrom"
        table.insert(powerColorWidgets, maelstromColor)
        y = y - FORM_ROW

        local lunarPowerColor = GUI:CreateFormColorPicker(tabContent, "Astral Power", "lunarPower", pc, RefreshPowerBars)
        lunarPowerColor:SetPoint("TOPLEFT", PAD, y)
        lunarPowerColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        lunarPowerColor.dbKey = "lunarPower"
        table.insert(powerColorWidgets, lunarPowerColor)
        y = y - FORM_ROW

        -- =====================================================
        -- SUB-SECTION: Builder Resources
        -- =====================================================
        y = y - 8
        local builderHeader = GUI:CreateSectionHeader(tabContent, "Bar Colors for Builder Resources")
        builderHeader:SetPoint("TOPLEFT", PAD, y)
        y = y - builderHeader.gap

        local holyPowerColor = GUI:CreateFormColorPicker(tabContent, "Holy Power", "holyPower", pc, RefreshPowerBars)
        holyPowerColor:SetPoint("TOPLEFT", PAD, y)
        holyPowerColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        holyPowerColor.dbKey = "holyPower"
        table.insert(powerColorWidgets, holyPowerColor)
        y = y - FORM_ROW

        local chiColor = GUI:CreateFormColorPicker(tabContent, "Chi", "chi", pc, RefreshPowerBars)
        chiColor:SetPoint("TOPLEFT", PAD, y)
        chiColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        chiColor.dbKey = "chi"
        table.insert(powerColorWidgets, chiColor)
        y = y - FORM_ROW

        local comboPointsColor = GUI:CreateFormColorPicker(tabContent, "Combo Points", "comboPoints", pc, RefreshPowerBars)
        comboPointsColor:SetPoint("TOPLEFT", PAD, y)
        comboPointsColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        comboPointsColor.dbKey = "comboPoints"
        table.insert(powerColorWidgets, comboPointsColor)
        y = y - FORM_ROW

        local soulShardsColor = GUI:CreateFormColorPicker(tabContent, "Soul Shards", "soulShards", pc, RefreshPowerBars)
        soulShardsColor:SetPoint("TOPLEFT", PAD, y)
        soulShardsColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        soulShardsColor.dbKey = "soulShards"
        table.insert(powerColorWidgets, soulShardsColor)
        y = y - FORM_ROW

        local arcaneChargesColor = GUI:CreateFormColorPicker(tabContent, "Arcane Charges", "arcaneCharges", pc, RefreshPowerBars)
        arcaneChargesColor:SetPoint("TOPLEFT", PAD, y)
        arcaneChargesColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        arcaneChargesColor.dbKey = "arcaneCharges"
        table.insert(powerColorWidgets, arcaneChargesColor)
        y = y - FORM_ROW

        local essenceColor = GUI:CreateFormColorPicker(tabContent, "Essence", "essence", pc, RefreshPowerBars)
        essenceColor:SetPoint("TOPLEFT", PAD, y)
        essenceColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        essenceColor.dbKey = "essence"
        table.insert(powerColorWidgets, essenceColor)
        y = y - FORM_ROW

        -- =====================================================
        -- SUB-SECTION: Specialized Resources
        -- =====================================================
        y = y - 8
        local specialHeader = GUI:CreateSectionHeader(tabContent, "Bar Colors for Specialized Resources")
        specialHeader:SetPoint("TOPLEFT", PAD, y)
        y = y - specialHeader.gap

        local staggerColor = GUI:CreateFormColorPicker(tabContent, "Stagger", "stagger", pc, RefreshPowerBars)
        staggerColor:SetPoint("TOPLEFT", PAD, y)
        staggerColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        staggerColor.dbKey = "stagger"
        table.insert(powerColorWidgets, staggerColor)
        y = y - FORM_ROW

        local soulFragmentsColor = GUI:CreateFormColorPicker(tabContent, "Soul Fragments", "soulFragments", pc, RefreshPowerBars)
        soulFragmentsColor:SetPoint("TOPLEFT", PAD, y)
        soulFragmentsColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        soulFragmentsColor.dbKey = "soulFragments"
        table.insert(powerColorWidgets, soulFragmentsColor)
        y = y - FORM_ROW

        local runesColor = GUI:CreateFormColorPicker(tabContent, "Runes (Generic)", "runes", pc, RefreshPowerBars)
        runesColor:SetPoint("TOPLEFT", PAD, y)
        runesColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        runesColor.dbKey = "runes"
        table.insert(powerColorWidgets, runesColor)
        y = y - FORM_ROW

        local bloodRunesColor = GUI:CreateFormColorPicker(tabContent, "Blood Runes", "bloodRunes", pc, RefreshPowerBars)
        bloodRunesColor:SetPoint("TOPLEFT", PAD, y)
        bloodRunesColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        bloodRunesColor.dbKey = "bloodRunes"
        table.insert(powerColorWidgets, bloodRunesColor)
        y = y - FORM_ROW

        local frostRunesColor = GUI:CreateFormColorPicker(tabContent, "Frost Runes", "frostRunes", pc, RefreshPowerBars)
        frostRunesColor:SetPoint("TOPLEFT", PAD, y)
        frostRunesColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        frostRunesColor.dbKey = "frostRunes"
        table.insert(powerColorWidgets, frostRunesColor)
        y = y - FORM_ROW

        local unholyRunesColor = GUI:CreateFormColorPicker(tabContent, "Unholy Runes", "unholyRunes", pc, RefreshPowerBars)
        unholyRunesColor:SetPoint("TOPLEFT", PAD, y)
        unholyRunesColor:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        unholyRunesColor.dbKey = "unholyRunes"
        table.insert(powerColorWidgets, unholyRunesColor)
        y = y - FORM_ROW

        -- Extra padding at bottom for dropdown menus to expand into
        tabContent:SetHeight(math.abs(y) + 60)
    end
    --]]

    -- Create sub-tabs
    local subTabs = GUI:CreateSubTabs(content, {
        {name = "Essential", builder = BuildEssentialTab},
        {name = "Utility", builder = BuildUtilityTab},
        {name = "Buff", builder = BuildBuffTab},
    })
    subTabs:SetPoint("TOPLEFT", 5, -5)
    subTabs:SetPoint("TOPRIGHT", -5, -5)
    subTabs:SetHeight(700)

    content:SetHeight(750)
end

-- Export the function
ns.NCDMOptions = { CreateCDMSetupPage = CreateCDMSetupPage }

-- Register with Options Page Registry
if ns.OptionsPageRegistry then
    ns.OptionsPageRegistry:RegisterSimplePage("ncdm_setup", "CDM Setup", CreateCDMSetupPage, 60)
end

return ns.NCDMOptions
