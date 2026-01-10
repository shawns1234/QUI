--[[
    QUI Positioning Module
    Handles frame positioning via SetPoint
    Single Responsibility: Execute frame positioning via SetPoint
]]

local ADDON_NAME, ns = ...
local QUICore = ns.Addon

---------------------------------------------------------------------------
-- MODULE TABLE
---------------------------------------------------------------------------
local QUI_Positioning = {}
ns.QUI_Positioning = QUI_Positioning

local Helpers = {}

---------------------------------------------------------------------------
-- SETUP HELPERS
---------------------------------------------------------------------------
function QUI_Positioning:SetHelpers(helpers)
    Helpers = helpers or {}
end

-- Helper function wrappers (with fallbacks)
local function Scale(x)
    return Helpers.Scale and Helpers.Scale(x) or (QUICore and QUICore.Scale and QUICore:Scale(x) or x)
end

---------------------------------------------------------------------------
-- BORDER HELPERS
---------------------------------------------------------------------------
-- Get border size from a frame's backdrop
local function GetBorderSize(frame)
    if not frame or not frame.GetBackdrop then
        return 0
    end
    
    local backdrop = frame:GetBackdrop()
    if not backdrop or not backdrop.edgeSize then
        return 0
    end
    
    return backdrop.edgeSize or 0
end

-- Calculate border adjustments for a given anchor point and border size
local function GetBorderAdjustment(anchorPoint, borderSize)
    if not borderSize or borderSize == 0 then return 0, 0 end
    
    local adjX, adjY = 0, 0
    if anchorPoint == "TOPLEFT" then
        adjX = borderSize
        adjY = -borderSize
    elseif anchorPoint == "TOP" then
        adjY = -borderSize
    elseif anchorPoint == "TOPRIGHT" then
        adjX = -borderSize
        adjY = -borderSize
    elseif anchorPoint == "LEFT" then
        adjX = borderSize
    elseif anchorPoint == "RIGHT" then
        adjX = -borderSize
    elseif anchorPoint == "BOTTOMLEFT" then
        adjX = borderSize
        adjY = borderSize
    elseif anchorPoint == "BOTTOM" then
        adjY = borderSize
    elseif anchorPoint == "BOTTOMRIGHT" then
        adjX = -borderSize
        adjY = borderSize
    end
    return adjX, adjY
end

---------------------------------------------------------------------------
-- ANCHOR DECOMPOSITION HELPERS
---------------------------------------------------------------------------
-- Decompose anchor point into horizontal/vertical components
local ANCHOR_H = {
    TOPLEFT = "LEFT", TOP = "CENTER", TOPRIGHT = "RIGHT",
    LEFT = "LEFT", CENTER = "CENTER", RIGHT = "RIGHT",
    BOTTOMLEFT = "LEFT", BOTTOM = "CENTER", BOTTOMRIGHT = "RIGHT",
}
local ANCHOR_V = {
    TOPLEFT = "TOP", TOP = "TOP", TOPRIGHT = "TOP",
    LEFT = "CENTER", CENTER = "CENTER", RIGHT = "CENTER",
    BOTTOMLEFT = "BOTTOM", BOTTOM = "BOTTOM", BOTTOMRIGHT = "BOTTOM",
}

-- Check if two anchor points are horizontally opposite
local function AreHorizontallyOpposite(anchor1, anchor2)
    local h1, h2 = ANCHOR_H[anchor1], ANCHOR_H[anchor2]
    return (h1 == "LEFT" and h2 == "RIGHT") or (h1 == "RIGHT" and h2 == "LEFT")
end

-- Check if two anchor points are vertically opposite
local function AreVerticallyOpposite(anchor1, anchor2)
    local v1, v2 = ANCHOR_V[anchor1], ANCHOR_V[anchor2]
    return (v1 == "TOP" and v2 == "BOTTOM") or (v1 == "BOTTOM" and v2 == "TOP")
end

---------------------------------------------------------------------------
-- VALIDATION
---------------------------------------------------------------------------
-- Valid anchor points
local VALID_ANCHOR_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

---------------------------------------------------------------------------
-- POSITIONING
---------------------------------------------------------------------------
-- Clear points and set temporary point (required before positioning)
-- Returns: true if successful, false otherwise
local function ClearAndSetTemporaryPoint(frame)
    return pcall(function()
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)  -- Temporary point
    end)
end

-- Position a frame using anchor configuration
-- Parameters:
--   frame: Frame to position
--   anchorTarget: Name of anchor target or "none"/"screen"/"unitframe"
--   anchors: Array of anchor point pairs {source, target}
--   offsetX: X offset in pixels
--   offsetY: Y offset in pixels
--   parentFrame: Optional parent frame (for "unitframe" anchor type)
--   getAnchorTarget: Function to get anchor target frame by name
-- Returns: success boolean
function QUI_Positioning:PositionFrame(frame, anchorTarget, anchors, offsetX, offsetY, parentFrame, getAnchorTarget)
    if not frame then return false end
    
    -- Defer positioning if in combat or secure context to avoid taint
    if InCombatLockdown() then
        C_Timer.After(0, function()
            self:PositionFrame(frame, anchorTarget, anchors, offsetX, offsetY, parentFrame, getAnchorTarget)
        end)
        return false
    end
    
    offsetX = offsetX or 0
    offsetY = offsetY or 0
    
    -- Normalize anchors array
    if not anchors or #anchors == 0 then
        anchors = {{source = "CENTER", target = "CENTER"}}
    end
    
    -- Clear points and immediately set temporary point (CRITICAL: frame must always have points)
    if not ClearAndSetTemporaryPoint(frame) then
        return false
    end
    
    -- Resolve the anchor target frame
    local anchorFrame
    if anchorTarget == "unitframe" and parentFrame then
        anchorFrame = parentFrame
    elseif not anchorTarget or anchorTarget == "none" or anchorTarget == "screen" then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
        return true
    else
        if getAnchorTarget then
            anchorFrame = getAnchorTarget(anchorTarget)
        end
    end
    
    -- Handle deferred positioning if anchor not ready
    if not anchorFrame then
        -- Anchor target not registered yet - defer positioning
        C_Timer.After(0, function()
            if frame then
                self:PositionFrame(frame, anchorTarget, anchors, offsetX, offsetY, parentFrame, getAnchorTarget)
            end
        end)
        return false
    end
    
    if not anchorFrame:IsShown() then
        -- Anchor target not shown yet - defer positioning
        C_Timer.After(0.1, function()
            if frame then
                self:PositionFrame(frame, anchorTarget, anchors, offsetX, offsetY, parentFrame, getAnchorTarget)
            end
        end)
        return false
    end
    
    -- Get border sizes for pixel-perfect positioning
    local sourceBorderSize = GetBorderSize(frame)
    local targetBorderSize = GetBorderSize(anchorFrame)
    
    -- Handle single or dual anchors
    if #anchors == 1 then
        -- Single anchor point
        local anchorPair = anchors[1]
        local source = anchorPair.source or "CENTER"
        local target = anchorPair.target or "CENTER"
        
        -- Validate anchor points
        if not VALID_ANCHOR_POINTS[source] then source = "CENTER" end
        if not VALID_ANCHOR_POINTS[target] then target = source end
        
        local sourceAdjX, sourceAdjY = GetBorderAdjustment(source, sourceBorderSize)
        local targetAdjX, targetAdjY = GetBorderAdjustment(target, targetBorderSize)
        
        -- For opposite directions on each axis, borders should cancel out
        local netAdjX = AreHorizontallyOpposite(source, target)
            and 0
            or (targetAdjX - sourceAdjX)
            
        local netAdjY = AreVerticallyOpposite(source, target)
            and 0
            or (targetAdjY - sourceAdjY)
        
        local scaledOffsetX = Scale(offsetX) + netAdjX
        local scaledOffsetY = math.floor(Scale(offsetY) + 0.5) + netAdjY
        
        frame:ClearAllPoints()
        frame:SetPoint(source, anchorFrame, target, scaledOffsetX, scaledOffsetY)
        return true
        
    elseif #anchors == 2 then
        -- Dual anchor points
        local anchorPair1 = anchors[1]
        local anchorPair2 = anchors[2]
        local source1 = anchorPair1.source or "CENTER"
        local target1 = anchorPair1.target or "CENTER"
        local source2 = anchorPair2.source or "CENTER"
        local target2 = anchorPair2.target or "CENTER"
        
        -- Validate anchor points
        if not VALID_ANCHOR_POINTS[source1] then source1 = "CENTER" end
        if not VALID_ANCHOR_POINTS[target1] then target1 = source1 end
        if not VALID_ANCHOR_POINTS[source2] then source2 = "CENTER" end
        if not VALID_ANCHOR_POINTS[target2] then target2 = source2 end
        
        local sourceAdjX1, sourceAdjY1 = GetBorderAdjustment(source1, sourceBorderSize)
        local targetAdjX1, targetAdjY1 = GetBorderAdjustment(target1, targetBorderSize)
        local netAdjX1 = AreHorizontallyOpposite(source1, target1)
            and 0
            or (targetAdjX1 - sourceAdjX1)
        local netAdjY1 = AreVerticallyOpposite(source1, target1)
            and 0
            or (targetAdjY1 - sourceAdjY1)
        
        local sourceAdjX2, sourceAdjY2 = GetBorderAdjustment(source2, sourceBorderSize)
        local targetAdjX2, targetAdjY2 = GetBorderAdjustment(target2, targetBorderSize)
        local netAdjX2 = AreHorizontallyOpposite(source2, target2)
            and 0
            or (targetAdjX2 - sourceAdjX2)
        local netAdjY2 = AreVerticallyOpposite(source2, target2)
            and 0
            or (targetAdjY2 - sourceAdjY2)
        
        local scaledOffsetX1 = Scale(offsetX) + netAdjX1
        local scaledOffsetY1 = math.floor(Scale(offsetY) + 0.5) + netAdjY1
        local scaledOffsetX2 = Scale(offsetX) + netAdjX2
        local scaledOffsetY2 = math.floor(Scale(offsetY) + 0.5) + netAdjY2
        
        frame:ClearAllPoints()
        frame:SetPoint(source1, anchorFrame, target1, scaledOffsetX1, scaledOffsetY1)
        frame:SetPoint(source2, anchorFrame, target2, scaledOffsetX2, scaledOffsetY2)
        return true
    end
    
    return false
end
