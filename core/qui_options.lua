--[[
    QuaziiUI Options Bootstrap
    Initializes the options GUI using the Options Page Registry
]]

local ADDON_NAME, ns = ...
local QUI = QuaziiUI
local GUI = QUI.GUI
local OptionsPageRegistry = ns.OptionsPageRegistry

---------------------------------------------------------------------------
-- INITIALIZE OPTIONS - Bootstrap from registry
---------------------------------------------------------------------------
function GUI:InitializeOptions()
    local frame = self:CreateMainFrame()
    
    -- Get all registered pages from registry
    if not OptionsPageRegistry then
        error("QuaziiUI: OptionsPageRegistry not found. Check load order in core.xml")
    end
    
    local pages = OptionsPageRegistry:GetAllPages()
    
    -- Add all registered pages to the GUI
    for _, page in ipairs(pages) do
        if page.type == "simple" and page.createFunc then
            GUI:AddTab(frame, page.name, page.createFunc)
        elseif page.type == "composed" then
            -- For composed pages, create a wrapper that uses CreateComposedPage
            local wrapper = function(parent)
                OptionsPageRegistry:CreateComposedPage(page.id, parent)
            end
            GUI:AddTab(frame, page.name, wrapper)
        end
    end
    
    -- Find and store search tab index
    for i, tab in ipairs(frame.tabs) do
        if tab.name == "Search" then
            GUI._searchTabIndex = i
            break
        end
    end
    
    -- Add action buttons
    GUI:AddActionButton(frame, "Cooldown Settings", function()
        if CooldownViewerSettings then
            CooldownViewerSettings:SetShown(not CooldownViewerSettings:IsShown())
        else
            print("|cFF56D1FFQuaziiUI:|r Cooldown Settings not available. Enable Cooldown Manager in Options > Gameplay Enhancement.")
        end
    end)
    
    GUI:AddActionButton(frame, "Edit Mode", function()
        if EditModeManagerFrame then
            ShowUIPanel(EditModeManagerFrame)
        end
    end)
    
    -- Mark that all tabs have been added (for search indexing)
    GUI._allTabsAdded = true
    
    return frame
end
