--[[
    qui_actionbars_options.lua
    Options UI for Action Bars component
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
local CreateCollapsibleSection = OptionsShared.CreateCollapsibleSection
local PADDING = OptionsShared.CONSTANTS.PADDING

local function CreateActionBarsPage(parent)
    -- Check if module is enabled before building content
    if not ns.IsModuleEnabled("actionbars") then
        local emptyLabel = GUI:CreateLabel(parent, "Action Bars module is disabled.", 14, GUI.Colors.textMuted)
        emptyLabel:SetPoint("CENTER", parent, "CENTER", 0, 0)
        return
    end
    local scroll, content = CreateScrollableContent(parent)
    local db = GetDB()

    -- Safety check
    if not db or not db.actionBars then
        local errorLabel = GUI:CreateLabel(content, "Action Bars settings not available. Please reload UI.", 12, C.text)
        errorLabel:SetPoint("TOPLEFT", PADDING, -15)
        content:SetHeight(100)
        return scroll, content
    end

    local actionBars = db.actionBars
    local global = actionBars.global
    local fade = actionBars.fade
    local bars = actionBars.bars

    -- Refresh callback
    local function RefreshActionBars()
        if _G.QuaziiUI_RefreshActionBars then
            _G.QuaziiUI_RefreshActionBars()
        end
    end

    ---------------------------------------------------------
    -- SUB-TAB: Mouseover Hide
    ---------------------------------------------------------
    local function BuildMouseoverHideTab(tabContent)
        local y = -15
        local PAD = PADDING
        local FORM_ROW = 32

        -- Set search context for widget auto-registration
        GUI:SetSearchContext({tabIndex = 4, tabName = "Action Bars", subTabIndex = 2, subTabName = "Mouseover Hide"})

        ---------------------------------------------------------
        -- Warning: Enable Blizzard Action Bars
        ---------------------------------------------------------
        local warningText = GUI:CreateLabel(tabContent,
            "Important: Enable all 8 action bars in Game Menu > Options > Gameplay > Action Bars for mouseover hide to work correctly. To remove the default dragon texture, open Edit Mode, select Action Bar 1, check 'Hide Bar Art', then reload.",
            11, C.warning)
        warningText:SetPoint("TOPLEFT", PAD, y)
        warningText:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        warningText:SetJustifyH("LEFT")
        warningText:SetWordWrap(true)
        warningText:SetHeight(45)
        y = y - 55

        local openSettingsBtn = GUI:CreateButton(tabContent, "Open Game Settings", 160, 26, function()
            if SettingsPanel then
                SettingsPanel:Open()
            end
        end)
        openSettingsBtn:SetPoint("TOPLEFT", PAD, y)
        openSettingsBtn:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        y = y - 46  -- Extra spacing before main content

        ---------------------------------------------------------
        -- Section: Mouseover Hide
        ---------------------------------------------------------
        local fadeSection, fadeContent, y = CreateCollapsibleSection(tabContent, "Mouseover Hide", y, PAD, false, nil)
        local fadeY = 0

        local fadeCheck = GUI:CreateFormCheckbox(fadeContent, "Enable Mouseover Hide",
            "enabled", fade, RefreshActionBars)
        fadeCheck:SetPoint("TOPLEFT", PAD, fadeY)
        fadeCheck:SetPoint("RIGHT", fadeContent, "RIGHT", -PAD, 0)
        fadeY = fadeY - FORM_ROW

        local fadeTip = GUI:CreateLabel(fadeContent,
            "Bars hide when mouse is not over them. Hover to reveal.",
            11, C.textMuted)
        fadeTip:SetPoint("TOPLEFT", PAD, fadeY)
        fadeTip:SetPoint("RIGHT", fadeContent, "RIGHT", -PAD, 0)
        fadeTip:SetJustifyH("LEFT")
        fadeY = fadeY - 24

        local fadeInSlider = GUI:CreateFormSlider(fadeContent, "Fade In Speed (sec)",
            0.1, 1.0, 0.05, "fadeInDuration", fade, RefreshActionBars)
        fadeInSlider:SetPoint("TOPLEFT", PAD, fadeY)
        fadeInSlider:SetPoint("RIGHT", fadeContent, "RIGHT", -PAD, 0)
        fadeY = fadeY - FORM_ROW

        local fadeOutSlider = GUI:CreateFormSlider(fadeContent, "Fade Out Speed (sec)",
            0.1, 1.0, 0.05, "fadeOutDuration", fade, RefreshActionBars)
        fadeOutSlider:SetPoint("TOPLEFT", PAD, fadeY)
        fadeOutSlider:SetPoint("RIGHT", fadeContent, "RIGHT", -PAD, 0)
        fadeY = fadeY - FORM_ROW

        local fadeAlphaSlider = GUI:CreateFormSlider(fadeContent, "Faded Opacity",
            0, 1, 0.05, "fadeOutAlpha", fade, RefreshActionBars)
        fadeAlphaSlider:SetPoint("TOPLEFT", PAD, fadeY)
        fadeAlphaSlider:SetPoint("RIGHT", fadeContent, "RIGHT", -PAD, 0)
        fadeY = fadeY - FORM_ROW

        local fadeDelaySlider = GUI:CreateFormSlider(fadeContent, "Fade Out Delay (sec)",
            0, 2.0, 0.1, "fadeOutDelay", fade, RefreshActionBars)
        fadeDelaySlider:SetPoint("TOPLEFT", PAD, fadeY)
        fadeDelaySlider:SetPoint("RIGHT", fadeContent, "RIGHT", -PAD, 0)
        fadeY = fadeY - FORM_ROW

        local combatCheck = GUI:CreateFormCheckbox(fadeContent, "Do Not Hide In Combat",
            "alwaysShowInCombat", fade, RefreshActionBars)
        combatCheck:SetPoint("TOPLEFT", PAD, fadeY)
        combatCheck:SetPoint("RIGHT", fadeContent, "RIGHT", -PAD, 0)
        fadeY = fadeY - FORM_ROW

        -- Always Show toggles (bars that ignore mouseover hide)
        local alwaysShowTip = GUI:CreateLabel(fadeContent,
            "Bars checked below will always remain visible, ignoring mouseover hide.",
            11, C.textMuted)
        alwaysShowTip:SetPoint("TOPLEFT", PAD, fadeY)
        alwaysShowTip:SetPoint("RIGHT", fadeContent, "RIGHT", -PAD, 0)
        alwaysShowTip:SetJustifyH("LEFT")
        fadeY = fadeY - 24

        local alwaysShowBars = {
            { key = "bar1", label = "Always Show Bar 1" },
            { key = "bar2", label = "Always Show Bar 2" },
            { key = "bar3", label = "Always Show Bar 3" },
            { key = "bar4", label = "Always Show Bar 4" },
            { key = "bar5", label = "Always Show Bar 5" },
            { key = "bar6", label = "Always Show Bar 6" },
            { key = "bar7", label = "Always Show Bar 7" },
            { key = "bar8", label = "Always Show Bar 8" },
            { key = "microbar", label = "Always Show Microbar" },
            { key = "bags", label = "Always Show Bags" },
            { key = "pet", label = "Always Show Pet Bar" },
            { key = "stance", label = "Always Show Stance Bar" },
            { key = "extraActionButton", label = "Always Show Extra Action" },
            { key = "zoneAbility", label = "Always Show Zone Ability" },
        }

        for _, barInfo in ipairs(alwaysShowBars) do
            local barDB = bars[barInfo.key]
            if barDB then
                local check = GUI:CreateFormCheckbox(fadeContent, barInfo.label,
                    "alwaysShow", barDB, RefreshActionBars)
                check:SetPoint("TOPLEFT", PAD, fadeY)
                check:SetPoint("RIGHT", fadeContent, "RIGHT", -PAD, 0)
                fadeY = fadeY - FORM_ROW
            end
        end

        fadeContent:SetHeight(math.abs(fadeY) + 4)
        fadeSection:UpdateHeight()

        tabContent:SetHeight(math.abs(y) + 50)
    end  -- End BuildMouseoverHideTab

    ---------------------------------------------------------
    -- SUB-TAB: Master Visual Settings (existing global settings)
    ---------------------------------------------------------
    local function BuildMasterSettingsTab(tabContent)
        local y = -15
        local PAD = PADDING
        local FORM_ROW = 32

        -- Set search context for auto-registration
        GUI:SetSearchContext({tabIndex = 4, tabName = "Action Bars", subTabIndex = 1, subTabName = "Master Settings"})

        -- 9-point anchor options for text positioning
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

        ---------------------------------------------------------
        -- Quick Keybind Mode (prominent tool at top)
        ---------------------------------------------------------
        local keybindModeBtn = GUI:CreateButton(tabContent, "Quick Keybind Mode", 180, 28, function()
            local LibKeyBound = LibStub("LibKeyBound-1.0", true)
            if LibKeyBound then
                LibKeyBound:Toggle()
            elseif QuickKeybindFrame then
                ShowUIPanel(QuickKeybindFrame)
            end
        end)
        keybindModeBtn:SetPoint("TOPLEFT", PAD, y)
        y = y - 38

        local keybindTip = GUI:CreateLabel(tabContent,
            "Hover over action buttons and press a key to bind. Type /kb anytime.",
            11, C.textMuted)
        keybindTip:SetPoint("TOPLEFT", PAD, y)
        keybindTip:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        keybindTip:SetJustifyH("LEFT")
        keybindTip:SetWordWrap(true)
        keybindTip:SetHeight(15)
        y = y - 30

        ---------------------------------------------------------
        -- Section: General
        ---------------------------------------------------------
        local generalSection, generalContent, y = CreateCollapsibleSection(tabContent, "General", y, PAD, false, nil)
        local generalY = 0

        local enableCheck = GUI:CreateFormCheckbox(generalContent, "Enable QUI Action Bars",
            "enabled", actionBars, function(val)
                GUI:ShowConfirmation({
                    title = "Reload Required",
                    message = "Action Bar styling requires a UI reload to take effect.",
                    acceptText = "Reload Now",
                    cancelText = "Later",
                    isDestructive = false,
                    onAccept = function()
                        QuaziiUI:SafeReload()
                    end,
                })
            end)
        enableCheck:SetPoint("TOPLEFT", PAD, generalY)
        enableCheck:SetPoint("RIGHT", generalContent, "RIGHT", -PAD, 0)
        generalY = generalY - FORM_ROW

        local tipText = GUI:CreateLabel(generalContent,
            "Position bars via Edit Mode. If using a standalone actionbar addon (e.g., Bartender4, Dominos), disable QUI Action Bars above for compatibility.",
            11, C.warning)
        tipText:SetPoint("TOPLEFT", PAD, generalY)
        tipText:SetPoint("RIGHT", generalContent, "RIGHT", -PAD, 0)
        tipText:SetJustifyH("LEFT")
        tipText:SetWordWrap(true)
        tipText:SetHeight(30)
        generalY = generalY - 40

        generalContent:SetHeight(math.abs(generalY) + 4)
        generalSection:UpdateHeight()

        ---------------------------------------------------------
        -- Section: Button Appearance
        ---------------------------------------------------------
        local appearanceSection, appearanceContent, y = CreateCollapsibleSection(tabContent, "Button Appearance", y, PAD, false, generalSection)
        local appearanceY = 0

        local zoomSlider = GUI:CreateFormSlider(appearanceContent, "Icon Crop Amount",
            0.05, 0.15, 0.01, "iconZoom", global, RefreshActionBars)
        zoomSlider:SetPoint("TOPLEFT", PAD, appearanceY)
        zoomSlider:SetPoint("RIGHT", appearanceContent, "RIGHT", -PAD, 0)
        appearanceY = appearanceY - FORM_ROW

        local backdropCheck = GUI:CreateFormCheckbox(appearanceContent, "Show Backdrop",
            "showBackdrop", global, RefreshActionBars)
        backdropCheck:SetPoint("TOPLEFT", PAD, appearanceY)
        backdropCheck:SetPoint("RIGHT", appearanceContent, "RIGHT", -PAD, 0)
        appearanceY = appearanceY - FORM_ROW

        local backdropAlphaSlider = GUI:CreateFormSlider(appearanceContent, "Backdrop Opacity",
            0, 1, 0.05, "backdropAlpha", global, RefreshActionBars)
        backdropAlphaSlider:SetPoint("TOPLEFT", PAD, appearanceY)
        backdropAlphaSlider:SetPoint("RIGHT", appearanceContent, "RIGHT", -PAD, 0)
        appearanceY = appearanceY - FORM_ROW

        local glossCheck = GUI:CreateFormCheckbox(appearanceContent, "Show Gloss Effect",
            "showGloss", global, RefreshActionBars)
        glossCheck:SetPoint("TOPLEFT", PAD, appearanceY)
        glossCheck:SetPoint("RIGHT", appearanceContent, "RIGHT", -PAD, 0)
        appearanceY = appearanceY - FORM_ROW

        local glossAlphaSlider = GUI:CreateFormSlider(appearanceContent, "Gloss Opacity",
            0, 1, 0.05, "glossAlpha", global, RefreshActionBars)
        glossAlphaSlider:SetPoint("TOPLEFT", PAD, appearanceY)
        glossAlphaSlider:SetPoint("RIGHT", appearanceContent, "RIGHT", -PAD, 0)
        appearanceY = appearanceY - FORM_ROW

        -- Button Padding (moved from Bar Layout)
        local buttonPaddingSlider = GUI:CreateFormSlider(appearanceContent, "Button Padding", -50, 20, 1,
            "buttonPadding", global, function()
                if _G.QuaziiUI_ApplyPaddingToActionBars then
                    _G.QuaziiUI_ApplyPaddingToActionBars()
                end
            end)
        buttonPaddingSlider:SetPoint("TOPLEFT", PAD, appearanceY)
        buttonPaddingSlider:SetPoint("RIGHT", appearanceContent, "RIGHT", -PAD, 0)
        appearanceY = appearanceY - FORM_ROW

        local paddingDesc = GUI:CreateLabel(appearanceContent, "Adjust button spacing. Minimum padding is hardcoded to -50 to allow overlap. Negative values allow buttons to overlap.", 11, C.textMuted)
        paddingDesc:SetPoint("TOPLEFT", PAD, appearanceY + 4)
        paddingDesc:SetPoint("RIGHT", appearanceContent, "RIGHT", -PAD, 0)
        paddingDesc:SetJustifyH("LEFT")
        paddingDesc:SetWordWrap(true)
        appearanceY = appearanceY - 40

        appearanceContent:SetHeight(math.abs(appearanceY) + 4)
        appearanceSection:UpdateHeight()

        ---------------------------------------------------------
        -- Section: Bar Layout
        ---------------------------------------------------------
        local layoutSection, layoutContent, y = CreateCollapsibleSection(tabContent, "Bar Layout", y, PAD, false, appearanceSection)
        local layoutY = 0

        local scaleWarning = GUI:CreateLabel(layoutContent, "To scale Action Bars, use Edit Mode: select each bar and adjust the 'Icon Size' slider. Enable 'Snap To Element' for easy alignment.", 11, C.warning)
        scaleWarning:SetPoint("TOPLEFT", PAD, layoutY)
        scaleWarning:SetPoint("RIGHT", layoutContent, "RIGHT", -PAD, 0)
        scaleWarning:SetJustifyH("LEFT")
        scaleWarning:SetWordWrap(true)
        scaleWarning:SetHeight(30)
        layoutY = layoutY - 32

        local hideEmptySlotsCheck = GUI:CreateFormCheckbox(layoutContent, "Hide Empty Slots",
            "hideEmptySlots", global, RefreshActionBars)
        hideEmptySlotsCheck:SetPoint("TOPLEFT", PAD, layoutY)
        hideEmptySlotsCheck:SetPoint("RIGHT", layoutContent, "RIGHT", -PAD, 0)
        layoutY = layoutY - FORM_ROW

        -- Action Button Lock - combined lock + override key in one clear dropdown
        local lockOptions = {
            {value = "unlocked", text = "Unlocked"},
            {value = "shift", text = "Locked - Shift to drag"},
            {value = "alt", text = "Locked - Alt to drag"},
            {value = "ctrl", text = "Locked - Ctrl to drag"},
            {value = "none", text = "Fully Locked"},
        }
        -- Proxy that reads/writes to Blizzard's CVars
        local lockProxy = setmetatable({}, {
            __index = function(t, k)
                if k == "buttonLock" then
                    local isLocked = GetCVar("lockActionBars") == "1"
                    if not isLocked then return "unlocked" end
                    local modifier = GetModifiedClick("PICKUPACTION") or "SHIFT"
                    if modifier == "NONE" then return "none" end
                    return modifier:lower()
                end
            end,
            __newindex = function(t, k, v)
                if k == "buttonLock" and type(v) == "string" then
                    if v == "unlocked" then
                        SetCVar("lockActionBars", "0")
                    else
                        SetCVar("lockActionBars", "1")
                        local modifier = (v == "none") and "NONE" or v:upper()
                        SetModifiedClick("PICKUPACTION", modifier)
                        SaveBindings(GetCurrentBindingSet())
                    end
                end
            end
        })
        local lockDropdown = GUI:CreateFormDropdown(layoutContent, "Action Button Lock", lockOptions,
            "buttonLock", lockProxy, RefreshActionBars)
        lockDropdown:SetPoint("TOPLEFT", PAD, layoutY)
        lockDropdown:SetPoint("RIGHT", layoutContent, "RIGHT", -PAD, 0)
        -- Refresh from Blizzard settings on show
        lockDropdown:HookScript("OnShow", function(self)
            self:SetValue(lockProxy.buttonLock, true)
        end)
        layoutY = layoutY - FORM_ROW

        local rangeCheck = GUI:CreateFormCheckbox(layoutContent, "Out of Range Indicator",
            "rangeIndicator", global, RefreshActionBars)
        rangeCheck:SetPoint("TOPLEFT", PAD, layoutY)
        rangeCheck:SetPoint("RIGHT", layoutContent, "RIGHT", -PAD, 0)
        layoutY = layoutY - FORM_ROW

        local rangeColorPicker = GUI:CreateFormColorPicker(layoutContent, "Out of Range Color",
            "rangeColor", global, RefreshActionBars)
        rangeColorPicker:SetPoint("TOPLEFT", PAD, layoutY)
        rangeColorPicker:SetPoint("RIGHT", layoutContent, "RIGHT", -PAD, 0)
        layoutY = layoutY - FORM_ROW

        local usabilityCheck = GUI:CreateFormCheckbox(layoutContent, "Dim Unusable Buttons",
            "usabilityIndicator", global, RefreshActionBars)
        usabilityCheck:SetPoint("TOPLEFT", PAD, layoutY)
        usabilityCheck:SetPoint("RIGHT", layoutContent, "RIGHT", -PAD, 0)
        layoutY = layoutY - FORM_ROW

        local desaturateCheck = GUI:CreateFormCheckbox(layoutContent, "Desaturate Unusable",
            "usabilityDesaturate", global, RefreshActionBars)
        desaturateCheck:SetPoint("TOPLEFT", PAD, layoutY)
        desaturateCheck:SetPoint("RIGHT", layoutContent, "RIGHT", -PAD, 0)
        layoutY = layoutY - FORM_ROW

        local manaColorPicker = GUI:CreateFormColorPicker(layoutContent, "Out of Mana Color",
            "manaColor", global, RefreshActionBars)
        manaColorPicker:SetPoint("TOPLEFT", PAD, layoutY)
        manaColorPicker:SetPoint("RIGHT", layoutContent, "RIGHT", -PAD, 0)
        layoutY = layoutY - FORM_ROW

        local fastUpdates = GUI:CreateFormCheckbox(layoutContent, "Unthrottled CPU Usage",
            "fastUsabilityUpdates", global, RefreshActionBars)
        fastUpdates:SetPoint("TOPLEFT", PAD, layoutY)
        fastUpdates:SetPoint("RIGHT", layoutContent, "RIGHT", -PAD, 0)
        layoutY = layoutY - FORM_ROW

        local fastDesc = GUI:CreateLabel(layoutContent, "Updates range/mana/unusable states 5x faster. Only enable if using action bars as your primary rotation display. Enabling while bars are hidden wastes CPU.", 11, {1, 0.6, 0})
        fastDesc:SetPoint("TOPLEFT", PAD, layoutY + 4)
        layoutY = layoutY - 18

        local layoutTipText = GUI:CreateLabel(layoutContent, "Enable 'Out of Range', 'Unusable' and 'Out of Mana' ONLY if you use Action Bars to replace CDM. They eat CPU resources.", 11, {1, 0.6, 0})
        layoutTipText:SetPoint("TOPLEFT", PAD, layoutY)
        layoutTipText:SetPoint("RIGHT", layoutContent, "RIGHT", -PAD, 0)
        layoutTipText:SetJustifyH("LEFT")
        layoutTipText:SetWordWrap(true)
        layoutY = layoutY - 40

        layoutContent:SetHeight(math.abs(layoutY) + 4)
        layoutSection:UpdateHeight()

        ---------------------------------------------------------
        -- Section: Text Display
        ---------------------------------------------------------
        local textSection, textContent, y = CreateCollapsibleSection(tabContent, "Text Display", y, PAD, false, layoutSection)
        local textY = 0

        local keybindCheck = GUI:CreateFormCheckbox(textContent, "Show Keybind Text",
            "showKeybinds", global, RefreshActionBars)
        keybindCheck:SetPoint("TOPLEFT", PAD, textY)
        keybindCheck:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local hideEmptyCheck = GUI:CreateFormCheckbox(textContent, "Hide Empty Keybinds",
            "hideEmptyKeybinds", global, RefreshActionBars)
        hideEmptyCheck:SetPoint("TOPLEFT", PAD, textY)
        hideEmptyCheck:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local keybindSizeSlider = GUI:CreateFormSlider(textContent, "Keybind Text Size",
            8, 50, 1, "keybindFontSize", global, RefreshActionBars)
        keybindSizeSlider:SetPoint("TOPLEFT", PAD, textY)
        keybindSizeSlider:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local keybindAnchorDD = GUI:CreateFormDropdown(textContent, "Keybind Text Anchor",
            anchorOptions, "keybindAnchor", global, RefreshActionBars)
        keybindAnchorDD:SetPoint("TOPLEFT", PAD, textY)
        keybindAnchorDD:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local keybindXOffsetSlider = GUI:CreateFormSlider(textContent, "Keybind Text X-Offset",
            -20, 20, 1, "keybindOffsetX", global, RefreshActionBars)
        keybindXOffsetSlider:SetPoint("TOPLEFT", PAD, textY)
        keybindXOffsetSlider:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local keybindYOffsetSlider = GUI:CreateFormSlider(textContent, "Keybind Text Y-Offset",
            -20, 20, 1, "keybindOffsetY", global, RefreshActionBars)
        keybindYOffsetSlider:SetPoint("TOPLEFT", PAD, textY)
        keybindYOffsetSlider:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local keybindColorPicker = GUI:CreateFormColorPicker(textContent, "Keybind Text Color",
            "keybindColor", global, RefreshActionBars)
        keybindColorPicker:SetPoint("TOPLEFT", PAD, textY)
        keybindColorPicker:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local macroCheck = GUI:CreateFormCheckbox(textContent, "Show Macro Names",
            "showMacroNames", global, RefreshActionBars)
        macroCheck:SetPoint("TOPLEFT", PAD, textY)
        macroCheck:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local macroSizeSlider = GUI:CreateFormSlider(textContent, "Macro Name Text Size",
            8, 50, 1, "macroNameFontSize", global, RefreshActionBars)
        macroSizeSlider:SetPoint("TOPLEFT", PAD, textY)
        macroSizeSlider:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local macroAnchorDD = GUI:CreateFormDropdown(textContent, "Macro Name Anchor",
            anchorOptions, "macroNameAnchor", global, RefreshActionBars)
        macroAnchorDD:SetPoint("TOPLEFT", PAD, textY)
        macroAnchorDD:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local macroXOffsetSlider = GUI:CreateFormSlider(textContent, "Macro Name X-Offset",
            -20, 20, 1, "macroNameOffsetX", global, RefreshActionBars)
        macroXOffsetSlider:SetPoint("TOPLEFT", PAD, textY)
        macroXOffsetSlider:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local macroYOffsetSlider = GUI:CreateFormSlider(textContent, "Macro Name Y-Offset",
            -20, 20, 1, "macroNameOffsetY", global, RefreshActionBars)
        macroYOffsetSlider:SetPoint("TOPLEFT", PAD, textY)
        macroYOffsetSlider:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local macroColorPicker = GUI:CreateFormColorPicker(textContent, "Macro Name Color",
            "macroNameColor", global, RefreshActionBars)
        macroColorPicker:SetPoint("TOPLEFT", PAD, textY)
        macroColorPicker:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local countCheck = GUI:CreateFormCheckbox(textContent, "Show Stack Counts",
            "showCounts", global, RefreshActionBars)
        countCheck:SetPoint("TOPLEFT", PAD, textY)
        countCheck:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local countSizeSlider = GUI:CreateFormSlider(textContent, "Stack Text Size",
            8, 50, 1, "countFontSize", global, RefreshActionBars)
        countSizeSlider:SetPoint("TOPLEFT", PAD, textY)
        countSizeSlider:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local countAnchorDD = GUI:CreateFormDropdown(textContent, "Stack Text Anchor",
            anchorOptions, "countAnchor", global, RefreshActionBars)
        countAnchorDD:SetPoint("TOPLEFT", PAD, textY)
        countAnchorDD:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local countXOffsetSlider = GUI:CreateFormSlider(textContent, "Stack Text X-Offset",
            -20, 20, 1, "countOffsetX", global, RefreshActionBars)
        countXOffsetSlider:SetPoint("TOPLEFT", PAD, textY)
        countXOffsetSlider:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local countYOffsetSlider = GUI:CreateFormSlider(textContent, "Stack Text Y-Offset",
            -20, 20, 1, "countOffsetY", global, RefreshActionBars)
        countYOffsetSlider:SetPoint("TOPLEFT", PAD, textY)
        countYOffsetSlider:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        local countColorPicker = GUI:CreateFormColorPicker(textContent, "Stack Count Color",
            "countColor", global, RefreshActionBars)
        countColorPicker:SetPoint("TOPLEFT", PAD, textY)
        countColorPicker:SetPoint("RIGHT", textContent, "RIGHT", -PAD, 0)
        textY = textY - FORM_ROW

        textContent:SetHeight(math.abs(textY) + 4)
        textSection:UpdateHeight()

        tabContent:SetHeight(math.abs(y) + 50)
    end  -- End BuildMasterSettingsTab

    ---------------------------------------------------------
    -- SUB-TAB: Per-Bar Overrides (Accordion Style)
    ---------------------------------------------------------
    local function BuildPerBarOverridesTab(tabContent)
        -- Set search context for widget auto-registration
        GUI:SetSearchContext({tabIndex = 4, tabName = "Action Bars", subTabIndex = 3, subTabName = "Per-Bar Overrides"})

        -- Use tabContent directly - parent Action Bars page already has scroll
        local content = tabContent
        local PAD = PADDING
        local FORM_ROW = 32
        local SECTION_GAP = 4

        -- 9-point anchor options for text positioning
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

        -- Bar info for accordion sections
        local barInfo = {
            {key = "bar1", label = "Action Bar 1"},
            {key = "bar2", label = "Action Bar 2"},
            {key = "bar3", label = "Action Bar 3"},
            {key = "bar4", label = "Action Bar 4"},
            {key = "bar5", label = "Action Bar 5"},
            {key = "bar6", label = "Action Bar 6"},
            {key = "bar7", label = "Action Bar 7"},
            {key = "bar8", label = "Action Bar 8"},
            {key = "pet", label = "Pet Bar"},
            {key = "stance", label = "Stance Bar"},
        }

        -- Track sections for accordion behavior
        local sections = {}

        -- Keys to copy when using Copy From
        local copyKeys = {
            "iconZoom", "showBackdrop", "backdropAlpha", "showGloss", "glossAlpha", "buttonPadding",
            "showKeybinds", "hideEmptyKeybinds", "keybindFontSize", "keybindColor",
            "keybindAnchor", "keybindOffsetX", "keybindOffsetY",
            "showMacroNames", "macroNameFontSize", "macroNameColor",
            "macroNameAnchor", "macroNameOffsetX", "macroNameOffsetY",
            "showCounts", "countFontSize", "countColor",
            "countAnchor", "countOffsetX", "countOffsetY",
        }

        -- Helper to update scroll content height
        local function UpdateScrollHeight()
            local totalHeight = 15
            for _, section in ipairs(sections) do
                totalHeight = totalHeight + section:GetHeight() + SECTION_GAP
            end
            content:SetHeight(totalHeight + 15)
        end

        -- Function to build settings into a container
        local function BuildBarSettingsIntoContainer(barKey, container, onOverrideChanged)
            local barDB = bars[barKey]
            if not barDB then return end

            local sy = -8  -- Start with small padding inside content area
            local widgetRefs = {}

            -- Create a non-collapsible wrapper section for the initial controls
            local controlsSection, controlsContent, sy = CreateCollapsibleSection(container, "", sy, 0, true, nil, { hideHeader = true, nonCollapsible = true })
            local controlsY = 0

            -- Hide Page Arrow toggle (bar1 only)
            if barKey == "bar1" then
                local pageArrowToggle = GUI:CreateFormCheckbox(controlsContent,
                    "Hide Default Paging Arrow", "hidePageArrow", barDB,
                    function(val)
                        if _G.QuaziiUI_ApplyPageArrowVisibility then
                            _G.QuaziiUI_ApplyPageArrowVisibility(val)
                        end
                    end)
                pageArrowToggle:SetPoint("TOPLEFT", 0, controlsY)
                pageArrowToggle:SetPoint("RIGHT", controlsContent, "RIGHT", 0, 0)
                controlsY = controlsY - FORM_ROW
            end

            -- Row 1: Override Master Settings toggle
            local overrideToggle = GUI:CreateFormCheckbox(controlsContent,
                "Override Master Settings", "overrideEnabled", barDB,
                function(val)
                    for _, widget in pairs(widgetRefs) do
                        widget:SetEnabled(val)
                    end
                    if onOverrideChanged then
                        onOverrideChanged()
                    end
                    RefreshActionBars()
                end)
            overrideToggle:SetPoint("TOPLEFT", 0, controlsY)
            overrideToggle:SetPoint("RIGHT", controlsContent, "RIGHT", 0, 0)
            controlsY = controlsY - FORM_ROW

            -- Row 2: Copy From dropdown
            local copyOptions = {
                {value = "master", text = "Master Settings"},
                {value = "bar1", text = "Bar 1"},
                {value = "bar2", text = "Bar 2"},
                {value = "bar3", text = "Bar 3"},
                {value = "bar4", text = "Bar 4"},
                {value = "bar5", text = "Bar 5"},
                {value = "bar6", text = "Bar 6"},
                {value = "bar7", text = "Bar 7"},
                {value = "bar8", text = "Bar 8"},
                {value = "pet", text = "Pet Bar"},
                {value = "stance", text = "Stance Bar"},
            }

            -- Create a wrapper table to hold the selected value, defaulting to nil (empty)
            local copyWrapper = { selected = nil }
            
            local copyDropdown = GUI:CreateFormDropdown(controlsContent, "Copy from", copyOptions, "selected", copyWrapper,
                function(sourceKey)
                    if not sourceKey or sourceKey == barKey then return end

                    local sourceDB
                    if sourceKey == "master" then
                        sourceDB = global
                    else
                        sourceDB = bars[sourceKey]
                    end

                    if not sourceDB then return end

                    for _, key in ipairs(copyKeys) do
                        if sourceDB[key] ~= nil then
                            -- For color tables, create a copy instead of reference
                            if key == "keybindColor" or key == "macroNameColor" or key == "countColor" then
                                local sourceColor = sourceDB[key]
                                if type(sourceColor) == "table" and sourceColor[1] and sourceColor[2] and sourceColor[3] then
                                    barDB[key] = {sourceColor[1], sourceColor[2], sourceColor[3], sourceColor[4] or 1}
                                else
                                    -- Invalid color, use default
                                    barDB[key] = {1, 1, 1, 1}
                                end
                            else
                                barDB[key] = sourceDB[key]
                            end
                        end
                    end

                    barDB.overrideEnabled = true

                    -- Rebuild this section's content
                    for _, child in pairs({container:GetChildren()}) do
                        child:Hide()
                        child:SetParent(nil)
                    end
                    BuildBarSettingsIntoContainer(barKey, container, onOverrideChanged)

                    if onOverrideChanged then
                        onOverrideChanged()
                    end
                    RefreshActionBars()
                end)
            copyDropdown:SetPoint("TOPLEFT", 0, controlsY)
            copyDropdown:SetPoint("RIGHT", controlsContent, "RIGHT", 0, 0)
            controlsY = controlsY - FORM_ROW

            -- Update controls section height
            controlsContent:SetHeight(math.abs(controlsY) + 4)
            controlsSection:UpdateHeight()

            -- Appearance Section - use CreateCollapsibleSection which auto-detects nesting
            -- Chain to controls section
            local appSection, appContent, sy = CreateCollapsibleSection(container, "Appearance", 0, 0, false, controlsSection)
            local appY = 0

            local zoomSlider = GUI:CreateFormSlider(appContent, "Icon Crop",
                0.05, 0.15, 0.01, "iconZoom", barDB, RefreshActionBars)
            zoomSlider:SetPoint("TOPLEFT", 0, appY)
            zoomSlider:SetPoint("RIGHT", appContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, zoomSlider)
            appY = appY - FORM_ROW

            local backdropCheck = GUI:CreateFormCheckbox(appContent, "Show Backdrop",
                "showBackdrop", barDB, RefreshActionBars)
            backdropCheck:SetPoint("TOPLEFT", 0, appY)
            backdropCheck:SetPoint("RIGHT", appContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, backdropCheck)
            appY = appY - FORM_ROW

            local backdropAlphaSlider = GUI:CreateFormSlider(appContent, "Backdrop Opacity",
                0, 1, 0.05, "backdropAlpha", barDB, RefreshActionBars)
            backdropAlphaSlider:SetPoint("TOPLEFT", 0, appY)
            backdropAlphaSlider:SetPoint("RIGHT", appContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, backdropAlphaSlider)
            appY = appY - FORM_ROW

            local glossCheck = GUI:CreateFormCheckbox(appContent, "Show Gloss",
                "showGloss", barDB, RefreshActionBars)
            glossCheck:SetPoint("TOPLEFT", 0, appY)
            glossCheck:SetPoint("RIGHT", appContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, glossCheck)
            appY = appY - FORM_ROW

            local glossAlphaSlider = GUI:CreateFormSlider(appContent, "Gloss Opacity",
                0, 1, 0.05, "glossAlpha", barDB, RefreshActionBars)
            glossAlphaSlider:SetPoint("TOPLEFT", 0, appY)
            glossAlphaSlider:SetPoint("RIGHT", appContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, glossAlphaSlider)
            appY = appY - FORM_ROW

            -- Button Padding
            local buttonPaddingSlider = GUI:CreateFormSlider(appContent, "Button Padding", -50, 20, 1,
                "buttonPadding", barDB, function()
                    if _G.QuaziiUI_ApplyPaddingToActionBars then
                        _G.QuaziiUI_ApplyPaddingToActionBars()
                    end
                end)
            buttonPaddingSlider:SetPoint("TOPLEFT", 0, appY)
            buttonPaddingSlider:SetPoint("RIGHT", appContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, buttonPaddingSlider)
            appY = appY - FORM_ROW

            appContent:SetHeight(math.abs(appY) + 4)
            appSection:UpdateHeight()

            -- Keybind Section - chain to previous nested section
            local keySection, keyContent, sy = CreateCollapsibleSection(container, "Keybind Text", 0, 0, false, appSection)
            local keyY = 0

            local keybindCheck = GUI:CreateFormCheckbox(keyContent, "Show Keybinds",
                "showKeybinds", barDB, RefreshActionBars)
            keybindCheck:SetPoint("TOPLEFT", 0, keyY)
            keybindCheck:SetPoint("RIGHT", keyContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, keybindCheck)
            keyY = keyY - FORM_ROW

            local hideEmptyCheck = GUI:CreateFormCheckbox(keyContent, "Hide Empty Keybinds",
                "hideEmptyKeybinds", barDB, RefreshActionBars)
            hideEmptyCheck:SetPoint("TOPLEFT", 0, keyY)
            hideEmptyCheck:SetPoint("RIGHT", keyContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, hideEmptyCheck)
            keyY = keyY - FORM_ROW

            local keybindSizeSlider = GUI:CreateFormSlider(keyContent, "Font Size",
                8, 18, 1, "keybindFontSize", barDB, RefreshActionBars)
            keybindSizeSlider:SetPoint("TOPLEFT", 0, keyY)
            keybindSizeSlider:SetPoint("RIGHT", keyContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, keybindSizeSlider)
            keyY = keyY - FORM_ROW

            local keybindAnchorDD = GUI:CreateFormDropdown(keyContent, "Anchor",
                anchorOptions, "keybindAnchor", barDB, RefreshActionBars)
            keybindAnchorDD:SetPoint("TOPLEFT", 0, keyY)
            keybindAnchorDD:SetPoint("RIGHT", keyContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, keybindAnchorDD)
            keyY = keyY - FORM_ROW

            local keybindXOffsetSlider = GUI:CreateFormSlider(keyContent, "X-Offset",
                -20, 20, 1, "keybindOffsetX", barDB, RefreshActionBars)
            keybindXOffsetSlider:SetPoint("TOPLEFT", 0, keyY)
            keybindXOffsetSlider:SetPoint("RIGHT", keyContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, keybindXOffsetSlider)
            keyY = keyY - FORM_ROW

            local keybindYOffsetSlider = GUI:CreateFormSlider(keyContent, "Y-Offset",
                -20, 20, 1, "keybindOffsetY", barDB, RefreshActionBars)
            keybindYOffsetSlider:SetPoint("TOPLEFT", 0, keyY)
            keybindYOffsetSlider:SetPoint("RIGHT", keyContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, keybindYOffsetSlider)
            keyY = keyY - FORM_ROW

            local keybindColorPicker = GUI:CreateFormColorPicker(keyContent, "Color",
                "keybindColor", barDB, RefreshActionBars)
            keybindColorPicker:SetPoint("TOPLEFT", 0, keyY)
            keybindColorPicker:SetPoint("RIGHT", keyContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, keybindColorPicker)
            keyY = keyY - FORM_ROW

            keyContent:SetHeight(math.abs(keyY) + 4)
            keySection:UpdateHeight()

            -- Macro Section - chain to previous nested section
            local macroSection, macroContent, sy = CreateCollapsibleSection(container, "Macro Text", 0, 0, false, keySection)
            local macroY = 0

            local macroCheck = GUI:CreateFormCheckbox(macroContent, "Show Macro Names",
                "showMacroNames", barDB, RefreshActionBars)
            macroCheck:SetPoint("TOPLEFT", 0, macroY)
            macroCheck:SetPoint("RIGHT", macroContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, macroCheck)
            macroY = macroY - FORM_ROW

            local macroSizeSlider = GUI:CreateFormSlider(macroContent, "Font Size",
                8, 18, 1, "macroNameFontSize", barDB, RefreshActionBars)
            macroSizeSlider:SetPoint("TOPLEFT", 0, macroY)
            macroSizeSlider:SetPoint("RIGHT", macroContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, macroSizeSlider)
            macroY = macroY - FORM_ROW

            local macroAnchorDD = GUI:CreateFormDropdown(macroContent, "Anchor",
                anchorOptions, "macroNameAnchor", barDB, RefreshActionBars)
            macroAnchorDD:SetPoint("TOPLEFT", 0, macroY)
            macroAnchorDD:SetPoint("RIGHT", macroContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, macroAnchorDD)
            macroY = macroY - FORM_ROW

            local macroXOffsetSlider = GUI:CreateFormSlider(macroContent, "X-Offset",
                -20, 20, 1, "macroNameOffsetX", barDB, RefreshActionBars)
            macroXOffsetSlider:SetPoint("TOPLEFT", 0, macroY)
            macroXOffsetSlider:SetPoint("RIGHT", macroContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, macroXOffsetSlider)
            macroY = macroY - FORM_ROW

            local macroYOffsetSlider = GUI:CreateFormSlider(macroContent, "Y-Offset",
                -20, 20, 1, "macroNameOffsetY", barDB, RefreshActionBars)
            macroYOffsetSlider:SetPoint("TOPLEFT", 0, macroY)
            macroYOffsetSlider:SetPoint("RIGHT", macroContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, macroYOffsetSlider)
            macroY = macroY - FORM_ROW

            local macroColorPicker = GUI:CreateFormColorPicker(macroContent, "Color",
                "macroNameColor", barDB, RefreshActionBars)
            macroColorPicker:SetPoint("TOPLEFT", 0, macroY)
            macroColorPicker:SetPoint("RIGHT", macroContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, macroColorPicker)
            macroY = macroY - FORM_ROW

            macroContent:SetHeight(math.abs(macroY) + 4)
            macroSection:UpdateHeight()

            -- Count Section - chain to previous nested section
            local countSection, countContent, sy = CreateCollapsibleSection(container, "Stack Count", 0, 0, false, macroSection)
            local countY = 0

            local countCheck = GUI:CreateFormCheckbox(countContent, "Show Counts",
                "showCounts", barDB, RefreshActionBars)
            countCheck:SetPoint("TOPLEFT", 0, countY)
            countCheck:SetPoint("RIGHT", countContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, countCheck)
            countY = countY - FORM_ROW

            local countSizeSlider = GUI:CreateFormSlider(countContent, "Font Size",
                8, 20, 1, "countFontSize", barDB, RefreshActionBars)
            countSizeSlider:SetPoint("TOPLEFT", 0, countY)
            countSizeSlider:SetPoint("RIGHT", countContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, countSizeSlider)
            countY = countY - FORM_ROW

            local countAnchorDD = GUI:CreateFormDropdown(countContent, "Anchor",
                anchorOptions, "countAnchor", barDB, RefreshActionBars)
            countAnchorDD:SetPoint("TOPLEFT", 0, countY)
            countAnchorDD:SetPoint("RIGHT", countContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, countAnchorDD)
            countY = countY - FORM_ROW

            local countXOffsetSlider = GUI:CreateFormSlider(countContent, "X-Offset",
                -20, 20, 1, "countOffsetX", barDB, RefreshActionBars)
            countXOffsetSlider:SetPoint("TOPLEFT", 0, countY)
            countXOffsetSlider:SetPoint("RIGHT", countContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, countXOffsetSlider)
            countY = countY - FORM_ROW

            local countYOffsetSlider = GUI:CreateFormSlider(countContent, "Y-Offset",
                -20, 20, 1, "countOffsetY", barDB, RefreshActionBars)
            countYOffsetSlider:SetPoint("TOPLEFT", 0, countY)
            countYOffsetSlider:SetPoint("RIGHT", countContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, countYOffsetSlider)
            countY = countY - FORM_ROW

            local countColorPicker = GUI:CreateFormColorPicker(countContent, "Color",
                "countColor", barDB, RefreshActionBars)
            countColorPicker:SetPoint("TOPLEFT", 0, countY)
            countColorPicker:SetPoint("RIGHT", countContent, "RIGHT", 0, 0)
            table.insert(widgetRefs, countColorPicker)
            countY = countY - FORM_ROW

            countContent:SetHeight(math.abs(countY) + 4)
            countSection:UpdateHeight()

            -- Initialize enabled state
            for _, widget in pairs(widgetRefs) do
                widget:SetEnabled(barDB.overrideEnabled or false)
            end

            -- Container height will be automatically calculated by the parent section
            -- based on nested sections' heights

            -- Update parent section height
            local section = container:GetParent()
            if section and section.UpdateHeight then
                section:UpdateHeight()
            end
        end

        -- Edit Mode tip
        local warningText = GUI:CreateLabel(content, "To modify the number of icons, growth direction, or scale of each Action Bar, use Edit Mode and click on the bar you want to configure.", 11, C.warning)
        warningText:SetPoint("TOPLEFT", PAD, -15)
        warningText:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
        warningText:SetJustifyH("LEFT")
        warningText:SetWordWrap(true)
        warningText:SetHeight(30)

        -- Create 8 accordion sections with relative anchoring
        -- Each section anchors to the previous section's bottom for dynamic repositioning
        local prevSection = nil
        for i, info in ipairs(barInfo) do
            local section = GUI:CreateCollapsibleSection(
                content,
                info.label,
                i == 1,  -- First section expanded by default
                {
                    text = "Override",
                    showFunc = function()
                        return bars[info.key] and bars[info.key].overrideEnabled
                    end
                }
            )

            -- Relative anchoring: each section anchors to the previous one's bottom
            if i == 1 then
                section:SetPoint("TOPLEFT", warningText, "BOTTOMLEFT", 0, -12)
            else
                section:SetPoint("TOPLEFT", prevSection, "BOTTOMLEFT", 0, -SECTION_GAP)
            end
            section:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)

            -- Build settings into this section's content
            BuildBarSettingsIntoContainer(info.key, section.content, function()
                section:UpdateBadge()
                section:UpdateHeight()
                UpdateScrollHeight()
            end)

            -- Accordion behavior: collapse others when this expands
            section.OnExpandChanged = function(isExpanded)
                if isExpanded then
                    for _, other in ipairs(sections) do
                        if other ~= section and other:GetExpanded() then
                            other:SetExpanded(false)
                        end
                    end
                end
                UpdateScrollHeight()
            end

            table.insert(sections, section)
            prevSection = section
        end

        -- Initial height calculation (delayed to ensure layout is complete)
        C_Timer.After(0.1, UpdateScrollHeight)
    end  -- End BuildPerBarOverridesTab

    ---------------------------------------------------------
    -- SUB-TAB: Extra Buttons (Extra Action Button & Zone Ability)
    ---------------------------------------------------------
    local function BuildExtraButtonsTab(tabContent)
        local y = -15
        local PAD = PADDING
        local FORM_ROW = 32

        -- Set search context
        GUI:SetSearchContext({tabIndex = 4, tabName = "Action Bars", subTabIndex = 4, subTabName = "Extra Buttons"})

        -- Refresh callback
        local function RefreshExtraButtons()
            if _G.QuaziiUI_RefreshExtraButtons then
                _G.QuaziiUI_RefreshExtraButtons()
            end
        end

        -- Description
        local descLabel = GUI:CreateLabel(tabContent,
            "Customize the Extra Action Button (boss encounters, quests) and Zone Ability Button (garrison, covenant, zone abilities) separately.",
            11, C.textMuted)
        descLabel:SetPoint("TOPLEFT", PAD, y)
        descLabel:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        descLabel:SetJustifyH("LEFT")
        descLabel:SetWordWrap(true)
        descLabel:SetHeight(30)
        y = y - 40

        -- Toggle Movers Button
        local moverBtn = GUI:CreateButton(tabContent, "Toggle Position Movers", 200, 28, function()
            if _G.QuaziiUI_ToggleExtraButtonMovers then
                _G.QuaziiUI_ToggleExtraButtonMovers()
            end
        end)
        moverBtn:SetPoint("TOPLEFT", PAD, y)
        y = y - 35

        local moverTip = GUI:CreateLabel(tabContent,
            "Click to show draggable movers. Drag to position, use sliders for fine-tuning.",
            10, C.textMuted)
        moverTip:SetPoint("TOPLEFT", PAD, y)
        moverTip:SetPoint("RIGHT", tabContent, "RIGHT", -PAD, 0)
        moverTip:SetJustifyH("LEFT")
        y = y - 25

        ---------------------------------------------------------
        -- SECTION: Extra Action Button
        ---------------------------------------------------------
        local extraSection, extraContent, y = CreateCollapsibleSection(tabContent, "Extra Action Button", y, PAD, false, nil)
        local extraY = 0

        local extraDB = bars.extraActionButton
        if extraDB then
            local enableCheck = GUI:CreateFormCheckbox(extraContent, "Enable Customization",
                "enabled", extraDB, RefreshExtraButtons)
            enableCheck:SetPoint("TOPLEFT", PAD, extraY)
            enableCheck:SetPoint("RIGHT", extraContent, "RIGHT", -PAD, 0)
            extraY = extraY - FORM_ROW

            local scaleSlider = GUI:CreateFormSlider(extraContent, "Scale",
                0.5, 2.0, 0.05, "scale", extraDB, RefreshExtraButtons)
            scaleSlider:SetPoint("TOPLEFT", PAD, extraY)
            scaleSlider:SetPoint("RIGHT", extraContent, "RIGHT", -PAD, 0)
            extraY = extraY - FORM_ROW

            local xOffsetSlider = GUI:CreateFormSlider(extraContent, "X Offset",
                -200, 200, 1, "offsetX", extraDB, RefreshExtraButtons)
            xOffsetSlider:SetPoint("TOPLEFT", PAD, extraY)
            xOffsetSlider:SetPoint("RIGHT", extraContent, "RIGHT", -PAD, 0)
            extraY = extraY - FORM_ROW

            local yOffsetSlider = GUI:CreateFormSlider(extraContent, "Y Offset",
                -200, 200, 1, "offsetY", extraDB, RefreshExtraButtons)
            yOffsetSlider:SetPoint("TOPLEFT", PAD, extraY)
            yOffsetSlider:SetPoint("RIGHT", extraContent, "RIGHT", -PAD, 0)
            extraY = extraY - FORM_ROW

            local hideArtCheck = GUI:CreateFormCheckbox(extraContent, "Hide Button Artwork",
                "hideArtwork", extraDB, RefreshExtraButtons)
            hideArtCheck:SetPoint("TOPLEFT", PAD, extraY)
            hideArtCheck:SetPoint("RIGHT", extraContent, "RIGHT", -PAD, 0)
            extraY = extraY - FORM_ROW

            local fadeCheck = GUI:CreateFormCheckbox(extraContent, "Enable Mouseover Fade",
                "fadeEnabled", extraDB, function()
                    RefreshExtraButtons()
                    if extraDB.fadeEnabled then
                        GUI:ShowConfirmation({
                            title = "Reload UI?",
                            message = "Mouseover fade requires a reload to take effect.",
                            acceptText = "Reload",
                            cancelText = "Later",
                            onAccept = function() QuaziiUI:SafeReload() end,
                        })
                    end
                end)
            fadeCheck:SetPoint("TOPLEFT", PAD, extraY)
            fadeCheck:SetPoint("RIGHT", extraContent, "RIGHT", -PAD, 0)
            extraY = extraY - FORM_ROW
        end

        extraContent:SetHeight(math.abs(extraY) + 4)
        extraSection:UpdateHeight()

        ---------------------------------------------------------
        -- SECTION: Zone Ability Button
        ---------------------------------------------------------
        local zoneSection, zoneContent, y = CreateCollapsibleSection(tabContent, "Zone Ability Button", y, PAD, false, extraSection)
        local zoneY = 0

        local zoneDB = bars.zoneAbility
        if zoneDB then
            local enableCheck = GUI:CreateFormCheckbox(zoneContent, "Enable Customization",
                "enabled", zoneDB, RefreshExtraButtons)
            enableCheck:SetPoint("TOPLEFT", PAD, zoneY)
            enableCheck:SetPoint("RIGHT", zoneContent, "RIGHT", -PAD, 0)
            zoneY = zoneY - FORM_ROW

            local scaleSlider = GUI:CreateFormSlider(zoneContent, "Scale",
                0.5, 2.0, 0.05, "scale", zoneDB, RefreshExtraButtons)
            scaleSlider:SetPoint("TOPLEFT", PAD, zoneY)
            scaleSlider:SetPoint("RIGHT", zoneContent, "RIGHT", -PAD, 0)
            zoneY = zoneY - FORM_ROW

            local xOffsetSlider = GUI:CreateFormSlider(zoneContent, "X Offset",
                -200, 200, 1, "offsetX", zoneDB, RefreshExtraButtons)
            xOffsetSlider:SetPoint("TOPLEFT", PAD, zoneY)
            xOffsetSlider:SetPoint("RIGHT", zoneContent, "RIGHT", -PAD, 0)
            zoneY = zoneY - FORM_ROW

            local yOffsetSlider = GUI:CreateFormSlider(zoneContent, "Y Offset",
                -200, 200, 1, "offsetY", zoneDB, RefreshExtraButtons)
            yOffsetSlider:SetPoint("TOPLEFT", PAD, zoneY)
            yOffsetSlider:SetPoint("RIGHT", zoneContent, "RIGHT", -PAD, 0)
            zoneY = zoneY - FORM_ROW

            local hideArtCheck = GUI:CreateFormCheckbox(zoneContent, "Hide Button Artwork",
                "hideArtwork", zoneDB, RefreshExtraButtons)
            hideArtCheck:SetPoint("TOPLEFT", PAD, zoneY)
            hideArtCheck:SetPoint("RIGHT", zoneContent, "RIGHT", -PAD, 0)
            zoneY = zoneY - FORM_ROW

            local fadeCheck = GUI:CreateFormCheckbox(zoneContent, "Enable Mouseover Fade",
                "fadeEnabled", zoneDB, function()
                    RefreshExtraButtons()
                    if zoneDB.fadeEnabled then
                        GUI:ShowConfirmation({
                            title = "Reload UI?",
                            message = "Mouseover fade requires a reload to take effect.",
                            acceptText = "Reload",
                            cancelText = "Later",
                            onAccept = function() QuaziiUI:SafeReload() end,
                        })
                    end
                end)
            fadeCheck:SetPoint("TOPLEFT", PAD, zoneY)
            fadeCheck:SetPoint("RIGHT", zoneContent, "RIGHT", -PAD, 0)
            zoneY = zoneY - FORM_ROW
        end

        zoneContent:SetHeight(math.abs(zoneY) + 4)
        zoneSection:UpdateHeight()

        tabContent:SetHeight(math.abs(y) + 50)
    end  -- End BuildExtraButtonsTab

    ---------------------------------------------------------
    -- Create Sub-Tabs
    ---------------------------------------------------------
    local subTabs = GUI:CreateSubTabs(content, {
        {name = "Master Settings", builder = BuildMasterSettingsTab},
        {name = "Mouseover Hide", builder = BuildMouseoverHideTab},
        {name = "Per-Bar Overrides", builder = BuildPerBarOverridesTab},
        {name = "Extra Buttons", builder = BuildExtraButtonsTab},
    })
    subTabs:SetPoint("TOPLEFT", 5, -5)
    subTabs:SetPoint("TOPRIGHT", -5, -5)
    subTabs:SetHeight(700)

    content:SetHeight(750)
    return scroll, content
end

---------------------------------------------------------------------------


-- Export the function
ns.ActionBarsOptions = { CreateActionBarsPage = CreateActionBarsPage }

-- Register with Options Page Registry
if ns.OptionsPageRegistry then
    ns.OptionsPageRegistry:RegisterSimplePage("actionbars", "Action Bars", CreateActionBarsPage, 40)
end

return ns.ActionBarsOptions
