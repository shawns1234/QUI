--[[
    qui_options_shared.lua
    Shared utilities and constants for all options components
]]

local ADDON_NAME, ns = ...
local QUI = QuaziiUI
local GUI = QUI.GUI
local QUICore = ns.Addon
local C = GUI.Colors

-- Shared constants
local OPTIONS_CONSTANTS = {
    ROW_GAP = 28,
    SECTION_GAP = 38,
    SECTION_HEADER_GAP = 46,
    PADDING = 15,
    SLIDER_HEIGHT = 65,
    -- Inset constants for consistent spacing
    NESTED_INSET = 6,           -- Inset for nested sections (title text, content text)
    CONTENT_PAD = 6,            -- General content padding in options pages
    SMALL_PAD = 5,               -- Small padding (scroll bars, popovers, text spacing)
    FORM_CONTROL_INSET = 35,     -- Inset for form control tracks (sliders, dropdowns)
    FORM_VALUE_OFFSET = 180,     -- Offset for form control values (sliders, dropdowns, color pickers)
    NINE_POINT_ANCHOR_OPTIONS = {
        {value = "TOPLEFT", text = "Top Left"},
        {value = "TOP", text = "Top"},
        {value = "TOPRIGHT", text = "Top Right"},
        {value = "LEFT", text = "Left"},
        {value = "CENTER", text = "Center"},
        {value = "RIGHT", text = "Right"},
        {value = "BOTTOMLEFT", text = "Bottom Left"},
        {value = "BOTTOM", text = "Bottom"},
        {value = "BOTTOMRIGHT", text = "Bottom Right"},
    },
    QUAZII_FPS_CVARS = {
        -- Graphics Tab
        ["vsync"] = "0",
        ["LowLatencyMode"] = "3",
        ["MSAAQuality"] = "0",
        ["ffxAntiAliasingMode"] = "0",
        ["alphaTestMSAA"] = "1",
        ["cameraFov"] = "90",

        -- Graphics Quality (Base)
        ["graphicsQuality"] = "9",
        ["graphicsShadowQuality"] = "0",
        ["graphicsLiquidDetail"] = "1",
        ["graphicsParticleDensity"] = "5",
        ["graphicsSSAO"] = "0",
        ["graphicsDepthEffects"] = "0",
        ["graphicsComputeEffects"] = "0",
        ["graphicsOutlineMode"] = "1",
        ["OutlineEngineMode"] = "1",
        ["graphicsTextureResolution"] = "2",
        ["graphicsSpellDensity"] = "0",
        ["spellClutter"] = "1",
        ["spellVisualDensityFilterSetting"] = "1",
        ["graphicsProjectedTextures"] = "1",
        ["projectedTextures"] = "1",
        ["graphicsViewDistance"] = "3",
        ["graphicsEnvironmentDetail"] = "0",
        ["graphicsGroundClutter"] = "0",

        -- Advanced Tab
        ["gxTripleBuffer"] = "0",
        ["textureFilteringMode"] = "5",
        ["graphicsRayTracedShadows"] = "0",
        ["rtShadowQuality"] = "0",
        ["ResampleQuality"] = "4",
        ["ffxSuperResolution"] = "1",
        ["VRSMode"] = "0",
        ["GxApi"] = "D3D12",
        ["physicsLevel"] = "0",
        ["maxFPS"] = "144",
        ["maxFPSBk"] = "60",
        ["targetFPS"] = "61",
        ["useTargetFPS"] = "0",
        ["ResampleSharpness"] = "0.2",
        ["Contrast"] = "75",
        ["Brightness"] = "50",
        ["Gamma"] = "1",

        -- Additional Optimizations
        ["particulatesEnabled"] = "0",
        ["clusteredShading"] = "0",
        ["volumeFogLevel"] = "0",
        ["reflectionMode"] = "0",
        ["ffxGlow"] = "0",
        ["farclip"] = "5000",
        ["horizonStart"] = "1000",
        ["horizonClip"] = "5000",
        ["lodObjectCullSize"] = "35",
        ["lodObjectFadeScale"] = "50",
        ["lodObjectMinSize"] = "0",
        ["doodadLodScale"] = "50",
        ["entityLodDist"] = "7",
        ["terrainLodDist"] = "350",
        ["TerrainLodDiv"] = "512",
        ["waterDetail"] = "1",
        ["rippleDetail"] = "0",
        ["weatherDensity"] = "3",
        ["entityShadowFadeScale"] = "15",
        ["groundEffectDist"] = "40",
        ["ResampleAlwaysSharpen"] = "1",

        -- Special Hacks
        ["cameraDistanceMaxZoomFactor"] = "2.6",
        ["CameraReduceUnexpectedMovement"] = "1",
    },
}

-- Helper: Get database safely
local function GetDB()
    if QUICore and QUICore.db and QUICore.db.profile then
        return QUICore.db.profile
    end
    return nil
end

-- Helper: Create scrollable content frame with auto-height management
local function CreateScrollableContent(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 5)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth())
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)
    content._hasContent = false

    scrollFrame:SetScript("OnSizeChanged", function(self, width, height)
        content:SetWidth(width)
    end)

    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        local SMALL_PAD = OPTIONS_CONSTANTS.SMALL_PAD or 5
        scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", SMALL_PAD, -16)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", SMALL_PAD, 16)

        local thumb = scrollBar:GetThumbTexture()
        if thumb then
            thumb:SetColorTexture(0.35, 0.45, 0.5, 0.8)
        end

        local scrollUp = scrollBar.ScrollUpButton or scrollBar.Back
        local scrollDown = scrollBar.ScrollDownButton or scrollBar.Forward
        if scrollUp then scrollUp:Hide(); scrollUp:SetAlpha(0) end
        if scrollDown then scrollDown:Hide(); scrollDown:SetAlpha(0) end

        scrollBar:HookScript("OnShow", function(self)
            C_Timer.After(0.066, function()
                local maxScroll = scrollFrame:GetVerticalScrollRange()
                if maxScroll <= 1 then
                    self:Hide()
                end
            end)
        end)
    end

    -- Track all sections created in this content frame
    local sections = {}
    
    -- Auto-update content height function
    -- Calculates total height based on all tracked sections
    local function UpdateContentHeight()
        local totalHeight = 10 -- Top padding
        local SECTION_GAP = 4
        
        for _, section in ipairs(sections) do
            if section and section:IsShown() then
                totalHeight = totalHeight + section:GetHeight() + SECTION_GAP
            end
        end
        
        -- Also check for any non-section children (like standalone controls)
        for i = 1, content:GetNumChildren() do
            local child = select(i, content:GetChildren())
            if child and child:IsShown() then
                local isTrackedSection = false
                for _, section in ipairs(sections) do
                    if child == section then
                        isTrackedSection = true
                        break
                    end
                end
                if not isTrackedSection then
                    local childHeight = child:GetHeight() or 0
                    local childBottom = child:GetBottom()
                    if childBottom then
                        -- Calculate height from top of content to bottom of this child
                        local contentTop = content:GetTop() or 0
                        local heightNeeded = contentTop - childBottom + 20
                        if heightNeeded > totalHeight then
                            totalHeight = heightNeeded
                        end
                    end
                end
            end
        end
        
        content:SetHeight(math.max(totalHeight, 100)) -- Minimum 100px
    end
    
    -- Store update function and sections tracker on content frame
    content.UpdateHeight = UpdateContentHeight
    content._sections = sections
    
    -- Initial height update after a short delay to ensure all content is created
    C_Timer.After(0.1, function()
        UpdateContentHeight()
    end)

    return scrollFrame, content
end

-- Helper: Get texture list from LSM
local LSM = LibStub("LibSharedMedia-3.0", true)
local function GetTextureList()
    local textures = {}
    if LSM then
        for _, name in ipairs(LSM:List("statusbar")) do
            table.insert(textures, {value = name, text = name})
        end
    else
        textures = {{value = "Solid", text = "Solid"}}
    end
    return textures
end

-- Helper: Get font list from LSM
local function GetFontList()
    local fonts = {}
    if LSM then
        for _, name in ipairs(LSM:List("font")) do
            table.insert(fonts, {value = name, text = name})
        end
    else
        fonts = {{value = "Friz Quadrata TT", text = "Friz Quadrata TT"}}
    end
    return fonts
end

-- FPS Settings helpers
local function BackupCurrentFPSSettings()
    local db = GetDB()
    local backup = {}
    for cvar, _ in pairs(OPTIONS_CONSTANTS.QUAZII_FPS_CVARS) do
        local success, current = pcall(C_CVar.GetCVar, cvar)
        if success and current then
            backup[cvar] = current
        end
    end
    db.fpsBackup = backup
    return true
end

local function RestorePreviousFPSSettings()
    local db = GetDB()
    if not db.fpsBackup then
        print("|cffFF6B6BQuaziiUI:|r No backup found. Apply FPS settings first to create a backup.")
        return false
    end

    local successCount = 0
    local failCount = 0
    for cvar, value in pairs(db.fpsBackup) do
        local ok = pcall(C_CVar.SetCVar, cvar, tostring(value))
        if ok then
            successCount = successCount + 1
        else
            failCount = failCount + 1
        end
    end

    db.fpsBackup = nil

    print("|cff34D399QuaziiUI:|r Restored " .. successCount .. " previous settings.")
    if failCount > 0 then
        print("|cffFF6B6BQuaziiUI:|r " .. failCount .. " settings could not be restored.")
    end
    return true
end

local function ApplyQuaziiFPSSettings()
    BackupCurrentFPSSettings()

    local successCount = 0
    local failCount = 0

    for cvar, value in pairs(OPTIONS_CONSTANTS.QUAZII_FPS_CVARS) do
        local success = pcall(function()
            C_CVar.SetCVar(cvar, value)
        end)

        if success then
            successCount = successCount + 1
        else
            failCount = failCount + 1
        end
    end

    print("|cff34D399QuaziiUI:|r Your previous settings have been backed up.")
    print("|cff34D399QuaziiUI:|r Applied " .. successCount .. " FPS settings. Use 'Restore Previous Settings' to undo.")
    if failCount > 0 then
        print("|cffFF6B6BQuaziiUI:|r " .. failCount .. " settings could not be applied (may require restart).")
    end
end

local function CheckCVarsMatch()
    local matchCount, totalCount = 0, 0
    for cvar, expectedVal in pairs(OPTIONS_CONSTANTS.QUAZII_FPS_CVARS) do
        totalCount = totalCount + 1
        local currentVal = C_CVar.GetCVar(cvar)
        if currentVal == expectedVal then
            matchCount = matchCount + 1
        end
    end
    return matchCount == totalCount, matchCount, totalCount
end

-- Helper to create a scrollable text box with fixed height
local function CreateScrollableTextBox(parent, height, text)
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetHeight(height)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    container:SetBackdropColor(0.1, 0.1, 0.1, 1)
    container:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    -- ScrollFrame to contain the EditBox
    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 6)
    
    -- Style the scroll bar
    local scrollBar = scrollFrame.ScrollBar or _G[scrollFrame:GetName().."ScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, -18)
        scrollBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -4, 18)
    end
    
    -- EditBox inside ScrollFrame
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(scrollFrame:GetWidth() or 400)
    editBox:SetText(text or "")
    editBox:SetCursorPosition(0)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    
    -- Update width when container is sized
    container:SetScript("OnSizeChanged", function(self)
        editBox:SetWidth(self:GetWidth() - 36)
    end)
    
    scrollFrame:SetScrollChild(editBox)
    
    container.editBox = editBox
    container.scrollFrame = scrollFrame
    return container
end

---------------------------------------------------------------------------
-- UI COMPOSITION HELPERS
-- Helper methods to reduce duplication in options UI creation
---------------------------------------------------------------------------

-- Helper: Add a form control with standard positioning
-- Parameters:
--   parent: Parent frame
--   control: The control widget (checkbox, slider, dropdown, etc.)
--   y: Current y position (will be updated)
--   PAD: Padding constant
--   FORM_ROW: Form row height constant
-- Returns: Updated y position
local function AddFormControl(parent, control, y, PAD, FORM_ROW)
    if not control then return y end
    control:SetPoint("TOPLEFT", PAD, y)
    control:SetPoint("RIGHT", parent, "RIGHT", -PAD, 0)
    return y - FORM_ROW
end

-- Helper: Create and position a note/description label
-- Parameters:
--   parent: Parent frame
--   text: Note/description text
--   y: Current y position (will be updated)
--   PAD: Padding constant (defaults to CONTENT_PAD)
--   fontSize: Font size (default: 11)
--   color: Text color (default: textMuted)
-- Returns: label frame, updated y position
local function AddFormNote(parent, text, y, PAD, fontSize, color)
    if not text or text == "" then return nil, y end
    
    PAD = PAD or OPTIONS_CONSTANTS.CONTENT_PAD or 10
    fontSize = fontSize or 11
    color = color or C.textMuted
    
    local label = GUI:CreateLabel(parent, text, fontSize, color)
    label:SetPoint("TOPLEFT", PAD, y)
    label:SetPoint("RIGHT", parent, "RIGHT", -PAD, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(true)
    
    -- Get actual height after text wrapping
    local NOTE_SPACING = 8  -- Spacing after note text
    
    -- Try to get the actual height from the FontString
    -- GetStringHeight() returns the height of the wrapped text string
    local actualHeight = label:GetStringHeight()
    
    -- If GetStringHeight() returns 0 or invalid, try GetHeight()
    if actualHeight == 0 or not actualHeight then
        actualHeight = label:GetHeight()
    end
    
    local updatedY = y - actualHeight - NOTE_SPACING
    
    return label, updatedY
end

-- Helper: Create a collapsible section and return content frame and updated y
-- Parameters:
--   parent: Parent frame
--   title: Section title
--   y: Current y position (will be updated)
--   PAD: Padding constant
--   isExpandedByDefault: Whether section starts expanded (default: false)
--   previousSection: Optional previous section to anchor to (for relative positioning)
--   sectionOptions: Optional table with additional options:
--     - hideHeader: If true, hide the header completely (default: false)
--     - nonCollapsible: If true, disable collapsing functionality (default: false)
-- Returns: section (with .content property), updated y position
local function CreateCollapsibleSection(parent, title, y, PAD, isExpandedByDefault, previousSection, sectionOptions)
    isExpandedByDefault = isExpandedByDefault or false
    sectionOptions = sectionOptions or {}
    
    -- Auto-detect nesting: if parent is a section's content, set up nesting options
    local parentSection = nil
    local depth = 0
    if parent and parent.GetParent then
        local parentFrame = parent:GetParent()
        -- Check if parent is a section's content (has .content property and parent is a section)
        if parentFrame and parentFrame.content == parent then
            parentSection = parentFrame
            depth = (parentSection.depth or 0) + 1
        end
    end
    
    -- Create section with nesting options if detected, plus any additional options
    local options = {}
    if parentSection then
        options.depth = depth
        options.parentSection = parentSection
    end
    -- Pass through section options
    if sectionOptions.hideHeader then
        options.hideHeader = true
    end
    if sectionOptions.nonCollapsible then
        options.nonCollapsible = true
    end
    
    local section = GUI:CreateCollapsibleSection(parent, title, isExpandedByDefault, options)
    
    -- Track nested sections in parent section
    if parentSection then
        if not parentSection._nestedSections then
            parentSection._nestedSections = {}
        end
        table.insert(parentSection._nestedSections, section)
    end
    
    -- Auto-register section with scroll content if parent has _sections tracker
    if parent._sections then
        table.insert(parent._sections, section)
    end
    
    -- Hook section's UpdateHeight to update both parent section (if nested) and scroll content
    local originalUpdateHeight = section.UpdateHeight
    section.UpdateHeight = function(self)
        if originalUpdateHeight then originalUpdateHeight(self) end
        
        -- Update parent section height if nested
        if parentSection and parentSection.UpdateHeight then
            C_Timer.After(0, function()
                parentSection:UpdateHeight()
            end)
        end
        
        -- Update scroll content height if registered
        if parent._sections and parent.UpdateHeight then
            C_Timer.After(0, function()
                parent:UpdateHeight()
            end)
        end
    end
    
    -- Hook section's expand/collapse to update both parent section (if nested) and scroll content
    local originalOnExpandChanged = section.OnExpandChanged
    section.OnExpandChanged = function(isExpanded)
        if originalOnExpandChanged then originalOnExpandChanged(isExpanded) end
        
        -- Update parent section height if nested
        if parentSection and parentSection.UpdateHeight then
            C_Timer.After(0, function()
                parentSection:UpdateHeight()
            end)
        end
        
        -- Update scroll content height if registered
        if parent._sections and parent.UpdateHeight then
            C_Timer.After(0, function()
                parent:UpdateHeight()
            end)
        end
    end
    
    -- Handle positioning
    if parentSection then
        -- Nested section: position relative to previous nested section or at top of content
        local prevNestedSection = nil
        if parentSection._nestedSections and #parentSection._nestedSections > 1 then
            prevNestedSection = parentSection._nestedSections[#parentSection._nestedSections - 1]
        end
        
        if prevNestedSection then
            -- Anchor to previous nested section
            section:SetPoint("TOPLEFT", prevNestedSection, "BOTTOMLEFT", 0, -4)
            section:SetPoint("TOPRIGHT", prevNestedSection, "BOTTOMRIGHT", 0, -4)
        else
            -- First nested section
            -- If parent is itself nested (depth > 0), parent content is already inset,
            -- so position at 0 to align with content edge (nested section's content will be inset)
            -- If parent is not nested (depth = 0), use NESTED_INSET to align with text
            local parentDepth = parentSection.depth or 0
            if parentDepth > 0 then
                -- Parent is nested: align with content edge (0 inset)
                section:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
            else
                -- Parent is not nested: use NESTED_INSET to align with text
                local NESTED_INSET = OPTIONS_CONSTANTS.NESTED_INSET or 4
                section:SetPoint("TOPLEFT", parent, "TOPLEFT", NESTED_INSET, 0)
            end
            section:SetPoint("RIGHT", parent, "RIGHT", 0, 0)  -- No right padding
        end
        -- For nested sections, y is not used for positioning
        local updatedY = y - section:GetHeight()
        return section, section.content, updatedY
    elseif previousSection then
        -- Relative anchoring: anchor to previous section's bottom
        -- This ensures sections push each other when expanding/collapsing
        section:SetPoint("TOPLEFT", previousSection, "BOTTOMLEFT", 0, -4)
        section:SetPoint("TOPRIGHT", previousSection, "BOTTOMRIGHT", 0, -4)
        -- When using relative anchoring, y is not used for positioning, but we still calculate it for tracking
        local updatedY = y - section:GetHeight()
        return section, section.content, updatedY
    else
        -- Absolute positioning (first section or fallback)
        section:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
        section:SetPoint("RIGHT", parent, "RIGHT", -PAD, 0)
        local updatedY = y - section:GetHeight()
        return section, section.content, updatedY
    end
end

-- Helper: Create a nested collapsible section inside another section's content area
-- Parameters:
--   parentSection: The parent collapsible section (created with CreateCollapsibleSection)
--   title: Section title
--   isExpandedByDefault: Whether section starts expanded (default: false)
--   depth: Nesting depth (default: calculated from parentSection.depth + 1)
-- Returns: section (with .content property), content frame
local function CreateNestedSection(parentSection, title, isExpandedByDefault, depth)
    if not parentSection or not parentSection.content then
        error("CreateNestedSection: parentSection must be a valid collapsible section with .content property")
    end
    
    depth = depth or ((parentSection.depth or 0) + 1)
    local parentContent = parentSection.content
    isExpandedByDefault = isExpandedByDefault or false
    
    -- Create the nested section with options
    local section = GUI:CreateCollapsibleSection(parentContent, title, isExpandedByDefault, {
        depth = depth,
        parentSection = parentSection,
    })
    
    -- Track nested sections for height calculation
    if not parentSection._nestedSections then
        parentSection._nestedSections = {}
    end
    table.insert(parentSection._nestedSections, section)
    
    -- Position relative to previous nested section or at top of content
    local prevSection = nil
    if #parentSection._nestedSections > 1 then
        prevSection = parentSection._nestedSections[#parentSection._nestedSections - 1]
    end
    
    if prevSection then
        -- Anchor to previous nested section
        section:SetPoint("TOPLEFT", prevSection, "BOTTOMLEFT", 0, -4)
        section:SetPoint("TOPRIGHT", prevSection, "BOTTOMRIGHT", 0, -4)
    else
        -- First nested section
        -- If parent is itself nested (depth > 0), parent content is already inset,
        -- so position at 0 to align with content edge (nested section's content will be inset)
        -- If parent is not nested (depth = 0), use NESTED_INSET to align with text
        local parentDepth = parentSection.depth or 0
        if parentDepth > 0 then
            -- Parent is nested: align with content edge (0 inset)
            section:SetPoint("TOPLEFT", parentContent, "TOPLEFT", 0, 0)
        else
            -- Parent is not nested: use NESTED_INSET to align with text
            local NESTED_INSET = OPTIONS_CONSTANTS.NESTED_INSET or 4
            section:SetPoint("TOPLEFT", parentContent, "TOPLEFT", NESTED_INSET, 0)
        end
        section:SetPoint("RIGHT", parentContent, "RIGHT", 0, 0)  -- No right padding
    end
    
    -- Hook to update parent height when nested section changes
    local originalUpdateHeight = section.UpdateHeight
    section.UpdateHeight = function(self)
        if originalUpdateHeight then 
            originalUpdateHeight(self) 
        end
        -- Bubble up to parent section
        if parentSection and parentSection.UpdateHeight then
            C_Timer.After(0, function()
                parentSection:UpdateHeight()
            end)
        end
    end
    
    -- Also hook expand/collapse to update parent
    local originalOnExpandChanged = section.OnExpandChanged
    section.OnExpandChanged = function(isExpanded)
        if originalOnExpandChanged then 
            originalOnExpandChanged(isExpanded) 
        end
        -- Update parent height when expanding/collapsing
        if parentSection and parentSection.UpdateHeight then
            C_Timer.After(0, function()
                parentSection:UpdateHeight()
            end)
        end
    end
    
    return section, section.content
end

-- Helper: Create a section manager to handle relative positioning of collapsible sections
-- This ensures sections push each other when expanding/collapsing
local function CreateSectionManager(parent, startY, PAD)
    local sections = {}
    local currentY = startY
    local firstSection = nil
    
    local manager = {}
    
    function manager:AddSection(title, isExpandedByDefault)
        local previousSection = #sections > 0 and sections[#sections] or nil
        local section, content, newY = CreateCollapsibleSection(
            parent, 
            title, 
            previousSection and 0 or currentY,  -- Use 0 if relative, currentY if absolute
            PAD, 
            isExpandedByDefault or false,
            previousSection
        )
        
        -- Set up height change callback to reposition following sections
        section.OnHeightChanged = function()
            -- When this section's height changes, all following sections will automatically
            -- reposition because they're anchored to the previous section's bottom
            -- WoW's layout system handles this automatically with relative anchors
        end
        
        table.insert(sections, section)
        if not firstSection then firstSection = section end
        
        -- Update currentY for next absolute-positioned section (if any)
        currentY = newY
        
        return section, content
    end
    
    function manager:GetSections()
        return sections
    end
    
    return manager
end

-- Helper: Add multiple form controls in sequence
-- Parameters:
--   parent: Parent frame
--   controls: Array of control widgets
--   y: Current y position (will be updated)
--   PAD: Padding constant
--   FORM_ROW: Form row height constant
-- Returns: Updated y position
local function AddFormControls(parent, controls, y, PAD, FORM_ROW)
    for _, control in ipairs(controls) do
        if control then
            y = AddFormControl(parent, control, y, PAD, FORM_ROW)
        end
    end
    return y
end

-- Export shared utilities
local OptionsShared = {
    GetDB = GetDB,
    CreateScrollableContent = CreateScrollableContent,
    CreateScrollableTextBox = CreateScrollableTextBox,
    GetTextureList = GetTextureList,
    GetFontList = GetFontList,
    BackupCurrentFPSSettings = BackupCurrentFPSSettings,
    RestorePreviousFPSSettings = RestorePreviousFPSSettings,
    ApplyQuaziiFPSSettings = ApplyQuaziiFPSSettings,
    CheckCVarsMatch = CheckCVarsMatch,
    CONSTANTS = OPTIONS_CONSTANTS,
    -- UI Composition helpers
    AddFormControl = AddFormControl,
    AddFormControls = AddFormControls,
    AddFormNote = AddFormNote,
    CreateCollapsibleSection = CreateCollapsibleSection,
    CreateNestedSection = CreateNestedSection,
}

-- Make available globally for component files
ns.OptionsShared = OptionsShared

return OptionsShared
