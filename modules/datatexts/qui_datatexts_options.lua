--[[
    qui_datatexts_options.lua
    Options UI for Datatexts component (includes custom datapanels)
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
local CreateCollapsibleSection = OptionsShared.CreateCollapsibleSection

-- Refresh callbacks
local function RefreshMinimap()
    if QUICore and QUICore.Minimap and QUICore.Minimap.Refresh then
        QUICore.Minimap:Refresh()
    end
end

-- Build datatext tab
local function BuildDatatextTab(tabContent)
    local db = GetDB()
    local y = -10
    local PAD = 10

    -- Set search context for auto-registration
    GUI:SetSearchContext({tabIndex = 3, tabName = "Minimap & Datatext", subTabIndex = 2, subTabName = "Datatext"})

    -- Early return if database not ready
    if not db then
        local errorLabel = GUI:CreateLabel(tabContent, "Database not ready. Please /reload.", 12, {1, 0.3, 0.3, 1})
        errorLabel:SetPoint("TOPLEFT", PAD, y)
        tabContent:SetHeight(50)
        return
    end

    -- Early return if module not enabled
    if not ns.IsModuleEnabled("datatexts") then
        local disabledLabel = GUI:CreateLabel(tabContent, "Datatexts module is disabled. Enable it in Options > General > Modules.", 12, {1, 0.8, 0.3, 1})
        disabledLabel:SetPoint("TOPLEFT", PAD, y)
        tabContent:SetHeight(50)
        return
    end

    -- Ensure datatext table exists
    if not db.datatext then
        db.datatext = {}
    end
    local dt = db.datatext

    -- SECTION 1: Minimap Datatext Settings
    GUI:SetSearchSection("Minimap Datatext Settings")
    local panelSection, panelContent, y = CreateCollapsibleSection(tabContent, "Minimap Datatext Settings", y, PAD, false, nil)
    local panelY = 0

    local noteLabel = GUI:CreateLabel(panelContent, "This datatext panel is anchored below the minimap and cannot be moved. To create additional movable panels, scroll down to 'Custom Movable Panels'.", 11, C.textMuted)
    noteLabel:SetPoint("TOPLEFT", PAD, panelY)
    noteLabel:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    noteLabel:SetJustifyH("LEFT")
    panelY = panelY - 38

    local enableCheck = GUI:CreateFormCheckbox(panelContent, "Enable Minimap Datatext", "enabled", dt, RefreshMinimap)
    enableCheck:SetPoint("TOPLEFT", PAD, panelY)
    enableCheck:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    panelY = panelY - FORM_ROW

    local forceSingleLine = GUI:CreateFormCheckbox(panelContent, "Force Single Line", "forceSingleLine", dt, RefreshMinimap)
    forceSingleLine:SetPoint("TOPLEFT", PAD, panelY)
    forceSingleLine:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    panelY = panelY - FORM_ROW

    local heightSlider = GUI:CreateFormSlider(panelContent, "Panel Height (Per Row)", 18, 50, 1, "height", dt, RefreshMinimap)
    heightSlider:SetPoint("TOPLEFT", PAD, panelY)
    heightSlider:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    panelY = panelY - FORM_ROW

    local bgOpacitySlider = GUI:CreateFormSlider(panelContent, "Background Transparency", 0, 100, 5, "bgOpacity", dt, RefreshMinimap)
    bgOpacitySlider:SetPoint("TOPLEFT", PAD, panelY)
    bgOpacitySlider:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    panelY = panelY - FORM_ROW

    local borderSizeSlider = GUI:CreateFormSlider(panelContent, "Border Size", 1, 8, 1, "borderSize", dt, RefreshMinimap)
    borderSizeSlider:SetPoint("TOPLEFT", PAD, panelY)
    borderSizeSlider:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    panelY = panelY - FORM_ROW

    local offsetYSlider = GUI:CreateFormSlider(panelContent, "Vertical Offset", -40, 40, 1, "offsetY", dt, RefreshMinimap)
    offsetYSlider:SetPoint("TOPLEFT", PAD, panelY)
    offsetYSlider:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    panelY = panelY - FORM_ROW

    panelY = panelY - 10

    -- Build datatext options from registry
    local dtOptions = {{value = "", text = "(Empty)"}}
    if QUI.QUICore and QUI.QUICore.Datatexts and QUI.QUICore.Datatexts.registry then
        for id, def in pairs(QUI.QUICore.Datatexts.registry) do
            table.insert(dtOptions, {value = id, text = def.displayName or id})
        end
        table.sort(dtOptions, function(a, b)
            if a.value == "" then return true end
            if b.value == "" then return false end
            return a.text < b.text
        end)
    end

    -- Ensure slots table and per-slot configs exist
    if not dt.slots then
        dt.slots = {"time", "friends", "guild"}
    end
    if not dt.slot1 then dt.slot1 = { shortLabel = false, noLabel = false, xOffset = 0, yOffset = 0 } end
    if not dt.slot2 then dt.slot2 = { shortLabel = false, noLabel = false, xOffset = 0, yOffset = 0 } end
    if not dt.slot3 then dt.slot3 = { shortLabel = false, noLabel = false, xOffset = 0, yOffset = 0 } end
    if dt.slot1.noLabel == nil then dt.slot1.noLabel = false end
    if dt.slot2.noLabel == nil then dt.slot2.noLabel = false end
    if dt.slot3.noLabel == nil then dt.slot3.noLabel = false end

    -- Slot 1 Group
    local slot1 = GUI:CreateFormDropdown(panelContent, "Slot 1 (Left)", dtOptions, nil, nil, function(val)
        dt.slots[1] = val
        RefreshMinimap()
    end)
    slot1:SetPoint("TOPLEFT", PAD, panelY)
    slot1:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    if slot1.SetValue then slot1.SetValue(dt.slots[1] or "") end
    panelY = panelY - FORM_ROW

    local slot1NoLabel
    local slot1Short = GUI:CreateFormCheckbox(panelContent, "Slot 1 Short Label", "shortLabel", dt.slot1, function()
        if slot1NoLabel then slot1NoLabel:SetEnabled(not dt.slot1.shortLabel) end
        RefreshMinimap()
    end)
    slot1Short:SetPoint("TOPLEFT", PAD, panelY)
    slot1Short:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    panelY = panelY - FORM_ROW

    slot1NoLabel = GUI:CreateFormCheckbox(panelContent, "Slot 1 No Label", "noLabel", dt.slot1, function()
        if slot1Short then slot1Short:SetEnabled(not dt.slot1.noLabel) end
        RefreshMinimap()
    end)
    slot1NoLabel:SetPoint("TOPLEFT", PAD, panelY)
    slot1NoLabel:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    slot1NoLabel:SetEnabled(not dt.slot1.shortLabel)
    slot1Short:SetEnabled(not dt.slot1.noLabel)
    panelY = panelY - FORM_ROW

    local slot1XOff = GUI:CreateFormSlider(panelContent, "Slot 1 X Offset", -50, 50, 1, "xOffset", dt.slot1, RefreshMinimap)
    slot1XOff:SetPoint("TOPLEFT", PAD, panelY)
    slot1XOff:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    panelY = panelY - FORM_ROW

    local slot1YOff = GUI:CreateFormSlider(panelContent, "Slot 1 Y Offset", -20, 20, 1, "yOffset", dt.slot1, RefreshMinimap)
    slot1YOff:SetPoint("TOPLEFT", PAD, panelY)
    slot1YOff:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    panelY = panelY - FORM_ROW

    panelY = panelY - 10

    -- Slot 2 Group
    local slot2 = GUI:CreateFormDropdown(panelContent, "Slot 2 (Center)", dtOptions, nil, nil, function(val)
        dt.slots[2] = val
        RefreshMinimap()
    end)
    slot2:SetPoint("TOPLEFT", PAD, panelY)
    slot2:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    if slot2.SetValue then slot2.SetValue(dt.slots[2] or "") end
    panelY = panelY - FORM_ROW

    local slot2NoLabel
    local slot2Short = GUI:CreateFormCheckbox(panelContent, "Slot 2 Short Label", "shortLabel", dt.slot2, function()
        if slot2NoLabel then slot2NoLabel:SetEnabled(not dt.slot2.shortLabel) end
        RefreshMinimap()
    end)
    slot2Short:SetPoint("TOPLEFT", PAD, panelY)
    slot2Short:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    panelY = panelY - FORM_ROW

    slot2NoLabel = GUI:CreateFormCheckbox(panelContent, "Slot 2 No Label", "noLabel", dt.slot2, function()
        if slot2Short then slot2Short:SetEnabled(not dt.slot2.noLabel) end
        RefreshMinimap()
    end)
    slot2NoLabel:SetPoint("TOPLEFT", PAD, panelY)
    slot2NoLabel:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    slot2NoLabel:SetEnabled(not dt.slot2.shortLabel)
    slot2Short:SetEnabled(not dt.slot2.noLabel)
    panelY = panelY - FORM_ROW

    local slot2XOff = GUI:CreateFormSlider(panelContent, "Slot 2 X Offset", -50, 50, 1, "xOffset", dt.slot2, RefreshMinimap)
    slot2XOff:SetPoint("TOPLEFT", PAD, panelY)
    slot2XOff:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    panelY = panelY - FORM_ROW

    local slot2YOff = GUI:CreateFormSlider(panelContent, "Slot 2 Y Offset", -20, 20, 1, "yOffset", dt.slot2, RefreshMinimap)
    slot2YOff:SetPoint("TOPLEFT", PAD, panelY)
    slot2YOff:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    panelY = panelY - FORM_ROW

    panelY = panelY - 10

    -- Slot 3 Group
    local slot3 = GUI:CreateFormDropdown(panelContent, "Slot 3 (Right)", dtOptions, nil, nil, function(val)
        dt.slots[3] = val
        RefreshMinimap()
    end)
    slot3:SetPoint("TOPLEFT", PAD, panelY)
    slot3:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    if slot3.SetValue then slot3.SetValue(dt.slots[3] or "") end
    panelY = panelY - FORM_ROW

    local slot3NoLabel
    local slot3Short = GUI:CreateFormCheckbox(panelContent, "Slot 3 Short Label", "shortLabel", dt.slot3, function()
        if slot3NoLabel then slot3NoLabel:SetEnabled(not dt.slot3.shortLabel) end
        RefreshMinimap()
    end)
    slot3Short:SetPoint("TOPLEFT", PAD, panelY)
    slot3Short:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    panelY = panelY - FORM_ROW

    slot3NoLabel = GUI:CreateFormCheckbox(panelContent, "Slot 3 No Label", "noLabel", dt.slot3, function()
        if slot3Short then slot3Short:SetEnabled(not dt.slot3.noLabel) end
        RefreshMinimap()
    end)
    slot3NoLabel:SetPoint("TOPLEFT", PAD, panelY)
    slot3NoLabel:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    slot3NoLabel:SetEnabled(not dt.slot3.shortLabel)
    slot3Short:SetEnabled(not dt.slot3.noLabel)
    panelY = panelY - FORM_ROW

    local slot3XOff = GUI:CreateFormSlider(panelContent, "Slot 3 X Offset", -50, 50, 1, "xOffset", dt.slot3, RefreshMinimap)
    slot3XOff:SetPoint("TOPLEFT", PAD, panelY)
    slot3XOff:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    panelY = panelY - FORM_ROW

    local slot3YOff = GUI:CreateFormSlider(panelContent, "Slot 3 Y Offset", -20, 20, 1, "yOffset", dt.slot3, RefreshMinimap)
    slot3YOff:SetPoint("TOPLEFT", PAD, panelY)
    slot3YOff:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    panelY = panelY - FORM_ROW

    local hintText = GUI:CreateLabel(panelContent, "Empty slots are hidden. Using 2 datatexts gives each 50% width.", 11, C.textMuted)
    hintText:SetPoint("TOPLEFT", PAD, panelY)
    hintText:SetPoint("RIGHT", panelContent, "RIGHT", -PAD, 0)
    hintText:SetJustifyH("LEFT")
    panelY = panelY - 28

    panelContent:SetHeight(math.abs(panelY) + 4)
    panelSection:UpdateHeight()

    -- SECTION 3: Spec Display Options
    local specSection, specContent, y = CreateCollapsibleSection(tabContent, "Spec Display Options", y, PAD, false, panelSection)
    local specY = 0

    local specDisplayDropdown = GUI:CreateFormDropdown(specContent, "Spec Display Mode", {
        {value = "icon", text = "Icon Only"},
        {value = "loadout", text = "Icon + Loadout"},
        {value = "full", text = "Full (Spec / Loadout)"},
    }, "specDisplayMode", dt, function()
        if QUICore and QUICore.Datatexts and QUICore.Datatexts.UpdateAll then
            QUICore.Datatexts:UpdateAll()
        end
    end)
    specDisplayDropdown:SetPoint("TOPLEFT", PAD, specY)
    specDisplayDropdown:SetPoint("RIGHT", specContent, "RIGHT", -PAD, 0)
    specY = specY - FORM_ROW

    specContent:SetHeight(math.abs(specY) + 4)
    specSection:UpdateHeight()

    -- SECTION 4: Time Options
    local timeSection, timeContent, y = CreateCollapsibleSection(tabContent, "Time Options", y, PAD, false, specSection)
    local timeY = 0

    local timeFormatDropdown = GUI:CreateFormDropdown(timeContent, "Time Format", {
        {value = "local", text = "Local Time"},
        {value = "server", text = "Server Time"},
    }, "timeFormat", dt, RefreshMinimap)
    timeFormatDropdown:SetPoint("TOPLEFT", PAD, timeY)
    timeFormatDropdown:SetPoint("RIGHT", timeContent, "RIGHT", -PAD, 0)
    timeY = timeY - FORM_ROW

    local clockFormatDropdown = GUI:CreateFormDropdown(timeContent, "Clock Format", {
        {value = true, text = "24-Hour Clock"},
        {value = false, text = "AM/PM"},
    }, "use24Hour", dt, RefreshMinimap)
    clockFormatDropdown:SetPoint("TOPLEFT", PAD, timeY)
    clockFormatDropdown:SetPoint("RIGHT", timeContent, "RIGHT", -PAD, 0)
    timeY = timeY - FORM_ROW

    timeContent:SetHeight(math.abs(timeY) + 4)
    timeSection:UpdateHeight()

    -- SECTION 5: Text Styling
    local fontSection, fontContent, y = CreateCollapsibleSection(tabContent, "Text Styling", y, PAD, false, timeSection)
    local fontY = 0

    local fontSizeSlider = GUI:CreateFormSlider(fontContent, "Text Size", 9, 18, 1, "fontSize", dt, RefreshMinimap)
    fontSizeSlider:SetPoint("TOPLEFT", PAD, fontY)
    fontSizeSlider:SetPoint("RIGHT", fontContent, "RIGHT", -PAD, 0)
    fontY = fontY - FORM_ROW

    local useClassColor = GUI:CreateFormCheckbox(fontContent, "Use Class Color", "useClassColor", dt, function()
        RefreshMinimap()
        if QUICore and QUICore.Datatexts and QUICore.Datatexts.UpdateAll then
            QUICore.Datatexts:UpdateAll()
        end
    end)
    useClassColor:SetPoint("TOPLEFT", PAD, fontY)
    useClassColor:SetPoint("RIGHT", fontContent, "RIGHT", -PAD, 0)
    fontY = fontY - FORM_ROW

    local valueColor = GUI:CreateFormColorPicker(fontContent, "Custom Text Color", "valueColor", dt, function()
        RefreshMinimap()
        if QUICore and QUICore.Datatexts and QUICore.Datatexts.UpdateAll then
            QUICore.Datatexts:UpdateAll()
        end
    end)
    valueColor:SetPoint("TOPLEFT", PAD, fontY)
    valueColor:SetPoint("RIGHT", fontContent, "RIGHT", -PAD, 0)
    fontY = fontY - FORM_ROW

    fontContent:SetHeight(math.abs(fontY) + 4)
    fontSection:UpdateHeight()

    -- SECTION 6: Custom Movable Datapanels
    local customPanelsSection, customPanelsContent, y = CreateCollapsibleSection(tabContent, "Custom Movable Panels", y, PAD, false, fontSection)
    local customPanelsY = 0

    local panelsNote = GUI:CreateLabel(customPanelsContent, "Create additional datatext panels that can be freely positioned anywhere on screen.", 11, C.textMuted)
    panelsNote:SetPoint("TOPLEFT", PAD, customPanelsY)
    panelsNote:SetPoint("RIGHT", customPanelsContent, "RIGHT", -PAD, 0)
    panelsNote:SetJustifyH("LEFT")
    customPanelsY = customPanelsY - 28

    local panelsWarning = GUI:CreateLabel(customPanelsContent, "Note: Panels will only appear if at least one slot has a datatext assigned.", 11, C.textMuted)
    panelsWarning:SetPoint("TOPLEFT", PAD, customPanelsY)
    panelsWarning:SetPoint("RIGHT", customPanelsContent, "RIGHT", -PAD, 0)
    panelsWarning:SetJustifyH("LEFT")
    customPanelsY = customPanelsY - 28
    
    if not db.quiDatatexts then
        db.quiDatatexts = {panels = {}}
    end
    if not db.quiDatatexts.panels then
        db.quiDatatexts.panels = {}
    end
    
    local panels = db.quiDatatexts.panels
    local openEditFrames = {}

    if #panels > 0 then
        for i, panelConfig in ipairs(panels) do
            local panelFrame = CreateFrame("Frame", nil, customPanelsContent, "BackdropTemplate")
            panelFrame:SetHeight(60)
            panelFrame:SetPoint("TOPLEFT", PAD, customPanelsY)
            panelFrame:SetPoint("RIGHT", customPanelsContent, "RIGHT", -PAD, 0)
            panelFrame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            panelFrame:SetBackdropColor(C.bgLight[1], C.bgLight[2], C.bgLight[3], 0.8)
            panelFrame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
            
            local nameLabel = panelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameLabel:SetPoint("TOPLEFT", 10, -10)
            nameLabel:SetText(string.format("Panel %d: %s", i, panelConfig.name or ("Panel " .. i)))
            nameLabel:SetTextColor(C.accentLight[1], C.accentLight[2], C.accentLight[3], 1)
            
            local statusLabel = panelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            statusLabel:SetPoint("TOPLEFT", 10, -30)
            statusLabel:SetText(string.format("%d slots", panelConfig.numSlots or 3))
            statusLabel:SetTextColor(0.7, 0.7, 0.7, 1)
            
            local editBtn = GUI:CreateButton(panelFrame, "Edit", 60, 22)
            editBtn:SetPoint("RIGHT", -140, 0)
            
            local editFrame = CreateFrame("Frame", nil, panelFrame, "BackdropTemplate")
            editFrame:SetPoint("TOPLEFT", panelFrame, "BOTTOMLEFT", 0, -5)
            editFrame:SetPoint("RIGHT", panelFrame, "RIGHT", 0, 0)
            editFrame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            editFrame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.98)
            editFrame:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
            editFrame:Hide()

            table.insert(openEditFrames, {frame = editFrame, button = editBtn})

            local editY = -10
            local editPad = 15
            
            local editTitle = editFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            editTitle:SetPoint("TOPLEFT", editPad, editY)
            editTitle:SetText("Configure " .. (panelConfig.name or ("Panel " .. i)))
            editTitle:SetTextColor(C.accentLight[1], C.accentLight[2], C.accentLight[3], 1)
            editY = editY - 30
            
            local nameLabel = editFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameLabel:SetPoint("TOPLEFT", editPad, editY)
            nameLabel:SetText("Panel Name:")
            editY = editY - 20
            
            local nameInput = CreateFrame("EditBox", nil, editFrame, "InputBoxTemplate")
            nameInput:SetSize(250, 20)
            nameInput:SetPoint("TOPLEFT", editPad, editY)
            nameInput:SetAutoFocus(false)
            nameInput:SetText(panelConfig.name or ("Panel " .. i))
            nameInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
            nameInput:SetScript("OnTextChanged", function(self)
                panelConfig.name = self:GetText()
            end)
            editY = editY - 35
            
            local slotsHeader = editFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            slotsHeader:SetPoint("TOPLEFT", editPad, editY)
            slotsHeader:SetText("Slot Configuration:")
            slotsHeader:SetTextColor(C.accentLight[1], C.accentLight[2], C.accentLight[3], 1)
            editY = editY - 25
            
            if not panelConfig.slots then panelConfig.slots = {} end
            
            local slotDropdowns = {}
            for slotIdx = 1, 6 do
                local slotLabel = editFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                slotLabel:SetPoint("TOPLEFT", editPad, editY)
                slotLabel:SetText("Slot " .. slotIdx .. ":")
                
                local datatextOptions = {{value = nil, text = "(empty)"}}
                if QUICore and QUICore.Datatexts then
                    local allDatatexts = QUICore.Datatexts:GetAll()
                    for _, datatextDef in ipairs(allDatatexts) do
                        table.insert(datatextOptions, {
                            value = datatextDef.id,
                            text = datatextDef.displayName
                        })
                    end
                end
                
                if not panelConfig.slots[slotIdx] then
                    panelConfig.slots[slotIdx] = nil
                end
                
                local slotWrapper = {value = panelConfig.slots[slotIdx]}
                
                local slotDropdown = GUI:CreateDropdown(editFrame, "", datatextOptions, "value", slotWrapper, function()
                    panelConfig.slots[slotIdx] = slotWrapper.value
                    if QUICore and QUICore.Datapanels then
                        QUICore.Datapanels:UpdatePanel(panelConfig.id)
                    end
                end)
                slotDropdown:SetPoint("LEFT", slotLabel, "RIGHT", 10, 0)
                slotDropdown:SetWidth(200)
                
                if slotIdx <= (panelConfig.numSlots or 3) then
                    slotLabel:Show()
                    slotDropdown:Show()
                else
                    slotLabel:Hide()
                    slotDropdown:Hide()
                end
                
                slotDropdowns[slotIdx] = {label = slotLabel, dropdown = slotDropdown}
                editY = editY - 30
            end
            
            editY = editY - 10
            
            local settingsHeader = editFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            settingsHeader:SetPoint("TOPLEFT", editPad, editY)
            settingsHeader:SetText("Panel Settings:")
            settingsHeader:SetTextColor(C.accentLight[1], C.accentLight[2], C.accentLight[3], 1)
            editY = editY - 25
            
            local widthSlider = GUI:CreateSlider(editFrame, "Width", 100, 800, 1, "width", panelConfig, function()
                if QUICore and QUICore.Datapanels then
                    QUICore.Datapanels:UpdatePanel(panelConfig.id)
                end
            end)
            widthSlider:SetPoint("TOPLEFT", editPad, editY)
            widthSlider:SetWidth(200)
            
            local heightSlider = GUI:CreateSlider(editFrame, "Height", 16, 50, 1, "height", panelConfig, function()
                if QUICore and QUICore.Datapanels then
                    QUICore.Datapanels:UpdatePanel(panelConfig.id)
                end
            end)
            heightSlider:SetPoint("LEFT", widthSlider, "RIGHT", 10, 0)
            heightSlider:SetWidth(200)
            editY = editY - 65
            
            local slotsSlider = GUI:CreateSlider(editFrame, "Number of Slots", 1, 6, 1, "numSlots", panelConfig, nil)
            slotsSlider:SetPoint("TOPLEFT", editPad, editY)
            slotsSlider:SetWidth(200)
            
            local fontSlider = GUI:CreateSlider(editFrame, "Font Size", 8, 18, 1, "fontSize", panelConfig, function()
                if QUICore and QUICore.Datapanels then
                    QUICore.Datapanels:UpdatePanel(panelConfig.id)
                end
            end)
            fontSlider:SetPoint("LEFT", slotsSlider, "RIGHT", 10, 0)
            fontSlider:SetWidth(200)
            editY = editY - 65
            
            local opacitySlider = GUI:CreateSlider(editFrame, "Background Opacity", 0, 100, 5, "bgOpacity", panelConfig, function()
                if QUICore and QUICore.Datapanels then
                    QUICore.Datapanels:UpdatePanel(panelConfig.id)
                end
            end)
            opacitySlider:SetPoint("TOPLEFT", editPad, editY)
            opacitySlider:SetWidth(200)
            
            local borderSlider = GUI:CreateSlider(editFrame, "Border Size", 0, 8, 1, "borderSize", panelConfig, function()
                if QUICore and QUICore.Datapanels then
                    QUICore.Datapanels:UpdatePanel(panelConfig.id)
                end
            end)
            borderSlider:SetPoint("LEFT", opacitySlider, "RIGHT", 10, 0)
            borderSlider:SetWidth(200)
            editY = editY - 65
            
            local lockCheck = GUI:CreateCheckbox(editFrame, "Lock Position (prevents dragging)", "locked", panelConfig, function()
                if QUICore and QUICore.Datapanels then
                    QUICore.Datapanels:SetLocked(panelConfig.id, panelConfig.locked)
                end
            end)
            lockCheck:SetPoint("TOPLEFT", editPad, editY)
            editY = editY - 35
            
            local originalOnValueChanged = slotsSlider.slider:GetScript("OnValueChanged")
            slotsSlider.slider:SetScript("OnValueChanged", function(self, value)
                if originalOnValueChanged then
                    originalOnValueChanged(self, value)
                end
                
                if QUICore and QUICore.Datapanels then
                    QUICore.Datapanels:UpdatePanel(panelConfig.id)
                end
                
                local numSlots = math.floor(value + 0.5)
                for idx, controls in ipairs(slotDropdowns) do
                    if idx <= numSlots then
                        controls.label:Show()
                        controls.dropdown:Show()
                    else
                        controls.label:Hide()
                        controls.dropdown:Hide()
                    end
                end

                statusLabel:SetText(string.format("%d slots", numSlots))
            end)
            
            local editFrameHeight = math.abs(editY) + 50
            editFrame:SetHeight(editFrameHeight)
            
            local closeBtn = GUI:CreateButton(editFrame, "Close", 80, 25, function()
                editFrame:Hide()
                editBtn.text:SetText("Edit")
            end)
            closeBtn:SetPoint("BOTTOM", 0, 10)
            
            editBtn:SetScript("OnClick", function()
                if editFrame:IsShown() then
                    editFrame:Hide()
                    editBtn.text:SetText("Edit")
                else
                    for _, entry in ipairs(openEditFrames) do
                        if entry.frame:IsShown() and entry.frame ~= editFrame then
                            entry.frame:Hide()
                            entry.button.text:SetText("Edit")
                        end
                    end

                    editFrame:Show()
                    editBtn.text:SetText("Close")

                    local numSlots = panelConfig.numSlots or 3
                    for idx, controls in ipairs(slotDropdowns) do
                        if idx <= numSlots then
                            controls.label:Show()
                            controls.dropdown:Show()
                        else
                            controls.label:Hide()
                            controls.dropdown:Hide()
                        end
                    end
                end
            end)
            
            local enableCheck = GUI:CreateCheckbox(panelFrame, "Enabled", "enabled", panelConfig, function()
                if QUICore and QUICore.Datapanels then
                    QUICore.Datapanels:UpdatePanel(panelConfig.id)
                end
            end)
            enableCheck:SetPoint("RIGHT", -80, 0)
            
            local delBtn = GUI:CreateButton(panelFrame, "Delete", 60, 22, function()
                table.remove(db.quiDatatexts.panels, i)
                if QUICore and QUICore.Datapanels then
                    QUICore.Datapanels:DeletePanel(panelConfig.id)
                    QUICore.Datapanels:RefreshAll()
                end
                GUI:ShowConfirmation({
                    title = "Reload UI?",
                    message = "Panel deleted. Reload UI to see changes?",
                    acceptText = "Reload",
                    cancelText = "Later",
                    onAccept = function() QuaziiUI:SafeReload() end,
                })
            end)
            delBtn:SetPoint("RIGHT", -10, 0)
            
            customPanelsY = customPanelsY - 70
        end
    else
        local noPanelsLabel = GUI:CreateLabel(customPanelsContent, "No custom panels created yet. Click 'Add Panel' below to get started.", 11, C.textDim)
        noPanelsLabel:SetPoint("TOPLEFT", PAD, customPanelsY)
        customPanelsY = customPanelsY - 30
    end
    
    local addPanelBtn = GUI:CreateButton(customPanelsContent, "Add Panel", 120, 28, function()
        local newID = "panel" .. (time() % 100000)
        local newPanel = {
            id = newID,
            name = "Panel " .. (#panels + 1),
            enabled = true,
            locked = false,
            numSlots = 3,
            width = 300,
            height = 22,
            bgOpacity = 50,
            borderSize = 2,
            fontSize = 12,
            position = {"CENTER", "CENTER", 0, 300},
            slots = {},
        }
        table.insert(db.quiDatatexts.panels, newPanel)
        
        if QUICore and QUICore.Datapanels then
            QUICore.Datapanels:RefreshAll()
        end
        
        GUI:ShowConfirmation({
            title = "Reload UI?",
            message = "Panel created. Reload UI to configure it?",
            acceptText = "Reload",
            cancelText = "Later",
            onAccept = function() QuaziiUI:SafeReload() end,
        })
    end)
    addPanelBtn:SetPoint("TOPLEFT", PAD, customPanelsY)
    customPanelsY = customPanelsY - 40

    customPanelsContent:SetHeight(math.abs(customPanelsY) + 4)
    customPanelsSection:UpdateHeight()

    tabContent:SetHeight(math.abs(y) + 50)
end

-- Export
local DatatextsOptions = {
    BuildDatatextTab = BuildDatatextTab,
}

ns.DatatextsOptions = DatatextsOptions

-- Register with Options Page Registry as sub-tab
if ns.OptionsPageRegistry then
    -- Add the datatext page as a sub-tab to the minimap composed page
    -- Use pcall to handle case where minimap page hasn't registered yet (shouldn't happen with correct load order)
    local success, err = pcall(function()
        ns.OptionsPageRegistry:AddSubTab("minimap", {
            name = "Datatext",
            builder = BuildDatatextTab,
            order = 20,
        })
    end)
    if not success then
        -- If registration failed, try again after a short delay (fallback for load order issues)
        C_Timer.After(0.1, function()
            if ns.OptionsPageRegistry then
                pcall(function()
                    ns.OptionsPageRegistry:AddSubTab("minimap", {
                        name = "Datatext",
                        builder = BuildDatatextTab,
                        order = 20,
                    })
                end)
            end
        end)
    end
end

return DatatextsOptions
