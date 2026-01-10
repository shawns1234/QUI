--[[
    QUI Layout State Module
    Handles persistence and loading of layout configuration
    Single Responsibility: Persist and load layout configuration
]]

local ADDON_NAME, ns = ...
local QUICore = ns.Addon

---------------------------------------------------------------------------
-- MODULE TABLE
---------------------------------------------------------------------------
local QUI_LayoutState = {}
ns.QUI_LayoutState = QUI_LayoutState

---------------------------------------------------------------------------
-- DATABASE MANAGEMENT
---------------------------------------------------------------------------
-- Get layout system's database (creates if doesn't exist)
function QUI_LayoutState:GetDatabase()
    if not QUICore or not QUICore.db or not QUICore.db.profile then
        return nil
    end
    
    if not QUICore.db.profile.layout then
        QUICore.db.profile.layout = {}
    end
    
    return QUICore.db.profile.layout
end

---------------------------------------------------------------------------
-- CONFIG LOADING
---------------------------------------------------------------------------
-- Load layout config from database
-- Parameters:
--   frameKey: Unique key for this frame (e.g., "unitFrames.player")
-- Returns: config table or empty table if not found
function QUI_LayoutState:LoadConfig(frameKey)
    if not frameKey then return {} end
    
    local db = self:GetDatabase()
    if not db then return {} end
    
    local saved = db[frameKey] or {}
    
    -- Validate and normalize numeric values (cleanup corrupted data)
    local config = {}
    if saved.anchorTarget ~= nil then
        config.anchorTarget = saved.anchorTarget
    end
    if saved.offsetX ~= nil then
        config.offsetX = tonumber(saved.offsetX) or 0
    end
    if saved.offsetY ~= nil then
        config.offsetY = tonumber(saved.offsetY) or 0
    end
    if saved.anchors and #saved.anchors > 0 then
        config.anchors = saved.anchors
    end
    if saved.width ~= nil then
        config.width = tonumber(saved.width)
    end
    if saved.height ~= nil then
        config.height = tonumber(saved.height)
    end
    
    return config
end

---------------------------------------------------------------------------
-- CONFIG SAVING
---------------------------------------------------------------------------
-- Save layout config to database
-- Parameters:
--   frameKey: Unique key for this frame
--   config: Config table with anchorTarget, anchors, offsetX, offsetY, width, height
function QUI_LayoutState:SaveConfig(frameKey, config)
    if not frameKey or not config then return end
    
    local db = self:GetDatabase()
    if not db then return end
    
    -- Save config to database
    db[frameKey] = {
        anchorTarget = config.anchorTarget,
        offsetX = config.offsetX,
        offsetY = config.offsetY,
        anchors = config.anchors,
        width = config.width,
        height = config.height,
    }
end

---------------------------------------------------------------------------
-- DEFAULTS APPLICATION
---------------------------------------------------------------------------
-- Apply default values for a frame
-- Parameters:
--   frameKey: Unique key for this frame
--   frameType: Frame type (e.g., "unitFrames", "castbars")
-- Returns: config table with defaults applied
function QUI_LayoutState:ApplyDefaults(frameKey, frameType)
    if not frameKey or not frameType then return {} end
    
    local QUI_Anchoring_Defaults = ns.QUI_Anchoring_Defaults
    if not QUI_Anchoring_Defaults then
        return {}
    end
    
    -- Extract frameKey name (e.g., "player" from "unitFrames.player")
    local defaultKey = frameKey:match("[^.]+$") or frameKey
    
    local defaultConfig = {}
    QUI_Anchoring_Defaults:ApplyDefaultAnchors(frameType, defaultKey, defaultConfig)
    
    -- Convert to layout system format
    -- Convert anchorTo/anchor to anchorTarget (for castbars, anchor is used; for others, anchorTo)
    local config = {}
    if defaultConfig.anchorTo then
        config.anchorTarget = defaultConfig.anchorTo
    elseif defaultConfig.anchor then
        config.anchorTarget = defaultConfig.anchor
    end
    
    if defaultConfig.offsetX ~= nil then
        config.offsetX = defaultConfig.offsetX
    end
    if defaultConfig.offsetY ~= nil then
        config.offsetY = defaultConfig.offsetY
    end
    if defaultConfig.anchors then
        config.anchors = defaultConfig.anchors
    end
    if defaultConfig.width ~= nil then
        config.width = defaultConfig.width
    end
    if defaultConfig.height ~= nil then
        config.height = defaultConfig.height
    end
    
    return config
end

---------------------------------------------------------------------------
-- MIGRATION
---------------------------------------------------------------------------
-- Migrate anchor configuration (handles "disabled" -> "none" migration)
-- Parameters:
--   config: Config table to migrate
-- Returns: migrated config table
function QUI_LayoutState:MigrateConfig(config)
    if not config then return config end
    
    -- Migrate "disabled" -> "none" for both anchorTo and anchor fields
    if config.anchorTo == "disabled" then
        config.anchorTo = "none"
    end
    if config.anchor == "disabled" then
        config.anchor = "none"
    end
    
    -- For castbars, if anchor is set but anchorTo is not, use anchor as anchorTo
    -- This handles the castbar-specific "anchor" field
    if config.anchor and not config.anchorTo then
        config.anchorTo = config.anchor
    end
    
    -- Normalize anchorTo to anchorTarget
    if config.anchorTo and not config.anchorTarget then
        config.anchorTarget = config.anchorTo
    end
    
    return config
end
