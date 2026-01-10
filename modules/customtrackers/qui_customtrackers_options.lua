--[[
    qui_customtrackers_options.lua
    Options UI for Custom Trackers component
    Includes consumables, trinkets, and custom spell trackers
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
local AddFormNote = OptionsShared.AddFormNote
local CreateCollapsibleSection = OptionsShared.CreateCollapsibleSection

---------------------------------------------------------------------------
-- Helper: Refresh bar position (re-registers with Layout Manager)
---------------------------------------------------------------------------
local function RefreshTrackerPosition(barID)
    local QUICore = ns.Addon
    if QUICore and QUICore.CustomTrackers and QUICore.CustomTrackers.RefreshBarPosition then
        QUICore.CustomTrackers:RefreshBarPosition(barID)
    end
end

local function CreateCustomTrackersPage(parent)
    -- Check if module is enabled before building content
    if not ns.IsModuleEnabled("customtrackers") then
        local emptyLabel = GUI:CreateLabel(parent, "Custom Trackers module is disabled.", 14, GUI.Colors.textMuted)
        emptyLabel:SetPoint("CENTER", parent, "CENTER", 0, 0)
        return
    end
    
    local scroll, content = CreateScrollableContent(parent)
    local db = GetDB()

    -- Set search context for auto-registration
    GUI:SetSearchContext({tabIndex = 9, tabName = "Custom Items/Spells"})

    -- Ensure customTrackers.bars exists
    if not db.customTrackers then
        db.customTrackers = {bars = {}}
    end
    if not db.customTrackers.bars then
        db.customTrackers.bars = {}
    end

    local bars = db.customTrackers.bars
    local PAD = 10
    local FORM_ROW = 32

    ---------------------------------------------------------------------------
    -- Helper: Create drop zone for adding items/spells via drag-and-drop
    ---------------------------------------------------------------------------
    local function CreateAddEntrySection(parentFrame, barID, refreshCallback)
        local container = CreateFrame("Frame", nil, parentFrame)
        container:SetHeight(83)  -- 50% taller than original 55

        -- DROP ZONE: Click here while holding an item/spell on cursor
        local dropZone = CreateFrame("Button", nil, container, "BackdropTemplate")
        dropZone:SetHeight(68)  -- 50% taller than original 45
        dropZone:SetPoint("TOPLEFT", 0, 0)
        dropZone:SetPoint("RIGHT", container, "RIGHT", 0, 0)  -- Full width
        dropZone:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        dropZone:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.8)
        dropZone:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.5)

        local dropLabel = dropZone:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        dropLabel:SetPoint("CENTER", 0, 0)
        dropLabel:SetText("Drop Items or Spells here")
        dropLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)

        -- Handle drop on mouse release (OnReceiveDrag fires when releasing with item on cursor)
        dropZone:SetScript("OnReceiveDrag", function(self)
            local cursorType, id1, id2, id3, id4 = GetCursorInfo()
            if cursorType == "item" then
                local itemID = id1
                if itemID then
                    local trackerModule = QUI and QUI.QUICore and QUI.QUICore.CustomTrackers
                    if trackerModule then
                        trackerModule:AddEntry(barID, "item", itemID)
                        ClearCursor()
                        if refreshCallback then refreshCallback() end
                    end
                end
            elseif cursorType == "spell" then
                -- id1 is slot index, id2 is bookType ("spell" or "pet")
                -- Need to look up actual spellID from spellbook
                local slotIndex = id1
                local bookType = id2 or "spell"
                local spellID = id4  -- Try direct spellID first (older API)

                -- If no direct spellID, look it up from spellbook
                if not spellID and slotIndex then
                    local spellBank = (bookType == "pet") and Enum.SpellBookSpellBank.Pet or Enum.SpellBookSpellBank.Player
                    local spellBookInfo = C_SpellBook.GetSpellBookItemInfo(slotIndex, spellBank)
                    if spellBookInfo then
                        spellID = spellBookInfo.spellID
                    end
                end

                -- Resolve override spell (talents that replace base spells)
                if spellID then
                    local overrideID = C_Spell.GetOverrideSpell(spellID)
                    if overrideID and overrideID ~= spellID then
                        spellID = overrideID
                    end
                end

                if spellID then
                    local trackerModule = QUI and QUI.QUICore and QUI.QUICore.CustomTrackers
                    if trackerModule then
                        trackerModule:AddEntry(barID, "spell", spellID)
                        ClearCursor()
                        if refreshCallback then refreshCallback() end
                    end
                end
            end
        end)

        -- Also handle OnMouseUp as fallback (some drag modes use this)
        dropZone:SetScript("OnMouseUp", function(self)
            local cursorType = GetCursorInfo()
            if cursorType == "item" or cursorType == "spell" then
                -- Trigger the same logic as OnReceiveDrag
                local handler = dropZone:GetScript("OnReceiveDrag")
                if handler then handler(self) end
            end
        end)

        -- Highlight on hover when cursor has item/spell
        dropZone:SetScript("OnEnter", function(self)
            local cursorType = GetCursorInfo()
            if cursorType == "item" or cursorType == "spell" then
                self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
                dropLabel:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 1)
            end
        end)
        dropZone:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.5)
            dropLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)
        end)

        return container
    end

    -- Helper: Get entry display name (prefers customName if set)
    local function GetEntryDisplayName(entry)
        -- Use custom name if set
        if entry.customName and entry.customName ~= "" then
            return entry.customName
        end
        -- Otherwise, auto-detect from spell/item info
        if entry.type == "spell" then
            local info = C_Spell.GetSpellInfo(entry.id)
            return info and info.name or ("Spell " .. entry.id)
        else
            local name = C_Item.GetItemInfo(entry.id)
            return name or ("Item " .. entry.id)
        end
    end

    ---------------------------------------------------------------------------
    -- Build tab content for a single tracker bar
    ---------------------------------------------------------------------------
    local function BuildTrackerBarTab(tabContent, barConfig, barIndex, subTabsRef)
        GUI:SetSearchContext({tabIndex = 9, tabName = "Custom Items/Spells", subTabIndex = barIndex + 1, subTabName = barConfig.name or ("Bar " .. barIndex)})
        local y = -10
        local PAD = 10
        local FORM_ROW = 32
        local entryListFrame  -- Forward declaration for refresh callback
        local trackersSection, trackersContent, trackersY -- Forward declarations for height updates

        -- Refresh callback for this bar
        local function RefreshThisBar()
            if QUICore and QUICore.CustomTrackers then
                QUICore.CustomTrackers:UpdateBar(barConfig.id)
            end
        end

        -- Refresh position callback
        local function RefreshPosition()
            RefreshTrackerPosition(barConfig.id)
        end

        -- =====================================================
        -- GENERAL SECTION (Collapsible)
        -- =====================================================
        local generalSection, generalContent, nextY = CreateCollapsibleSection(tabContent, "General", y, PAD, false, nil)
        y = nextY
        local generalY = 0

        local generalHint, nextGenY = AddFormNote(generalContent, "Reminder: Enable this bar, else nothing will show. If you are deleting the ONLY remaining bar, it would just restore the original 'Trinket & Pot' bar that is disabled by default.", generalY, CONTENT_PAD)
        generalY = nextGenY

        local enableCheck = GUI:CreateFormCheckbox(generalContent, "Enable Bar", "enabled", barConfig, RefreshThisBar)
        generalY = AddFormControl(generalContent, enableCheck, generalY, CONTENT_PAD, FORM_ROW)

        -- Bar Name (editable, updates tab text instantly)
        local nameContainer = CreateFrame("Frame", nil, generalContent)
        nameContainer:SetHeight(FORM_ROW)
        local nameLabel = nameContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLabel:SetPoint("LEFT", 0, 0)
        nameLabel:SetText("Bar Name")
        nameLabel:SetTextColor(C.text[1], C.text[2], C.text[3], 1)

        local nameInputBg = CreateFrame("Frame", nil, nameContainer, "BackdropTemplate")
        nameInputBg:SetPoint("LEFT", nameContainer, "LEFT", 180, 0)
        nameInputBg:SetSize(200, 24)
        nameInputBg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        nameInputBg:SetBackdropColor(0.08, 0.08, 0.08, 1)
        nameInputBg:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)

        local nameInput = CreateFrame("EditBox", nil, nameInputBg)
        nameInput:SetPoint("LEFT", 8, 0)
        nameInput:SetPoint("RIGHT", -8, 0)
        nameInput:SetHeight(22)
        nameInput:SetAutoFocus(false)
        nameInput:SetFont(GUI.FONT_PATH, 11, "")
        nameInput:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
        nameInput:SetText(barConfig.name or "Tracker")
        nameInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        nameInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        nameInput:SetScript("OnEditFocusGained", function() nameInputBg:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1) end)
        nameInput:SetScript("OnEditFocusLost", function() nameInputBg:SetBackdropBorderColor(0.35, 0.35, 0.35, 1) end)
        nameInput:SetScript("OnTextChanged", function(self)
            local newName = self:GetText()
            if newName == "" then newName = "Tracker" end
            barConfig.name = newName
            if subTabsRef and subTabsRef.tabButtons and subTabsRef.tabButtons[barIndex] then
                local displayName = newName
                if #displayName > 20 then displayName = displayName:sub(1, 17) .. "..." end
                subTabsRef.tabButtons[barIndex].text:SetText(displayName)
            end
        end)
        generalY = AddFormControl(generalContent, nameContainer, generalY, CONTENT_PAD, FORM_ROW)

        -- Delete Bar button
        local deleteBtn = GUI:CreateButton(generalContent, "Delete Bar", 120, 26, function()
            GUI:ShowConfirmation({
                title = "Delete Tracker Bar?",
                message = "Delete this tracker bar?",
                warningText = "This cannot be undone.",
                acceptText = "Delete",
                cancelText = "Cancel",
                isDestructive = true,
                onAccept = function()
                    for i, bc in ipairs(db.customTrackers.bars) do
                        if bc.id == barConfig.id then
                            table.remove(db.customTrackers.bars, i)
                            break
                        end
                    end
                    if QUICore and QUICore.CustomTrackers then
                        QUICore.CustomTrackers:DeleteBar(barConfig.id)
                    end
                    GUI:ShowConfirmation({
                        title = "Reload UI?",
                        message = "Tracker deleted. Reload UI to see changes?",
                        acceptText = "Reload",
                        cancelText = "Later",
                        onAccept = function() QuaziiUI:SafeReload() end,
                    })
                end,
            })
        end)
        generalY = AddFormControl(generalContent, deleteBtn, generalY, CONTENT_PAD, FORM_ROW + 4)

        generalContent:SetHeight(math.abs(generalY) + 4)
        generalSection:UpdateHeight()

        -- =====================================================
        -- POSITIONING SECTION (Integrated)
        -- =====================================================
        local positioningSection = nil
        if ns.QUI_Anchoring_Options then
            if not barConfig.anchorTo then
                barConfig.anchorTo = "player"
                barConfig.anchors = {
                    {source = "BOTTOMLEFT", target = "TOPLEFT"},
                    {source = "BOTTOMRIGHT", target = "TOPRIGHT"}
                }
                barConfig.offsetX = 0
                barConfig.offsetY = 0
            end
            
            local function OnAnchorChange()
                RefreshTrackerPosition(barConfig.id)
            end
            
            local tracker = QUICore and QUICore.CustomTrackers
            local frame = tracker and tracker.activeBars and tracker.activeBars[barConfig.id] or nil
            if ns.QUI_LayoutControl_Options then
                positioningSection, positioningContent, nextY = ns.QUI_LayoutControl_Options:CreateLayoutControl(
                    tabContent, frame, y, PAD, FORM_ROW, OnAnchorChange, {
                        sectionTitle = "Positioning",  -- Rename to avoid confusion with "Appearance & Layout"
                        previousSection = generalSection,  -- Chain to General section
                        anchorKey = "anchorTo",
                        maxAnchors = 2,
                        excludeSelf = "customTracker",
                        showSize = false,  -- Size is handled by Layout Manager automatically
                        widthMin = 1,
                        widthMax = 2000,
                        heightMin = 1,
                        heightMax = 2000
                    }
                )
                y = nextY
            end
        end

        -- =====================================================
        -- TRACKED ITEMS & SPELLS (Collapsible)
        -- =====================================================
        trackersSection, trackersContent, nextY = CreateCollapsibleSection(tabContent, "Tracked Items & Spells", y, PAD, false, positioningSection)
        y = nextY
        trackersY = 0

        local addHint, nextTrackersY = AddFormNote(trackersContent, "Drag items from bags/character pane, or spells from spellbook into the box below.", trackersY, CONTENT_PAD)
        trackersY = nextTrackersY

        local function RefreshEntryList()
            if not entryListFrame then return end
            for _, child in ipairs({entryListFrame:GetChildren()}) do child:Hide(); child:SetParent(nil) end
            local entries = barConfig.entries or {}
            local listY = 0
            for j, entry in ipairs(entries) do
                local entryFrame = CreateFrame("Frame", nil, entryListFrame)
                entryFrame:SetSize(320, 28)
                entryFrame:SetPoint("TOPLEFT", 0, listY)
                local iconTex = entryFrame:CreateTexture(nil, "ARTWORK")
                iconTex:SetSize(24, 24)
                iconTex:SetPoint("LEFT", 0, 0)
                if entry.type == "spell" then
                    local info = C_Spell.GetSpellInfo(entry.id)
                    iconTex:SetTexture(info and info.iconID or "Interface\\Icons\\INV_Misc_QuestionMark")
                else
                    local _, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(entry.id)
                    iconTex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                end
                iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                entryFrame.iconTex = iconTex
                local nameInputBg = CreateFrame("Frame", nil, entryFrame, "BackdropTemplate")
                nameInputBg:SetPoint("LEFT", iconTex, "RIGHT", 6, 0)
                nameInputBg:SetSize(176, 22)
                nameInputBg:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
                nameInputBg:SetBackdropColor(0.05, 0.05, 0.05, 0.4)
                nameInputBg:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.6)
                local nameInput = CreateFrame("EditBox", nil, nameInputBg)
                nameInput:SetPoint("LEFT", 6, 0); nameInput:SetPoint("RIGHT", -6, 0); nameInput:SetHeight(20)
                nameInput:SetAutoFocus(false); nameInput:SetFont(GUI.FONT_PATH, 11, ""); nameInput:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
                nameInput:SetText(GetEntryDisplayName(entry)); nameInput:SetCursorPosition(0)
                nameInput.entry, nameInput.barConfig = entry, barConfig
                local function ResolveAndUpdateEntry(self)
                    local newName = self:GetText()
                    if newName == "" then self.entry.customName = nil; self:SetText(GetEntryDisplayName(self.entry)); return end
                    if newName == GetEntryDisplayName(self.entry) then return end
                    local resolved = false
                    if self.entry.type == "spell" then
                        local newSpellID = C_Spell.GetSpellIDForSpellIdentifier(newName)
                        if newSpellID then self.entry.id = newSpellID; self.entry.customName = nil; resolved = true
                            if QUICore and QUICore.CustomTrackers then QUICore.CustomTrackers:UpdateBar(self.barConfig.id) end
                            self:SetText(GetEntryDisplayName(self.entry))
                            local iconTexRef = self:GetParent():GetParent().iconTex
                            if iconTexRef then local info = C_Spell.GetSpellInfo(newSpellID); if info and info.iconID then iconTexRef:SetTexture(info.iconID) end end
                        end
                    elseif self.entry.type == "item" then
                        local newItemID = C_Item.GetItemIDForItemInfo(newName)
                        if newItemID then self.entry.id = newItemID; self.entry.customName = nil; resolved = true
                            if QUICore and QUICore.CustomTrackers then QUICore.CustomTrackers:UpdateBar(self.barConfig.id) end
                            self:SetText(GetEntryDisplayName(self.entry))
                            local iconTexRef = self:GetParent():GetParent().iconTex
                            if iconTexRef then local _, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(newItemID); if itemIcon then iconTexRef:SetTexture(itemIcon) end end
                        end
                    end
                    if not resolved then self:SetText(GetEntryDisplayName(self.entry)) end
                end
                nameInput:SetScript("OnEnterPressed", function(self) ResolveAndUpdateEntry(self); self:ClearFocus() end)
                nameInput:SetScript("OnEditFocusGained", function(self) nameInputBg:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1); self:HighlightText() end)
                nameInput:SetScript("OnEditFocusLost", function(self) nameInputBg:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.6); ResolveAndUpdateEntry(self) end)

                local function CreateChevronButton(parent, direction, onClick)
                    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
                    btn:SetSize(22, 22)
                    btn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
                    btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                    btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
                    local cl = btn:CreateTexture(nil, "OVERLAY"); cl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.7); cl:SetSize(6, 2)
                    local cr = btn:CreateTexture(nil, "OVERLAY"); cr:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.7); cr:SetSize(6, 2)
                    if direction == "up" then cl:SetPoint("CENTER", -2, 1); cl:SetRotation(math.rad(45)); cr:SetPoint("CENTER", 2, 1); cr:SetRotation(math.rad(-45))
                    else cl:SetPoint("CENTER", -2, -1); cl:SetRotation(math.rad(-45)); cr:SetPoint("CENTER", 2, -1); cr:SetRotation(math.rad(45)) end
                    btn.cl, btn.cr = cl, cr
                    btn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1); self.cl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1); self.cr:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1) end)
                    btn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1); self.cl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.7); self.cr:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.7) end)
                    btn:SetScript("OnClick", onClick)
                    return btn
                end

                local upBtn = CreateChevronButton(entryFrame, "up", function() if QUICore.CustomTrackers then QUICore.CustomTrackers:MoveEntry(barConfig.id, j, -1) end; RefreshEntryList() end)
                upBtn:SetPoint("LEFT", nameInputBg, "RIGHT", 8, 0)
                if j == 1 then upBtn:SetAlpha(0.3); upBtn:EnableMouse(false) end

                local downBtn = CreateChevronButton(entryFrame, "down", function() if QUICore.CustomTrackers then QUICore.CustomTrackers:MoveEntry(barConfig.id, j, 1) end; RefreshEntryList() end)
                downBtn:SetPoint("LEFT", upBtn, "RIGHT", 2, 0)
                if j == #entries then downBtn:SetAlpha(0.3); downBtn:EnableMouse(false) end

                local removeBtn = CreateFrame("Button", nil, entryFrame, "BackdropTemplate")
                removeBtn:SetSize(22, 22)
                removeBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
                removeBtn:SetBackdropColor(0.1, 0.1, 0.1, 0.8); removeBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
                local xText = removeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal"); xText:SetPoint("CENTER", 0, 0); xText:SetText("X"); xText:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 0.7)
                removeBtn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1); xText:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 1) end)
                removeBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1); xText:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 0.7) end)
                removeBtn:SetScript("OnClick", function() if QUICore.CustomTrackers then QUICore.CustomTrackers:RemoveEntry(barConfig.id, entry.type, entry.id) end; RefreshEntryList() end)
                removeBtn:SetPoint("LEFT", downBtn, "RIGHT", 4, 0)

                listY = listY - 30
            end
            local listHeight = math.max(20, math.abs(listY))
            entryListFrame:SetHeight(listHeight)
            if trackersContent then
                trackersContent:SetHeight(math.abs(trackersY) + listHeight + 10)
                trackersSection:UpdateHeight()
            end
        end

        local addSection = CreateAddEntrySection(trackersContent, barConfig.id, RefreshEntryList)
        trackersY = AddFormControl(trackersContent, addSection, trackersY, CONTENT_PAD, 83 + 10)

        local trackedListHeader = trackersContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        trackedListHeader:SetPoint("TOPLEFT", CONTENT_PAD, trackersY)
        trackedListHeader:SetText("Active Trackers")
        trackersY = trackersY - 20

        entryListFrame = CreateFrame("Frame", nil, trackersContent)
        entryListFrame:SetPoint("TOPLEFT", CONTENT_PAD, trackersY)
        entryListFrame:SetSize(400, 20)
        RefreshEntryList()

        -- =====================================================
        -- APPEARANCE & LAYOUT (Collapsible)
        -- =====================================================
        local layoutSection, layoutContent, nextY = CreateCollapsibleSection(tabContent, "Appearance & Layout", y, PAD, false, trackersSection)
        y = nextY
        local layoutY = 0

        local growOptions = {{value = "RIGHT", text = "Right"}, {value = "LEFT", text = "Left"}, {value = "UP", text = "Up"}, {value = "DOWN", text = "Down"}}
        local growDropdown = GUI:CreateFormDropdown(layoutContent, "Grow Direction", growOptions, "growDirection", barConfig, RefreshThisBar)
        layoutY = AddFormControl(layoutContent, growDropdown, layoutY, CONTENT_PAD, FORM_ROW)

        layoutContent:SetHeight(math.abs(layoutY) + 4)
        layoutSection:UpdateHeight()

        -- =====================================================
        -- VISIBILITY & BEHAVIOR (Collapsible)
        -- =====================================================
        local visSection, visContent, nextY = CreateCollapsibleSection(tabContent, "Visibility & Behavior", y, PAD, false, layoutSection)
        y = nextY
        local visY = 0

        local autohideDesc, nextVisY = AddFormNote(visContent, "By default, when a consumable has 0 stacks, a trinket is unequipped, or you have unlearned a spell, those elements are desaturated. Toggle this to hide them entirely.", visY, CONTENT_PAD)
        visY = nextVisY
        local hideNonUsableCheck = GUI:CreateFormCheckbox(visContent, "Hide Non-Usable", "hideNonUsable", barConfig, RefreshThisBar)
        visY = AddFormControl(visContent, hideNonUsableCheck, visY, CONTENT_PAD, FORM_ROW)

        local cooldownOnlyDesc, nextVisY = AddFormNote(visContent, "When enabled, icons are invisible when ready to be used. They appear desaturated when on cooldown.", visY, CONTENT_PAD)
        visY = nextVisY
        local showOnlyOnCooldownCheck = GUI:CreateFormCheckbox(visContent, "Show Only On Cooldown", "showOnlyOnCooldown", barConfig, RefreshThisBar)
        visY = AddFormControl(visContent, showOnlyOnCooldownCheck, visY, CONTENT_PAD, FORM_ROW)

        visContent:SetHeight(math.abs(visY) + 4)
        visSection:UpdateHeight()

        -- =====================================================
        -- ACTIVE STATE VISUALS (Collapsible)
        -- =====================================================
        local activeSection, activeContent, nextY = CreateCollapsibleSection(tabContent, "Active State Visuals", y, PAD, false, visSection)
        y = nextY
        local activeY = 0

        local activeStateDesc, nextActiveY = AddFormNote(activeContent, "Highlight icons when actively casting, channeling, or when their buff is on you. Icons appear saturated with optional glow.", activeY, CONTENT_PAD)
        activeY = nextActiveY

        local showActiveStateCheck = GUI:CreateFormCheckbox(activeContent, "Show Active State (Saturated)", "showActiveState", barConfig, RefreshThisBar)
        activeY = AddFormControl(activeContent, showActiveStateCheck, activeY, CONTENT_PAD, FORM_ROW)

        local enableGlowCheck = GUI:CreateFormCheckbox(activeContent, "Enable Glow Effect", "activeGlowEnabled", barConfig, RefreshThisBar)
        activeY = AddFormControl(activeContent, enableGlowCheck, activeY, CONTENT_PAD, FORM_ROW)

        local glowTypeOptions = {{value = "Button Glow", text = "Button Glow (Classic)"}, {value = "Pixel Glow", text = "Pixel Glow"}, {value = "Autocast Shine", text = "Autocast Shine"}}
        local glowTypeDropdown = GUI:CreateFormDropdown(activeContent, "Glow Type", glowTypeOptions, "activeGlowType", barConfig, RefreshThisBar, 150)
        activeY = AddFormControl(activeContent, glowTypeDropdown, activeY, CONTENT_PAD, FORM_ROW)

        local glowColorPicker = GUI:CreateFormColorPicker(activeContent, "Glow Color", "activeGlowColor", barConfig, RefreshThisBar)
        activeY = AddFormControl(activeContent, glowColorPicker, activeY, CONTENT_PAD, FORM_ROW)

        local glowLinesSlider = GUI:CreateFormSlider(activeContent, "Lines / Spots", 1, 16, 1, "activeGlowLines", barConfig, RefreshThisBar)
        activeY = AddFormControl(activeContent, glowLinesSlider, activeY, CONTENT_PAD, FORM_ROW)

        local glowThicknessSlider = GUI:CreateFormSlider(activeContent, "Line Thickness", 1, 8, 1, "activeGlowThickness", barConfig, RefreshThisBar)
        activeY = AddFormControl(activeContent, glowThicknessSlider, activeY, CONTENT_PAD, FORM_ROW)

        local glowScaleSlider = GUI:CreateFormSlider(activeContent, "Shine Scale", 0.5, 2.0, 0.1, "activeGlowScale", barConfig, RefreshThisBar)
        activeY = AddFormControl(activeContent, glowScaleSlider, activeY, CONTENT_PAD, FORM_ROW)

        local glowSpeedSlider = GUI:CreateFormSlider(activeContent, "Animation Speed", 0.1, 1.0, 0.05, "activeGlowFrequency", barConfig, RefreshThisBar)
        activeY = AddFormControl(activeContent, glowSpeedSlider, activeY, CONTENT_PAD, FORM_ROW)

        activeContent:SetHeight(math.abs(activeY) + 4)
        activeSection:UpdateHeight()

        -- =====================================================
        -- TEXT SETTINGS (Collapsible)
        -- =====================================================
        local textSection, textContent, nextY = CreateCollapsibleSection(tabContent, "Duration & Stack Text", y, PAD, false, activeSection)
        y = nextY
        local textY = 0

        local durHeader = textContent:CreateFontString(nil, "OVERLAY", "GameFontNormal"); durHeader:SetPoint("TOPLEFT", CONTENT_PAD, textY); durHeader:SetText("Duration Text"); textY = textY - 20
        local hideDurCheck = GUI:CreateFormCheckbox(textContent, "Hide Duration Text", "hideDurationText", barConfig, RefreshThisBar)
        textY = AddFormControl(textContent, hideDurCheck, textY, CONTENT_PAD, FORM_ROW)
        local durSizeSlider = GUI:CreateFormSlider(textContent, "Text Size", 8, 24, 1, "durationSize", barConfig, RefreshThisBar)
        textY = AddFormControl(textContent, durSizeSlider, textY, CONTENT_PAD, FORM_ROW)
        local durColorPicker = GUI:CreateFormColorPicker(textContent, "Text Color", "durationColor", barConfig, RefreshThisBar)
        textY = AddFormControl(textContent, durColorPicker, textY, CONTENT_PAD, FORM_ROW)
        local durXSlider = GUI:CreateFormSlider(textContent, "X Offset", -20, 20, 1, "durationOffsetX", barConfig, RefreshThisBar)
        textY = AddFormControl(textContent, durXSlider, textY, CONTENT_PAD, FORM_ROW)
        local durYSlider = GUI:CreateFormSlider(textContent, "Y Offset", -20, 20, 1, "durationOffsetY", barConfig, RefreshThisBar)
        textY = AddFormControl(textContent, durYSlider, textY, CONTENT_PAD, FORM_ROW)

        textY = textY - 10
        local stackHeader = textContent:CreateFontString(nil, "OVERLAY", "GameFontNormal"); stackHeader:SetPoint("TOPLEFT", CONTENT_PAD, textY); stackHeader:SetText("Stack Text"); textY = textY - 20
        local hideStackCheck = GUI:CreateFormCheckbox(textContent, "Hide Stack Text", "hideStackText", barConfig, RefreshThisBar)
        textY = AddFormControl(textContent, hideStackCheck, textY, CONTENT_PAD, FORM_ROW)
        local stackSizeSlider = GUI:CreateFormSlider(textContent, "Text Size", 8, 24, 1, "stackSize", barConfig, RefreshThisBar)
        textY = AddFormControl(textContent, stackSizeSlider, textY, CONTENT_PAD, FORM_ROW)
        local stackColorPicker = GUI:CreateFormColorPicker(textContent, "Text Color", "stackColor", barConfig, RefreshThisBar)
        textY = AddFormControl(textContent, stackColorPicker, textY, CONTENT_PAD, FORM_ROW)
        local stackXSlider = GUI:CreateFormSlider(textContent, "X Offset", -20, 20, 1, "stackOffsetX", barConfig, RefreshThisBar)
        textY = AddFormControl(textContent, stackXSlider, textY, CONTENT_PAD, FORM_ROW)
        local stackYSlider = GUI:CreateFormSlider(textContent, "Y Offset", -20, 20, 1, "stackOffsetY", barConfig, RefreshThisBar)
        textY = AddFormControl(textContent, stackYSlider, textY, CONTENT_PAD, FORM_ROW)

        textContent:SetHeight(math.abs(textY) + 4)
        textSection:UpdateHeight()

        tabContent:SetHeight(math.abs(y) + 50)
    end

    ---------------------------------------------------------------------------
    -- Build sub-tabs dynamically from bars
    ---------------------------------------------------------------------------
    -- Reference to be populated after subTabs creation (for live tab text updates)
    local subTabsRef = {}

    local tabDefs = {}

    -- Add a tab for each existing bar
    for i, barConfig in ipairs(bars) do
        local tabName = barConfig.name or ("Tracker " .. i)
        -- Truncate long names for tab display
        if #tabName > 20 then
            tabName = tabName:sub(1, 17) .. "..."
        end
        table.insert(tabDefs, {
            name = tabName,
            builder = function(tabContent)
                BuildTrackerBarTab(tabContent, barConfig, i, subTabsRef)
            end,
        })
    end

    -- If no bars exist, show empty state
    if #tabDefs == 0 then
        local section, sectionContent, y = CreateCollapsibleSection(content, "Custom Tracker Bars", -15, PAD, false, nil)
        local sectionY = 0

        local emptyLabel, nextY = AddFormNote(sectionContent, "No tracker bars created yet. A default bar will be created on next /reload.", sectionY, CONTENT_PAD)
        sectionY = nextY

        -- Add bar button
        local addBtn = GUI:CreateButton(sectionContent, "+ Add Tracker Bar", 160, 28, function()
            local newID = "tracker" .. (time() % 100000)
            local newBar = {
                id = newID,
                name = "Tracker " .. (#bars + 1),
                enabled = false,
                -- Anchoring system
                anchorTo = "player",  -- Anchor to player frame
                anchors = {
                    {source = "BOTTOMLEFT", target = "TOPLEFT"},  -- Bottom-left of bar to top-left of player
                    {source = "BOTTOMRIGHT", target = "TOPRIGHT"}  -- Bottom-right of bar to top-right of player
                },
                growDirection = "RIGHT",
                durationSize = 13,
                durationColor = {1, 1, 1, 1},
                durationOffsetX = 0,
                durationOffsetY = 0,
                stackSize = 9,
                stackColor = {1, 1, 1, 1},
                stackOffsetX = 3,
                stackOffsetY = -1,
                bgOpacity = 0,
                hideGCD = true,
                entries = {},
            }
            table.insert(db.customTrackers.bars, newBar)
            if QUICore and QUICore.CustomTrackers then
                QUICore.CustomTrackers:RefreshAll()
            end
            GUI:ShowConfirmation({
                title = "Reload UI?",
                message = "Tracker bar created. Reload UI to configure it?",
                acceptText = "Reload",
                cancelText = "Later",
                onAccept = function() QuaziiUI:SafeReload() end,
            })
        end)
        sectionY = AddFormControl(sectionContent, addBtn, sectionY, CONTENT_PAD, 28 + 10)

        sectionContent:SetHeight(math.abs(sectionY) + 4)
        section:UpdateHeight()
        content:SetHeight(200)
    else
        -- Add a "+" tab to create new bars
        table.insert(tabDefs, {
            name = "+ Add Bar",
            builder = function(tabContent)
                local y = -10
                local section, sectionContent, nextY = CreateCollapsibleSection(tabContent, "Add New Tracker Bar", y, PAD, false, nil)
                local sectionY = 0

                local desc, nextSecY = AddFormNote(sectionContent, "Create a new tracker bar to monitor consumables, trinkets, or ability cooldowns.", sectionY, CONTENT_PAD)
                sectionY = nextSecY

                local addBtn = GUI:CreateButton(sectionContent, "Create New Tracker Bar", 180, 28, function()
                    local newID = "tracker" .. (time() % 100000)
                    local newBar = {
                        id = newID,
                        name = "Tracker " .. (#bars + 1),
                        enabled = false,
                        anchorTo = "player",
                        anchors = {
                            {source = "BOTTOMLEFT", target = "TOPLEFT"},
                            {source = "BOTTOMRIGHT", target = "TOPRIGHT"}
                        },
                        growDirection = "RIGHT",
                        durationSize = 13,
                        durationColor = {1, 1, 1, 1},
                        durationOffsetX = 0,
                        durationOffsetY = 0,
                        stackSize = 9,
                        stackColor = {1, 1, 1, 1},
                        stackOffsetX = 3,
                        stackOffsetY = -1,
                        bgOpacity = 0,
                        hideGCD = true,
                        entries = {},
                    }
                    table.insert(db.customTrackers.bars, newBar)
                    if QUICore and QUICore.CustomTrackers then
                        QUICore.CustomTrackers:RefreshAll()
                    end
                    GUI:ShowConfirmation({
                        title = "Reload UI?",
                        message = "Tracker bar created. Reload UI to configure it?",
                        acceptText = "Reload",
                        cancelText = "Later",
                        onAccept = function() QuaziiUI:SafeReload() end,
                    })
                end)
                sectionY = AddFormControl(sectionContent, addBtn, sectionY, CONTENT_PAD, 28 + 10)

                sectionContent:SetHeight(math.abs(sectionY) + 4)
                section:UpdateHeight()
                tabContent:SetHeight(math.abs(nextY) + 150)
            end,
        })

        -- Create sub-tabs
        local subTabs = GUI:CreateSubTabs(content, tabDefs)
        subTabsRef.tabButtons = subTabs.tabButtons  -- Populate reference for live tab text updates
        subTabs:SetPoint("TOPLEFT", 5, -5)
        subTabs:SetPoint("TOPRIGHT", -5, -5)
        subTabs:SetHeight(750)

        content:SetHeight(800)
    end
end

---------------------------------------------------------------------------


-- Export the function
ns.CustomTrackersOptions = { CreateCustomTrackersPage = CreateCustomTrackersPage }

-- Register with Options Page Registry
if ns.OptionsPageRegistry then
    ns.OptionsPageRegistry:RegisterSimplePage("customtrackers", "Custom Items/Spells", CreateCustomTrackersPage, 90)
end

return ns.CustomTrackersOptions
