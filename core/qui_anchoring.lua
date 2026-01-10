--[[
    QUI Anchoring Module
    Unified anchoring system for castbars, unit frames, and custom frames
    Supports 9-point anchoring with X/Y offsets and dynamic anchor target registration
]]

local ADDON_NAME, ns = ...
local QUICore = ns.Addon

---------------------------------------------------------------------------
-- MODULE TABLE
---------------------------------------------------------------------------
local QUI_Anchoring = {}
ns.QUI_Anchoring = QUI_Anchoring

-- Anchor target registry: { name = { frame = frame, options = {...} } }
QUI_Anchoring.anchorTargets = {}

-- Category registry: { categoryName = { order = number } }
QUI_Anchoring.categories = {}

-- DEPRECATED: Frame registry moved to QUI_LayoutManager.frames
-- Kept for backward compatibility checks only
QUI_Anchoring.anchoredFrames = {}

local Helpers = {}

---------------------------------------------------------------------------
-- SETUP HELPERS
---------------------------------------------------------------------------
function QUI_Anchoring:SetHelpers(helpers)
    Helpers = helpers or {}
end

-- Helper function wrappers (with fallbacks)
local function Scale(x)
    return Helpers.Scale and Helpers.Scale(x) or (QUICore and QUICore.Scale and QUICore:Scale(x) or x)
end

---------------------------------------------------------------------------
-- ANCHOR TARGET REGISTRY
---------------------------------------------------------------------------
-- Register a frame as an anchor target with a custom name
-- options can include: displayName, category, categoryOrder (for category sorting), order (for item sorting within category), and other custom properties
function QUI_Anchoring:RegisterAnchorTarget(name, frame, options)
    if not name or not frame then
        return false
    end
    
    options = options or {}
    self.anchorTargets[name] = {
        frame = frame,
        options = options
    }
    
    -- Register category with its order if provided
    local category = options.category
    if category then
        if not self.categories[category] then
            self.categories[category] = {
                order = options.categoryOrder or 999
            }
        end
    end
    
    return true
end

-- Unregister an anchor target
function QUI_Anchoring:UnregisterAnchorTarget(name)
    if not name then return false end
    self.anchorTargets[name] = nil
    return true
end

-- Get an anchor target by name
function QUI_Anchoring:GetAnchorTarget(name)
    if not name then return nil end
    
    -- Check registry only
    local registered = self.anchorTargets[name]
    if registered then
        return registered.frame
    end
    
    return nil
end

-- Get list of registered anchor targets for options dropdowns
-- Parameters:
--   include: optional table of anchor values to include (if provided, only these are included)
--   exclude: optional table of anchor values to exclude (if provided, these are filtered out)
--   excludeSelf: optional anchor target name to exclude (prevents self-anchoring)
-- Returns array of {value = name, text = displayName}
function QUI_Anchoring:GetAnchorTargetList(include, exclude, excludeSelf)
    include = include or {}
    exclude = exclude or {}
    
    -- Convert include/exclude to lookup tables for faster checking
    local includeLookup = {}
    local excludeLookup = {}
    
    if type(include) == "table" and #include > 0 then
        for _, value in ipairs(include) do
            includeLookup[value] = true
        end
    elseif type(include) == "table" then
        -- Empty table means include all
        includeLookup = nil
    end
    
    if type(exclude) == "table" then
        for _, value in ipairs(exclude) do
            excludeLookup[value] = true
        end
    end
    
    -- Helper to check if an anchor should be included
    local function ShouldInclude(value)
        -- Check exclude first
        if excludeLookup[value] then
            return false
        end
        -- Check excludeSelf (prevents self-anchoring)
        if excludeSelf and value == excludeSelf then
            return false
        end
        -- If include list is provided, check it
        if includeLookup then
            return includeLookup[value] == true
        end
        -- Otherwise include all
        return true
    end
    
    local list = {}
    
    -- Add special anchor targets (always check include/exclude)
    if ShouldInclude("none") then
        table.insert(list, {value = "none", text = "None"})
    end
    if ShouldInclude("screen") then
        table.insert(list, {value = "screen", text = "Screen Center"})
    end
    
    -- Group registered anchor targets by category
    local categorized = {}
    local uncategorized = {}
    
    for name, data in pairs(self.anchorTargets) do
        if ShouldInclude(name) then
            local displayName = data.options and data.options.displayName or name
            -- Capitalize first letter and add spaces before capitals
            displayName = displayName:gsub("^%l", string.upper)
            displayName = displayName:gsub("([a-z])([A-Z])", "%1 %2")
            
            local category = data.options and data.options.category
            local order = data.options and data.options.order or 999
            local item = {value = name, text = displayName, category = category, order = order}
            
            if category then
                if not categorized[category] then
                    categorized[category] = {}
                end
                table.insert(categorized[category], item)
            else
                table.insert(uncategorized, item)
            end
        end
    end
    
    -- Sort categories by order (from category registry), then alphabetically
    local sortedCategories = {}
    for category, items in pairs(categorized) do
        local categoryInfo = self.categories[category] or {}
        local categoryOrder = categoryInfo.order or 999
        table.insert(sortedCategories, {name = category, order = categoryOrder})
        -- Sort items within category by order, then by text
        table.sort(items, function(a, b)
            if a.order ~= b.order then
                return a.order < b.order
            end
            return a.text < b.text
        end)
    end
    table.sort(sortedCategories, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.name < b.name
    end)
    
    -- Sort uncategorized items
    table.sort(uncategorized, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.text < b.text
    end)
    
    -- Build final list: special values, then categorized items, then uncategorized
    -- Add categorized items with headers
    for _, catInfo in ipairs(sortedCategories) do
        local category = catInfo.name
        -- Add category header (non-clickable, value is nil)
        table.insert(list, {value = nil, text = category, isHeader = true})
        -- Add items in this category
        for _, item in ipairs(categorized[category]) do
            table.insert(list, item)
        end
    end
    
    -- Add uncategorized items (only if there are any)
    if #uncategorized > 0 then
        -- Only add "Other" header if we have categorized items above
        if #sortedCategories > 0 then
            table.insert(list, {value = nil, text = "Other", isHeader = true})
        end
        for _, item in ipairs(uncategorized) do
            table.insert(list, item)
        end
    end
    
    return list
end

---------------------------------------------------------------------------
-- ANCHOR DIMENSIONS HELPER
---------------------------------------------------------------------------
-- Get anchor frame dimensions and position data
function QUI_Anchoring:GetAnchorDimensions(anchorFrame, anchorTargetName)
    if not anchorFrame then return nil end
    
    local registered = self.anchorTargets[anchorTargetName]
    local options = registered and registered.options or {}
    
    local width, height
    if options.customWidth then
        width = type(options.customWidth) == "function" and options.customWidth(anchorFrame) or options.customWidth
    else
        width = anchorFrame:GetWidth()
    end
    
    if options.customHeight then
        height = type(options.customHeight) == "function" and options.customHeight(anchorFrame) or options.customHeight
    else
        height = anchorFrame:GetHeight()
    end
    
    local centerX, centerY = anchorFrame:GetCenter()
    if not centerX or not centerY then return nil end
    
    return {
        width = width,
        height = height,
        centerX = centerX,
        centerY = centerY,
        top = centerY + (height / 2),
        bottom = centerY - (height / 2),
        left = centerX - (width / 2),
        right = centerX + (width / 2),
    }
end


---------------------------------------------------------------------------
-- ANCHORED FRAME REGISTRATION
---------------------------------------------------------------------------
-- Get anchor target name for a given frame (reverse lookup)
function QUI_Anchoring:GetAnchorTargetName(frame)
    if not frame then return nil end
    
    for name, data in pairs(self.anchorTargets) do
        if data.frame == frame then
            return name
        end
    end
    
    return nil
end

-- Check for circular anchoring dependencies
-- This works at registration time by checking the CURRENT state of already-registered frames.
-- Example: If Frame A â†’ Frame B â†’ Frame C are already registered, and Frame C tries to anchor to Frame A,
-- we follow the chain: Frame C â†’ Frame A â†’ Frame B â†’ Frame C, detecting the cycle.
-- Returns true if circular dependency would be created, false otherwise
function QUI_Anchoring:CheckCircularDependency(frame, anchorTarget)
    if not frame or not anchorTarget then return false end
    
    -- Skip check for special anchor targets
    if anchorTarget == "screen" or anchorTarget == "none" then
        return false
    end
    
    -- Get the anchor target frame
    local targetFrame = self:GetAnchorTarget(anchorTarget)
    if not targetFrame then return false end
    
    -- Check if the target frame is the same as the source frame (self-anchoring)
    if targetFrame == frame then
        return true -- Self-anchoring detected
    end
    
    -- Check if target frame is anchored to anything (must be already registered)
    local QUI_LayoutManager = ns.QUI_LayoutManager
    local targetConfig = QUI_LayoutManager and QUI_LayoutManager:GetLayout(targetFrame) or nil
    if not targetConfig then 
        -- Target frame is not yet anchored to anything, so no cycle possible
        return false 
    end
    
    -- Recursively follow the anchor chain to see if we eventually loop back to the starting frame
    -- visited tracks frames we've seen to prevent infinite loops in case of malformed data
    local visited = {}
    local function CheckCycle(currentFrame, startFrame)
        -- If we've reached the starting frame again, we have a cycle
        if currentFrame == startFrame then
            return true -- Cycle detected
        end
        
        -- If we've already visited this frame in this traversal, skip it (prevents infinite loops)
        if visited[currentFrame] then
            return false -- Already visited, no cycle through this path
        end
        visited[currentFrame] = true
        
        -- Get the anchor configuration for the current frame
        local QUI_LayoutManager = ns.QUI_LayoutManager
        local config = QUI_LayoutManager and QUI_LayoutManager:GetLayout(currentFrame) or nil
        if not config then 
            -- This frame is not anchored to anything, chain ends here, no cycle
            return false 
        end
        
        -- Skip special anchor targets (they don't create cycles)
        if config.anchorTarget == "screen" or config.anchorTarget == "none" then
            return false
        end
        
        -- Get the next frame in the chain
        local nextTargetFrame = self:GetAnchorTarget(config.anchorTarget)
        if not nextTargetFrame then 
            -- Anchor target doesn't exist or isn't registered, chain ends, no cycle
            return false 
        end
        
        -- Recursively check the next frame in the chain
        return CheckCycle(nextTargetFrame, startFrame)
    end
    
    -- Start checking from the target frame, looking for a path back to the starting frame
    return CheckCycle(targetFrame, frame)
end

-- Helper: Check if anchors array represents horizontal dual anchors (width controlled by target)
-- Returns: true if horizontal dual anchors detected
local function IsHorizontalDualAnchor(anchors)
    if not anchors or #anchors < 2 then return false end
    local firstSource = anchors[1].source
    local secondSource = anchors[2].source
    -- Horizontal anchors: TOPLEFT/TOPRIGHT or BOTTOMLEFT/BOTTOMRIGHT
    return (firstSource == "TOPLEFT" and secondSource == "TOPRIGHT") or
           (firstSource == "TOPRIGHT" and secondSource == "TOPLEFT") or
           (firstSource == "BOTTOMLEFT" and secondSource == "BOTTOMRIGHT") or
           (firstSource == "BOTTOMRIGHT" and secondSource == "BOTTOMLEFT")
end

-- Helper: Check if anchors array represents vertical dual anchors (height controlled by target)
-- Returns: true if vertical dual anchors detected
local function IsVerticalDualAnchor(anchors)
    if not anchors or #anchors < 2 then return false end
    local firstSource = anchors[1].source
    local secondSource = anchors[2].source
    -- Vertical anchors: TOPLEFT/BOTTOMLEFT or TOPRIGHT/BOTTOMRIGHT
    return (firstSource == "TOPLEFT" and secondSource == "BOTTOMLEFT") or
           (firstSource == "BOTTOMLEFT" and secondSource == "TOPLEFT") or
           (firstSource == "TOPRIGHT" and secondSource == "BOTTOMRIGHT") or
           (firstSource == "BOTTOMRIGHT" and secondSource == "TOPRIGHT")
end





-- Find a frame by elementKey (for selection handling)
function QUI_Anchoring:GetFrameByElementKey(elementKey)
    if not elementKey then return nil end
    
    local QUI_LayoutManager = ns.QUI_LayoutManager
    if QUI_LayoutManager then
        for frame, config in pairs(QUI_LayoutManager.frames) do
            if config.editMode and config.editMode.elementKey == elementKey then
                return frame
            end
        end
    end
    
    return nil
end

---------------------------------------------------------------------------
-- INITIALIZATION EVENT HANDLER
-- Re-positions all frames after reload to ensure saved positions are applied
---------------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    -- Only process QuaziiUI addon load
    if event == "ADDON_LOADED" and addonName ~= "QuaziiUI" then
        return
    end
end)
