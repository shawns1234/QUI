--[[
    QUI Castbar Module
    Extracted from qui_unitframes.lua for better organization
    Handles castbar creation and management for player, target, focus, and boss units
]]

local ADDON_NAME, ns = ...

-- Check if module should load (with fallback if registry not initialized)
local shouldLoad = true
if ns.ShouldLoadModule then
    shouldLoad = ns.ShouldLoadModule("castbars", { name = "Castbars", enabled = true })
end
if not shouldLoad then
    return
end

local QUICore = ns.Addon
local LSM = LibStub("LibSharedMedia-3.0")

---------------------------------------------------------------------------
-- MODULE TABLE
---------------------------------------------------------------------------
local QUI_Castbar = {}
ns.QUI_Castbar = QUI_Castbar

QUI_Castbar.castbars = {}

-- Reference to layout manager
local QUI_LayoutManager = ns.QUI_LayoutManager

local Helpers = {}

---------------------------------------------------------------------------
-- SETUP HELPERS
---------------------------------------------------------------------------
function QUI_Castbar:SetHelpers(helpers)
    Helpers = helpers or {}
end

-- Helper function wrappers (with fallbacks)
local function GetUnitSettings(unit)
    return Helpers.GetUnitSettings and Helpers.GetUnitSettings(unit) or nil
end

local function Scale(x)
    return Helpers.Scale and Helpers.Scale(x) or x
end

local function GetFontPath()
    return Helpers.GetFontPath and Helpers.GetFontPath() or "Fonts\\FRIZQT__.TTF"
end

local function GetFontOutline()
    return Helpers.GetFontOutline and Helpers.GetFontOutline() or "OUTLINE"
end

local function GetTexturePath(textureName)
    return Helpers.GetTexturePath and Helpers.GetTexturePath(textureName) or "Interface\\Buttons\\WHITE8x8"
end

local function GetUnitClassColor(unit)
    if Helpers.GetUnitClassColor then
        return Helpers.GetUnitClassColor(unit)
    end
    return 0.5, 0.5, 0.5, 1
end

local function TruncateName(name, maxLength)
    return Helpers.TruncateName and Helpers.TruncateName(name, maxLength) or name
end

local function GetGeneralSettings()
    return Helpers.GetGeneralSettings and Helpers.GetGeneralSettings() or nil
end

local function GetDB()
    return Helpers.GetDB and Helpers.GetDB() or nil
end

---------------------------------------------------------------------------
-- HELPER: Safe secret value check (checks if global exists first)
---------------------------------------------------------------------------
local function IsSecretValue(value)
    if type(issecretvalue) == "function" then
        return issecretvalue(value)
    end
    -- Fallback: if issecretvalue doesn't exist, assume value is not secret
    return false
end

---------------------------------------------------------------------------
-- CONSTANTS
---------------------------------------------------------------------------
QUI_Castbar.STAGE_COLORS = {
    {0.15, 0.38, 0.58, 1},   -- Stage 1: Dark Blue
    {0.55, 0.20, 0.24, 1},   -- Stage 2: Dark Red/Pink
    {0.58, 0.45, 0.18, 1},   -- Stage 3: Dark Yellow/Orange
    {0.27, 0.50, 0.21, 1},   -- Stage 4: Dark Green
    {0.40, 0.20, 0.50, 1},   -- Stage 5: Dark Purple
}

QUI_Castbar.STAGE_FILL_COLORS = {
    {0.26, 0.64, 0.96, 1},   -- Stage 1: Bright Blue
    {0.91, 0.35, 0.40, 1},   -- Stage 2: Bright Red/Pink
    {0.95, 0.75, 0.30, 1},   -- Stage 3: Bright Yellow/Orange
    {0.45, 0.82, 0.35, 1},   -- Stage 4: Bright Green
    {0.75, 0.45, 0.85, 1},   -- Stage 5: Bright Purple
}

-- Local references for internal use
local STAGE_COLORS = QUI_Castbar.STAGE_COLORS
local STAGE_FILL_COLORS = QUI_Castbar.STAGE_FILL_COLORS

---------------------------------------------------------------------------
-- SETTINGS HELPERS
---------------------------------------------------------------------------
local function GetCastSettings(unitKey)
    local settings = GetUnitSettings(unitKey)
    return settings and settings.castbar or nil
end

-- Text throttling helper (updates text at 10 FPS to reduce overhead)
local function UpdateThrottledText(castbar, elapsed, text, value)
    castbar.textThrottle = (castbar.textThrottle or 0) + elapsed
    if castbar.textThrottle >= 0.1 then
        castbar.textThrottle = 0
        if text then
            if type(value) == "number" then
                text:SetText(string.format("%.1f", value))
            else
                text:SetText(tostring(value))
            end
        end
        return true
    end
    return false
end

local function InitializeDefaultSettings(castSettings)
    if castSettings.iconAnchor == nil then castSettings.iconAnchor = "LEFT" end
    if castSettings.iconSpacing == nil then castSettings.iconSpacing = 0 end
    if castSettings.showIcon == nil then castSettings.showIcon = true end
    
    if not castSettings.borderColor then
        castSettings.borderColor = {0, 0, 0, 1}
    elseif not castSettings.borderColor[4] then
        castSettings.borderColor[4] = 1
    end
    if not castSettings.iconBorderColor then
        castSettings.iconBorderColor = {0, 0, 0, 1}
    elseif not castSettings.iconBorderColor[4] then
        castSettings.iconBorderColor[4] = 1
    end
    if castSettings.iconBorderSize == nil then
        castSettings.iconBorderSize = 2
    end
    
    if castSettings.statusBarAnchor == nil then castSettings.statusBarAnchor = "BOTTOMRIGHT" end
    
    if castSettings.spellTextAnchor == nil then castSettings.spellTextAnchor = "LEFT" end
    if castSettings.spellTextOffsetX == nil then castSettings.spellTextOffsetX = 4 end
    if castSettings.spellTextOffsetY == nil then castSettings.spellTextOffsetY = 0 end
    if castSettings.showSpellText == nil then castSettings.showSpellText = true end
    
    if castSettings.timeTextAnchor == nil then castSettings.timeTextAnchor = "RIGHT" end
    if castSettings.timeTextOffsetX == nil then castSettings.timeTextOffsetX = -4 end
    if castSettings.timeTextOffsetY == nil then castSettings.timeTextOffsetY = 0 end
    if castSettings.showTimeText == nil then castSettings.showTimeText = true end
    
    if castSettings.empoweredLevelTextAnchor == nil then castSettings.empoweredLevelTextAnchor = "CENTER" end
    if castSettings.empoweredLevelTextOffsetX == nil then castSettings.empoweredLevelTextOffsetX = 0 end
    if castSettings.empoweredLevelTextOffsetY == nil then castSettings.empoweredLevelTextOffsetY = 0 end
    if castSettings.showEmpoweredLevel == nil then castSettings.showEmpoweredLevel = false end
    if castSettings.hideTimeTextOnEmpowered == nil then castSettings.hideTimeTextOnEmpowered = false end
    
    -- Empowered color overrides (player only) - initialize with default constants
    if not castSettings.empoweredStageColors then
        castSettings.empoweredStageColors = {}
        for i = 1, 5 do
            if STAGE_COLORS[i] then
                castSettings.empoweredStageColors[i] = {STAGE_COLORS[i][1], STAGE_COLORS[i][2], STAGE_COLORS[i][3], STAGE_COLORS[i][4]}
            end
        end
    end
    if not castSettings.empoweredFillColors then
        castSettings.empoweredFillColors = {}
        for i = 1, 5 do
            if STAGE_FILL_COLORS[i] then
                castSettings.empoweredFillColors[i] = {STAGE_FILL_COLORS[i][1], STAGE_FILL_COLORS[i][2], STAGE_FILL_COLORS[i][3], STAGE_FILL_COLORS[i][4]}
            end
        end
    end
end

local function GetSizingValues(castSettings)
    local barHeight = Scale(castSettings.height or 25)
    barHeight = math.max(barHeight, Scale(4))
    local iconSize = Scale((castSettings.iconSize and castSettings.iconSize > 0) and castSettings.iconSize or 25)
    local iconScale = castSettings.iconScale or 1.0
    return barHeight, iconSize, iconScale
end

---------------------------------------------------------------------------
-- COLOR HELPERS
---------------------------------------------------------------------------
-- Default colors
local DEFAULT_BAR_COLOR = {1, 0.7, 0, 1}
local DEFAULT_BG_COLOR = {0.149, 0.149, 0.149, 1}
local NOT_INTERRUPTIBLE_COLOR = {0.7, 0.2, 0.2, 1}

-- Safe color getter - returns valid color table or fallback
local function GetSafeColor(color, fallback)
    if color and color[1] and color[2] and color[3] then
        return color[1], color[2], color[3], color[4] or 1
    end
    fallback = fallback or DEFAULT_BAR_COLOR
    return fallback[1], fallback[2], fallback[3], fallback[4] or 1
end

---------------------------------------------------------------------------
-- BORDER CREATION
---------------------------------------------------------------------------
local function CreateStatusBarBorder(statusBar, borderSize, borderColor)
    local border = CreateFrame("Frame", nil, statusBar, "BackdropTemplate")
    border:SetFrameLevel(statusBar:GetFrameLevel() - 1)
    
    -- Defer backdrop setup to prevent script timeout when creating multiple borders
    C_Timer.After(0, function()
        if border and statusBar and statusBar.Border == border then
            border:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = borderSize,
            })
            local r, g, b, a = GetSafeColor(borderColor, {0, 0, 0, 1})
            border:SetBackdropBorderColor(r, g, b, a)
        end
    end)
    
    statusBar.Border = border
    return border
end

---------------------------------------------------------------------------
-- UI ELEMENT CREATION
---------------------------------------------------------------------------
local function CreateAnchorFrame(name, parent)
    local anchorFrame = CreateFrame("Frame", name, parent)
    anchorFrame:SetFrameStrata("MEDIUM")
    anchorFrame:SetFrameLevel(200)
    anchorFrame:Hide()
    return anchorFrame
end

local function CreateCastbarFrame(name, parent)
    return CreateAnchorFrame(name, parent)
end

local function CreateIcon(anchorFrame, iconSize, iconBorderSize, iconBorderColor)
    local iconFrame = CreateFrame("Frame", nil, anchorFrame)
    iconFrame:SetSize(iconSize, iconSize)
    iconFrame:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", 0, 0)
    
    local border = iconFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    local r, g, b, a = GetSafeColor(iconBorderColor, {0, 0, 0, 1})
    border:SetColorTexture(r, g, b, a)
    border:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", -iconBorderSize, iconBorderSize)
    border:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", iconBorderSize, -iconBorderSize)
    iconFrame.border = border
    
    local iconTexture = iconFrame:CreateTexture(nil, "ARTWORK")
    iconTexture:SetAllPoints(iconFrame)
    iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    iconFrame.texture = iconTexture
    
    anchorFrame.icon = iconFrame
    anchorFrame.iconTexture = iconTexture
    anchorFrame.iconBorder = border
    return iconFrame
end

local function CreateStatusBar(anchorFrame)
    local statusBar = CreateFrame("StatusBar", nil, anchorFrame)
    statusBar:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", 0, 0)
    statusBar:SetMinMaxValues(0, 1)
    statusBar:SetValue(0)
    anchorFrame.statusBar = statusBar
    return statusBar
end

local function CreateBackgroundBar(statusBar)
    local bgBar = statusBar:CreateTexture(nil, "BACKGROUND")
    bgBar:SetAllPoints()
    bgBar:SetTexture("Interface\\Buttons\\WHITE8x8")
    return bgBar
end

local function CreateTextElement(statusBar, fontSize, layer)
    local text = statusBar:CreateFontString(nil, layer or "OVERLAY")
    text:SetFont(GetFontPath(), fontSize, GetFontOutline())
    text:SetTextColor(1, 1, 1, 1)
    return text
end

local function GetBarColor(unitKey, castSettings)
    if unitKey == "player" and castSettings.useClassColor then
        local _, class = UnitClass("player")
        if class and RAID_CLASS_COLORS[class] then
            local c = RAID_CLASS_COLORS[class]
            return {c.r, c.g, c.b, 1}
        end
    end
    return castSettings.color or DEFAULT_BAR_COLOR
end

local function ApplyBarColor(statusBar, barColor)
    local r, g, b, a = GetSafeColor(barColor, DEFAULT_BAR_COLOR)
    statusBar:SetStatusBarColor(r, g, b, a)
end

local function ApplyBackgroundColor(bgBar, bgColor)
    local r, g, b, a = GetSafeColor(bgColor, DEFAULT_BG_COLOR)
    bgBar:SetVertexColor(r, g, b, a)
end

local function ApplyCastColor(statusBar, notInterruptible, customColor)
    if notInterruptible then
        local r, g, b, a = GetSafeColor(NOT_INTERRUPTIBLE_COLOR)
        statusBar:SetStatusBarColor(r, g, b, a)
    else
        local r, g, b, a = GetSafeColor(customColor, DEFAULT_BAR_COLOR)
        statusBar:SetStatusBarColor(r, g, b, a)
    end
end

---------------------------------------------------------------------------
-- POSITIONING HELPERS
---------------------------------------------------------------------------
local function PositionCastbarByAnchor(anchorFrame, castSettings, unitFrame, unitKey)
    if not QUI_LayoutManager then
        return
    end
    
    -- Unregister first in case anchor settings changed
    QUI_LayoutManager:UnregisterFrame(anchorFrame)
    
    -- Prepare edit mode configuration
    local unitKeyForEdit = unitKey or (anchorFrame.unitKey or "default")
    local label = "Castbar"
    if unitKeyForEdit and unitKeyForEdit ~= "default" then
        label = unitKeyForEdit:gsub("^%l", string.upper):gsub("(%l)(%u)", "%1 %2") .. " Castbar"
    end
    
    -- Frame key for layout system
    local castbarFrameKey = "castbars." .. (unitKeyForEdit or "default")
    
    -- Register with layout manager - handles migration, defaults, and positioning
    -- Layout manager is the source of truth for all anchor/positioning settings
    -- parentFrame is optional - Layout Manager will handle parent frame based on anchorTarget
    QUI_LayoutManager:RegisterFrame(anchorFrame, castbarFrameKey, "castbars", {
        parentFrame = unitFrame,  -- Pass unitFrame if it exists (Layout Manager will use it if anchorTarget matches)
        editMode = {
            label = label,
            elementKey = unitKeyForEdit or "default",
            skipKeyboardEnable = false,
            elementType = "castbar",  -- For selection handling
        },
    })
    -- Note: Layout is already applied by RegisterFrame, including width/height from saved config
    -- All positioning and sizing comes from the layout manager (source of truth)
end

-- SetCastbarSize removed - layout manager handles width/height automatically

---------------------------------------------------------------------------
-- ELEMENT POSITIONING HELPERS
---------------------------------------------------------------------------
local function ShouldShowIcon(anchorFrame, castSettings)
    return castSettings.showIcon == true
end

local function UpdateIconPosition(anchorFrame, castSettings, iconSize, iconScale, iconBorderSize)
    local iconFrame = anchorFrame.icon
    local iconTexture = anchorFrame.iconTexture
    local iconBorder = anchorFrame.iconBorder
    
    if not ShouldShowIcon(anchorFrame, castSettings) or not iconFrame then
        if iconFrame then iconFrame:Hide() end
        return false
    end
    
    local baseIconSize = iconSize * iconScale
    iconFrame:SetSize(baseIconSize, baseIconSize)
    iconFrame:ClearAllPoints()
    local iconAnchor = castSettings.iconAnchor or "TOPLEFT"
    iconFrame:SetPoint(iconAnchor, anchorFrame, iconAnchor, 0, 0)
    
    local textureToUse = anchorFrame.currentIconTexture or anchorFrame.previewIconTexture
    if textureToUse and iconTexture then
        iconTexture:SetTexture(textureToUse)
        if ShouldShowIcon(anchorFrame, castSettings) then
            iconFrame:Show()
        else
        iconFrame:Hide()
        return false
    end
    
    if iconBorder then
            local r, g, b, a = GetSafeColor(castSettings.iconBorderColor, {0, 0, 0, 1})
            iconBorder:SetColorTexture(r, g, b, a)
            iconBorder:ClearAllPoints()
            iconBorder:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", -iconBorderSize, iconBorderSize)
            iconBorder:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", iconBorderSize, -iconBorderSize)
        end
        return true
    else
        iconFrame:Hide()
        return false
    end
end

local function UpdateStatusBarPosition(anchorFrame, castSettings, barHeight, iconSize, iconScale, borderSize)
    local statusBar = anchorFrame.statusBar
    local border = statusBar and statusBar.Border
    
    if not statusBar then return end
    
    statusBar:SetHeight(barHeight)
    statusBar:ClearAllPoints()
    
    if ShouldShowIcon(anchorFrame, castSettings) then
        local iconSizePx = iconSize * iconScale
        local iconSpacing = Scale(castSettings.iconSpacing or 0)
        local iconAnchor = castSettings.iconAnchor or "TOPLEFT"
        if iconAnchor:find("LEFT") then
            statusBar:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", iconSizePx + iconSpacing, 0)
            statusBar:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", 0, 0)
        elseif iconAnchor:find("RIGHT") then
            statusBar:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", 0, 0)
            statusBar:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", -iconSizePx - iconSpacing, 0)
        else
            statusBar:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", 0, 0)
            statusBar:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", 0, 0)
        end
    else
        statusBar:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", 0, 0)
        statusBar:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", 0, 0)
    end
    
    if border then
        border:SetFrameLevel(statusBar:GetFrameLevel() - 1)
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", statusBar, "TOPLEFT", -borderSize, borderSize)
        border:SetPoint("BOTTOMRIGHT", statusBar, "BOTTOMRIGHT", borderSize, -borderSize)
        
        -- Only update backdrop if it changed to avoid expensive operations
        local backdrop = border:GetBackdrop()
        local needsUpdate = not backdrop or 
                           (backdrop.edgeSize or 0) ~= borderSize or
                           backdrop.edgeFile ~= "Interface\\Buttons\\WHITE8x8"
        
        if needsUpdate then
            border:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = borderSize,
            })
        end
        
        local r, g, b, a = GetSafeColor(castSettings.borderColor, {0, 0, 0, 1})
        border:SetBackdropBorderColor(r, g, b, a)
        border:Show()
    end
end

local function UpdateTextPosition(textElement, statusBar, anchor, offsetX, offsetY, show)
    if not textElement then return end
    
    if show then
        textElement:ClearAllPoints()
        textElement:SetPoint(anchor, statusBar, anchor, Scale(offsetX), Scale(offsetY))
        textElement:Show()
    else
        textElement:Hide()
    end
end

---------------------------------------------------------------------------
-- MAIN UPDATE FUNCTION
---------------------------------------------------------------------------
local function UpdateCastbarElements(anchorFrame, unitKey, castSettings)
    local currentSettings = GetUnitSettings(unitKey)
    local currentCastSettings = currentSettings and currentSettings.castbar or castSettings
    
    -- Read height from frame itself (set by layout manager) - don't overwrite it
    -- The layout manager is the source of truth for width/height
    local barHeight = anchorFrame:GetHeight() or 0
    
    -- Icon size/scale still come from castSettings (not managed by layout)
    local iconSize = Scale((currentCastSettings.iconSize and currentCastSettings.iconSize > 0) and currentCastSettings.iconSize or 25)
    local iconScale = currentCastSettings.iconScale or 1.0
    
    local borderSize = Scale(currentCastSettings.borderSize or 1)
    local iconBorderSize = Scale(currentCastSettings.iconBorderSize or 1)
    
    UpdateIconPosition(anchorFrame, currentCastSettings, iconSize, iconScale, iconBorderSize)
    UpdateStatusBarPosition(anchorFrame, currentCastSettings, barHeight, iconSize, iconScale, borderSize)
    
    UpdateTextPosition(
        anchorFrame.spellText, anchorFrame.statusBar,
        currentCastSettings.spellTextAnchor or "LEFT",
        currentCastSettings.spellTextOffsetX or 4,
        currentCastSettings.spellTextOffsetY or 0,
        currentCastSettings.showSpellText
    )
    
    -- Time text visibility: hide if empowered and setting is enabled
    local showTimeText = currentCastSettings.showTimeText
    if showTimeText and currentCastSettings.hideTimeTextOnEmpowered and anchorFrame.isEmpowered then
        showTimeText = false
    end
    
    UpdateTextPosition(
        anchorFrame.timeText, anchorFrame.statusBar,
        currentCastSettings.timeTextAnchor or "RIGHT",
        currentCastSettings.timeTextOffsetX or -4,
        currentCastSettings.timeTextOffsetY or 0,
        showTimeText
    )
    
    -- Empowered level text (player only)
    if unitKey == "player" and anchorFrame.empoweredLevelText then
        UpdateTextPosition(
            anchorFrame.empoweredLevelText, anchorFrame.statusBar,
            currentCastSettings.empoweredLevelTextAnchor or "CENTER",
            currentCastSettings.empoweredLevelTextOffsetX or 0,
            currentCastSettings.empoweredLevelTextOffsetY or 0,
            currentCastSettings.showEmpoweredLevel
        )
    end
end

---------------------------------------------------------------------------
-- EMPOWERED CAST HELPERS
---------------------------------------------------------------------------
local function ClearEmpoweredState(bar)
    if not bar then return end
    
    bar.isEmpowered = false
    bar.numStages = 0
    bar.stagePositions = nil
    
    for _, stage in ipairs(bar.empoweredStages or {}) do
        if stage then stage:Hide() end
    end
    
    if bar.stageOverlays then
        for _, overlay in ipairs(bar.stageOverlays) do
            if overlay then overlay:Hide() end
        end
    end
    
    if bar.bgBar then bar.bgBar:Show() end
    
    if bar.statusBar then
        ApplyCastColor(bar.statusBar, false, bar.customColor)
    end
    
    if bar.empoweredLevelText then
        bar.empoweredLevelText:SetText("")
    end
end

---------------------------------------------------------------------------
-- ICON TEXTURE HELPER
---------------------------------------------------------------------------
local function SetIconTexture(castbar, texture)
    if not castbar or not castbar.iconTexture then return false end
    if not texture then return false end
    
    castbar.currentIconTexture = texture
    castbar.iconTexture:SetTexture(texture)
    return true
end

---------------------------------------------------------------------------
-- PREVIEW MODE / SIMULATE CAST
---------------------------------------------------------------------------
local PREVIEW_ICON_ID = 136048

local function SimulateCast(castbar, castSettings, unitKey, bossIndex)
    if not castbar then return end
    
    local castTime = 3.0
    local spellName = (unitKey == "boss" and bossIndex) and ("Boss " .. bossIndex .. " Cast") or "Preview Cast"
    local iconTexture = PREVIEW_ICON_ID
    castbar.isPreviewSimulation = true
    castbar.previewStartTime = GetTime()
    castbar.previewEndTime = GetTime() + castTime
    castbar.previewValue = 0
    castbar.previewMaxValue = castTime
    castbar.previewSpellName = spellName
    castbar.previewIconTexture = iconTexture
    
    -- Set initial visual state
    if castbar.statusBar then
        castbar.statusBar:SetStatusBarTexture(GetTexturePath(castSettings.texture))
        ApplyCastColor(castbar.statusBar, false, castbar.customColor)
        castbar.statusBar:SetMinMaxValues(0, castTime)
        castbar.statusBar:SetValue(0)
        castbar.statusBar:SetReverseFill(false)
    end
    
    if SetIconTexture(castbar, iconTexture) then
        castbar.previewIconTexture = iconTexture
        if ShouldShowIcon(castbar, castSettings) then
            castbar.icon:Show()
        else
            castbar.icon:Hide()
        end
    end
    
    if castbar.spellText then
        castbar.spellText:SetText(spellName)
        castbar.spellText:SetTextColor(1, 1, 1, 1)
        if castSettings.showSpellText ~= false then
            castbar.spellText:Show()
        end
    end
    
    if castbar.timeText then
        castbar.timeText:SetText(string.format("%.1f", castTime))
        castbar.timeText:SetTextColor(1, 1, 1, 1)
        if castSettings.showTimeText ~= false then
            castbar.timeText:Show()
        end
    end
    
    if castbar.bgBar then
        castbar.bgBar:Show()
    end
    
    ClearEmpoweredState(castbar)
    
    -- Manual drag handling removed - now handled by edit mode system
    -- Drag tracking is enabled in EnableEditMode() function
    
    castbar:Show()
end

-- Clear preview simulation
local function ClearPreviewSimulation(castbar)
    if not castbar then return end
    
    castbar.isPreviewSimulation = false
    castbar.previewStartTime = nil
    castbar.previewEndTime = nil
    castbar.previewValue = nil
    castbar.previewMaxValue = nil
    castbar.previewSpellName = nil
    castbar.previewIconTexture = nil
    
    castbar:SetMovable(false)
    castbar:EnableMouse(false)
    castbar:SetScript("OnDragStart", nil)
    castbar:SetScript("OnDragStop", nil)
    
    if not UnitCastingInfo(castbar.unit) and not UnitChannelInfo(castbar.unit) then
        castbar:Hide()
    end
end

---------------------------------------------------------------------------
-- EMPOWERED CAST HELPERS
---------------------------------------------------------------------------
local function UpdateEmpoweredStages(bar, numStages)
    -- Hide existing stage markers and overlays
    for _, stage in ipairs(bar.empoweredStages or {}) do
        if stage then stage:Hide() end
    end
    bar.stageOverlays = bar.stageOverlays or {}
    for _, overlay in ipairs(bar.stageOverlays) do
        if overlay then overlay:Hide() end
    end
    
    if not numStages or numStages <= 0 then
        bar.isEmpowered = false
        bar.numStages = 0
        if bar.bgBar then bar.bgBar:Show() end
        return
    end
    
    bar.isEmpowered = true
    bar.numStages = numStages
    if bar.bgBar then bar.bgBar:Hide() end
    
    C_Timer.After(0, function()
        if not bar.statusBar:IsVisible() then
            C_Timer.After(0.066, function()
                UpdateEmpoweredStages(bar, numStages)
            end)
            return
        end
        
        local barWidth = bar.statusBar:GetWidth()
        if barWidth <= 0 then barWidth = 150 end
        local barHeight = bar.statusBar:GetHeight()
        
        -- Stage boundary positions
        local stagePositions
        if numStages >= 4 then
            stagePositions = {0, 0.18, 0.42, 0.63, 0.84, 1.0}
        elseif numStages == 3 then
            stagePositions = {0, 0.25, 0.50, 0.75, 1.0}
        elseif numStages == 2 then
            stagePositions = {0, 0.50, 1.0}
        else
            stagePositions = {0, 1.0}
        end
        
        bar.stagePositions = stagePositions
        
        -- Create colored overlays for each stage zone
        for i = 1, #stagePositions - 1 do
            local overlay = bar.stageOverlays[i]
            if not overlay then
                overlay = bar.statusBar:CreateTexture(nil, "BACKGROUND", nil, 1)
                bar.stageOverlays[i] = overlay
            end
            
            local startPos = stagePositions[i] * barWidth
            local endPos = stagePositions[i + 1] * barWidth
            local width = endPos - startPos
            
            -- Get cast settings for color overrides
            local castSettings = GetCastSettings(bar.unitKey)
            local stageColor = STAGE_COLORS[i] or STAGE_COLORS[1]
            if castSettings and castSettings.empoweredStageColors and castSettings.empoweredStageColors[i] then
                stageColor = castSettings.empoweredStageColors[i]
            end
            
            overlay:SetColorTexture(unpack(stageColor))
            overlay:SetSize(width, barHeight)
            overlay:ClearAllPoints()
            overlay:SetPoint("LEFT", bar.statusBar, "LEFT", startPos, 0)
            overlay:SetPoint("TOP", bar.statusBar, "TOP", 0, 0)
            overlay:SetPoint("BOTTOM", bar.statusBar, "BOTTOM", 0, 0)
            overlay:Show()
        end
        
        -- Create white tick markers between stages
        for i = 2, #stagePositions - 1 do
            local tickIndex = i - 1
            local stage = bar.empoweredStages[tickIndex]
            if not stage then
                stage = bar.statusBar:CreateTexture(nil, "OVERLAY", nil, 2)
                stage:SetColorTexture(1, 1, 1, 0.95)
                stage:SetWidth(2)
                bar.empoweredStages[tickIndex] = stage
            end
            
            stage:SetHeight(barHeight)
            local position = stagePositions[i] * barWidth
            stage:ClearAllPoints()
            stage:SetPoint("LEFT", bar.statusBar, "LEFT", position - 1, 0)
            stage:SetPoint("TOP", bar.statusBar, "TOP", 0, 0)
            stage:SetPoint("BOTTOM", bar.statusBar, "BOTTOM", 0, 0)
            stage:Show()
        end
    end)
end

local function UpdateEmpoweredFillColor(bar, progress, duration)
    if not bar.isEmpowered or not bar.stagePositions then return end
    
    local progressPercent = progress / duration
    local currentStage = 1
    
    for i = 2, #bar.stagePositions do
        if progressPercent >= bar.stagePositions[i] then
            currentStage = i
        else
            break
        end
    end
    
    -- Get cast settings for color overrides
    local castSettings = GetCastSettings(bar.unitKey)
    local fillColors = STAGE_FILL_COLORS
    if castSettings and castSettings.empoweredFillColors then
        -- Use override colors if available, fallback to defaults
        fillColors = {}
        for i = 1, 5 do
            if castSettings.empoweredFillColors[i] then
                fillColors[i] = castSettings.empoweredFillColors[i]
            else
                fillColors[i] = STAGE_FILL_COLORS[i] or STAGE_FILL_COLORS[1]
            end
        end
    end
    
    if currentStage > #fillColors then
        currentStage = #fillColors
    end
    
    local c = fillColors[currentStage]
    if c then
        bar.statusBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
    end
end

-- Get current empowered level from player castbar
function QUI_Castbar:GetEmpoweredLevel()
    local playerCastbar = self.castbars["player"]
    if not playerCastbar then
        playerCastbar = _G.QuaziiUI_Castbars and _G.QuaziiUI_Castbars["player"]
    end
    
    if not playerCastbar or not playerCastbar.isEmpowered then
        return nil, nil, false
    end
    
    if not playerCastbar.startTime or not playerCastbar.endTime or not playerCastbar.stagePositions then
        return nil, nil, false
    end
    
    local now = GetTime()
    local progress = now - playerCastbar.startTime
    local duration = playerCastbar.endTime - playerCastbar.startTime
    
    if duration <= 0 then
        return nil, nil, false
    end
    
    local progressPercent = progress / duration
    local currentStage = 1
    
    for i = 2, #playerCastbar.stagePositions do
        if progressPercent >= playerCastbar.stagePositions[i] then
            currentStage = i
        else
            break
        end
    end
    
    local maxStages = playerCastbar.numStages or 0
    return currentStage, maxStages, true
end

---------------------------------------------------------------------------
-- TEXT HELPERS
---------------------------------------------------------------------------
local function UpdateSpellText(castbar, text, spellName, castSettings, unit)
    if not castbar.spellText then return end
    
    local displayName = text or spellName or "Casting..."
    local maxLen = castSettings.maxLength
    if maxLen and maxLen > 0 then
        displayName = TruncateName(displayName, maxLen)
    end
    castbar.spellText:SetText(displayName)
    
    local general = GetGeneralSettings()
    if general and general.masterColorCastbarText then
        local r, g, b = GetUnitClassColor(unit)
        castbar.spellText:SetTextColor(r, g, b, 1)
    else
        castbar.spellText:SetTextColor(1, 1, 1, 1)
    end
end

local function UpdateTimeTextColor(castbar, unit)
    if not castbar.timeText then return end
    
    local general = GetGeneralSettings()
    if general and general.masterColorCastbarText then
        local r, g, b = GetUnitClassColor(unit)
        castbar.timeText:SetTextColor(r, g, b, 1)
    else
        castbar.timeText:SetTextColor(1, 1, 1, 1)
    end
end

---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- CREATE: Castbar for a unit frame
---------------------------------------------------------------------------
function QUI_Castbar:CreateCastbar(unitFrame, unit, unitKey)
    local settings = GetUnitSettings(unitKey)
    if not settings or not settings.castbar or not settings.castbar.enabled then
        return nil
    end
    
    local castSettings = settings.castbar
    InitializeDefaultSettings(castSettings)
    
    -- Initial size (temporary - layout manager will apply correct size when frame is registered)
    -- Don't read from castSettings - layout manager is the source of truth
    local iconSize = Scale((castSettings.iconSize and castSettings.iconSize > 0) and castSettings.iconSize or 25)
    local iconScale = castSettings.iconScale or 1.0
    local borderSize = Scale(castSettings.borderSize or 1)
    local iconBorderSize = Scale(castSettings.iconBorderSize or 1)
    local fontSize = castSettings.fontSize or 12
    
    local anchorFrame = CreateAnchorFrame(nil, UIParent)
    -- Set minimal initial size - layout manager will apply correct size
    anchorFrame:SetSize(1, Scale(25))
    
    CreateIcon(anchorFrame, iconSize, iconBorderSize, castSettings.iconBorderColor)
    local statusBar = CreateStatusBar(anchorFrame)
    
    CreateStatusBarBorder(statusBar, borderSize, castSettings.borderColor)
    
    local bgBar = CreateBackgroundBar(statusBar)
    anchorFrame.bgBar = bgBar
    
    local spellText = CreateTextElement(statusBar, fontSize)
    anchorFrame.spellText = spellText
    
    local timeText = CreateTextElement(statusBar, fontSize)
    anchorFrame.timeText = timeText
    
    -- Empowered level text (player only)
    if unitKey == "player" then
        local empoweredLevelText = CreateTextElement(statusBar, fontSize)
        anchorFrame.empoweredLevelText = empoweredLevelText
    end
    
    anchorFrame.UpdateCastbarElements = function(self)
        UpdateCastbarElements(self, unitKey, castSettings)
    end
    
    PositionCastbarByAnchor(anchorFrame, castSettings, unitFrame, unitKey)
    
    local barColor = GetBarColor(unitKey, castSettings)
    anchorFrame.customColor = barColor
    ApplyBarColor(statusBar, barColor)
    ApplyBackgroundColor(bgBar, castSettings.bgColor)
    statusBar:SetStatusBarTexture(GetTexturePath(castSettings.texture))
    
    -- Store unit info
    anchorFrame.unit = unit
    anchorFrame.unitKey = unitKey
    anchorFrame.isChanneled = false
    
    anchorFrame.isEmpowered = false
    anchorFrame.numStages = 0
    anchorFrame.empoweredStages = {}
    anchorFrame.stageOverlays = {}
    
    self:SetupCastbar(anchorFrame, unit, unitKey, castSettings)
    
    -- Store castbar in unit frames module's castbars table for edit mode access
    local QUI_UF = self.unitFramesModule
    if QUI_UF and QUI_UF.castbars then
        QUI_UF.castbars[unitKey] = anchorFrame
    end
    
    -- Manual drag handling removed - now handled by edit mode system
    -- Drag tracking is enabled in EnableEditMode() function
    
    UpdateCastbarElements(anchorFrame, unitKey, castSettings)
    
    -- Check if there's already an active cast when castbar is created
    -- Also handle preview mode if enabled
    C_Timer.After(0.1, function()
        if not anchorFrame then return end
        
        -- Check for active cast first (real cast takes priority)
        if UnitCastingInfo(anchorFrame.unit) or UnitChannelInfo(anchorFrame.unit) then
            if anchorFrame.Cast then
                anchorFrame:Cast()
            end
        elseif castSettings.previewMode then
            -- No real cast, but preview mode is enabled - show preview
            if not UnitCastingInfo(anchorFrame.unit) and not UnitChannelInfo(anchorFrame.unit) then
                SimulateCast(anchorFrame, castSettings, unitKey, anchorFrame.bossIndex)
                -- Start OnUpdate handler for preview
                if anchorFrame.castbarOnUpdate or anchorFrame.bossOnUpdate then
                    local onUpdateHandler = anchorFrame.castbarOnUpdate or anchorFrame.bossOnUpdate
                    anchorFrame:SetScript("OnUpdate", onUpdateHandler)
                end
            end
        end
    end)
    
    -- Store castbar in unit frames module's castbars table for edit mode access
    local QUI_UF = self.unitFramesModule
    if QUI_UF and QUI_UF.castbars then
        QUI_UF.castbars[unitKey] = anchorFrame
    end
    -- Also store unitKey on the castbar for reference
    anchorFrame.unitKey = unitKey
    
    return anchorFrame
end

---------------------------------------------------------------------------
-- CAST FUNCTION HELPERS
---------------------------------------------------------------------------
-- Get cast information from UnitCastingInfo or UnitChannelInfo
local function GetCastInfo(castbar, unit)
    local spellName, text, texture, startTimeMS, endTimeMS, _, _, notInterruptible, unitSpellID = UnitCastingInfo(unit)
    local isChanneled = false
    local channelStages = 0
    
    if not spellName then
        spellName, text, texture, startTimeMS, endTimeMS, _, notInterruptible, _, _, channelStages = UnitChannelInfo(unit)
        isChanneled = true
    end
    
    -- Check for secret values (API restriction for target units in combat)
    -- issecretvalue() only exists in 12.0+, so check for its existence first
    if spellName and startTimeMS and endTimeMS then
        if IsSecretValue(startTimeMS) or IsSecretValue(endTimeMS) then
            return nil, nil, nil, nil, nil, nil, nil, false, 0
        end
        -- Also check if values are valid numbers (not nil and numeric)
        if type(startTimeMS) ~= "number" or type(endTimeMS) ~= "number" then
            return nil, nil, nil, nil, nil, nil, nil, false, 0
        end
    end
    
    return spellName, text, texture, startTimeMS, endTimeMS, notInterruptible, unitSpellID, isChanneled, channelStages
end

-- Detect if cast is empowered (player only)
local function DetectEmpoweredCast(isPlayer, spellID, unitSpellID, isEmpowerEvent, isChanneled, channelStages)
    if not isPlayer then
        return false, 0
    end
    
    local isEmpowered = isEmpowerEvent or false
    local numStages = 0
    
    if isChanneled and isEmpowerEvent and channelStages and channelStages > 0 then
        numStages = channelStages
        isEmpowered = true
    end
    
    local checkSpellID = spellID or unitSpellID
    if checkSpellID and C_Spell and C_Spell.GetSpellEmpowerInfo then
        local empowerInfo = C_Spell.GetSpellEmpowerInfo(checkSpellID)
        if empowerInfo and empowerInfo.numStages and empowerInfo.numStages > 0 then
            isEmpowered = true
            numStages = empowerInfo.numStages
        end
    end
    
    return isEmpowered, numStages
end

-- Adjust end time for empowered cast hold time
local function AdjustEmpoweredEndTime(castbar, isPlayer, isEmpowered, endTime)
    if not (isPlayer and isEmpowered and GetUnitEmpowerHoldAtMaxTime) then
        return endTime
    end
    
    local ok, adjustedEndTime = pcall(function()
        local ht = GetUnitEmpowerHoldAtMaxTime(castbar.unit)
        if ht and ht > 0 then
            return endTime + (ht / 1000)
        end
        return endTime
    end)
    
    return ok and adjustedEndTime or endTime
end

-- Store cast times in appropriate format
local function StoreCastTimes(castbar, isPlayer, startTimeMS, endTimeMS, startTime, endTime)
    if isPlayer then
        castbar.startTime = startTime
        castbar.endTime = endTime
    else
        castbar.castStartTime = startTimeMS
        castbar.castEndTime = endTimeMS
    end
end

-- Update castbar visual elements (icon, text, colors, bar)
local function UpdateCastbarVisuals(castbar, castSettings, unitKey, texture, text, spellName, unit, isChanneled, notInterruptible, startTime, endTime, isEmpowered)
    -- Get current settings
    local currentSettings = GetUnitSettings(unitKey)
    local currentCastSettings = currentSettings and currentSettings.castbar or castSettings
    
    -- Update status bar texture
    if castbar.statusBar then
        castbar.statusBar:SetStatusBarTexture(GetTexturePath(currentCastSettings.texture))
    end
    
    -- Icon texture is already set in Cast function before this is called
    -- This function just updates other visual elements
    
    -- Update spell text
    UpdateSpellText(castbar, text, spellName, castSettings, unit)
    
    castbar.statusBar:SetReverseFill(false)
    
    -- Set initial bar value
    local now = GetTime()
    local duration = endTime - startTime
    local progress = now - startTime
    
    if duration > 0 then
        castbar.statusBar:SetMinMaxValues(0, duration)
        castbar.statusBar:SetValue(math.max(0, math.min(duration, progress)))
    end
    
    -- Set color using helper
    ApplyCastColor(castbar.statusBar, notInterruptible, castbar.customColor)
    
    -- Set initial time text
    if castbar.timeText then
        local remaining = endTime - now
        castbar.timeText:SetText(string.format("%.1f", math.max(0, remaining)))
    end
end

-- Update empowered cast state
local function UpdateEmpoweredState(castbar, isPlayer, isEmpowered, numStages)
    if isPlayer then
        if isEmpowered and numStages and numStages > 0 then
            UpdateEmpoweredStages(castbar, numStages)
        else
            ClearEmpoweredState(castbar)
        end
    end
end

-- Handle case when no cast is active
local function HandleNoCast(castbar, castSettings, isPlayer, onUpdateHandler)
    C_Timer.After(0.1, function()
        if not castbar then return end
        
        if not UnitCastingInfo(castbar.unit) and not UnitChannelInfo(castbar.unit) then
            if isPlayer then
                ClearEmpoweredState(castbar)
            end
            
            local settings = GetUnitSettings(castbar.unitKey)
            if settings and settings.castbar and settings.castbar.previewMode then
                -- Show preview simulation
                SimulateCast(castbar, castSettings, castbar.unitKey, castbar.bossIndex)
                if onUpdateHandler then
                    castbar:SetScript("OnUpdate", onUpdateHandler)
                elseif castbar.castbarOnUpdate or castbar.bossOnUpdate then
                    local handler = castbar.castbarOnUpdate or castbar.bossOnUpdate
                    castbar:SetScript("OnUpdate", handler)
                end
            else
                -- No preview mode - hide
                if castbar.isPreviewSimulation then
                    ClearPreviewSimulation(castbar)
                end
                castbar:SetScript("OnUpdate", nil)
                castbar:Hide()
            end
        end
    end)
end

---------------------------------------------------------------------------
-- UNIFIED CASTBAR SETUP (handles player, target, focus, targettarget)
---------------------------------------------------------------------------
function QUI_Castbar:SetupCastbar(castbar, unit, unitKey, castSettings)
    local isPlayer = (unit == "player")
    
    -- Unified OnUpdate handler - handles both real casts and preview
    local function CastBar_OnUpdate(self, elapsed)
        -- Check if actually casting (real cast takes priority)
        local spellName = UnitCastingInfo(self.unit)
        local channelName = UnitChannelInfo(self.unit)
        
        -- For empowered spells, continue showing castbar during hold phase even if API returns nil
        local isInEmpoweredHold = isPlayer and self.isEmpowered and self.startTime and self.endTime
        
        if spellName or channelName or isInEmpoweredHold then
            -- Real cast - use real cast data
            -- Normalize time units: convert milliseconds to seconds for unified handling
            local startTime, endTime
            if isPlayer then
                startTime = self.startTime
                endTime = self.endTime
            else
                -- Target/focus uses milliseconds, convert to seconds
                if not self.castStartTime or not self.castEndTime then
                    self:SetScript("OnUpdate", nil)
                    self:Hide()
                    return
                end
                startTime = self.castStartTime / 1000
                endTime = self.castEndTime / 1000
            end
            
            if not startTime or not endTime then
                self:SetScript("OnUpdate", nil)
                self:Hide()
                return
            end
            
            local now = GetTime()
            if now >= endTime then
                if isPlayer then
                    ClearEmpoweredState(self)
                    if self.empoweredLevelText then
                        self.empoweredLevelText:SetText("")
                    end
                end
                self:SetScript("OnUpdate", nil)
                self:Hide()
                return
            end
            
            local duration = endTime - startTime
            if duration <= 0 then duration = 0.001 end
            
            self.statusBar:SetReverseFill(false)
            
            local progress = now - startTime
            local remaining = endTime - now
            
            self.statusBar:SetMinMaxValues(0, duration)
            self.statusBar:SetValue(progress)
            
            -- Empowered cast handling (player only)
            if isPlayer and self.isEmpowered then
                UpdateEmpoweredFillColor(self, progress, duration)
                
                -- Update empowered level text
                if self.empoweredLevelText and self.showEmpoweredLevel then
                    local currentStage, maxStages, isEmpowered = QUI_Castbar:GetEmpoweredLevel()
                    if isEmpowered and currentStage then
                        self.textThrottle = (self.textThrottle or 0) + elapsed
                        if self.textThrottle >= 0.1 then
                            self.textThrottle = 0
                            self.empoweredLevelText:SetText(tostring(math.floor(currentStage)))
                            UpdateTimeTextColor(self, self.unit)
                        end
                    else
                        self.empoweredLevelText:SetText("")
                    end
                elseif self.empoweredLevelText then
                    self.empoweredLevelText:SetText("")
                end
                
                -- Update time text visibility if hiding on empowered
                local currentSettings = GetUnitSettings(self.unitKey)
                local currentCastSettings = currentSettings and currentSettings.castbar
                if currentCastSettings and currentCastSettings.hideTimeTextOnEmpowered then
                    if self.timeText then
                        self.timeText:Hide()
                    end
                end
            elseif isPlayer and self.empoweredLevelText then
                self.empoweredLevelText:SetText("")
                
                -- Show time text again if not empowered
                local currentSettings = GetUnitSettings(self.unitKey)
                local currentCastSettings = currentSettings and currentSettings.castbar
                if currentCastSettings and currentCastSettings.showTimeText and self.timeText then
                    self.timeText:Show()
                end
            end
            
            -- Update time text (throttle to 10 FPS) - only if not hiding on empowered
            if isPlayer and self.isEmpowered then
                local currentSettings = GetUnitSettings(self.unitKey)
                local currentCastSettings = currentSettings and currentSettings.castbar
                if not (currentCastSettings and currentCastSettings.hideTimeTextOnEmpowered) then
                    if UpdateThrottledText(self, elapsed, self.timeText, remaining) and remaining > 0 then
                        UpdateTimeTextColor(self, self.unit)
                    end
                end
            else
                if UpdateThrottledText(self, elapsed, self.timeText, remaining) and remaining > 0 and isPlayer then
                    UpdateTimeTextColor(self, self.unit)
                end
            end
        elseif self.isPreviewSimulation then
            -- Preview simulation - use preview data
            if not self.previewStartTime or not self.previewEndTime then
                return
            end
            
            local now = GetTime()
            if now >= self.previewEndTime then
                -- Loop preview animation
                self.previewStartTime = now
                self.previewEndTime = now + self.previewMaxValue
                self.previewValue = 0
            end
            
            self.previewValue = self.previewValue + elapsed
            local progress = math.min(self.previewValue, self.previewMaxValue)
            local remaining = self.previewMaxValue - progress
            
            self.statusBar:SetValue(progress)
            
            UpdateThrottledText(self, elapsed, self.timeText, remaining)
        else
            -- No cast and no preview - hide
            self:SetScript("OnUpdate", nil)
            self:Hide()
        end
    end
    
    -- Store OnUpdate handler reference
    castbar.castbarOnUpdate = CastBar_OnUpdate
    
    -- Unified Cast function
    function castbar:Cast(spellID, isEmpowerEvent)
        -- Get cast information
        local spellName, text, texture, startTimeMS, endTimeMS, notInterruptible, unitSpellID, isChanneled, channelStages = GetCastInfo(self, self.unit)
        
        -- Detect empowered cast (player only)
        local isEmpowered, numStages = DetectEmpoweredCast(isPlayer, spellID, unitSpellID, isEmpowerEvent, isChanneled, channelStages)
        
        -- If actually casting, show real cast
        -- Validate that startTimeMS and endTimeMS are valid numbers before arithmetic
        if spellName and startTimeMS and endTimeMS and type(startTimeMS) == "number" and type(endTimeMS) == "number" then
            -- Clear preview simulation if active
            if self.isPreviewSimulation then
                ClearPreviewSimulation(self)
            end
            
            -- Normalize time to seconds
            local startTime = startTimeMS / 1000
            local endTime = endTimeMS / 1000
            
            -- Adjust end time for empowered hold time
            endTime = AdjustEmpoweredEndTime(self, isPlayer, isEmpowered, endTime)
            
            -- Store times and cast state
            StoreCastTimes(self, isPlayer, startTimeMS, endTimeMS, startTime, endTime)
            self.isChanneled = isChanneled
            self.isEmpowered = isEmpowered
            self.numStages = numStages or 0
            self.notInterruptible = notInterruptible
            
            -- Set icon texture IMMEDIATELY (exactly like Blizzard: if Icon exists, SetTexture)
            -- Blizzard does: if ( self.Icon ) then self.Icon:SetTexture(texture); end
            if SetIconTexture(self, texture) then
                -- Only show icon if showIcon is enabled
                if ShouldShowIcon(self, castSettings) then
                    self.icon:Show()
                else
                    self.icon:Hide()
                end
            end
            
            -- Update visual elements
            UpdateCastbarVisuals(self, castSettings, self.unitKey, texture, text, spellName, self.unit, isChanneled, notInterruptible, startTime, endTime, isEmpowered)
            
            -- Store showEmpoweredLevel setting for OnUpdate
            if isPlayer then
                self.showEmpoweredLevel = castSettings.showEmpoweredLevel
            end
            
            -- Update empowered state
            UpdateEmpoweredState(self, isPlayer, isEmpowered, numStages)
            
            -- Update spell text visibility if hiding on empowered
            if isPlayer and self.spellText then
                UpdateCastbarElements(self, self.unitKey, castSettings)
            end
            
            -- Start OnUpdate handler and show
            self:SetScript("OnUpdate", CastBar_OnUpdate)
            self:Show()
        else
            -- No real cast - handle preview mode
            HandleNoCast(self, castSettings, isPlayer, CastBar_OnUpdate)
        end
    end
    
    -- Event dispatch table (cleaner than if-elseif chain)
    local eventHandlers = {
        -- Target/focus change events
        PLAYER_TARGET_CHANGED = function(self) self:Cast() end,
        PLAYER_FOCUS_CHANGED = function(self) self:Cast() end,
        UNIT_TARGET = function(self) self:Cast() end,
        
        -- Cast start events
        UNIT_SPELLCAST_START = function(self, spellID) self:Cast(spellID, false) end,
        UNIT_SPELLCAST_CHANNEL_START = function(self, spellID) self:Cast(spellID, false) end,
        
        -- Cast end events (clear empowered state for player)
        UNIT_SPELLCAST_STOP = function(self, spellID)
            if isPlayer then ClearEmpoweredState(self) end
            self:Cast(spellID, false)
        end,
        UNIT_SPELLCAST_CHANNEL_STOP = function(self, spellID)
            if isPlayer then ClearEmpoweredState(self) end
            self:Cast(spellID, false)
        end,
        UNIT_SPELLCAST_FAILED = function(self, spellID)
            if isPlayer then ClearEmpoweredState(self) end
            self:Cast(spellID, false)
        end,
        UNIT_SPELLCAST_INTERRUPTED = function(self, spellID)
            if isPlayer then ClearEmpoweredState(self) end
            self:Cast(spellID, false)
        end,
        
        -- Interruptible state changes
        UNIT_SPELLCAST_INTERRUPTIBLE = function(self)
            ApplyCastColor(self.statusBar, false, self.customColor)
        end,
        UNIT_SPELLCAST_NOT_INTERRUPTIBLE = function(self)
            ApplyCastColor(self.statusBar, true, self.customColor)
        end,
    }
    
    -- Player-only empowered cast handlers
    if isPlayer then
        eventHandlers.UNIT_SPELLCAST_EMPOWER_START = function(self, spellID)
            self:Cast(spellID, true)
        end
        eventHandlers.UNIT_SPELLCAST_EMPOWER_UPDATE = function(self, spellID)
            self:Cast(spellID, true)
        end
        eventHandlers.UNIT_SPELLCAST_EMPOWER_STOP = function(self, spellID)
            local name = UnitCastingInfo(self.unit)
            ClearEmpoweredState(self)
            if name then
                self:Cast(spellID, false)
            else
                self:SetScript("OnUpdate", nil)
                self:Hide()
            end
        end
    end
    
    -- Register common events
    castbar:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
    castbar:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit)
    castbar:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", unit)
    castbar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
    castbar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit)
    castbar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", unit)
    castbar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", unit)
    castbar:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", unit)
    
    -- Player-specific events (empowered casts)
    if isPlayer then
        castbar:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", unit)
        castbar:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", unit)
        castbar:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", unit)
    end
    
    -- Target/focus-specific events
    if unit == "target" then
        castbar:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif unit == "focus" then
        castbar:RegisterEvent("PLAYER_FOCUS_CHANGED")
    elseif unit == "targettarget" then
        castbar:RegisterEvent("PLAYER_TARGET_CHANGED")
        castbar:RegisterUnitEvent("UNIT_TARGET", "target")
    end
    
    -- Unified event handler using dispatch table
    castbar:SetScript("OnEvent", function(self, event, eventUnit, castGUID, spellID)
        local handler = eventHandlers[event]
        if handler then
            handler(self, spellID)
        end
    end)
end

-- Legacy function names for backwards compatibility (now just call unified setup)
function QUI_Castbar:SetupTargetFocusCastbar(castbar, unit, unitKey, castSettings)
    self:SetupCastbar(castbar, unit, unitKey, castSettings)
end

function QUI_Castbar:SetupPlayerCastbar(castbar, unit, unitKey, castSettings)
    self:SetupCastbar(castbar, unit, unitKey, castSettings)
end

---------------------------------------------------------------------------
-- BOSS CASTBAR SETUP
---------------------------------------------------------------------------
function QUI_Castbar:SetupBossCastbar(castbar, unit, bossIndex, castSettings)
    -- Unified OnUpdate handler - handles both real casts and preview
    local function CastBar_OnUpdate(self, elapsed)
        -- Check if actually casting (real cast takes priority)
        local spellName = UnitCastingInfo(self.unit)
        local channelName = UnitChannelInfo(self.unit)
        
        if spellName or channelName then
            -- Real cast - use real cast data
            if not self.startTime or not self.endTime then return end
            
            local now = GetTime()
            if now >= self.endTime then
                ClearEmpoweredState(self)
                self:SetScript("OnUpdate", nil)
                self:Hide()
                return
            end
            
            local duration = self.endTime - self.startTime
            if duration <= 0 then duration = 0.001 end
            
            self.statusBar:SetReverseFill(false)
            
            local progress = now - self.startTime
            
            self.statusBar:SetMinMaxValues(0, duration)
            self.statusBar:SetValue(progress)
            
            if self.isEmpowered then
                UpdateEmpoweredFillColor(self, progress, duration)
            end
            
            if UpdateThrottledText(self, elapsed, self.timeText, remaining) and remaining > 0 then
                UpdateTimeTextColor(self, self.unit)
            end
        elseif self.isPreviewSimulation then
            -- Preview simulation - use preview data
            if not self.previewStartTime or not self.previewEndTime then
                return
            end
            
            local now = GetTime()
            if now >= self.previewEndTime then
                -- Loop preview animation
                self.previewStartTime = now
                self.previewEndTime = now + self.previewMaxValue
                self.previewValue = 0
            end
            
            self.previewValue = self.previewValue + elapsed
            local progress = math.min(self.previewValue, self.previewMaxValue)
            local remaining = self.previewMaxValue - progress
            
            self.statusBar:SetValue(progress)
            
            UpdateThrottledText(self, elapsed, self.timeText, remaining)
        else
            -- No cast and no preview - hide
            self:SetScript("OnUpdate", nil)
            self:Hide()
        end
    end
    
    -- Store OnUpdate handler reference
    castbar.playerOnUpdate = CastBar_OnUpdate
    
    -- Cast function for player
    function castbar:Cast(spellID, isEmpowerEvent)
        -- Check if actually casting
        local spellName, text, texture, startTimeMS, endTimeMS, _, _, notInterruptible, unitSpellID = UnitCastingInfo(self.unit)
        local isChanneled = false
        local isEmpowered = isEmpowerEvent or false
        local numStages = 0
        
        if not spellName then
            local channelName, _, channelTex, channelStart, channelEnd, _, channelNotInt, _, _, channelStages = UnitChannelInfo(self.unit)
            if channelName then
                spellName = channelName
                texture = channelTex
                startTimeMS = channelStart
                endTimeMS = channelEnd
                notInterruptible = channelNotInt
                isChanneled = true
                if isEmpowerEvent and channelStages and channelStages > 0 then
                    numStages = channelStages
                end
            end
        end
        
        local checkSpellID = spellID or unitSpellID
        if checkSpellID and C_Spell and C_Spell.GetSpellEmpowerInfo then
            local empowerInfo = C_Spell.GetSpellEmpowerInfo(checkSpellID)
            if empowerInfo and empowerInfo.numStages and empowerInfo.numStages > 0 then
                isEmpowered = true
                numStages = empowerInfo.numStages
            end
        end
        
        if spellName and startTimeMS and endTimeMS and type(startTimeMS) == "number" and type(endTimeMS) == "number" then
            local startTime = startTimeMS / 1000
            local endTime = endTimeMS / 1000
            
            if isEmpowered and GetUnitEmpowerHoldAtMaxTime then
                local ok, adjustedEndTime = pcall(function()
                    local ht = GetUnitEmpowerHoldAtMaxTime(self.unit)
                    if ht and ht > 0 then
                        return endTime + (ht / 1000)
                    end
                    return endTime
                end)
                if ok and adjustedEndTime then
                    endTime = adjustedEndTime
                end
            end
            
            local now = GetTime()
            self.startTime = startTime
            self.endTime = endTime
            self.isChanneled = isChanneled
            self.isEmpowered = isEmpowered
            self.numStages = numStages or 0
            self.notInterruptible = notInterruptible
            
            -- Ensure status bar has texture
            local currentSettings = GetUnitSettings(self.unitKey)
            local currentCastSettings = currentSettings and currentSettings.castbar or castSettings
            if self.statusBar then
                self.statusBar:SetStatusBarTexture(GetTexturePath(currentCastSettings.texture))
            end
            
            -- Set icon texture and show it
            if SetIconTexture(self, texture) then
                -- Only show icon if showIcon is enabled
                local currentSettings = GetUnitSettings(self.unitKey)
                local currentCastSettings = currentSettings and currentSettings.castbar or castSettings
                if ShouldShowIcon(self, currentCastSettings) then
                    self.icon:Show()
                else
                    self.icon:Hide()
                end
            end
            
            UpdateSpellText(self, text, spellName, castSettings, self.unit)
            
            self.statusBar:SetReverseFill(false)
            
            ApplyCastColor(self.statusBar, notInterruptible, self.customColor)
            
            if isEmpowered and numStages and numStages > 0 then
                UpdateEmpoweredStages(self, numStages)
            else
                ClearEmpoweredState(self)
            end
            
            -- Clear preview simulation if active
            if self.isPreviewSimulation then
                ClearPreviewSimulation(self)
            end
            
            -- Start OnUpdate handler
            self:SetScript("OnUpdate", CastBar_OnUpdate)
            self:Show()
        else
            -- No real cast - check if preview mode is enabled
            C_Timer.After(0.1, function()
                if not UnitCastingInfo(self.unit) and not UnitChannelInfo(self.unit) then
                    ClearEmpoweredState(self)
                    local settings = GetUnitSettings(self.unitKey)
                    if settings and settings.castbar and settings.castbar.previewMode then
                        -- Show preview simulation
                        SimulateCast(self, castSettings, self.unitKey)
                        self:SetScript("OnUpdate", CastBar_OnUpdate)
                    else
                        -- No preview mode - hide
                        if self.isPreviewSimulation then
                            ClearPreviewSimulation(self)
                        end
                        self:SetScript("OnUpdate", nil)
                        self:Hide()
                    end
                end
            end)
        end
    end
    
    -- Register events
    castbar:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
    castbar:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit)
    castbar:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", unit)
    castbar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
    castbar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit)
    castbar:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", unit)
    castbar:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", unit)
    castbar:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", unit)
    castbar:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", unit)
    castbar:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", unit)
    castbar:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", unit)
    
    castbar:SetScript("OnEvent", function(self, event, eventUnit, castGUID, spellID)
        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
            self:Cast(spellID, false)
        elseif event == "UNIT_SPELLCAST_EMPOWER_START" then
            self:Cast(spellID, true)
        elseif event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
            self:Cast(spellID, true)
        elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
            local name = UnitCastingInfo(self.unit)
            if name then
                ClearEmpoweredState(self)
                self:Cast(spellID, false)
            else
                ClearEmpoweredState(self)
                self:SetScript("OnUpdate", nil)
                self:Hide()
            end
        elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP"
            or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
            ClearEmpoweredState(self)
            self:Cast(spellID, false)
        elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
            ApplyCastColor(self.statusBar, false, self.customColor)
        elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            ApplyCastColor(self.statusBar, true, self.customColor)
        end
    end)
end

---------------------------------------------------------------------------
-- CREATE: Boss Castbar
---------------------------------------------------------------------------
function QUI_Castbar:CreateBossCastbar(unitFrame, unit, bossIndex)
    local settings = GetUnitSettings("boss")
    if not settings or not settings.castbar or not settings.castbar.enabled then
        return nil
    end
    
    local castSettings = settings.castbar
    InitializeDefaultSettings(castSettings)
    
    -- Initial size (temporary - layout manager will apply correct size when frame is registered)
    -- Don't read from castSettings - layout manager is the source of truth
    local iconSize = Scale((castSettings.iconSize and castSettings.iconSize > 0) and castSettings.iconSize or 25)
    local iconScale = castSettings.iconScale or 1.0
    local borderSize = Scale(castSettings.borderSize or 1)
    local iconBorderSize = Scale(castSettings.iconBorderSize or 1)
    local fontSize = castSettings.fontSize or 12
    
    -- Create anchor frame (outer frame for positioning/sizing)
    local anchorFrame = CreateAnchorFrame("QUI_Boss" .. bossIndex .. "_Castbar", UIParent)
    -- Set minimal initial size - layout manager will apply correct size
    anchorFrame:SetSize(Scale(250), Scale(25))
    
    -- Store unitKey and bossIndex on frame for reference
    anchorFrame.unitKey = "boss" .. bossIndex
    anchorFrame.bossIndex = bossIndex
    
    -- Use layout manager for positioning
    if QUI_LayoutManager then
        -- Prepare edit mode configuration for boss castbar
        local unitKeyForEdit = "boss" .. bossIndex
        local label = "Boss " .. bossIndex .. " Castbar"
        local castbarFrameKey = "castbars." .. unitKeyForEdit
        
        -- Register with layout manager - handles migration, defaults, and positioning
        -- Layout manager is the source of truth for all anchor, offset, width, and height settings
        QUI_LayoutManager:RegisterFrame(anchorFrame, castbarFrameKey, "castbars", {
            parentFrame = unitFrame,
            editMode = {
                label = label,
                elementKey = unitKeyForEdit,
                skipKeyboardEnable = false,
                elementType = "castbar",  -- For selection handling
            },
        })
        -- Note: Layout is already applied by RegisterFrame, including all positioning and sizing
    end
    
    -- Create UI elements (icon with integrated border) - parented to anchorFrame
    CreateIcon(anchorFrame, iconSize, iconBorderSize, castSettings.iconBorderColor)
    local statusBar = CreateStatusBar(anchorFrame)
    
    -- Create border for status bar (parented to statusBar)
    CreateStatusBarBorder(statusBar, borderSize, castSettings.borderColor)
    
    local bgBar = CreateBackgroundBar(statusBar)
    anchorFrame.bgBar = bgBar
    
    local spellText = CreateTextElement(statusBar, fontSize)
    spellText:SetPoint("LEFT", statusBar, "LEFT", Scale(4), 0)
    spellText:SetJustifyH("LEFT")
    anchorFrame.spellText = spellText
    
    local timeText = CreateTextElement(statusBar, fontSize)
    timeText:SetPoint("RIGHT", statusBar, "RIGHT", -4, 0)
    timeText:SetJustifyH("RIGHT")
    anchorFrame.timeText = timeText
    
    -- Set up UpdateCastbarElements function
    anchorFrame.UpdateCastbarElements = function(self)
        UpdateCastbarElements(self, "boss", castSettings)
    end
    
    -- Apply colors and textures
    local barColor = castSettings.color or {1, 0.7, 0, 1}
    anchorFrame.customColor = barColor
    ApplyBarColor(statusBar, barColor)
    ApplyBackgroundColor(bgBar, castSettings.bgColor)
    statusBar:SetStatusBarTexture(GetTexturePath(castSettings.texture))
    
    -- Update element positions
    UpdateCastbarElements(anchorFrame, "boss", castSettings)
    
    -- Store unit info
    anchorFrame.unit = unit
    anchorFrame.unitKey = "boss" .. bossIndex
    anchorFrame.bossIndex = bossIndex
    
    -- Store castbar in unit frames module's castbars table for edit mode access
    local QUI_UF = self.unitFramesModule
    if QUI_UF and QUI_UF.castbars then
        local bossKey = "boss" .. bossIndex
        QUI_UF.castbars[bossKey] = anchorFrame
    end
    anchorFrame.bossIndex = bossIndex
    anchorFrame.isChanneled = false
    
    -- Unified OnUpdate handler - handles both real casts and preview
    local function BossCastBar_OnUpdate(self, elapsed)
        -- Check if actually casting (real cast takes priority)
        local spellName = UnitCastingInfo(self.unit)
        local channelName = UnitChannelInfo(self.unit)
        
        if spellName or channelName then
            -- Real cast - use real cast data
            if not self.startTime or not self.endTime then return end
            
            local ufdb = GetDB()
            local uncapped = ufdb and ufdb.general and ufdb.general.smootherAnimation
            
            if not uncapped then
                self.updateElapsed = (self.updateElapsed or 0) + elapsed
                if self.updateElapsed < 0.0167 then return end
                self.updateElapsed = 0
            end
            
            local now = GetTime()
            if now >= self.endTime then
                self:SetScript("OnUpdate", nil)
                self:Hide()
                return
            end
            
            local duration = self.endTime - self.startTime
            if duration <= 0 then return end
            
            self.statusBar:SetReverseFill(false)
            
            local progress = (now - self.startTime) / duration
            
            self.statusBar:SetMinMaxValues(0, 1)
            self.statusBar:SetValue(math.max(0, math.min(1, progress)))
            
            local remaining = self.endTime - now
            if self.timeText then
                self.timeText:SetText(string.format("%.1f", remaining))
                UpdateTimeTextColor(self, self.unit)
            end
        elseif self.isPreviewSimulation then
            -- Preview simulation - use preview data
            if not self.previewStartTime or not self.previewEndTime then
                return
            end
            
            local now = GetTime()
            if now >= self.previewEndTime then
                -- Loop preview animation
                self.previewStartTime = now
                self.previewEndTime = now + self.previewMaxValue
                self.previewValue = 0
            end
            
            self.previewValue = self.previewValue + elapsed
            local progress = math.min(self.previewValue, self.previewMaxValue)
            local remaining = self.previewMaxValue - progress
            
            self.statusBar:SetValue(progress)
            
            UpdateThrottledText(self, elapsed, self.timeText, remaining)
        else
            -- No cast and no preview - hide
            self:SetScript("OnUpdate", nil)
            self:Hide()
        end
    end
    
    -- Store OnUpdate handler reference
    anchorFrame.bossOnUpdate = BossCastBar_OnUpdate
    
    -- Cast function
    function anchorFrame:Cast()
        -- Check if actually casting
        local spellName, text, texture, startTimeMS, endTimeMS, _, _, notInterruptible = UnitCastingInfo(self.unit)
        local isChanneled = false
        
        if not spellName then
            spellName, text, texture, startTimeMS, endTimeMS, _, notInterruptible = UnitChannelInfo(self.unit)
            isChanneled = true
        end
        
        -- If actually casting, show real cast (preview is hidden during real casts)
        if spellName and startTimeMS and endTimeMS and type(startTimeMS) == "number" and type(endTimeMS) == "number" then
            -- Clear preview simulation
            if self.isPreviewSimulation then
                ClearPreviewSimulation(self)
            end
            local startTime = startTimeMS / 1000
            local endTime = endTimeMS / 1000
            
            local now = GetTime()
            self.startTime = startTime
            self.endTime = endTime
            self.isChanneled = isChanneled
            self.notInterruptible = notInterruptible
            
            if self.startTime < now - 5 then
                local dur = (endTimeMS - startTimeMS) / 1000
                self.startTime = now
                self.endTime = now + dur
            end
            
            -- Ensure status bar has texture
            local currentSettings = GetUnitSettings(self.unitKey)
            local currentCastSettings = currentSettings and currentSettings.castbar or castSettings
            if self.statusBar then
                self.statusBar:SetStatusBarTexture(GetTexturePath(currentCastSettings.texture))
            end
            
            -- Set icon texture and show it
            if SetIconTexture(self, texture) then
                -- Only show icon if showIcon is enabled
                local currentSettings = GetUnitSettings(self.unitKey)
                local currentCastSettings = currentSettings and currentSettings.castbar or castSettings
                if ShouldShowIcon(self, currentCastSettings) then
                    self.icon:Show()
                else
                    self.icon:Hide()
                end
            end
            
            UpdateSpellText(self, text, spellName, castSettings, self.unit)
            
            self.statusBar:SetReverseFill(false)
            
            ApplyCastColor(self.statusBar, notInterruptible, self.customColor)
            
            -- Start OnUpdate handler
            self:SetScript("OnUpdate", BossCastBar_OnUpdate)
            self:Show()
        else
            -- No real cast - check if preview mode is enabled
            C_Timer.After(0.1, function()
                if not UnitCastingInfo(self.unit) and not UnitChannelInfo(self.unit) then
                    local settings = GetUnitSettings(self.unitKey)
                    if settings and settings.castbar and settings.castbar.previewMode then
                        -- Show preview simulation
                        SimulateCast(self, castSettings, "boss", self.bossIndex)
                        self:SetScript("OnUpdate", BossCastBar_OnUpdate)
                    else
                        -- No preview mode - hide
                        if self.isPreviewSimulation then
                            ClearPreviewSimulation(self)
                        end
                        self:SetScript("OnUpdate", nil)
                        self:Hide()
                    end
                end
            end)
        end
    end
    
    -- Register events
    anchorFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
    anchorFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit)
    anchorFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", unit)
    anchorFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
    anchorFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit)
    anchorFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", unit)
    anchorFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", unit)
    anchorFrame:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", unit)
    anchorFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", unit)
    
    anchorFrame:SetScript("OnEvent", function(self, event, eventUnit)
        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
            self:Cast()
        elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" 
            or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED"
            or event == "UNIT_SPELLCAST_SUCCEEDED" then
            self:Cast()
        elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
            ApplyCastColor(self.statusBar, false, self.customColor)
        elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            ApplyCastColor(self.statusBar, true, self.customColor)
        end
    end)
    
    -- Apply preview if enabled and start OnUpdate
    if castSettings.previewMode then
        SimulateCast(anchorFrame, castSettings, "boss", bossIndex)
        -- Start OnUpdate handler for preview
        if anchorFrame.bossOnUpdate then
            anchorFrame:SetScript("OnUpdate", anchorFrame.bossOnUpdate)
        end
    end
    
    return anchorFrame
end

---------------------------------------------------------------------------
-- GLOBAL FUNCTIONS
---------------------------------------------------------------------------
QUI_Castbar.unitFramesModule = nil

function QUI_Castbar:SetUnitFramesModule(ufModule)
    self.unitFramesModule = ufModule
    if ufModule and ufModule.castbars then
        self.castbars = ufModule.castbars
    end
end

_G.QuaziiUI_ShowCastbarPreview = function(unitKey)
    local settings = GetUnitSettings(unitKey)
    if not settings or not settings.castbar then
        return
    end
    
    settings.castbar.previewMode = true
    
    -- Refresh the frame to apply preview
    local QUI_UF = QUI_Castbar.unitFramesModule
    if QUI_UF then
        QUI_UF:RefreshFrame(unitKey)
    end
end

_G.QuaziiUI_HideCastbarPreview = function(unitKey)
    local settings = GetUnitSettings(unitKey)
    if not settings or not settings.castbar then
        return
    end
    
    settings.castbar.previewMode = false
    
    -- Refresh the frame to clear preview
    local QUI_UF = QUI_Castbar.unitFramesModule
    if QUI_UF then
        QUI_UF:RefreshFrame(unitKey)
    end
end

---------------------------------------------------------------------------
-- DESTROY: Clean up a castbar
---------------------------------------------------------------------------
local function DestroyCastbar(castbar)
    if not castbar then return end
    
    castbar:SetScript("OnUpdate", nil)
    castbar:SetScript("OnEvent", nil)
    castbar:SetScript("OnDragStart", nil)
    castbar:SetScript("OnDragStop", nil)
    
    castbar:Hide()
    castbar:ClearAllPoints()
end

---------------------------------------------------------------------------
-- REFRESH: Update castbar in place (preserves active casts)
---------------------------------------------------------------------------
function QUI_Castbar:RefreshCastbar(castbar, unitKey, castSettings, unitFrame)
    if not castbar then return end
    
    -- Get current settings (in case they changed)
    local currentSettings = GetUnitSettings(unitKey)
    local currentCastSettings = currentSettings and currentSettings.castbar or castSettings
    
    if not currentCastSettings then return end
    
    -- Handle enabled/disabled state
    if not currentCastSettings.enabled then
        -- Castbar is disabled - hide it and clear preview
        if castbar.isPreviewSimulation then
            ClearPreviewSimulation(castbar)
        end
        castbar:SetScript("OnUpdate", nil)
        castbar:Hide()
        return
    end
    
    -- Update colors
    local barColor = GetBarColor(unitKey, currentCastSettings)
    castbar.customColor = barColor
    if castbar.statusBar then
        ApplyBarColor(castbar.statusBar, barColor)
        castbar.statusBar:SetStatusBarTexture(GetTexturePath(currentCastSettings.texture))
    end
    
    if castbar.bgBar then
        ApplyBackgroundColor(castbar.bgBar, currentCastSettings.bgColor)
    end
    
    -- Update font sizes for text elements
    local fontSize = currentCastSettings.fontSize or 12
    if castbar.spellText then
        castbar.spellText:SetFont(GetFontPath(), fontSize, GetFontOutline())
    end
    if castbar.timeText then
        castbar.timeText:SetFont(GetFontPath(), fontSize, GetFontOutline())
    end
    if castbar.empoweredLevelText then
        castbar.empoweredLevelText:SetFont(GetFontPath(), fontSize, GetFontOutline())
    end
    
    -- Update all element positions and visibility
    UpdateCastbarElements(castbar, unitKey, currentCastSettings)
    
    -- Handle preview mode
    local hasRealCast = UnitCastingInfo(castbar.unit) or UnitChannelInfo(castbar.unit)
    
    if not hasRealCast then
        -- No real cast active - handle preview mode
        if currentCastSettings.previewMode then
            -- Preview mode enabled - start preview if not already active
            if not castbar.isPreviewSimulation then
                SimulateCast(castbar, currentCastSettings, unitKey, castbar.bossIndex)
                -- Start OnUpdate handler for preview
                if castbar.castbarOnUpdate or castbar.bossOnUpdate then
                    local onUpdateHandler = castbar.castbarOnUpdate or castbar.bossOnUpdate
                    castbar:SetScript("OnUpdate", onUpdateHandler)
                end
            end
        else
            -- Preview mode disabled - stop preview if active
            if castbar.isPreviewSimulation then
                ClearPreviewSimulation(castbar)
            end
            castbar:SetScript("OnUpdate", nil)
            castbar:Hide()
        end
    end
    -- If there's a real cast, let the existing OnUpdate handler continue
end

function QUI_Castbar:RefreshBossCastbar(castbar, bossKey, castSettings, unitFrame)
    -- Boss castbars use the same refresh logic
    self:RefreshCastbar(castbar, bossKey, castSettings, unitFrame)
end

_G.QuaziiUI_RefreshCastbar = function(unitKey)
    local QUI_UF = QUI_Castbar.unitFramesModule
    if not QUI_UF then return end
    QUI_UF:RefreshFrame(unitKey)
end

---------------------------------------------------------------------------
-- EDIT MODE FUNCTIONS
---------------------------------------------------------------------------
QUI_Castbar.editModeActive = false

-- Helper function to enable edit mode for a single castbar
local function EnableEditModeForCastbar(castbar, castbarKey, unitKey)
    if not castbar or not QUI_LayoutManager then return end
    
    local settings = GetUnitSettings(unitKey)
    local castSettings = settings and settings.castbar
    if not castSettings or not castSettings.enabled then return end
    
    -- Enable preview mode for castbars in edit mode (so they're visible)
    if not castSettings.previewMode then
        castSettings.previewMode = true
        -- Start preview simulation if castbar exists
        if not UnitCastingInfo(castbar.unit) and not UnitChannelInfo(castbar.unit) then
            SimulateCast(castbar, castSettings, unitKey, castbar.bossIndex)
            if castbar.castbarOnUpdate or castbar.bossOnUpdate then
                local onUpdateHandler = castbar.castbarOnUpdate or castbar.bossOnUpdate
                castbar:SetScript("OnUpdate", onUpdateHandler)
            end
        end
    end
    
    -- Show the castbar (even if it was hidden)
    castbar:Show()
    
    local label = "Castbar"
    if unitKey then
        label = unitKey:gsub("^%l", string.upper):gsub("(%l)(%u)", "%1 %2") .. " Castbar"
    end
    
    -- No updateCallback needed - layout system handles positioning automatically
    -- Only refresh if internal elements need repositioning (not needed for simple castbars)
    local updateCallback = function()
        -- Layout system handles position/size changes automatically
        -- Only add refresh logic here if castbar has internal child elements that need repositioning
    end
    
    castbar._editModeCleanup = QUI_LayoutManager:EnableEditModeForFrame(
        castbar,
        updateCallback,
        label,
        castbarKey,
        false,  -- Don't skip keyboard enable
        "castbar"  -- Element type for selection
    )
end

function QUI_Castbar:EnableEditMode()
    if InCombatLockdown() then
        return
    end
    
    self.editModeActive = true
    
    -- Get castbars from unit frames module (castbars are stored there)
    local QUI_UF = self.unitFramesModule
    if not QUI_UF or not QUI_UF.castbars then
        return
    end
    
    -- Enable edit mode for all castbars using layout manager
    if not QUI_LayoutManager then
        return
    end
    
    for castbarKey, castbar in pairs(QUI_UF.castbars) do
        if castbar then
            local unitKey = castbar.unitKey or castbarKey
            EnableEditModeForCastbar(castbar, castbarKey, unitKey)
        end
    end
end

function QUI_Castbar:DisableEditMode()
    self.editModeActive = false
    
    -- Get castbars from unit frames module (castbars are stored there)
    local QUI_UF = self.unitFramesModule
    if not QUI_UF or not QUI_UF.castbars then
        return
    end
    
    for castbarKey, castbar in pairs(QUI_UF.castbars) do
        if castbar then
            local unitKey = castbar.unitKey or castbarKey
            
            -- Call cleanup function (handles overlay, drag tracking, keyboard nudging)
            if castbar._editModeCleanup then
                castbar._editModeCleanup()
                castbar._editModeCleanup = nil
            end
            
            -- Restore preview mode state (disable if it was only enabled for edit mode)
            -- Note: We don't automatically disable preview mode here because the user
            -- might have explicitly enabled it. The preview toggle in options controls this.
            -- However, if there's no real cast and preview mode is off, hide the castbar
            local settings = GetUnitSettings(unitKey)
            local castSettings = settings and settings.castbar
            if castSettings and not castSettings.previewMode then
                if not UnitCastingInfo(castbar.unit) and not UnitChannelInfo(castbar.unit) then
                    if castbar.isPreviewSimulation then
                        ClearPreviewSimulation(castbar)
                    end
                    castbar:SetScript("OnUpdate", nil)
                    castbar:Hide()
                end
            end
        end
    end
end

-- Global is set by unit frames module (qui_unitframes.lua) after initialization
-- _G.QuaziiUI_Castbars = QUI_UF.castbars (set in qui_unitframes.lua line 3951)
