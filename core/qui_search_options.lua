--[[
    qui_search_options.lua
    Options UI for Search component
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

local function CreateSearchPage(tabContent)
    local PAD = 15
    local y = -10

    -- Search input at top
    local searchBox = GUI:CreateSearchBox(tabContent)
    searchBox:SetSize(tabContent:GetWidth() - (PAD * 2), 28)
    searchBox:SetPoint("TOPLEFT", PAD, y)
    y = y - 40

    -- Results scroll area below
    local scrollFrame = CreateFrame("ScrollFrame", nil, tabContent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", PAD, y)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local resultsContent = CreateFrame("Frame", nil, scrollFrame)
    resultsContent:SetWidth(scrollFrame:GetWidth() - 10)
    scrollFrame:SetScrollChild(resultsContent)

    -- Scroll bar styling
    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 4, -16)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 4, 16)
    end

    -- Initial empty state
    GUI:RenderSearchResults(resultsContent, nil, nil)

    -- Wire up search callbacks
    searchBox.onSearch = function(text)
        local results = GUI:ExecuteSearch(text)
        GUI:RenderSearchResults(resultsContent, results, text)
    end

    searchBox.onClear = function()
        GUI:RenderSearchResults(resultsContent, nil, nil)
    end

    tabContent.searchBox = searchBox
    tabContent.resultsContent = resultsContent
end

-- Export the function
ns.SearchOptions = { CreateSearchPage = CreateSearchPage }

-- Register with Options Page Registry
if ns.OptionsPageRegistry then
    ns.OptionsPageRegistry:RegisterSimplePage("search", "Search", CreateSearchPage, 130)
end

return ns.SearchOptions
