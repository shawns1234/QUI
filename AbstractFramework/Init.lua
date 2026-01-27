---@class AbstractFramework
local AF = select(2, ...)
_G.AbstractFramework = AF
AF.name = "AbstractFramework"

-- no operation
AF.noop = function() end
AF.noop_true = function() return true end
AF.noop_false = function() return false end

---------------------------------------------------------------------
-- libs
---------------------------------------------------------------------
AF.Libs = {}

-- external libs
AF.Libs.LSM = LibStub("LibSharedMedia-3.0")
AF.Libs.LCG = LibStub("LibCustomGlow-1.0")
AF.Libs.LibDeflate = LibStub("LibDeflate")
AF.Libs.LibSerialize = LibStub("LibSerialize")
AF.Libs.Comm = LibStub("AceComm-3.0")
AF.Libs.LibDataBroker = LibStub("LibDataBroker-1.1")
AF.Libs.LibDBIcon = LibStub("LibDBIcon-1.0")

-- embedded libs
AF.Libs.FAIAP = LibStub("AF_FAIAP")

AF.Libs.MD5 = LibStub("AF_MD5")
---@type fun(str:string):string
AF.MD5 = AF.Libs.MD5.sumhexa

AF.Libs.SHA256 = LibStub("AF_SHA256")
---@type fun(str:string):string
AF.SHA256 = AF.Libs.SHA256.hash

AF.Libs.BASE64 = LibStub("AF_BASE64")
---@type fun(str:string, encoder:table?, usecaching:boolean?):string
AF.EncodeBase64 = AF.Libs.BASE64.encode
---@type fun(str:string, decoder:table?, usecaching:boolean?):string
AF.DecodeBase64 = AF.Libs.BASE64.decode

AF.Libs.JSON = LibStub("AF_JSON")
---@type fun(obj:any, options:table?):string
AF.EncodeJson = AF.Libs.JSON.encode_json
---@type fun(obj:any, options:table?):string
AF.EncodeHJson = AF.Libs.JSON.encode_hjson
---@type fun(str:string, options:table?):any
AF.DecodeJson = AF.Libs.JSON.decode

AF.Libs.QRCODE = LibStub("AF_QRCODE")
---@type fun(parent:Frame, str:string, size:number?, padding:number?):Frame
AF.GetQRCodeFrame = AF.Libs.QRCODE.GetQRCodeFrame
---@type fun(str:string, white_pixel:string?, black_pixel:string?):string
AF.GetQRCodeString = AF.Libs.QRCODE.GetQRCodeString

---------------------------------------------------------------------
-- game version
---------------------------------------------------------------------
AF.isAsian = LOCALE_zhCN or LOCALE_zhTW or LOCALE_koKR

if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
    AF.isRetail = true
    AF.flavor = "retail"
elseif WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC then
    AF.isMists = true
    AF.flavor = "mists"
elseif WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC then
    AF.isCata = true
    AF.flavor = "cata"
elseif WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC then
    AF.isWrath = true
    AF.flavor = "wrath"
elseif WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then
    AF.isTBC = true
    AF.flavor = "tbc"
elseif WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
    AF.isVanilla = true
    AF.flavor = "vanilla"
end

---------------------------------------------------------------------
-- game region
---------------------------------------------------------------------
AF.portal = GetCVar("portal")

---------------------------------------------------------------------
-- UIParent
---------------------------------------------------------------------
AF.UIParent = CreateFrame("Frame", "AFParent", UIParent)
AF.UIParent:SetAllPoints(UIParent)
AF.UIParent:SetFrameLevel(0)

AF.UIParent:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)

-- update pixels
local function UpdatePixels()
    AF.UpdatePixels_Auto()
    AF.Fire("AF_PIXEL_UPDATE")
end

local timer
local function DelayedUpdatePixels(_, _, skipPixelsUpdate)
    if skipPixelsUpdate then return end
    if timer then timer:Cancel() end
    timer = C_Timer.NewTimer(1, UpdatePixels)
end
hooksecurefunc(UIParent, "SetScale", DelayedUpdatePixels)

AF.UIParent:RegisterEvent("FIRST_FRAME_RENDERED")

function AF.UIParent:FIRST_FRAME_RENDERED()
    AF.UIParent:UnregisterEvent("FIRST_FRAME_RENDERED")
    AF.UIParent:RegisterEvent("UI_SCALE_CHANGED")
    AF.SetupPopups(AFConfig.popups)
    AF.Fire("AF_FIRST_FRAME_RENDERED")
    AF.Fire("AF_POPUPS_READY")
end

function AF.UIParent:UI_SCALE_CHANGED()
    DelayedUpdatePixels()
end

-- loaded
AF.UIParent:RegisterEvent("ADDON_LOADED")
function AF.UIParent:ADDON_LOADED(addon)
    if addon == AF.name then
        AF.UIParent:UnregisterEvent("ADDON_LOADED")

        AF.version, AF.versionNum = AF.GetAddOnVersion(AF.name)

        if type(AFConfig) ~= "table" then AFConfig = {} end

        -- accent color
        if type(AFConfig.accentColor) ~= "table" then
            AFConfig.accentColor = {
                type = "default",
                color = AF.BuildAccentColorTable("hotpink"),
            }
        end

        -- font size offset
        if type(AFConfig.fontSizeDelta) ~= "number" then AFConfig.fontSizeDelta = 0 end
        AF.UpdateFontSize(AFConfig.fontSizeDelta)

        -- debug
        if type(AFConfig.debug) ~= "table" then
            AFConfig.debug = {
                ["AF"] = false,
                ["AF_EVENTS"] = false,
            }
        end

        -- scale
        if type(AFConfig.scale) ~= "number" then AFConfig.scale = 1 end
        AF.SetScale(AFConfig.scale, true)
        -- if type(AFConfig.uiScale) ~= "number" then AFConfig.uiScale = UIParent:GetScale() end
        -- UIParent:SetScale(AFConfig.uiScale)

        --! AF_LOADED
        AF.Fire("AF_LOADED", AF.version, AF.versionNum)
        AF.InitMoverParent()

        -- setup popups
        if type(AFConfig.popups) ~= "table" then AFConfig.popups = {} end
    end
end

-- Event system
AF.callbacks = {}
function AF.RegisterCallback(event, callback)
    if not AF.callbacks[event] then AF.callbacks[event] = {} end
    table.insert(AF.callbacks[event], callback)
end

function AF.Fire(event, ...)
    if AF.callbacks[event] then
        for _, callback in ipairs(AF.callbacks[event]) do
            callback(...)
        end
    end
end

function AF.CreateBasicEventHandler(func, event)
    if not AF.eventHandlers then AF.eventHandlers = {} end
    AF.eventHandlers[event] = func
end

--! scale should NOT be TOO SMALL
--! or it will result in abnormal display of borders
--! since AF has changed SetSnapToPixelGrid / SetTexelSnappingBias
function AF.SetScale(scale, skipPixelsUpdate)
    AFConfig.scale = scale
    AF.scale = scale
    AF.UIParent:SetScale(scale)
    AF.Fire("AF_SCALE_CHANGED", scale)
    if not skipPixelsUpdate then
        if timer then timer:Cancel() end
        UpdatePixels()
    end
end

function AF.GetScale()
    return AFConfig.scale
end

function AF.SetUIParentScale(scale, skipPixelsUpdate)
    UIParent:SetScale(scale, skipPixelsUpdate)
end

-- Missing utility functions
function AF.GetAddon()
    return "QuaziiUI"
end

function AF.CalcPoint(region)
    if region:GetNumPoints() ~= 1 then return "CENTER", 0, 0 end
    local point, relativeTo, relativePoint, offsetX, offsetY = region:GetPoint()
    return point, offsetX, offsetY
end

function AF.Lerp(min, max, t)
    return min + (max - min) * t
end

function AF.IsBlank(str)
    return not str or str == ""
end

function AF.Debug(msg)
    if AFConfig and AFConfig.debug and AFConfig.debug.AF then
        print("|cFF56D1FF[AF]|r " .. tostring(msg))
    end
end

function AF.GetColorStr(color, text)
    local colors = {
        yellow = "FFFF00",
        red = "FF0000",
        green = "00FF00",
        blue = "0000FF",
    }
    local hex = colors[color] or "FFFFFF"
    return "|cFF" .. hex .. text .. "|r"
end

function AF.WrapTextInColor(text, color)
    return AF.GetColorStr(color, text)
end

---------------------------------------------------------------------
-- hidden parent
---------------------------------------------------------------------
AF.hiddenParent = CreateFrame("Frame", nil, UIParent)
AF.hiddenParent:SetPoint("BOTTOMLEFT")
AF.hiddenParent:SetSize(1, 1)
AF.hiddenParent:Hide()

---------------------------------------------------------------------
-- slash command
---------------------------------------------------------------------
_G["SLASH_ABSTRACTFRAMEWORK1"] = "/abstract"
_G["SLASH_ABSTRACTFRAMEWORK2"] = "/afw"
_G["SLASH_ABSTRACTFRAMEWORK3"] = "/af"
SlashCmdList.ABSTRACTFRAMEWORK = function()
    AF.ShowDemo()
end