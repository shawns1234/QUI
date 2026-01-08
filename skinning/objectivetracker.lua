local addonName, ns = ...

---------------------------------------------------------------------------
-- OBJECTIVE TRACKER SKINNING
-- Applies QUI color scheme with dynamic content-height backdrop
---------------------------------------------------------------------------

local FONT_FLAGS = "OUTLINE"

-- Debounce flag to prevent multiple concurrent backdrop updates
local pendingBackdropUpdate = false

-- Get settings
local function GetSettings()
    local QUICore = _G.QuaziiUI and _G.QuaziiUI.QUICore
    local settings = QUICore and QUICore.db and QUICore.db.profile and QUICore.db.profile.general
    return settings
end

-- Get skinning colors
local function GetColors()
    local QUI = _G.QuaziiUI
    local sr, sg, sb, sa = 0.2, 1.0, 0.6, 1
    local bgr, bgg, bgb, bga = 0.05, 0.05, 0.05, 0.95

    if QUI and QUI.GetSkinColor then
        sr, sg, sb, sa = QUI:GetSkinColor()
    end
    if QUI and QUI.GetSkinBgColor then
        bgr, bgg, bgb, bga = QUI:GetSkinBgColor()
    end

    return sr, sg, sb, sa, bgr, bgg, bgb, bga
end

-- List of tracker modules
local trackerModules = {
    "ScenarioObjectiveTracker",
    "UIWidgetObjectiveTracker",
    "CampaignQuestObjectiveTracker",
    "QuestObjectiveTracker",
    "AdventureObjectiveTracker",
    "AchievementObjectiveTracker",
    "MonthlyActivitiesObjectiveTracker",
    "ProfessionsRecipeTracker",
    "BonusObjectiveTracker",
    "WorldQuestObjectiveTracker",
}

-- Hide header background atlas (keep header text visible)
local function SkinTrackerHeader(header)
    if not header then return end
    if header.Background then
        header.Background:SetAtlas(nil)
        header.Background:SetAlpha(0)
    end
end

-- Sync QUI max height with Blizzard's editModeHeight so truncation matches backdrop
local function SyncBlizzardHeight()
    local TrackerFrame = _G.ObjectiveTrackerFrame
    if not TrackerFrame then return end

    local settings = GetSettings()
    local maxHeight = settings and settings.objectiveTrackerHeight or 600

    -- Set Blizzard's internal height so truncation happens at our max
    TrackerFrame.editModeHeight = maxHeight
    if TrackerFrame.UpdateHeight then
        TrackerFrame:UpdateHeight()
    end
end

-- Update backdrop to match content, respecting max height setting
local function UpdateBackdropAnchors()
    local TrackerFrame = _G.ObjectiveTrackerFrame
    if not TrackerFrame or not TrackerFrame.quiBackdrop then return end

    local settings = GetSettings()
    local maxHeight = settings and settings.objectiveTrackerHeight or 600

    -- Find the module with the lowest bottom (furthest down on screen)
    local bottomModule = nil
    local lowestBottom = math.huge

    for _, trackerName in ipairs(trackerModules) do
        local tracker = _G[trackerName]
        if tracker and tracker:IsShown() then
            -- Check if module has content (try GetContentsHeight first, fall back to GetHeight)
            local hasContent = false
            if tracker.GetContentsHeight then
                local contentHeight = tracker:GetContentsHeight()
                hasContent = contentHeight and contentHeight > 0
            end
            -- Fallback: check actual frame height if GetContentsHeight didn't work
            if not hasContent then
                local frameHeight = tracker:GetHeight()
                hasContent = frameHeight and frameHeight > 1
            end

            if hasContent then
                local bottom = tracker:GetBottom()
                if bottom and bottom < lowestBottom then
                    lowestBottom = bottom
                    bottomModule = tracker
                end
            end
        end
    end

    -- Re-anchor backdrop to match content bounds
    TrackerFrame.quiBackdrop:ClearAllPoints()
    TrackerFrame.quiBackdrop:SetPoint("TOPLEFT", TrackerFrame, "TOPLEFT", -15, 0)
    TrackerFrame.quiBackdrop:SetPoint("TOPRIGHT", TrackerFrame, "TOPRIGHT", 10, 0)

    if bottomModule then
        -- Calculate actual content height
        local trackerTop = TrackerFrame:GetTop() or 0
        local contentHeight = trackerTop - lowestBottom + 15  -- +15 for bottom padding

        if contentHeight > maxHeight then
            -- Content exceeds max height, use fixed height
            TrackerFrame.quiBackdrop:SetHeight(maxHeight)
        else
            -- Content fits, anchor to bottommost module
            TrackerFrame.quiBackdrop:SetPoint("BOTTOM", bottomModule, "BOTTOM", 0, -15)
        end
        TrackerFrame.quiBackdrop:Show()
    else
        -- No visible modules, hide backdrop
        TrackerFrame.quiBackdrop:Hide()
    end
end

-- Debounced backdrop update to prevent multiple concurrent timers
-- 0.15s delay allows Blizzard's layout pass to complete before we measure
local function ScheduleBackdropUpdate()
    if pendingBackdropUpdate then return end
    pendingBackdropUpdate = true
    C_Timer.After(0.15, function()
        pendingBackdropUpdate = false
        UpdateBackdropAnchors()
    end)
end

-- Apply QUI backdrop
local function ApplyQUIBackdrop(trackerFrame, sr, sg, sb, sa, bgr, bgg, bgb, bga)
    if not trackerFrame then return end

    -- Hide Blizzard's NineSlice
    if trackerFrame.NineSlice then
        trackerFrame.NineSlice:SetAlpha(0)
    end

    -- Create QUI backdrop (anchors will be set by UpdateBackdropAnchors)
    if not trackerFrame.quiBackdrop then
        trackerFrame.quiBackdrop = CreateFrame("Frame", nil, trackerFrame, "BackdropTemplate")
        trackerFrame.quiBackdrop:SetFrameLevel(math.max(trackerFrame:GetFrameLevel() - 1, 0))
        trackerFrame.quiBackdrop:EnableMouse(false)
    end

    trackerFrame.quiBackdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    trackerFrame.quiBackdrop:SetBackdropColor(bgr, bgg, bgb, bga)
    trackerFrame.quiBackdrop:SetBackdropBorderColor(sr, sg, sb, sa)

    -- Set initial anchors
    UpdateBackdropAnchors()
end

-- Get font path
local function GetFontPath()
    local QUI = _G.QuaziiUI
    return QUI and QUI.GetGlobalFont and QUI:GetGlobalFont() or STANDARD_TEXT_FONT
end

-- Apply font to a single line (objective text)
local function StyleLine(line, fontPath, textFontSize)
    if not line then return end
    if line.Text then
        line.Text:SetFont(fontPath, textFontSize, FONT_FLAGS)
    end
    if line.Dash then
        line.Dash:SetFont(fontPath, textFontSize, FONT_FLAGS)
    end
end

-- Apply font to a block (quest name header + all objective lines)
local function StyleBlock(block, fontPath, titleFontSize, textFontSize)
    if not block then return end

    -- Style block header (quest/achievement title)
    if titleFontSize > 0 and block.HeaderText then
        block.HeaderText:SetFont(fontPath, titleFontSize, FONT_FLAGS)
    end

    -- Style all lines in the block (objectives)
    if textFontSize > 0 and block.usedLines then
        for _, line in pairs(block.usedLines) do
            StyleLine(line, fontPath, textFontSize)
        end
    end
end

-- Apply font sizes to all tracker elements
-- moduleFontSize: module headers (QUESTS, ACHIEVEMENTS, etc.)
-- titleFontSize: quest/achievement titles
-- textFontSize: objective text lines (- Kill 5 boars: 3/5)
local function ApplyFontSizes(moduleFontSize, titleFontSize, textFontSize)
    local fontPath = GetFontPath()

    for _, trackerName in ipairs(trackerModules) do
        local tracker = _G[trackerName]
        if tracker then
            -- Style module header text (e.g., "QUESTS", "ACHIEVEMENTS")
            if moduleFontSize > 0 and tracker.Header and tracker.Header.Text then
                tracker.Header.Text:SetFont(fontPath, moduleFontSize, FONT_FLAGS)
            end

            -- Style all blocks in this module
            if tracker.usedBlocks then
                for template, blocks in pairs(tracker.usedBlocks) do
                    for blockID, block in pairs(blocks) do
                        StyleBlock(block, fontPath, titleFontSize, textFontSize)
                    end
                end
            end
        end
    end

    -- Main objective tracker header
    local TrackerFrame = _G.ObjectiveTrackerFrame
    if TrackerFrame and TrackerFrame.Header and TrackerFrame.Header.Text then
        if moduleFontSize > 0 then
            TrackerFrame.Header.Text:SetFont(fontPath, moduleFontSize, FONT_FLAGS)
        end
    end
end

-- Hook to style newly created lines
local function HookLineCreation()
    local settings = GetSettings()
    if not settings then return end

    local textFontSize = settings.objectiveTrackerTextFontSize or 0
    if textFontSize <= 0 then return end

    local fontPath = GetFontPath()

    -- Hook ObjectiveTrackerBlockMixin:AddObjective to style lines as they're created
    if ObjectiveTrackerBlockMixin and ObjectiveTrackerBlockMixin.AddObjective and not ObjectiveTrackerBlockMixin.quiAddObjectiveHooked then
        hooksecurefunc(ObjectiveTrackerBlockMixin, "AddObjective", function(self, objectiveKey, text, template, useFullHeight, dashStyle, colorStyle, adjustForNoText, overrideHeight)
            local line = self.usedLines and self.usedLines[objectiveKey]
            if line then
                local currentSettings = GetSettings()
                local currentTextSize = currentSettings and currentSettings.objectiveTrackerTextFontSize or 0
                if currentTextSize > 0 then
                    StyleLine(line, GetFontPath(), currentTextSize)
                end
            end
        end)
        ObjectiveTrackerBlockMixin.quiAddObjectiveHooked = true
    end

    -- Hook ObjectiveTrackerBlockMixin:SetHeader to style block headers (quest/achievement titles)
    if ObjectiveTrackerBlockMixin and ObjectiveTrackerBlockMixin.SetHeader and not ObjectiveTrackerBlockMixin.quiSetHeaderHooked then
        hooksecurefunc(ObjectiveTrackerBlockMixin, "SetHeader", function(self, text)
            local currentSettings = GetSettings()
            local currentTitleSize = currentSettings and currentSettings.objectiveTrackerTitleFontSize or 0
            if currentTitleSize > 0 and self.HeaderText then
                self.HeaderText:SetFont(GetFontPath(), currentTitleSize, FONT_FLAGS)
            end
        end)
        ObjectiveTrackerBlockMixin.quiSetHeaderHooked = true
    end
end

-- Main skinning function
local function SkinObjectiveTracker()
    local settings = GetSettings()
    if not settings or not settings.skinObjectiveTracker then return end

    local TrackerFrame = _G.ObjectiveTrackerFrame
    if not TrackerFrame then return end

    local sr, sg, sb, sa, bgr, bgg, bgb, bga = GetColors()

    -- Sync Blizzard's height with our max height setting
    SyncBlizzardHeight()

    -- Apply QUI backdrop with our colors/opacity
    ApplyQUIBackdrop(TrackerFrame, sr, sg, sb, sa, bgr, bgg, bgb, bga)

    -- Apply font size settings (three separate options)
    local moduleFontSize = settings.objectiveTrackerModuleFontSize or 12
    local titleFontSize = settings.objectiveTrackerTitleFontSize or 10
    local textFontSize = settings.objectiveTrackerTextFontSize or 10
    ApplyFontSizes(moduleFontSize, titleFontSize, textFontSize)

    -- Hook line creation to style new lines dynamically
    HookLineCreation()

    -- Skin main header
    local TrackerHeader = TrackerFrame.Header
    if TrackerHeader then
        SkinTrackerHeader(TrackerHeader)

        -- Style minimize button
        local MinimizeButton = TrackerHeader.MinimizeButton
        if MinimizeButton then
            MinimizeButton:SetSize(16, 16)
        end
    end

    -- Skin all tracker module headers
    for _, trackerName in ipairs(trackerModules) do
        local tracker = _G[trackerName]
        if tracker then
            SkinTrackerHeader(tracker.Header)
        end
    end

    -- Hook the main container's Update to update backdrop anchors when content changes
    if TrackerFrame.Update and not TrackerFrame.quiUpdateHooked then
        hooksecurefunc(TrackerFrame, "Update", ScheduleBackdropUpdate)
        TrackerFrame.quiUpdateHooked = true
    end

    -- Hook main container's SetCollapsed for when entire tracker is collapsed/expanded
    if TrackerFrame.SetCollapsed and not TrackerFrame.quiCollapseHooked then
        hooksecurefunc(TrackerFrame, "SetCollapsed", ScheduleBackdropUpdate)
        TrackerFrame.quiCollapseHooked = true
    end

    -- Hook each module's header minimize button, SetCollapsed, and LayoutContents
    for _, trackerName in ipairs(trackerModules) do
        local tracker = _G[trackerName]
        if tracker and not tracker.quiCollapseHooked then
            -- Hook the header's minimize button click
            if tracker.Header and tracker.Header.MinimizeButton then
                tracker.Header.MinimizeButton:HookScript("OnClick", ScheduleBackdropUpdate)
            end

            -- Hook SetCollapsed on the module itself
            if tracker.SetCollapsed then
                hooksecurefunc(tracker, "SetCollapsed", ScheduleBackdropUpdate)
            end

            -- Hook LayoutContents to catch world quest/bonus objective changes
            if tracker.LayoutContents then
                hooksecurefunc(tracker, "LayoutContents", ScheduleBackdropUpdate)
            end

            tracker.quiCollapseHooked = true
        end
    end

    -- Also update on size changes (with guard to prevent multiple hooks)
    if not TrackerFrame.quiSizeChangedHooked then
        TrackerFrame:HookScript("OnSizeChanged", UpdateBackdropAnchors)
        TrackerFrame.quiSizeChangedHooked = true
    end

    TrackerFrame.quiSkinned = true
end

-- Refresh/update settings (called from options panel)
local function RefreshObjectiveTracker()
    local settings = GetSettings()
    if not settings or not settings.skinObjectiveTracker then return end

    local TrackerFrame = _G.ObjectiveTrackerFrame
    if not TrackerFrame then return end

    local sr, sg, sb, sa, bgr, bgg, bgb, bga = GetColors()

    -- Sync Blizzard's height with our max height setting
    SyncBlizzardHeight()

    -- Update backdrop colors
    if TrackerFrame.quiBackdrop then
        TrackerFrame.quiBackdrop:SetBackdropColor(bgr, bgg, bgb, bga)
        TrackerFrame.quiBackdrop:SetBackdropBorderColor(sr, sg, sb, sa)
    end

    -- Update anchors
    UpdateBackdropAnchors()

    -- Update font sizes (three separate options)
    local moduleFontSize = settings.objectiveTrackerModuleFontSize or 12
    local titleFontSize = settings.objectiveTrackerTitleFontSize or 10
    local textFontSize = settings.objectiveTrackerTextFontSize or 10
    ApplyFontSizes(moduleFontSize, titleFontSize, textFontSize)

    -- Ensure hooks are in place
    HookLineCreation()
end

-- Expose refresh function globally
_G.QuaziiUI_RefreshObjectiveTracker = RefreshObjectiveTracker
_G.QuaziiUI_RefreshObjectiveTrackerColors = RefreshObjectiveTracker

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------

-- All events used by objective tracker modules (from Blizzard source)
local trackingEvents = {
    -- Achievement tracker
    "CONTENT_TRACKING_UPDATE",
    "TRACKED_ACHIEVEMENT_UPDATE",
    "TRACKED_ACHIEVEMENT_LIST_CHANGED",
    "ACHIEVEMENT_EARNED",
    -- Adventure tracker
    "TRANSMOG_COLLECTION_SOURCE_ADDED",
    "SUPER_TRACKING_CHANGED",
    "TRACKING_TARGET_INFO_UPDATE",
    "TRACKABLE_INFO_UPDATE",
    "HOUSE_DECOR_ADDED_TO_CHEST",
    -- Bonus objective tracker
    "CRITERIA_COMPLETE",
    "QUEST_TURNED_IN",
    "QUEST_LOG_UPDATE",
    "QUEST_WATCH_LIST_CHANGED",
    "SCENARIO_BONUS_VISIBILITY_UPDATE",
    "SCENARIO_CRITERIA_UPDATE",
    "SCENARIO_UPDATE",
    "QUEST_ACCEPTED",
    "QUEST_REMOVED",
    -- Campaign quest tracker
    -- (uses QUEST_LOG_UPDATE, QUEST_WATCH_LIST_CHANGED - already listed)
    -- Monthly activities tracker
    "PERKS_ACTIVITY_COMPLETED",
    "PERKS_ACTIVITIES_TRACKED_UPDATED",
    "PERKS_ACTIVITIES_TRACKED_LIST_CHANGED",
    -- UI Widget tracker
    "ZONE_CHANGED_NEW_AREA",
    -- Professions recipe tracker
    "CURRENCY_DISPLAY_UPDATE",
    "TRACKED_RECIPE_UPDATE",
    "BAG_UPDATE_DELAYED",
    -- Quest tracker
    "QUEST_AUTOCOMPLETE",
    "QUEST_POI_UPDATE",
    -- Scenario tracker
    "SCENARIO_SPELL_UPDATE",
    "SCENARIO_COMPLETED",
    "SCENARIO_CRITERIA_SHOW_STATE_UPDATE",
    -- World quest tracker
    -- (uses events already listed above)
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Delay to ensure ObjectiveTrackerFrame is ready
        C_Timer.After(1, function()
            SkinObjectiveTracker()
            -- Register for tracking events after initial skin
            for _, trackEvent in ipairs(trackingEvents) do
                self:RegisterEvent(trackEvent)
            end
        end)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    else
        -- Content changed, update backdrop with debouncing
        ScheduleBackdropUpdate()
    end
end)
