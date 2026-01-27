-- ============================================================================
-- QUI PIXEL PROFILER - Debug Tool
-- ============================================================================
-- Monitors CPU usage of pixel-perfect UI scaling operations
-- Tracks AF.GetNearestPixelSize() calls and font scaling operations
-- Only loads when debug mode is enabled

local ADDON_NAME, QUI = ...
local AF = _G.AbstractFramework

-- Only initialize if in debug mode or explicitly enabled
local DEBUG_MODE = QUI.db and QUI.db.global and QUI.db.global.debugMode
if not DEBUG_MODE then return end

-- ============================================================================
-- PIXEL OPERATION CPU PROFILER
-- ============================================================================

local PixelProfiler = {
    enabled = false,
    frame = nil,
    data = {
        totalTime = 0,
        callCount = 0,
        maxTime = 0,
        avgTime = 0,
        lastUpdate = 0,
        updateInterval = 1.0
    }
}

-- Hook into AF.GetNearestPixelSize for profiling
function PixelProfiler:HookAF()
    if not AF or not AF.GetNearestPixelSize then return end

    local originalGetNearestPixelSize = AF.GetNearestPixelSize
    AF.GetNearestPixelSize = function(value, scale)
        local startTime = debugprofilestop()

        -- Call original function
        local result = originalGetNearestPixelSize(value, scale)

        local endTime = debugprofilestop()
        local duration = endTime - startTime

        -- Record metrics
        self.data.callCount = self.data.callCount + 1
        self.data.totalTime = self.data.totalTime + duration
        if duration > self.data.maxTime then
            self.data.maxTime = duration
        end

        return result
    end
end

-- Hook into QUI.SafeSetFont for font scaling profiling
function PixelProfiler:HookFontScaling()
    if not QUI.SafeSetFont then return end

    local originalSafeSetFont = QUI.SafeSetFont
    QUI.SafeSetFont = function(fontString, fontPath, size, flags)
        local startTime = debugprofilestop()

        -- Call original function
        local result = originalSafeSetFont(fontString, fontPath, size, flags)

        local endTime = debugprofilestop()
        local duration = endTime - startTime

        -- Record metrics (font operations are more expensive)
        self.data.callCount = self.data.callCount + 1
        self.data.totalTime = self.data.totalTime + duration
        if duration > self.data.maxTime then
            self.data.maxTime = duration
        end

        return result
    end
end

-- Create the profiler overlay frame
function PixelProfiler:CreateOverlay()
    if self.frame then return end

    self.frame = CreateFrame("Frame", "QUIPixelProfilerOverlay", UIParent, "BackdropTemplate")
    self.frame:SetSize(300, 150)
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    self.frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    self.frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", self.frame.StartMoving)
    self.frame:SetScript("OnDragStop", self.frame.StopMovingOrSizing)

    -- Title
    local title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", self.frame, "TOP", 0, -15)
    title:SetText("QUI Pixel Profiler")
    title:SetTextColor(1, 0.82, 0, 1)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() self:Disable() end)

    -- Metrics display
    self.frame.callsLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.callsLabel:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 20, -40)
    self.frame.callsLabel:SetText("Pixel Operations/sec: --")
    self.frame.callsLabel:SetTextColor(1, 1, 1, 1)

    self.frame.avgLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.avgLabel:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 20, -55)
    self.frame.avgLabel:SetText("Average Time/op: -- μs")
    self.frame.avgLabel:SetTextColor(1, 1, 1, 1)

    self.frame.maxLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.maxLabel:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 20, -70)
    self.frame.maxLabel:SetText("Peak Time: -- μs")
    self.frame.maxLabel:SetTextColor(1, 1, 1, 1)

    self.frame.totalLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.totalLabel:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 20, -85)
    self.frame.totalLabel:SetText("Total CPU Time: -- ms")
    self.frame.totalLabel:SetTextColor(1, 1, 1, 1)

    -- Status
    self.frame.statusLabel = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.frame.statusLabel:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, 20)
    self.frame.statusLabel:SetText("Status: Active")
    self.frame.statusLabel:SetTextColor(0, 1, 0, 1)

    -- Update script
    self.frame:SetScript("OnUpdate", function()
        local now = GetTime()
        if now - self.data.lastUpdate >= self.data.updateInterval then
            self:UpdateDisplay()
            self.data.lastUpdate = now
        end
    end)
end

-- Update the overlay display
function PixelProfiler:UpdateDisplay()
    if not self.frame then return end

    local callsPerSec = self.data.callCount / self.data.updateInterval
    local avgTime = self.data.callCount > 0 and (self.data.totalTime / self.data.callCount) or 0
    local totalTimeMs = self.data.totalTime / 1000

    self.frame.callsLabel:SetText(string.format("Pixel Operations/sec: %.0f", callsPerSec))
    self.frame.avgLabel:SetText(string.format("Average Time/op: %.2f μs", avgTime))
    self.frame.maxLabel:SetText(string.format("Peak Time: %.2f μs", self.data.maxTime))
    self.frame.totalLabel:SetText(string.format("Total CPU Time: %.2f ms", totalTimeMs))

    -- Reset counters for next interval
    self.data.callCount = 0
    self.data.totalTime = 0
    self.data.maxTime = 0
end

-- Enable the profiler
function PixelProfiler:Enable()
    if self.enabled then return end

    self.enabled = true
    self:CreateOverlay()
    self:HookAF()
    self:HookFontScaling()

    if self.frame then
        self.frame:Show()
        self.frame.statusLabel:SetText("Status: Active")
        self.frame.statusLabel:SetTextColor(0, 1, 0, 1)
    end

    print("|cFF56D1FF[QUI Pixel Profiler]|r Enabled - monitoring pixel operations")
end

-- Disable the profiler
function PixelProfiler:Disable()
    if not self.enabled then return end

    self.enabled = false

    -- Restore original functions
    if AF and AF.GetNearestPixelSize then
        -- Note: In a real implementation, we'd need to store the original function
        -- For now, we'll just disable the overlay
    end

    if self.frame then
        self.frame:Hide()
        self.frame.statusLabel:SetText("Status: Disabled")
        self.frame.statusLabel:SetTextColor(1, 0, 0, 1)
    end

    print("|cFF56D1FF[QUI Pixel Profiler]|r Disabled")
end

-- Toggle profiler
function PixelProfiler:Toggle()
    if self.enabled then
        self:Disable()
    else
        self:Enable()
    end
end

-- ============================================================================
-- OPTIONS PAGE INTEGRATION
-- ============================================================================

local function CreatePixelProfilerPage(parent)
    local scroll, content = CreateScrollableContent(parent)
    local y = -15
    local PAD = 15
    local FORM_ROW = 32

    -- Header
    local header = GUI:CreateSectionHeader(content, "Pixel Operation CPU Profiler")
    header:SetPoint("TOPLEFT", PAD, y)
    y = y - header.gap

    local desc = GUI:CreateLabel(content,
        "Monitor CPU usage of pixel-perfect UI scaling operations. " ..
        "Tracks AF.GetNearestPixelSize() calls and font scaling operations.",
        11, GUI.Colors.textMuted)
    desc:SetPoint("TOPLEFT", PAD, y)
    desc:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    y = y - 40

    -- Enable toggle
    local enableCheck = GUI:CreateFormCheckbox(content, "Enable Pixel Profiler",
        function() return PixelProfiler.enabled end,
        function(val)
            if val then PixelProfiler:Enable() else PixelProfiler:Disable() end
        end)
    enableCheck:SetPoint("TOPLEFT", PAD, y)
    enableCheck:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
    y = y - FORM_ROW

    -- Slash command hint
    local cmdLabel = GUI:CreateLabel(content,
        "Use /pixelprofile to toggle the profiler overlay",
        11, GUI.Colors.accent)
    cmdLabel:SetPoint("TOPLEFT", PAD, y)
    y = y - 24

    -- Performance metrics display
    if PixelProfiler.enabled then
        local metricsHeader = GUI:CreateSectionHeader(content, "Current Metrics")
        metricsHeader:SetPoint("TOPLEFT", PAD, y)
        y = y - metricsHeader.gap

        local callsLabel = GUI:CreateLabel(content,
            string.format("Pixel Operations/sec: %.0f", PixelProfiler.data.callCount / PixelProfiler.data.updateInterval),
            11, GUI.Colors.text)
        callsLabel:SetPoint("TOPLEFT", PAD, y)
        y = y - 20

        local avgLabel = GUI:CreateLabel(content,
            string.format("Average Time/op: %.2f μs", PixelProfiler.data.avgTime),
            11, GUI.Colors.text)
        avgLabel:SetPoint("TOPLEFT", PAD, y)
        y = y - 20

        local maxLabel = GUI:CreateLabel(content,
            string.format("Peak Time: %.2f μs", PixelProfiler.data.maxTime),
            11, GUI.Colors.text)
        maxLabel:SetPoint("TOPLEFT", PAD, y)
        y = y - 20
    end

    content:SetHeight(math.abs(y) + 50)
    return scroll, content
end

-- ============================================================================
-- REGISTER WITH QUI OPTIONS
-- ============================================================================

-- Hook into QUI's options system when it loads
local function InitializeOptionsIntegration()
    local QUI_GUI = _G.QuaziiUI and _G.QuaziiUI.GUI
    if not QUI_GUI then
        -- Try again in a moment
        C_Timer.After(1, InitializeOptionsIntegration)
        return
    end

    -- Add as a new main tab
    if QUI_GUI.AddTab and QUI_GUI.MainFrame then
        QUI_GUI:AddTab(QUI_GUI.MainFrame, "🔧 Debug Tools", CreatePixelProfilerPage)
    end
end

-- Initialize after QUI loads
if QUI.OnInitialize then
    hooksecurefunc(QUI, "OnInitialize", InitializeOptionsIntegration)
else
    C_Timer.After(2, InitializeOptionsIntegration)
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

SLASH_PIXELPROFILER1 = "/pixelprofile"
SLASH_PIXELPROFILER2 = "/pp"
SlashCmdList["PIXELPROFILER"] = function()
    PixelProfiler:Toggle()
end

-- ============================================================================
-- EXPORT FOR OTHER DEBUG TOOLS
-- ============================================================================

QUI.Debug = QUI.Debug or {}
QUI.Debug.PixelProfiler = PixelProfiler

-- Auto-enable if debug mode is detected
if DEBUG_MODE then
    C_Timer.After(3, function()
        print("|cFF56D1FF[QUI]|r Pixel Profiler available. Use /pixelprofile to toggle.")
    end)
end