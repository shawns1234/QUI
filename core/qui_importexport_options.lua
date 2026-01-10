--[[
    qui_importexport_options.lua
    Options UI for Import/Export Profile component
]]

local ADDON_NAME, ns = ...
local QUI = QuaziiUI
local GUI = QUI.GUI
local QUICore = ns.Addon
local C = GUI.Colors
local OptionsShared = ns.OptionsShared

-- Import shared utilities
local CreateScrollableContent = OptionsShared.CreateScrollableContent
local PADDING = OptionsShared.CONSTANTS.PADDING

local function CreateImportExportPage(parent)
    local scroll, content = CreateScrollableContent(parent)
    local y = -15
    local PAD = PADDING

    local info = GUI:CreateLabel(content, "Import and export QuaziiUI profiles", 11, C.textMuted)
    info:SetPoint("TOPLEFT", PAD, y)
    info:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
    info:SetJustifyH("LEFT")
    y = y - 28

    -- Export Section Header
    local exportHeader = GUI:CreateSectionHeader(content, "Export Current Profile")
    exportHeader:SetPoint("TOPLEFT", PAD, y)
    y = y - exportHeader.gap
    
    -- Create a scroll frame for the export box
    local exportScroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    exportScroll:SetPoint("TOPLEFT", PAD, y)
    exportScroll:SetPoint("TOPRIGHT", -PAD - 20, y)
    exportScroll:SetHeight(100)
    
    local exportEditBox = CreateFrame("EditBox", nil, exportScroll)
    exportEditBox:SetMultiLine(true)
    exportEditBox:SetAutoFocus(false)
    exportEditBox:SetFont(GUI.FONT_PATH, 11, "")
    exportEditBox:SetTextColor(0.8, 0.85, 0.9, 1)
    exportEditBox:SetWidth(exportScroll:GetWidth() - 10)
    exportEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    exportEditBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    exportScroll:SetScrollChild(exportEditBox)
    
    -- Background for export box
    local exportBg = content:CreateTexture(nil, "BACKGROUND")
    exportBg:SetPoint("TOPLEFT", exportScroll, -5, 5)
    exportBg:SetPoint("BOTTOMRIGHT", exportScroll, 25, -5)
    exportBg:SetColorTexture(0.05, 0.07, 0.1, 0.9)
    
    -- Border for export box
    local exportBorder = CreateFrame("Frame", nil, content, "BackdropTemplate")
    exportBorder:SetPoint("TOPLEFT", exportScroll, -6, 6)
    exportBorder:SetPoint("BOTTOMRIGHT", exportScroll, 26, -6)
    exportBorder:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    exportBorder:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    
    -- Populate export string
    local function RefreshExportString()
        local QUICore = _G.QuaziiUI and _G.QuaziiUI.QUICore
        if QUICore and QUICore.ExportProfileToString then
            local str = QUICore:ExportProfileToString()
            exportEditBox:SetText(str or "Error generating export string")
        else
            exportEditBox:SetText("QUICore not available")
        end
    end
    RefreshExportString()
    
    y = y - 115
    
    -- SELECT ALL button (themed)
    local selectBtn = GUI:CreateButton(content, "SELECT ALL", 120, 28, function()
        RefreshExportString()
        exportEditBox:SetFocus()
        exportEditBox:HighlightText()
    end)
    selectBtn:SetPoint("TOPLEFT", PAD, y)
    
    -- Hint text
    local copyHint = GUI:CreateLabel(content, "then press Ctrl+C to copy", 11, C.textMuted)
    copyHint:SetPoint("LEFT", selectBtn, "RIGHT", 12, 0)
    
    y = y - 50
    
    -- Import Section Header
    local importHeader = GUI:CreateSectionHeader(content, "Import Profile String")
    importHeader:SetPoint("TOPLEFT", PAD, y)

    -- Paste hint next to header
    local pasteHint = GUI:CreateLabel(content, "press Ctrl+V to paste", 11, C.textMuted)
    pasteHint:SetPoint("LEFT", importHeader, "RIGHT", 12, 0)

    y = y - importHeader.gap
    
    -- Import EditBox (user pastes string here)
    local importScroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    importScroll:SetPoint("TOPLEFT", PAD, y)
    importScroll:SetPoint("TOPRIGHT", -PAD - 20, y)
    importScroll:SetHeight(100)
    
    local importEditBox = CreateFrame("EditBox", nil, importScroll)
    importEditBox:SetMultiLine(true)
    importEditBox:SetAutoFocus(false)
    importEditBox:SetFont(GUI.FONT_PATH, 11, "")
    importEditBox:SetTextColor(0.8, 0.85, 0.9, 1)
    importEditBox:SetWidth(importScroll:GetWidth() - 10)
    importEditBox:SetHeight(100)  -- Set explicit height for better click target
    importEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    importScroll:SetScrollChild(importEditBox)
    
    -- Background for import box - make it clickable to focus the editbox
    local importBg = CreateFrame("Button", nil, content)
    importBg:SetPoint("TOPLEFT", importScroll, -5, 5)
    importBg:SetPoint("BOTTOMRIGHT", importScroll, 25, -5)
    importBg:SetScript("OnClick", function() importEditBox:SetFocus() end)
    
    local importBgTex = importBg:CreateTexture(nil, "BACKGROUND")
    importBgTex:SetAllPoints()
    importBgTex:SetColorTexture(0.05, 0.07, 0.1, 0.9)
    
    -- Border for import box
    local importBorder = CreateFrame("Frame", nil, content, "BackdropTemplate")
    importBorder:SetPoint("TOPLEFT", importScroll, -6, 6)
    importBorder:SetPoint("BOTTOMRIGHT", importScroll, 26, -6)
    importBorder:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    importBorder:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    
    y = y - 115
    
    -- IMPORT AND RELOAD button (themed)
    local importBtn = GUI:CreateButton(content, "IMPORT AND RELOAD", 200, 28, function()
        local str = importEditBox:GetText()
        if not str or str == "" then
            print("|cffff0000QuaziiUI: No import string provided.|r")
            return
        end
        local QUICore = _G.QuaziiUI and _G.QuaziiUI.QUICore
        if QUICore and QUICore.ImportProfileFromString then
            local ok, err = QUICore:ImportProfileFromString(str)
            if ok then
                print("|cff34D399QuaziiUI:|r Profile imported successfully!")
                print("|cff34D399QuaziiUI:|r Please type |cFFFFD700/reload|r to apply changes.")
            else
                print("|cffff0000QuaziiUI: Import failed: " .. (err or "Unknown error") .. "|r")
            end
        else
            print("|cffff0000QuaziiUI: QUICore not available for import.|r")
        end
    end)
    importBtn:SetPoint("TOPLEFT", PAD, y)
    y = y - 40
    
    content:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- PAGE: Spec Profiles (Autoswap)
---------------------------------------------------------------------------


-- Export the function
ns.ImportExportOptions = { CreateImportExportPage = CreateImportExportPage }

-- Register with Options Page Registry
if ns.OptionsPageRegistry then
    ns.OptionsPageRegistry:RegisterSimplePage("import_export", "QUI Import/Export", CreateImportExportPage, 120)
end
return ns.ImportExportOptions
