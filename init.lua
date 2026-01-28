-- Keybinding display name (must be global before Bindings.xml loads)
BINDING_NAME_QUAZIIUI_TOGGLE_OPTIONS = "Open QuaziiUI Options"

---@type table|AceAddon
QuaziiUI = LibStub("AceAddon-3.0"):NewAddon("QuaziiUI", "AceConsole-3.0", "AceEvent-3.0")
---@type table<string, string>
QuaziiUI.L = LibStub("AceLocale-3.0"):GetLocale("QuaziiUI")

local L = QuaziiUI.L

---@type table
QuaziiUI.DF = _G["DetailsFramework"]
QuaziiUI.DEBUG_MODE = false

-- Version info
QuaziiUI.versionString = C_AddOns.GetAddOnMetadata("QuaziiUI", "Version") or "1.42"

---@type table
QuaziiUI.defaults = {
    global = {},
    char = {
        ---@type table
        debug = {
            ---@type boolean
            reload = false
        }
    }
}

function QuaziiUI:OnInitialize()
    ---@type AceDBObject-3.0
    self.db = LibStub("AceDB-3.0"):New("QuaziiUI_DB", self.defaults, "Default")

    self:RegisterChatCommand("qui", "SlashCommandOpen")
    self:RegisterChatCommand("quaziiui", "SlashCommandOpen")
    self:RegisterChatCommand("rl", "SlashCommandReload")
    
    -- Register our media files with LibSharedMedia
    self:CheckMediaRegistration()
end

-- Quick Keybind Mode shortcut (/kb)
SLASH_QUIKB1 = "/kb"
SlashCmdList["QUIKB"] = function()
    local LibKeyBound = LibStub("LibKeyBound-1.0", true)
    if LibKeyBound then
        LibKeyBound:Toggle()
    elseif QuickKeybindFrame then
        -- Fallback to Blizzard's Quick Keybind Mode (no mousewheel support)
        ShowUIPanel(QuickKeybindFrame)
    else
        print("|cff34D399QuaziiUI:|r Quick Keybind Mode not available.")
    end
end

-- Cooldown Settings shortcut (/cdm)
SLASH_QUAZIIUI_CDM1 = "/cdm"
SlashCmdList["QUAZIIUI_CDM"] = function()
    if CooldownViewerSettings then
        CooldownViewerSettings:SetShown(not CooldownViewerSettings:IsShown())
    else
        print("|cff34D399QuaziiUI:|r Cooldown Settings not available. Enable CDM first.")
    end
end

function QuaziiUI:SlashCommandOpen(input)
    if input and input == "debug" then
        self.db.char.debug.reload = true
        QuaziiUI:SafeReload()
    elseif input and input == "editmode" then
        -- Toggle Unit Frames Edit Mode
        if _G.QuaziiUI_ToggleUnitFrameEditMode then
            _G.QuaziiUI_ToggleUnitFrameEditMode()
        else
            print("|cFF56D1FFQuaziiUI:|r Unit Frames module not loaded.")
        end
        return
    end
    
    -- Default: Open custom GUI
    if self.GUI then
        self.GUI:Toggle()
    else
        print("|cFF56D1FFQuaziiUI:|r GUI not loaded yet. Try again in a moment.")
    end
end

function QuaziiUI:SlashCommandReload()
    QuaziiUI:SafeReload()
end

function QuaziiUI:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    -- Initialize QUICore (AceDB-based integration)
    if self.QUICore then
        -- Show intro message if enabled (defaults to true)
        if self.db.profile.chat.showIntroMessage ~= false then
            print("|cFF30D1FFQuazii UI|r loaded. |cFFFFFF00/qui|r to setup.")
            print("|cFF30D1FFQUI REMINDER:|r")
            print("|cFF34D3991.|r ENABLE |cFFFFFF00Cooldown Manager|r in Options > Gameplay Enhancement")
            print("|cFF34D3992.|r Action Bars & Menu Bar |cFFFFFF00HIDDEN|r on mouseover |cFFFFFF00by default|r. Go to |cFFFFFF00'Actionbars'|r tab in |cFFFFFF00/qui|r to unhide.")
            print("|cFF34D3993.|r Use |cFFFFFF00100% Icon Size|r on CDM Essential & Utility bars via |cFFFFFF00Edit Mode|r for best results.")
            print("|cFF34D3994.|r Position your |cFFFFFF00CDM bars|r in |cFFFFFF00Edit Mode|r and click |cFFFFFF00Save|r before exiting.")
        end
    end
end

function QuaziiUI:PLAYER_ENTERING_WORLD(_, isInitialLogin, isReloadingUi)
    QuaziiUI:BackwardsCompat()

    -- Ensure debug table exists
    if not self.db.char.debug then
        self.db.char.debug = { reload = false }
    end

    if not self.DEBUG_MODE then
        if self.db.char.debug.reload then
            self.DEBUG_MODE = true
            self.db.char.debug.reload = false
            self:DebugPrint("Debug Mode Enabled")
        end
    else
        self:DebugPrint("Debug Mode Enabled")
    end
end

function QuaziiUI:DebugPrint(...)
    if self.DEBUG_MODE then
        self:Print(...)
    end
end

-- ADDON COMPARTMENT FUNCTIONS --
function QuaziiUI_CompartmentClick()
    -- Open the new GUI
    if QuaziiUI.GUI then
        QuaziiUI.GUI:Toggle()
    end
end

local GameTooltip = GameTooltip
function QuaziiUI_CompartmentOnEnter(self, button)
    GameTooltip:ClearLines()
    GameTooltip:SetOwner(type(self) ~= "string" and self or button, "ANCHOR_LEFT")
    GameTooltip:AddLine(L["AddonName"] .. " v" .. QuaziiUI.versionString)
    GameTooltip:AddLine(L["LeftClickOpen"])
    GameTooltip:Show()
end

function QuaziiUI_CompartmentOnLeave()
    GameTooltip:Hide()
end
