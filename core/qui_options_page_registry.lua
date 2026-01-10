--[[
    QuaziiUI Options Page Registry
    Manages registration of options pages and sub-tabs
    Supports simple pages, composed pages, and sub-tab contributions
]]

local ADDON_NAME, ns = ...

-- Helper to get GUI (may not be available at load time)
local function GetGUI()
    local QUI = _G.QuaziiUI
    if QUI and QUI.GUI then
        return QUI.GUI
    end
    return nil
end

-- Options Page Registry
local OptionsPageRegistry = {
    simplePages = {},  -- {id = {name, createFunc, order}}
    composedPages = {},  -- {id = {name, subTabs = {}, order}}
}

ns.OptionsPageRegistry = OptionsPageRegistry

---------------------------------------------------------------------------
-- REGISTER SIMPLE PAGE
---------------------------------------------------------------------------
--[[
    Register a simple options page (single function creates the page)
    @param id string - Unique page identifier
    @param name string - Display name for the tab
    @param createFunc function - Function that creates the page (receives parent frame)
    @param order number - Display order (lower = earlier, default: 999)
]]
function OptionsPageRegistry:RegisterSimplePage(id, name, createFunc, order)
    if not id or not name or not createFunc then
        error("OptionsPageRegistry:RegisterSimplePage requires id, name, and createFunc")
    end
    
    if self.simplePages[id] or self.composedPages[id] then
        error(string.format("Options page '%s' is already registered", id))
    end
    
    self.simplePages[id] = {
        id = id,
        name = name,
        createFunc = createFunc,
        order = order or 999,
    }
end

---------------------------------------------------------------------------
-- REGISTER COMPOSED PAGE
---------------------------------------------------------------------------
--[[
    Register a composed page (top-level tab that collects sub-tabs from multiple modules)
    @param id string - Unique page identifier
    @param name string - Display name for the tab
    @param order number - Display order (lower = earlier, default: 999)
]]
function OptionsPageRegistry:RegisterComposedPage(id, name, order)
    if not id or not name then
        error("OptionsPageRegistry:RegisterComposedPage requires id and name")
    end
    
    if self.simplePages[id] or self.composedPages[id] then
        error(string.format("Options page '%s' is already registered", id))
    end
    
    self.composedPages[id] = {
        id = id,
        name = name,
        subTabs = {},
        order = order or 999,
    }
end

---------------------------------------------------------------------------
-- ADD SUB-TAB TO COMPOSED PAGE
---------------------------------------------------------------------------
--[[
    Add a sub-tab to an existing composed page
    @param composedPageId string - ID of the composed page
    @param subTabInfo table - Sub-tab information:
        - name: string - Display name for the sub-tab
        - builder: function - Function that builds the sub-tab content (receives tabContent frame)
        - order: number - Position in sub-tab list (lower = earlier, default: 999)
]]
function OptionsPageRegistry:AddSubTab(composedPageId, subTabInfo)
    local composedPage = self.composedPages[composedPageId]
    if not composedPage then
        error(string.format("Composed page '%s' does not exist. Register it first with RegisterComposedPage.", composedPageId))
    end
    
    if not subTabInfo.name or not subTabInfo.builder then
        error("OptionsPageRegistry:AddSubTab requires name and builder in subTabInfo")
    end
    
    table.insert(composedPage.subTabs, {
        name = subTabInfo.name,
        builder = subTabInfo.builder,
        order = subTabInfo.order or 999,
    })
    
    -- Sort sub-tabs by order
    table.sort(composedPage.subTabs, function(a, b)
        return a.order < b.order
    end)
end

---------------------------------------------------------------------------
-- GET PAGE INFO
---------------------------------------------------------------------------
function OptionsPageRegistry:GetPage(id)
    return self.simplePages[id] or self.composedPages[id]
end

---------------------------------------------------------------------------
-- GET SUB-TABS FOR COMPOSED PAGE
---------------------------------------------------------------------------
function OptionsPageRegistry:GetSubTabs(composedPageId)
    local composedPage = self.composedPages[composedPageId]
    if not composedPage then
        return {}
    end
    
    -- Return sorted sub-tabs
    local sorted = {}
    for _, subTab in ipairs(composedPage.subTabs) do
        table.insert(sorted, {
            name = subTab.name,
            builder = subTab.builder,
        })
    end
    return sorted
end

---------------------------------------------------------------------------
-- CREATE COMPOSED PAGE
---------------------------------------------------------------------------
--[[
    Creates a composed page with all contributed sub-tabs
    @param composedPageId string - ID of the composed page
    @param parent Frame - Parent frame to create the page in
    @return scroll, content - Scroll frame and content frame
]]
function OptionsPageRegistry:CreateComposedPage(composedPageId, parent)
    local composedPage = self.composedPages[composedPageId]
    if not composedPage then
        error(string.format("Composed page '%s' does not exist", composedPageId))
    end
    
    -- Import CreateScrollableContent from OptionsShared
    local OptionsShared = ns.OptionsShared
    if not OptionsShared then
        error("OptionsShared not loaded")
    end
    
    local scroll, content = OptionsShared.CreateScrollableContent(parent)
    
    -- Get sorted sub-tabs
    local subTabs = self:GetSubTabs(composedPageId)
    
    if #subTabs == 0 then
        -- No sub-tabs registered yet
        local GUI = GetGUI()
        if GUI then
            local emptyLabel = GUI:CreateLabel(content, "No options available for this page.", 12, GUI.Colors.textMuted)
            emptyLabel:SetPoint("TOPLEFT", 15, -15)
        end
        content:SetHeight(100)
        return scroll, content
    end
    
    -- Create sub-tabs using GUI:CreateSubTabs
    local GUI = GetGUI()
    if not GUI then
        error("GUI not available for CreateComposedPage")
    end
    local subTabsFrame = GUI:CreateSubTabs(content, subTabs)
    subTabsFrame:SetPoint("TOPLEFT", 5, -5)
    subTabsFrame:SetPoint("TOPRIGHT", -5, -5)
    subTabsFrame:SetHeight(700)
    
    content:SetHeight(750)
    
    return scroll, content
end

---------------------------------------------------------------------------
-- GET ALL PAGES (SORTED BY ORDER)
---------------------------------------------------------------------------
function OptionsPageRegistry:GetAllPages()
    local all = {}
    
    -- Add simple pages
    for id, page in pairs(self.simplePages) do
        table.insert(all, {
            id = id,
            name = page.name,
            type = "simple",
            createFunc = page.createFunc,
            order = page.order,
        })
    end
    
    -- Add composed pages
    for id, page in pairs(self.composedPages) do
        table.insert(all, {
            id = id,
            name = page.name,
            type = "composed",
            order = page.order,
        })
    end
    
    -- Sort by order
    table.sort(all, function(a, b)
        return a.order < b.order
    end)
    
    return all
end

return OptionsPageRegistry
