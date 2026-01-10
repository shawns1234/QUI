--[[
    QUI Sizing Module
    Handles frame dimension management (width/height)
    Single Responsibility: Manage frame dimensions
]]

local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- MODULE TABLE
---------------------------------------------------------------------------
local QUI_Sizing = {}
ns.QUI_Sizing = QUI_Sizing

---------------------------------------------------------------------------
-- AUTO-SIZE DETECTION
---------------------------------------------------------------------------
-- Check if anchors array uses horizontal dual anchors (LEFT/RIGHT)
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

-- Check if anchors array uses vertical dual anchors (TOP/BOTTOM)
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

---------------------------------------------------------------------------
-- AUTO-SIZE CONFIG
---------------------------------------------------------------------------
-- Get width/height auto-configuration state for a frame
-- Parameters:
--   anchors: Array of anchor point pairs
--   anchorTarget: Anchor target name (or nil/"none"/"screen" for no auto-sizing)
-- Returns: {widthAuto = bool, heightAuto = bool}
function QUI_Sizing:GetAutoConfig(anchors, anchorTarget)
    -- Only auto-configure if anchored to something (not "none" or "screen")
    if not anchorTarget or anchorTarget == "none" or anchorTarget == "screen" then
        return {widthAuto = false, heightAuto = false}
    end
    
    return {
        widthAuto = IsHorizontalDualAnchor(anchors),
        heightAuto = IsVerticalDualAnchor(anchors),
    }
end

---------------------------------------------------------------------------
-- SIZE APPLICATION
---------------------------------------------------------------------------
-- Apply width/height to frame
-- Parameters:
--   frame: Frame to size
--   width: Width in pixels (nil to skip)
--   height: Height in pixels (nil to skip)
--   autoConfig: {widthAuto = bool, heightAuto = bool} from GetAutoConfig
-- Returns: success boolean
function QUI_Sizing:ApplySize(frame, width, height, autoConfig)
    if not frame then return false end
    
    autoConfig = autoConfig or {widthAuto = false, heightAuto = false}
    
    -- Only apply dimensions that are NOT auto-managed by dual anchors
    if (width ~= nil and not autoConfig.widthAuto) or (height ~= nil and not autoConfig.heightAuto) then
        local success = pcall(function()
            if width ~= nil and not autoConfig.widthAuto then
                frame:SetWidth(width)
            end
            if height ~= nil and not autoConfig.heightAuto then
                frame:SetHeight(height)
            end
        end)
        -- Continue even if size setting fails (secure frames)
        return success
    end
    
    return true
end

---------------------------------------------------------------------------
-- SIZE VALIDATION
---------------------------------------------------------------------------
-- Validate size values
-- Parameters:
--   width: Width value to validate
--   height: Height value to validate
-- Returns: {width = validWidth, height = validHeight}
function QUI_Sizing:ValidateSize(width, height)
    local validWidth = (width ~= nil) and tonumber(width) or nil
    local validHeight = (height ~= nil) and tonumber(height) or nil
    
    return {
        width = validWidth,
        height = validHeight,
    }
end
