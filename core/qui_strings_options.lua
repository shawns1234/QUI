--[[
    qui_strings_options.lua
    Options UI for Quazii Strings component
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
local CreateScrollableTextBox = OptionsShared.CreateScrollableTextBox
local PADDING = OptionsShared.CONSTANTS.PADDING

local function CreateQuaziiStringsPage(parent)
    local scroll, content = CreateScrollableContent(parent)
    local y = -15
    local PAD = PADDING
    local BOX_HEIGHT = 70

    local info = GUI:CreateLabel(content, "Quazii's personal import strings - select all and copy", 11, C.textMuted)
    info:SetPoint("TOPLEFT", PAD, y)
    info:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
    info:SetJustifyH("LEFT")
    y = y - 28
    
    -- Store all text boxes for clearing selections
    local allTextBoxes = {}
    
    -- Helper to clear all selections except the target
    local function selectOnly(targetEditBox)
        for _, editBox in ipairs(allTextBoxes) do
            if editBox ~= targetEditBox then
                editBox:ClearFocus()
                editBox:HighlightText(0, 0)  -- Clear highlight
            end
        end
        targetEditBox:SetFocus()
        targetEditBox:HighlightText()
    end
    
    -- =====================================================
    -- EDIT MODE STRING
    -- =====================================================
    local editModeHeader = GUI:CreateSectionHeader(content, "Quazii Edit Mode String")
    editModeHeader:SetPoint("TOPLEFT", PAD, y)
    y = y - editModeHeader.gap
    
    local editModeString = ""
    if _G.QuaziiUI and _G.QuaziiUI.imports and _G.QuaziiUI.imports.EditMode then
        editModeString = _G.QuaziiUI.imports.EditMode.data or ""
    end
    
    local editModeContainer = CreateScrollableTextBox(content, BOX_HEIGHT, editModeString)
    editModeContainer:SetPoint("TOPLEFT", PAD, y)
    editModeContainer:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
    table.insert(allTextBoxes, editModeContainer.editBox)
    
    y = y - BOX_HEIGHT - 8
    
    local editModeBtn = GUI:CreateButton(content, "SELECT ALL", 120, 24, function()
        selectOnly(editModeContainer.editBox)
    end)
    editModeBtn:SetPoint("TOPLEFT", PAD, y)
    
    local editModeTip = GUI:CreateLabel(content, "then press Ctrl+C to copy", 11, C.textMuted)
    editModeTip:SetPoint("LEFT", editModeBtn, "RIGHT", 10, 0)
    y = y - 40
    
    -- =====================================================
    -- QUI IMPORT/EXPORT STRING - DEFAULT PROFILE
    -- =====================================================
    local quiHeader = GUI:CreateSectionHeader(content, "QUI Import/Export String - Default Profile")
    quiHeader:SetPoint("TOPLEFT", PAD, y)
    y = y - quiHeader.gap
    
    local quiString = ""
    if _G.QuaziiUI and _G.QuaziiUI.imports and _G.QuaziiUI.imports.QUIProfile then
        quiString = _G.QuaziiUI.imports.QUIProfile.data or ""
    end
    
    local quiContainer = CreateScrollableTextBox(content, BOX_HEIGHT, quiString)
    quiContainer:SetPoint("TOPLEFT", PAD, y)
    quiContainer:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
    table.insert(allTextBoxes, quiContainer.editBox)
    
    y = y - BOX_HEIGHT - 8
    
    local quiBtn = GUI:CreateButton(content, "SELECT ALL", 120, 24, function()
        selectOnly(quiContainer.editBox)
    end)
    quiBtn:SetPoint("TOPLEFT", PAD, y)
    
    local quiTip = GUI:CreateLabel(content, "then press Ctrl+C to copy", 11, C.textMuted)
    quiTip:SetPoint("LEFT", quiBtn, "RIGHT", 10, 0)
    y = y - 40

    -- =====================================================
    -- QUI IMPORT/EXPORT STRING - DARK MODE
    -- =====================================================
    local quiDarkHeader = GUI:CreateSectionHeader(content, "QUI Import/Export String - Dark Mode")
    quiDarkHeader:SetPoint("TOPLEFT", PAD, y)
    y = y - quiDarkHeader.gap

    local quiDarkString = ""
    if _G.QuaziiUI and _G.QuaziiUI.imports and _G.QuaziiUI.imports.QUIProfileDarkMode then
        quiDarkString = _G.QuaziiUI.imports.QUIProfileDarkMode.data or ""
    end

    local quiDarkContainer = CreateScrollableTextBox(content, BOX_HEIGHT, quiDarkString)
    quiDarkContainer:SetPoint("TOPLEFT", PAD, y)
    quiDarkContainer:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
    table.insert(allTextBoxes, quiDarkContainer.editBox)

    y = y - BOX_HEIGHT - 8

    local quiDarkBtn = GUI:CreateButton(content, "SELECT ALL", 120, 24, function()
        selectOnly(quiDarkContainer.editBox)
    end)
    quiDarkBtn:SetPoint("TOPLEFT", PAD, y)

    local quiDarkTip = GUI:CreateLabel(content, "then press Ctrl+C to copy", 11, C.textMuted)
    quiDarkTip:SetPoint("LEFT", quiDarkBtn, "RIGHT", 10, 0)
    y = y - 40

    -- =====================================================
    -- PLATYNATOR STRING
    -- =====================================================
    local platHeader = GUI:CreateSectionHeader(content, "Platynator String")
    platHeader:SetPoint("TOPLEFT", PAD, y)
    y = y - platHeader.gap
    
    local platString = ""
    if _G.QuaziiUI and _G.QuaziiUI.imports and _G.QuaziiUI.imports.Platynator then
        platString = _G.QuaziiUI.imports.Platynator.data or ""
    end
    
    local platContainer = CreateScrollableTextBox(content, BOX_HEIGHT, platString)
    platContainer:SetPoint("TOPLEFT", PAD, y)
    platContainer:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
    table.insert(allTextBoxes, platContainer.editBox)
    
    y = y - BOX_HEIGHT - 8
    
    local platBtn = GUI:CreateButton(content, "SELECT ALL", 120, 24, function()
        selectOnly(platContainer.editBox)
    end)
    platBtn:SetPoint("TOPLEFT", PAD, y)
    
    local platTip = GUI:CreateLabel(content, "then press Ctrl+C to copy", 11, C.textMuted)
    platTip:SetPoint("LEFT", platBtn, "RIGHT", 10, 0)
    y = y - 30
    
    content:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- SEARCH TAB - Search settings across all tabs
---------------------------------------------------------------------------


-- Export the function
ns.QuaziiStringsOptions = { CreateQuaziiStringsPage = CreateQuaziiStringsPage }

-- Register with Options Page Registry
if ns.OptionsPageRegistry then
    ns.OptionsPageRegistry:RegisterSimplePage("quazii_strings", "Quazii's Strings", CreateQuaziiStringsPage, 100)
end
return ns.QuaziiStringsOptions
