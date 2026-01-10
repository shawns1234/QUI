--[[
    QUI Anchoring Defaults Module
    Centralized default anchor configurations for all frame types
    Single source of truth for anchor defaults across the entire addon
]]

local ADDON_NAME, ns = ...

local QUI_Anchoring_Defaults = {}
ns.QUI_Anchoring_Defaults = QUI_Anchoring_Defaults

---------------------------------------------------------------------------
-- DEFAULT ANCHOR CONFIGURATIONS
---------------------------------------------------------------------------

-- Default anchor configurations for all frame types
QUI_Anchoring_Defaults.defaults = {
    -- Unit Frames
    unitFrames = {
        player = {
            anchorTo = "none",
            offsetX = 0,
            offsetY = 0,
            anchors = {{source = "TOPLEFT", target = "TOPLEFT"}},
        },
        target = {
            anchorTo = "none",
            offsetX = 0,
            offsetY = 0,
            anchors = {{source = "TOPRIGHT", target = "TOPRIGHT"}},
        },
        pet = {
            anchorTo = "none",
            offsetX = 0,
            offsetY = 0,
            anchors = {{source = "TOPLEFT", target = "TOPLEFT"}},
        },
        focus = {
            anchorTo = "none",
            offsetX = 0,
            offsetY = 0,
            anchors = {{source = "TOPLEFT", target = "TOPLEFT"}},
        },
        targettarget = {
            anchorTo = "none",
            offsetX = 0,
            offsetY = 0,
            anchors = {{source = "TOPLEFT", target = "TOPLEFT"}},
        },
        boss = {
            anchorTo = "none",
            offsetX = 0,
            offsetY = 0,
            anchors = {{source = "TOPLEFT", target = "TOPLEFT"}},
        },
    },
    
    -- Castbars
    castbars = {
        default = {
            anchor = "screen",
            offsetX = 0,
            offsetY = -25,
            anchors = {{source = "CENTER", target = "CENTER"}},
        },
    },
    
    -- Resource Bars
    resourceBars = {
        primary = {
            anchorTo = "none",
            offsetX = 0,
            offsetY = 0,
            anchors = {{source = "CENTER", target = "CENTER"}},
            width = 200,  -- Default width
            height = 8,   -- Default height
        },
        secondary = {
            anchorTo = "none",
            offsetX = 0,
            offsetY = 0,
            anchors = {{source = "CENTER", target = "CENTER"}},
            width = 200,  -- Default width
            height = 8,   -- Default height
        },
    },
    
    -- Custom Trackers (CDM - Cooldown Display Manager)
    customTrackers = {
        essential = {
            anchorTo = "screen",
            offsetX = 0,
            offsetY = -150,  -- 150px down from screen center
            anchors = {{source = "CENTER", target = "CENTER"}},
        },
        utility = {
            anchorTo = "essential",  -- Below Essential CDM
            offsetX = 0,
            offsetY = -35,  -- Gap below essential
            anchors = {{source = "TOP", target = "BOTTOM"}},
        },
        default = {
            anchorTo = "none",
            offsetX = 0,
            offsetY = 0,
            anchors = {{source = "CENTER", target = "CENTER"}},
        },
    },
    
    -- Minimap
    minimap = {
        default = {
            anchorTo = "none",
            offsetX = 0,
            offsetY = 0,
            anchors = {{source = "CENTER", target = "CENTER"}},
        },
    },
    
    -- Rotation Assist Icon
    rotationAssist = {
        default = {
            anchorTo = "screen",
            offsetX = 0,
            offsetY = -180,  -- Default position: center screen, 180px down
            anchors = {{source = "CENTER", target = "CENTER"}},
        },
    },
}

---------------------------------------------------------------------------
-- HELPER FUNCTIONS
---------------------------------------------------------------------------

-- Get default anchor configuration for a specific frame type and key
-- Parameters:
--   frameType: "unitFrames", "castbars", "resourceBars", "customTrackers"
--   frameKey: Specific frame key (e.g., "player", "target", "primary", "secondary")
-- Returns: Default config table or nil if not found
function QUI_Anchoring_Defaults:GetDefaultAnchorConfig(frameType, frameKey)
    if not frameType or not frameKey then return nil end
    
    local defaults = self.defaults[frameType]
    if not defaults then return nil end
    
    -- Try specific key first
    local config = defaults[frameKey]
    if config then
        -- Return a copy to avoid modifying the original
        local result = {
            anchorTo = config.anchorTo,
            anchor = config.anchor,  -- For castbars
            offsetX = config.offsetX,
            offsetY = config.offsetY,
            width = config.width,
            height = config.height,
        }
        -- Deep copy anchors array
        if config.anchors then
            result.anchors = {}
            for i, anchorPair in ipairs(config.anchors) do
                result.anchors[i] = {
                    source = anchorPair.source,
                    target = anchorPair.target,
                }
            end
        end
        return result
    end
    
    -- Fall back to "default" if specific key not found
    if defaults.default then
        local defaultConfig = defaults.default
        local result = {
            anchorTo = defaultConfig.anchorTo,
            anchor = defaultConfig.anchor,  -- For castbars
            offsetX = defaultConfig.offsetX,
            offsetY = defaultConfig.offsetY,
            width = defaultConfig.width,
            height = defaultConfig.height,
        }
        -- Deep copy anchors array
        if defaultConfig.anchors then
            result.anchors = {}
            for i, anchorPair in ipairs(defaultConfig.anchors) do
                result.anchors[i] = {
                    source = anchorPair.source,
                    target = anchorPair.target,
                }
            end
        end
        return result
    end
    
    return nil
end

-- Apply default anchor values to settings if they are missing
-- Parameters:
--   frameType: "unitFrames", "castbars", "resourceBars", "customTrackers"
--   frameKey: Specific frame key
--   settings: Settings table to apply defaults to (modified in place)
-- Returns: true if any defaults were applied, false otherwise
function QUI_Anchoring_Defaults:ApplyDefaultAnchors(frameType, frameKey, settings)
    if not frameType or not frameKey or not settings then return false end
    
    local defaults = self:GetDefaultAnchorConfig(frameType, frameKey)
    if not defaults then return false end
    
    local applied = false
    
    -- Apply anchorTo (for unit frames, resource bars, custom trackers)
    if defaults.anchorTo and not settings.anchorTo then
        settings.anchorTo = defaults.anchorTo
        applied = true
    end
    
    -- Apply anchor (for castbars)
    if defaults.anchor and not settings.anchor then
        settings.anchor = defaults.anchor
        applied = true
    end
    
    -- Apply offsetX
    if defaults.offsetX ~= nil and settings.offsetX == nil then
        settings.offsetX = defaults.offsetX
        applied = true
    end
    
    -- Apply offsetY
    if defaults.offsetY ~= nil and settings.offsetY == nil then
        settings.offsetY = defaults.offsetY
        applied = true
    end
    
    -- Apply anchors array (deep copy)
    if defaults.anchors and (not settings.anchors or #settings.anchors == 0) then
        settings.anchors = {}
        for i, anchorPair in ipairs(defaults.anchors) do
            settings.anchors[i] = {
                source = anchorPair.source,
                target = anchorPair.target,
            }
        end
        applied = true
    end
    
    return applied
end

-- Reset a frame's anchor settings to defaults
-- Parameters:
--   frameType: "unitFrames", "castbars", "resourceBars", "customTrackers"
--   frameKey: Specific frame key
--   settings: Settings table to reset (modified in place)
-- Returns: true if reset was successful, false otherwise
function QUI_Anchoring_Defaults:ResetFrameToDefaults(frameType, frameKey, settings)
    if not frameType or not frameKey or not settings then return false end
    
    local defaults = self:GetDefaultAnchorConfig(frameType, frameKey)
    if not defaults then return false end
    
    -- Reset anchorTo (for unit frames, resource bars, custom trackers)
    if defaults.anchorTo then
        settings.anchorTo = defaults.anchorTo
    end
    
    -- Reset anchor (for castbars)
    if defaults.anchor then
        settings.anchor = defaults.anchor
    end
    
    -- Reset offsets
    if defaults.offsetX ~= nil then
        settings.offsetX = defaults.offsetX
    end
    if defaults.offsetY ~= nil then
        settings.offsetY = defaults.offsetY
    end
    
    -- Reset anchors array (deep copy)
    if defaults.anchors then
        settings.anchors = {}
        for i, anchorPair in ipairs(defaults.anchors) do
            settings.anchors[i] = {
                source = anchorPair.source,
                target = anchorPair.target,
            }
        end
    end
    
    return true
end

