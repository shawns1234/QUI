--- QuaziiUI Datatext Registry
--- Central system for managing and displaying datatexts

local ADDON_NAME, ns = ...
local QUICore = ns.Addon
local LSM = LibStub("LibSharedMedia-3.0")

-- Cache frequently used globals
local format = string.format
local floor = math.floor
local wipe = wipe

-- Constants
local MAX_GUILD_TOOLTIP_DISPLAY = 20

-- Module reference
local Datatexts = {}
QUICore.Datatexts = Datatexts

-- Registry storage
Datatexts.registry = {}
Datatexts.activeInstances = {}  -- Track active datatext instances for cleanup

-- Get user's configured value color for datatexts (returns 0-255 integers for hex formatting)
local function GetValueColor()
    -- Access db through ns.Addon which is always available
    local addon = ns and ns.Addon
    local db = addon and addon.db and addon.db.profile
    if not db then return 26, 255, 26 end  -- Default green in 0-255

    local dt = db.datatext
    if not dt then return 26, 255, 26 end

    if dt.useClassColor then
        local _, class = UnitClass("player")
        if class then
            local color = RAID_CLASS_COLORS[class]
            if color then
                return floor(color.r * 255), floor(color.g * 255), floor(color.b * 255)
            end
        end
    end

    local c = dt.valueColor or {0.1, 1.0, 0.1, 1}
    return floor(c[1] * 255), floor(c[2] * 255), floor(c[3] * 255)
end

-- Get label based on per-slot shortLabel/noLabel settings
-- @param fullLabel string The full label (e.g., "FPS: ")
-- @param shortLabel string The abbreviated label (e.g., "F: ")
-- @param useShortLabel boolean Per-slot shortLabel setting from slotFrame.shortLabel
-- @param useNoLabel boolean Per-slot noLabel setting from slotFrame.noLabel
-- @return string The appropriate label based on slot settings
local function GetLabel(fullLabel, shortLabel, useShortLabel, useNoLabel)
    if useNoLabel then
        return ""
    end
    if useShortLabel then
        return shortLabel
    end
    return fullLabel
end

---=================================================================================
--- REGISTRATION API
---=================================================================================

--- Register a new datatext
-- @param id string Unique identifier
-- @param datatextDef table Datatext definition with OnEnable, OnDisable, etc.
function Datatexts:Register(id, datatextDef)
    if self.registry[id] then
        print("|cffff0000QuaziiUI:|r Datatext '" .. id .. "' is already registered!")
        return false
    end
    
    if not datatextDef.OnEnable or type(datatextDef.OnEnable) ~= "function" then
        print("|cffff0000QuaziiUI:|r Datatext '" .. id .. "' missing OnEnable function!")
        return false
    end
    
    self.registry[id] = {
        id = id,
        displayName = datatextDef.displayName or id,
        category = datatextDef.category or "General",
        description = datatextDef.description or "",
        OnEnable = datatextDef.OnEnable,
        OnDisable = datatextDef.OnDisable,
    }
    
    return true
end

--- Get a sorted list of all registered datatexts
function Datatexts:GetAll()
    local list = {}
    for id, def in pairs(self.registry) do
        table.insert(list, def)
    end
    table.sort(list, function(a, b)
        if a.category == b.category then
            return a.displayName < b.displayName
        end
        return a.category < b.category
    end)
    return list
end

--- Get datatext definition by ID
function Datatexts:Get(id)
    return self.registry[id]
end

---=================================================================================
--- SLOT ATTACHMENT API
---=================================================================================

--- Attach a datatext to a slot frame
-- @param slotFrame Frame The slot container
-- @param datatextID string The datatext to attach
-- @param settings table Optional settings for this instance
-- @return boolean success
function Datatexts:AttachToSlot(slotFrame, datatextID, settings)
    if not slotFrame then
        print("|cffff0000QuaziiUI:|r Invalid slot frame provided")
        return false
    end
    
    -- Clean up existing datatext on this slot
    if slotFrame.datatextInstance then
        self:DetachFromSlot(slotFrame)
    end
    
    local datatextDef = self.registry[datatextID]
    if not datatextDef then
        -- Empty slot - show placeholder
        if not slotFrame.text then
            slotFrame.text = slotFrame:CreateFontString(nil, "OVERLAY")
            slotFrame.text:SetPoint("CENTER")
        end
        slotFrame.text:SetText("|cff666666(empty)")
        return true
    end
    
    -- Create datatext instance
    local success, instance = pcall(datatextDef.OnEnable, slotFrame, settings or {})
    
    if not success then
        print("|cffff0000QuaziiUI:|r Failed to enable datatext '" .. datatextID .. "': " .. tostring(instance))
        return false
    end
    
    -- Store instance for cleanup
    slotFrame.datatextInstance = {
        id = datatextID,
        frame = instance,
        def = datatextDef,
    }
    
    -- Track globally for mass updates
    table.insert(self.activeInstances, {
        slot = slotFrame,
        instance = instance,
        id = datatextID,
    })
    
    return true
end

--- Detach datatext from a slot
function Datatexts:DetachFromSlot(slotFrame)
    if not slotFrame or not slotFrame.datatextInstance then return end
    
    local instance = slotFrame.datatextInstance
    
    -- Call OnDisable if provided
    if instance.def.OnDisable then
        pcall(instance.def.OnDisable, instance.frame)
    end
    
    -- Clean up instance frame
    if instance.frame then
        instance.frame:Hide()
        instance.frame:SetParent(nil)
    end
    
    -- Remove from global tracking
    for i = #self.activeInstances, 1, -1 do
        if self.activeInstances[i].slot == slotFrame then
            table.remove(self.activeInstances, i)
        end
    end
    
    slotFrame.datatextInstance = nil
end

--- Update all active datatexts (useful for settings changes)
function Datatexts:UpdateAll()
    for _, active in ipairs(self.activeInstances) do
        if active.instance and active.instance.Update then
            pcall(active.instance.Update)
        end
    end
end

---=================================================================================
--- BUILT-IN DATATEXTS
---=================================================================================

-- Time datatext
Datatexts:Register("time", {
    displayName = "Time",
    category = "System",
    description = "Displays current time (local or server)",
    
    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()
        
        local text = slotFrame.text
        if not text then
            text = slotFrame:CreateFontString(nil, "OVERLAY")
            text:SetPoint("CENTER")
            slotFrame.text = text
        end
        
        local function Update()
            -- Read time settings from global config (not panel config)
            local dtSettings = QUICore.db and QUICore.db.profile and QUICore.db.profile.datatext
            local useLocalTime = (not dtSettings) or (dtSettings.timeFormat == "local")
            local use24Hour = (not dtSettings) or (dtSettings.use24Hour ~= false)

            local hour, minute
            if useLocalTime then
                hour, minute = tonumber(date("%H")), tonumber(date("%M"))
            else
                hour, minute = GetGameTime()
            end

            local r, g, b = GetValueColor()
            local label = GetLabel("Time: ", "T: ", slotFrame.shortLabel, slotFrame.noLabel)
            if use24Hour then
                text:SetFormattedText(label .. "|cff%02x%02x%02x%02d:%02d|r", r, g, b, hour, minute)
            else
                local suffix = hour >= 12 and "PM" or "AM"
                if hour == 0 then hour = 12
                elseif hour > 12 then hour = hour - 12 end
                text:SetFormattedText(label .. "|cff%02x%02x%02x%d:%02d %s|r", r, g, b, hour, minute, suffix)
            end
        end

        frame.Update = Update

        -- Update every second
        frame.ticker = C_Timer.NewTicker(1, Update)
        
        -- Tooltip
        slotFrame:EnableMouse(true)
        slotFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Time", 1, 1, 1)
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Server Time:", GameTime_GetGameTime(true), 0.8, 0.8, 0.8, 1, 1, 1)
            GameTooltip:AddDoubleLine("Local Time:", GameTime_GetLocalTime(true), 0.8, 0.8, 0.8, 1, 1, 1)
            GameTooltip:AddLine(" ")
            local ar, ag, ab = GetValueColor(); ar, ag, ab = ar/255, ag/255, ab/255
            GameTooltip:AddLine("|cffFFFFFFLeft Click:|r Open Calendar", ar, ag, ab)
            GameTooltip:AddLine("|cffFFFFFFRight Click:|r Toggle Clock", ar, ag, ab)
            GameTooltip:Show()
        end)
        slotFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Click handlers: Left = Calendar, Right = Clock
        slotFrame:RegisterForClicks("AnyUp")
        slotFrame:SetScript("OnClick", function(self, button)
            if InCombatLockdown() then return end
            if button == "LeftButton" then
                ToggleCalendar()
            elseif button == "RightButton" then
                if TimeManagerFrame then
                    if TimeManagerFrame:IsShown() then
                        TimeManagerFrame:Hide()
                    else
                        TimeManagerFrame:Show()
                    end
                end
            end
        end)
        
        Update()
        return frame
    end,
    
    OnDisable = function(frame)
        if frame.ticker then
            frame.ticker:Cancel()
        end
    end,
})

-- FPS datatext
Datatexts:Register("fps", {
    displayName = "FPS",
    category = "System",
    description = "Displays frames per second",
    
    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()
        
        local text = slotFrame.text
        if not text then
            text = slotFrame:CreateFontString(nil, "OVERLAY")
            text:SetPoint("CENTER")
            slotFrame.text = text
        end
        
        local function Update()
            local fps = floor(GetFramerate() + 0.5)
            local r, g, b
            if fps < 30 then
                r, g, b = 255, 51, 51  -- Red warning (0-255)
            else
                r, g, b = GetValueColor()
            end
            local label = GetLabel("FPS: ", "F: ", slotFrame.shortLabel, slotFrame.noLabel)
            text:SetFormattedText(label .. "|cff%02x%02x%02x%d|r", r, g, b, fps)
        end
        
        frame.Update = Update
        frame.ticker = C_Timer.NewTicker(1, Update)
        
        Update()
        return frame
    end,
    
    OnDisable = function(frame)
        if frame.ticker then
            frame.ticker:Cancel()
        end
    end,
})

-- Latency datatext
Datatexts:Register("latency", {
    displayName = "Latency",
    category = "System",
    description = "Displays world latency",
    
    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()
        
        local text = slotFrame.text
        if not text then
            text = slotFrame:CreateFontString(nil, "OVERLAY")
            text:SetPoint("CENTER")
            slotFrame.text = text
        end
        
        local function Update()
            local _, _, home = GetNetStats()
            local ms = home or 0
            local r, g, b
            if ms > 100 then
                r, g, b = 255, 51, 51  -- Red warning (0-255)
            else
                r, g, b = GetValueColor()
            end
            local label = GetLabel("MS: ", "M: ", slotFrame.shortLabel, slotFrame.noLabel)
            text:SetFormattedText(label .. "|cff%02x%02x%02x%d|r", r, g, b, ms)
        end

        frame.Update = Update
        frame.ticker = C_Timer.NewTicker(1, Update)

        Update()
        return frame
    end,
    
    OnDisable = function(frame)
        if frame.ticker then
            frame.ticker:Cancel()
        end
    end,
})

-- Gold datatext
Datatexts:Register("gold", {
    displayName = "Gold",
    category = "Character",
    description = "Displays your current gold (tooltip shows all characters)",

    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()

        local text = slotFrame.text
        if not text then
            text = slotFrame:CreateFontString(nil, "OVERLAY")
            text:SetPoint("CENTER")
            slotFrame.text = text
        end

        local function FormatGold(copper)
            local gold = floor(copper / 10000)
            local goldStr = tostring(gold)
            if gold >= 1000 then
                goldStr = string.format("%d,%03d", floor(gold / 1000), gold % 1000)
            end
            if gold >= 1000000 then
                local millions = floor(gold / 1000000)
                local thousands = floor((gold % 1000000) / 1000)
                goldStr = string.format("%d,%03d,%03d", millions, thousands, gold % 1000)
            end
            return goldStr .. "g"
        end

        -- Get character key for gold tracking (realm-name format)
        local function GetCharKey()
            local name = UnitName("player")
            local realm = GetRealmName()
            if not name or not realm then return nil end
            return realm .. "-" .. name
        end

        -- Get class color for a class name
        local function GetClassColor(className)
            if not className then return 1, 1, 1 end
            local classColor = RAID_CLASS_COLORS[className]
            if classColor then
                return classColor.r, classColor.g, classColor.b
            end
            return 1, 1, 1  -- White fallback
        end

        -- Save current character's gold to global storage (with class info)
        local function SaveGold()
            local charKey = GetCharKey()
            if not charKey then return end  -- Guard against nil during early load
            local db = QUICore and QUICore.db
            if db and db.global then
                if not db.global.goldData then db.global.goldData = {} end
                local _, className = UnitClass("player")
                -- Store as table with money and class
                db.global.goldData[charKey] = {
                    money = GetMoney() or 0,
                    class = className
                }
            end
        end

        -- Get money from goldData entry (handles old format migration)
        local function GetCharMoney(data)
            if type(data) == "number" then
                return data  -- Old format: just the copper amount
            elseif type(data) == "table" then
                return data.money or 0  -- New format: table with money key
            end
            return 0
        end

        -- Get class from goldData entry
        local function GetCharClass(data)
            if type(data) == "table" then
                return data.class
            end
            return nil  -- Old format has no class
        end

        local function Update()
            local money = GetMoney() or 0
            SaveGold()  -- Update stored gold on every update
            local r, g, b = GetValueColor()
            local label = GetLabel("Gold: ", "G: ", slotFrame.shortLabel, slotFrame.noLabel)
            text:SetFormattedText(label .. "|cff%02x%02x%02x%s|r", r, g, b, FormatGold(money))
        end

        frame.Update = Update

        frame:RegisterEvent("PLAYER_MONEY")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED")
        frame:SetScript("OnEvent", Update)

        -- Request WoW Token price from server and set up refresh ticker
        if C_WowTokenPublic and C_WowTokenPublic.UpdateMarketPrice then
            C_WowTokenPublic.UpdateMarketPrice()
            -- Refresh token price every 60 seconds
            frame.tokenTicker = C_Timer.NewTicker(60, function()
                C_WowTokenPublic.UpdateMarketPrice()
            end)
        end

        -- Tooltip
        slotFrame:EnableMouse(true)
        slotFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Gold", 1, 1, 1)
            GameTooltip:AddLine(" ")

            local money = GetMoney() or 0
            local gold = floor(money / 10000)
            local silver = floor((money % 10000) / 100)
            local copper = money % 100
            GameTooltip:AddDoubleLine("Current:", string.format("%dg %ds %dc", gold, silver, copper), 0.8, 0.8, 0.8, 1, 1, 1)

            -- Show all characters' gold from global storage
            local db = QUICore and QUICore.db
            if db and db.global and db.global.goldData then
                local total = 0
                local charList = {}
                for charKey, charData in pairs(db.global.goldData) do
                    local charMoney = GetCharMoney(charData)
                    local charClass = GetCharClass(charData)
                    total = total + charMoney
                    table.insert(charList, {key = charKey, money = charMoney, class = charClass})
                end

                if #charList > 1 then
                    -- Sort by gold amount descending
                    table.sort(charList, function(a, b) return a.money > b.money end)

                    -- Get configured accent color for section headers
                    local vr, vg, vb = GetValueColor()
                    local ar, ag, ab = vr/255, vg/255, vb/255

                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("All Characters", 1, 1, 1)
                    local currentCharKey = GetCharKey()
                    for _, char in ipairs(charList) do
                        local isCurrentChar = (char.key == currentCharKey)
                        -- Use class color for character name
                        local cr, cg, cb = GetClassColor(char.class)
                        -- Add bullet accent for current character
                        local displayName = isCurrentChar and ("• " .. char.key) or char.key
                        GameTooltip:AddDoubleLine(displayName, FormatGold(char.money), cr, cg, cb, 1, 1, 1)
                    end
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddDoubleLine("Total:", FormatGold(total), ar, ag, ab, 1, 0.82, 0)
                end
            end

            -- Get accent color for section headers
            local vr, vg, vb = GetValueColor()
            local ar, ag, ab = vr/255, vg/255, vb/255

            -- Warbound Bank Gold
            if C_Bank and C_Bank.FetchDepositedMoney then
                local warboundMoney = C_Bank.FetchDepositedMoney(Enum.BankType.Account)
                if warboundMoney and warboundMoney > 0 then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Warbound Bank", 1, 1, 1)
                    GameTooltip:AddDoubleLine("Account Gold:", FormatGold(warboundMoney), 0.8, 0.8, 0.8, 1, 0.82, 0)
                end
            end

            -- WoW Token Price (always show section, display "Updating..." if not available yet)
            if C_WowTokenPublic and C_WowTokenPublic.GetCurrentMarketPrice then
                local tokenPrice = C_WowTokenPublic.GetCurrentMarketPrice()
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("WoW Token", 1, 1, 1)
                if tokenPrice and tokenPrice > 0 then
                    GameTooltip:AddDoubleLine("Market Price:", FormatGold(tokenPrice), 0.8, 0.8, 0.8, 1, 0.82, 0)
                else
                    GameTooltip:AddDoubleLine("Market Price:", "Updating...", 0.8, 0.8, 0.8, 0.5, 0.5, 0.5)
                end
            end

            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cffFFFFFFLeft Click:|r Open Currency", ar, ag, ab)
            GameTooltip:AddLine("|cffFFFFFFRight Click:|r Toggle Bags", ar, ag, ab)
            GameTooltip:AddLine("|cffFFFFFFMiddle Click:|r Manage Characters", ar, ag, ab)
            GameTooltip:Show()
        end)
        slotFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Character management menu using MenuUtil
        local function ShowCharacterMenu(anchorFrame)
            local db = QUICore and QUICore.db
            if not db or not db.global or not db.global.goldData then return end

            local currentCharKey = GetCharKey()

            MenuUtil.CreateContextMenu(anchorFrame, function(_, root)
                root:CreateTitle("Manage Characters")

                -- Add each character as a deletable entry
                for charKey, charData in pairs(db.global.goldData) do
                    local charMoney = GetCharMoney(charData)
                    local charClass = GetCharClass(charData)
                    local cr, cg, cb = GetClassColor(charClass)
                    local colorCode = format("|cff%02x%02x%02x", cr*255, cg*255, cb*255)
                    local isCurrentChar = (charKey == currentCharKey)

                    -- Capture values for closure
                    local deleteCharKey = charKey
                    local btn = root:CreateButton(colorCode .. charKey .. "|r - " .. FormatGold(charMoney), function()
                        -- Confirm deletion
                        StaticPopupDialogs["QUAZII_GOLD_DELETE_CHAR"] = {
                            text = "Delete gold data for " .. deleteCharKey .. "?",
                            button1 = "Delete",
                            button2 = "Cancel",
                            OnAccept = function()
                                db.global.goldData[deleteCharKey] = nil
                                print("|cff30D1FF[QuaziiUI]|r Removed gold data for " .. deleteCharKey)
                            end,
                            timeout = 0,
                            whileDead = true,
                            hideOnEscape = true,
                        }
                        StaticPopup_Show("QUAZII_GOLD_DELETE_CHAR")
                    end)

                    -- Can't delete current character
                    if isCurrentChar then
                        btn:SetEnabled(false)
                    end
                end

                root:CreateDivider()
                root:CreateButton("|cffFF6666Reset All (Keep Current)|r", function()
                    StaticPopupDialogs["QUAZII_GOLD_RESET_ALL"] = {
                        text = "Delete gold data for ALL characters except current?",
                        button1 = "Reset All",
                        button2 = "Cancel",
                        OnAccept = function()
                            local keepKey = currentCharKey
                            local keepData = db.global.goldData[keepKey]
                            db.global.goldData = {}
                            if keepKey and keepData then
                                db.global.goldData[keepKey] = keepData
                            end
                            print("|cff30D1FF[QuaziiUI]|r Reset gold data (kept current character)")
                        end,
                        timeout = 0,
                        whileDead = true,
                        hideOnEscape = true,
                    }
                    StaticPopup_Show("QUAZII_GOLD_RESET_ALL")
                end)
            end)
        end

        -- Click handler: Left = Currency, Right = Bags, Middle = Manage
        slotFrame:RegisterForClicks("AnyUp")
        slotFrame:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                ToggleCharacter("TokenFrame")
            elseif button == "RightButton" then
                ToggleAllBags()
            elseif button == "MiddleButton" then
                ShowCharacterMenu(self)
            end
        end)

        Update()
        return frame
    end,

    OnDisable = function(frame)
        frame:UnregisterAllEvents()
        if frame.tokenTicker then
            frame.tokenTicker:Cancel()
            frame.tokenTicker = nil
        end
    end,
})

-- Durability datatext
Datatexts:Register("durability", {
    displayName = "Durability",
    category = "Character",
    description = "Displays lowest equipment durability",
    
    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()
        
        local text = slotFrame.text
        if not text then
            text = slotFrame:CreateFontString(nil, "OVERLAY")
            text:SetPoint("CENTER")
            slotFrame.text = text
        end
        
        local DURABLE_SLOTS = {1, 3, 5, 6, 7, 8, 9, 10, 15, 16, 17}
        local SLOT_NAMES = {
            [1] = "Head",
            [3] = "Shoulder",
            [5] = "Chest",
            [6] = "Waist",
            [7] = "Legs",
            [8] = "Feet",
            [9] = "Wrist",
            [10] = "Hands",
            [15] = "Back",
            [16] = "Main Hand",
            [17] = "Off Hand",
        }

        local function Update()
            local minVal = 100
            for _, slot in ipairs(DURABLE_SLOTS) do
                local cur, maxVal = GetInventoryItemDurability(slot)
                if cur and maxVal and maxVal > 0 then
                    local pct = (cur / maxVal) * 100
                    if pct < minVal then minVal = pct end
                end
            end

            local r, g, b
            if minVal <= 25 then
                r, g, b = 255, 51, 51  -- Red warning (0-255)
            elseif minVal <= 50 then
                r, g, b = 255, 255, 0  -- Yellow warning (0-255)
            else
                r, g, b = GetValueColor()
            end
            local label = GetLabel("Gear: ", "D: ", slotFrame.shortLabel, slotFrame.noLabel)
            text:SetFormattedText(label .. "|cff%02x%02x%02x%d%%|r", r, g, b, floor(minVal + 0.5))
        end
        
        frame.Update = Update
        
        frame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:SetScript("OnEvent", Update)

        -- Tooltip
        slotFrame:EnableMouse(true)
        slotFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Durability", 1, 1, 1)
            GameTooltip:AddLine(" ")

            -- Show durability for each slot
            for _, slot in ipairs(DURABLE_SLOTS) do
                local cur, maxVal = GetInventoryItemDurability(slot)
                if cur and maxVal and maxVal > 0 then
                    local pct = (cur / maxVal) * 100
                    local slotName = SLOT_NAMES[slot] or ("Slot " .. slot)
                    local r, g, b
                    if pct <= 25 then
                        r, g, b = 1, 0.2, 0.2  -- Red warning
                    elseif pct <= 50 then
                        r, g, b = 1, 1, 0  -- Yellow caution
                    else
                        -- Good condition - use configured accent color
                        local vr, vg, vb = GetValueColor()
                        r, g, b = vr/255, vg/255, vb/255
                    end
                    GameTooltip:AddDoubleLine(slotName, string.format("%d%%", floor(pct + 0.5)), 0.8, 0.8, 0.8, r, g, b)
                end
            end

            GameTooltip:AddLine(" ")
            local ar, ag, ab = GetValueColor(); ar, ag, ab = ar/255, ag/255, ab/255
            GameTooltip:AddLine("|cffFFFFFFLeft Click:|r Open Character", ar, ag, ab)
            GameTooltip:Show()
        end)
        slotFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Click handler: Left = Character panel
        slotFrame:RegisterForClicks("AnyUp")
        slotFrame:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                ToggleCharacter("PaperDollFrame")
            end
        end)

        Update()
        return frame
    end,

    OnDisable = function(frame)
        frame:UnregisterAllEvents()
    end,
})

---=================================================================================
--- SOCIAL DATATEXT HELPERS (Friends & Guild)
---=================================================================================

-- Constants for social datatexts
local TIMERUNNING_ICON = "|A:timerunning-glues-icon-small:12:10:0:0|a"
local MOBILE_ICON = "|TInterface\\ChatFrame\\UI-ChatIcon-ArmoryChat:14:14:0:0:16:16:0:16:0:16:73:177:73|t"
local WOW_PROJECT_ID = WOW_PROJECT_ID or 1
local PROJECT_NAMES = {
    [1] = "Retail",
    [2] = "Classic Era",
    [5] = "TBC Classic",
    [11] = "Wrath Classic",
    [14] = "Cata Classic",
}

-- Check if player is in current group
local function IsPlayerInGroup(name, realmName)
    if not name or name == "" then return false end

    local fullName = name
    local shortName = name

    -- Handle "Player-Realm" format from guild roster
    if name:find("-") then
        shortName = name:gsub("%-[^%-]+$", "")
    elseif realmName and realmName ~= "" and realmName ~= GetRealmName() then
        fullName = name .. "-" .. realmName
    end

    -- Try both formats for consistency
    return UnitInParty(fullName) or UnitInRaid(fullName) or
           UnitInParty(shortName) or UnitInRaid(shortName)
end

-- Send whisper to player (regular or BNet)
local function SendWhisperTo(name, isBNet)
    if not name or name == "" then return end
    if isBNet then
        ChatFrameUtil.SendBNetTell(name)
    else
        SetItemRef("player:" .. name, format("|Hplayer:%1$s|h[%1$s]|h", name), "LeftButton")
    end
end

-- Invite player to group (regular or BNet)
local function InvitePlayerToGroup(nameOrGameID, guid, isBNet)
    if not nameOrGameID then return end

    if guid and GetDisplayedInviteType then
        local inviteType = GetDisplayedInviteType(guid)
        if inviteType == "INVITE" or inviteType == "SUGGEST_INVITE" then
            if isBNet then
                BNInviteFriend(nameOrGameID)
            else
                C_PartyInfo.InviteUnit(nameOrGameID)
            end
        elseif inviteType == "REQUEST_INVITE" then
            if C_PartyInfo and C_PartyInfo.RequestInviteFromUnit then
                C_PartyInfo.RequestInviteFromUnit(nameOrGameID)
            end
        end
    else
        -- Fallback when GUID unavailable
        if isBNet then
            BNInviteFriend(nameOrGameID)
        else
            C_PartyInfo.InviteUnit(nameOrGameID)
        end
    end
end

-- Get level color (difficulty-based)
local function GetLevelColor(level)
    if not level or level <= 0 then return 1, 1, 1 end
    local color = GetQuestDifficultyColor(level)
    return color.r, color.g, color.b
end

---=================================================================================
--- FRIENDS CACHE SYSTEM
---=================================================================================

local friendsCache = {
    wowFriends = {},    -- Regular WoW friends
    bnetRetail = {},    -- BNet friends on Retail
    bnetClassic = {},   -- BNet friends on Classic versions
    bnetOther = {},     -- BNet friends on other games
    lastUpdate = 0
}

-- Build reverse lookup: localized class name -> class token (e.g., "Warrior" -> "WARRIOR")
local unlocalizedClasses = {}
do
    local classMale = LOCALIZED_CLASS_NAMES_MALE
    local classFemale = LOCALIZED_CLASS_NAMES_FEMALE
    if classMale then
        for token, localized in pairs(classMale) do unlocalizedClasses[localized] = token end
    end
    if classFemale then
        for token, localized in pairs(classFemale) do unlocalizedClasses[localized] = token end
    end
end

local function GetClassColor(className)
    if not className then return nil end
    -- First check if it's already a token (e.g., "WARRIOR")
    if RAID_CLASS_COLORS[className] then
        return RAID_CLASS_COLORS[className]
    end
    -- Otherwise try localized lookup (e.g., "Warrior" -> "WARRIOR")
    local classToken = unlocalizedClasses[className]
    return classToken and RAID_CLASS_COLORS[classToken]
end

-- Client priority: higher = better (games beat App/Mobile)
local CLIENT_PRIORITY = {
    -- WoW is handled separately with wowProjectID
    App = 1,    -- Desktop App
    BSAp = 1,   -- Mobile App
}

local function GetClientPriority(client, wowProjectID)
    if client == BNET_CLIENT_WOW then
        -- WoW Retail is highest priority, then Classic
        if wowProjectID == WOW_PROJECT_ID then
            return 100  -- Current retail
        else
            return 50   -- Classic versions
        end
    end
    return CLIENT_PRIORITY[client] or 10  -- Other games
end

local function BuildFriendsCache()
    wipe(friendsCache.wowFriends)
    wipe(friendsCache.bnetRetail)
    wipe(friendsCache.bnetClassic)
    wipe(friendsCache.bnetOther)

    -- Regular WoW friends (non-BNet)
    for i = 1, C_FriendList.GetNumFriends() do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected then
            table.insert(friendsCache.wowFriends, {
                name = info.name,
                level = info.level,
                class = info.className,
                zone = info.area,
                afk = info.afk,
                dnd = info.dnd,
                guid = info.guid,
                notes = info.notes,
            })
        end
    end

    -- Battle.net friends - deduplicate by picking best game account per friend
    -- Each friend appears only ONCE, prioritizing games over App/Mobile
    if BNConnected() then
        local seenAccounts = {}  -- Track best entry per bnetAccountID

        for i = 1, BNGetNumFriends() do
            local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
            if accountInfo then
                local bnetID = accountInfo.bnetAccountID
                local numGameAccounts = C_BattleNet.GetFriendNumGameAccounts(i) or 0
                local foundGameAccount = false

                -- Find the best game account for this friend
                for y = 1, numGameAccounts do
                    local gameInfo = C_BattleNet.GetFriendGameAccountInfo(i, y)
                    if gameInfo and gameInfo.isOnline then
                        foundGameAccount = true
                        local priority = GetClientPriority(gameInfo.clientProgram, gameInfo.wowProjectID)
                        local existing = seenAccounts[bnetID]

                        -- Only keep if this is higher priority than existing
                        if not existing or priority > existing.priority then
                            seenAccounts[bnetID] = {
                                priority = priority,
                                entry = {
                                    accountName = accountInfo.accountName,
                                    bnetID = bnetID,
                                    gameID = gameInfo.gameAccountID,
                                    characterName = gameInfo.characterName,
                                    className = gameInfo.className,
                                    level = gameInfo.characterLevel,
                                    zone = gameInfo.areaName,
                                    realmName = gameInfo.realmName,
                                    faction = gameInfo.factionName,
                                    client = gameInfo.clientProgram,
                                    wowProjectID = gameInfo.wowProjectID,
                                    timerunningID = gameInfo.timerunningSeasonID,
                                    guid = gameInfo.playerGuid,
                                    afk = accountInfo.isAFK or gameInfo.isGameAFK,
                                    dnd = accountInfo.isDND or gameInfo.isGameBusy,
                                    richPresence = gameInfo.richPresence,
                                }
                            }
                        end
                    end
                end

                -- If no game accounts found but friend is online, they're App/Mobile only
                -- Add them so they can still be whispered
                if not foundGameAccount and not seenAccounts[bnetID] then
                    -- Check if account is actually online via gameAccountInfo
                    local gameAccountInfo = accountInfo.gameAccountInfo
                    if gameAccountInfo and gameAccountInfo.isOnline then
                        seenAccounts[bnetID] = {
                            priority = 1,  -- Lowest priority (App/Mobile)
                            entry = {
                                accountName = accountInfo.accountName,
                                bnetID = bnetID,
                                gameID = gameAccountInfo.gameAccountID,
                                client = gameAccountInfo.clientProgram or "App",
                                afk = accountInfo.isAFK,
                                dnd = accountInfo.isDND,
                                richPresence = gameAccountInfo.richPresence or "Battle.net",
                            }
                        }
                    end
                end
            end
        end

        -- Now add each friend's best entry to the appropriate category
        for _, data in pairs(seenAccounts) do
            local entry = data.entry
            if entry.client == BNET_CLIENT_WOW then
                if entry.wowProjectID == WOW_PROJECT_ID then
                    table.insert(friendsCache.bnetRetail, entry)
                else
                    table.insert(friendsCache.bnetClassic, entry)
                end
            else
                table.insert(friendsCache.bnetOther, entry)
            end
        end
    end

    friendsCache.lastUpdate = GetTime()
end

-- Friends datatext
Datatexts:Register("friends", {
    displayName = "Friends",
    category = "Social",
    description = "Displays online friends count with detailed tooltip",
    
    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()
        
        local text = slotFrame.text
        if not text then
            text = slotFrame:CreateFontString(nil, "OVERLAY")
            text:SetPoint("CENTER")
            slotFrame.text = text
        end
        
        local function Update()
            -- WoW friends
            local wowOnline = C_FriendList.GetNumOnlineFriends() or 0
            local wowTotal = C_FriendList.GetNumFriends() or 0

            -- Battle.net friends
            local bnetTotal, bnetOnline = 0, 0
            if BNConnected() then
                bnetTotal, bnetOnline = BNGetNumFriends()
            end

            -- Combined
            local online = wowOnline + (bnetOnline or 0)
            local total = wowTotal + (bnetTotal or 0)

            local r, g, b = GetValueColor()
            local label = GetLabel("Friends: ", "Fr: ", slotFrame.shortLabel, slotFrame.noLabel)
            if settings.showTotal then
                text:SetFormattedText(label .. "|cff%02x%02x%02x%d/%d|r", r, g, b, online, total)
            else
                text:SetFormattedText(label .. "|cff%02x%02x%02x%d|r", r, g, b, online)
            end
        end

        frame.Update = Update

        -- Events
        frame:RegisterEvent("FRIENDLIST_UPDATE")
        frame:RegisterEvent("CHAT_MSG_SYSTEM")
        frame:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
        frame:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
        frame:RegisterEvent("BN_FRIEND_INFO_CHANGED")
        frame:RegisterEvent("BN_CONNECTED")
        frame:RegisterEvent("BN_DISCONNECTED")
        frame:SetScript("OnEvent", function()
            friendsCache.lastUpdate = 0  -- Invalidate cache
            Update()
        end)
        
        -- Tooltip
        slotFrame:EnableMouse(true)
        slotFrame:SetScript("OnEnter", function(self)
            -- Rebuild cache if stale (> 1 second old)
            if GetTime() - friendsCache.lastUpdate > 1 then
                BuildFriendsCache()
            end

            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Friends", 1, 1, 1)

            -- Get configured accent color for section headers
            local vr, vg, vb = GetValueColor()
            local ar, ag, ab = vr/255, vg/255, vb/255

            local hasAnyFriends = false

            -- WoW Friends section
            if #friendsCache.wowFriends > 0 then
                hasAnyFriends = true
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("WoW Friends", ar, ag, ab)

                for _, info in ipairs(friendsCache.wowFriends) do
                    local classColor = GetClassColor(info.class) or {r=1, g=1, b=1}
                    local statusText = info.afk and " |cffFFFF00(AFK)|r" or info.dnd and " |cffFF0000(DND)|r" or ""
                    local inGroupMark = IsPlayerInGroup(info.name) and " |cffaaaaaa*|r" or ""
                    local lr, lg, lb = GetLevelColor(info.level)
                    local levelStr = info.level and info.level > 0 and format("|cff%02x%02x%02x%d|r ", lr*255, lg*255, lb*255, info.level) or ""

                    GameTooltip:AddDoubleLine(
                        levelStr .. info.name .. inGroupMark .. statusText,
                        info.zone or "Unknown",
                        classColor.r, classColor.g, classColor.b,
                        0.7, 0.7, 0.7
                    )
                end
            end

            -- Battle.net (Retail) section
            if #friendsCache.bnetRetail > 0 then
                if hasAnyFriends then GameTooltip:AddLine(" ") end
                hasAnyFriends = true
                GameTooltip:AddLine("Battle.net (Retail)", 0.31, 0.69, 0.9)

                for _, info in ipairs(friendsCache.bnetRetail) do
                    local classColor = GetClassColor(info.className) or {r=0.8, g=0.8, b=0.8}
                    local statusText = info.afk and " |cffFFFF00(AFK)|r" or info.dnd and " |cffFF0000(DND)|r" or ""
                    local timerunning = (info.timerunningID and info.timerunningID ~= 0) and (" " .. TIMERUNNING_ICON) or ""
                    local inGroupMark = IsPlayerInGroup(info.characterName, info.realmName) and " |cffaaaaaa*|r" or ""
                    local lr, lg, lb = GetLevelColor(info.level)
                    local levelStr = info.level and info.level > 0 and format("|cff%02x%02x%02x%d|r ", lr*255, lg*255, lb*255, info.level) or ""

                    local leftText
                    if info.characterName and info.characterName ~= "" then
                        leftText = levelStr .. info.characterName .. " (" .. info.accountName .. ")" .. inGroupMark .. statusText .. timerunning
                    else
                        leftText = info.accountName .. statusText
                    end

                    GameTooltip:AddDoubleLine(
                        leftText,
                        info.zone or "Unknown",
                        classColor.r, classColor.g, classColor.b,
                        0.7, 0.7, 0.7
                    )
                end
            end

            -- Battle.net (Classic) section
            if #friendsCache.bnetClassic > 0 then
                if hasAnyFriends then GameTooltip:AddLine(" ") end
                hasAnyFriends = true
                GameTooltip:AddLine("Battle.net (Classic)", 0.6, 0.4, 0.2)

                for _, info in ipairs(friendsCache.bnetClassic) do
                    local classColor = GetClassColor(info.className) or {r=0.8, g=0.8, b=0.8}
                    local statusText = info.afk and " |cffFFFF00(AFK)|r" or info.dnd and " |cffFF0000(DND)|r" or ""
                    local versionName = PROJECT_NAMES[info.wowProjectID] or "Classic"

                    local leftText
                    if info.characterName and info.characterName ~= "" then
                        leftText = format("%s (%s) - %s%s", info.characterName, info.accountName, versionName, statusText)
                    else
                        leftText = format("%s - %s%s", info.accountName, versionName, statusText)
                    end

                    GameTooltip:AddDoubleLine(
                        leftText,
                        info.zone or "Unknown",
                        classColor.r, classColor.g, classColor.b,
                        0.7, 0.7, 0.7
                    )
                end
            end

            -- Other Games section
            if #friendsCache.bnetOther > 0 then
                if hasAnyFriends then GameTooltip:AddLine(" ") end
                hasAnyFriends = true
                GameTooltip:AddLine("Other Games", 0.5, 0.5, 0.5)

                for _, info in ipairs(friendsCache.bnetOther) do
                    local statusText = info.afk and " |cffFFFF00(AFK)|r" or info.dnd and " |cffFF0000(DND)|r" or ""
                    local gameName = info.richPresence or info.client or "Online"

                    GameTooltip:AddDoubleLine(
                        info.accountName .. statusText,
                        gameName,
                        0.8, 0.8, 0.8,
                        0.5, 0.5, 0.5
                    )
                end
            end

            if not hasAnyFriends then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("No friends online", 0.7, 0.7, 0.7)
            end

            GameTooltip:AddLine(" ")
            local ar, ag, ab = GetValueColor(); ar, ag, ab = ar/255, ag/255, ab/255
            GameTooltip:AddLine("|cffFFFFFFLeft Click:|r Open Friends", ar, ag, ab)
            GameTooltip:AddLine("|cffFFFFFFRight Click:|r Whisper/Invite Menu", ar, ag, ab)
            GameTooltip:Show()
        end)
        slotFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Click
        slotFrame:RegisterForClicks("AnyUp")
        slotFrame:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                ToggleFriendsFrame(1)
            elseif button == "RightButton" then
                -- Rebuild cache if needed
                if GetTime() - friendsCache.lastUpdate > 1 then
                    BuildFriendsCache()
                end

                MenuUtil.CreateContextMenu(self, function(_, root)
                    root:CreateTitle("Friends Menu")

                    -- Whisper submenu
                    local whisperMenu = root:CreateButton("Whisper")
                    local hasWhisperTargets = false

                    -- Add WoW friends to whisper
                    for _, info in ipairs(friendsCache.wowFriends) do
                        hasWhisperTargets = true
                        local classColor = GetClassColor(info.class)
                        local colorCode = classColor and format("|cff%02x%02x%02x", classColor.r*255, classColor.g*255, classColor.b*255) or "|cffffffff"
                        -- Capture name in local to ensure closure works correctly
                        local whisperName = info.name
                        whisperMenu:CreateButton(colorCode .. info.name .. "|r", function()
                            SendWhisperTo(whisperName, false)
                        end)
                    end

                    -- Add BNet Retail friends to whisper
                    for _, info in ipairs(friendsCache.bnetRetail) do
                        hasWhisperTargets = true
                        local classColor = GetClassColor(info.className)
                        local colorCode = classColor and format("|cff%02x%02x%02x", classColor.r*255, classColor.g*255, classColor.b*255) or "|cffffffff"
                        local displayName = info.characterName and info.characterName ~= "" and (colorCode .. info.characterName .. "|r (" .. info.accountName .. ")") or info.accountName
                        -- Capture accountName in local to ensure closure works correctly
                        local whisperName = info.accountName
                        whisperMenu:CreateButton(displayName, function()
                            SendWhisperTo(whisperName, true)
                        end)
                    end

                    -- Add BNet Classic friends to whisper
                    for _, info in ipairs(friendsCache.bnetClassic) do
                        hasWhisperTargets = true
                        local classColor = GetClassColor(info.className)
                        local colorCode = classColor and format("|cff%02x%02x%02x", classColor.r*255, classColor.g*255, classColor.b*255) or "|cffffffff"
                        local versionName = PROJECT_NAMES[info.wowProjectID] or "Classic"
                        local displayName = info.characterName and info.characterName ~= "" and (colorCode .. info.characterName .. "|r (" .. info.accountName .. ")") or info.accountName
                        -- Capture accountName in local to ensure closure works correctly
                        local whisperName = info.accountName
                        whisperMenu:CreateButton(displayName .. " - " .. versionName, function()
                            SendWhisperTo(whisperName, true)
                        end)
                    end

                    -- Add BNet Other Games / App-only friends to whisper
                    for _, info in ipairs(friendsCache.bnetOther) do
                        hasWhisperTargets = true
                        local gameName = info.richPresence or info.client or "Online"
                        local displayName = info.accountName .. " |cff808080(" .. gameName .. ")|r"
                        -- Capture accountName in local to ensure closure works correctly
                        local whisperName = info.accountName
                        whisperMenu:CreateButton(displayName, function()
                            SendWhisperTo(whisperName, true)
                        end)
                    end

                    if not hasWhisperTargets then
                        local noFriends = whisperMenu:CreateButton("No friends online")
                        noFriends:SetEnabled(false)
                    end

                    -- Invite submenu (only invitable friends)
                    local inviteMenu = root:CreateButton("Invite")
                    local hasInviteTargets = false

                    -- WoW friends
                    for _, info in ipairs(friendsCache.wowFriends) do
                        if not IsPlayerInGroup(info.name) then
                            hasInviteTargets = true
                            local classColor = GetClassColor(info.class)
                            local colorCode = classColor and format("|cff%02x%02x%02x", classColor.r*255, classColor.g*255, classColor.b*255) or "|cffffffff"
                            -- Capture values in locals for closure
                            local inviteName, inviteGuid = info.name, info.guid
                            inviteMenu:CreateButton(colorCode .. info.name .. "|r", function()
                                InvitePlayerToGroup(inviteName, inviteGuid, false)
                            end)
                        end
                    end

                    -- BNet Retail friends (same project = invitable)
                    for _, info in ipairs(friendsCache.bnetRetail) do
                        if info.characterName and info.characterName ~= "" and not IsPlayerInGroup(info.characterName, info.realmName) then
                            hasInviteTargets = true
                            local classColor = GetClassColor(info.className)
                            local colorCode = classColor and format("|cff%02x%02x%02x", classColor.r*255, classColor.g*255, classColor.b*255) or "|cffffffff"
                            -- Capture values in locals for closure
                            local inviteGameID, inviteGuid = info.gameID, info.guid
                            inviteMenu:CreateButton(colorCode .. info.characterName .. "|r", function()
                                InvitePlayerToGroup(inviteGameID, inviteGuid, true)
                            end)
                        end
                    end

                    if not hasInviteTargets then
                        local noInvite = inviteMenu:CreateButton("No invitable friends")
                        noInvite:SetEnabled(false)
                    end

                    root:CreateDivider()
                    root:CreateButton("Open Friends Panel", function()
                        ToggleFriendsFrame(1)
                    end)
                end)
            end
        end)

        -- Initial update
        C_FriendList.ShowFriends()
        Update()
        
        return frame
    end,
    
    OnDisable = function(frame)
        frame:UnregisterAllEvents()
    end,
})

---=================================================================================
--- GUILD CACHE SYSTEM
---=================================================================================

local guildCache = {
    members = {},       -- Guild roster data
    clubMembers = {},   -- Club API data (for timerunning detection)
    lastUpdate = 0
}

-- Strip only the player's realm suffix from names
-- "Player-MyRealm" -> "Player", "Player-OtherRealm" -> "Player-OtherRealm"
local myRealmPattern
local function StripMyRealm(name)
    if not myRealmPattern then
        local realm = GetNormalizedRealmName()
        if realm then
            myRealmPattern = "%-" .. realm
        else
            return name  -- Can't strip without realm info
        end
    end
    return (gsub(name, myRealmPattern, ""))
end

local function BuildGuildCache()
    wipe(guildCache.members)
    wipe(guildCache.clubMembers)

    if not IsInGuild() then return end

    -- Get club data for timerunning detection (uses C_Club API)
    local clubs = C_Club and C_Club.GetSubscribedClubs()
    if clubs then
        local guildClubID
        for _, data in ipairs(clubs) do
            if data.clubType == Enum.ClubType.Guild then
                guildClubID = data.clubId
                break
            end
        end

        if guildClubID and CommunitiesUtil and CommunitiesUtil.GetAndSortMemberInfo then
            local members = CommunitiesUtil.GetAndSortMemberInfo(guildClubID)
            if members then
                for _, data in ipairs(members) do
                    if data.guid then
                        guildCache.clubMembers[data.guid] = {
                            timerunningID = data.timerunningSeasonID,
                            faction = data.faction,
                        }
                    end
                end
            end
        end
    end

    -- Get roster data
    local total, online = GetNumGuildMembers()
    local showOffline = GetGuildRosterShowOffline()
    local scanTotal = showOffline and total or online

    for i = 1, scanTotal do
        local name, rank, rankIndex, level, class, zone, note, offNote, connected, status, engClass, _, _, isMobile, _, _, guid = GetGuildRosterInfo(i)
        if name and (connected or isMobile) then
            local clubData = guildCache.clubMembers[guid]

            table.insert(guildCache.members, {
                name = name,  -- Full name with realm, use Ambiguate() for display
                rank = rank,
                rankIndex = rankIndex,
                level = level,
                class = engClass,
                zone = zone,
                note = note,
                officerNote = offNote,
                online = connected,
                status = status,  -- 0=online, 1=AFK, 2=DND
                isMobile = isMobile,
                guid = guid,
                timerunningID = clubData and clubData.timerunningID,
                faction = clubData and clubData.faction,
            })
        end
    end

    guildCache.lastUpdate = GetTime()
end

-- Guild datatext
Datatexts:Register("guild", {
    displayName = "Guild",
    category = "Social",
    description = "Displays online guild members with detailed tooltip",
    
    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()
        
        local text = slotFrame.text
        if not text then
            text = slotFrame:CreateFontString(nil, "OVERLAY")
            text:SetPoint("CENTER")
            slotFrame.text = text
        end
        
        local function Update()
            if not IsInGuild() then
                text:SetText("No Guild")
                return
            end

            local total, online = GetNumGuildMembers()
            local r, g, b = GetValueColor()
            local label = GetLabel("Guild: ", "Gu: ", slotFrame.shortLabel, slotFrame.noLabel)

            if settings.showGuildName then
                local guildName = GetGuildInfo("player")
                if guildName then
                    text:SetFormattedText("%s: |cff%02x%02x%02x%d/%d|r", guildName, r, g, b, online or 0, total or 0)
                else
                    text:SetFormattedText(label .. "|cff%02x%02x%02x%d/%d|r", r, g, b, online or 0, total or 0)
                end
            elseif settings.showTotal then
                text:SetFormattedText(label .. "|cff%02x%02x%02x%d/%d|r", r, g, b, online or 0, total or 0)
            else
                text:SetFormattedText(label .. "|cff%02x%02x%02x%d|r", r, g, b, online or 0)
            end
        end

        frame.Update = Update

        -- Events
        frame:RegisterEvent("GUILD_ROSTER_UPDATE")
        frame:RegisterEvent("PLAYER_GUILD_UPDATE")
        frame:SetScript("OnEvent", function(self, event, unit)
            if event == "PLAYER_GUILD_UPDATE" and unit and unit ~= "player" then
                return
            end
            guildCache.lastUpdate = 0  -- Invalidate cache
            Update()
        end)
        
        -- Tooltip
        slotFrame:EnableMouse(true)
        slotFrame:SetScript("OnEnter", function(self)
            if not IsInGuild() then return end

            -- Rebuild cache if stale
            if GetTime() - guildCache.lastUpdate > 1 then
                BuildGuildCache()
            end

            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:ClearLines()

            local guildName = GetGuildInfo("player")
            -- Get configured accent color for section headers
            local vr, vg, vb = GetValueColor()
            local ar, ag, ab = vr/255, vg/255, vb/255

            GameTooltip:AddLine(guildName or "Guild", 1, 1, 1)

            local motd = GetGuildRosterMOTD()
            if motd and motd ~= "" then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("MOTD:", 1, 0.8, 0)
                GameTooltip:AddLine(motd, 0.8, 0.8, 0.8, true)
            end

            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Online Members", ar, ag, ab)

            local memberCount = 0

            for _, info in ipairs(guildCache.members) do
                if memberCount >= MAX_GUILD_TOOLTIP_DISPLAY then
                    local remaining = #guildCache.members - MAX_GUILD_TOOLTIP_DISPLAY
                    if remaining > 0 then
                        GameTooltip:AddLine(format("... and %d more", remaining), 0.7, 0.7, 0.7)
                    end
                    break
                end

                memberCount = memberCount + 1

                local classColor = GetClassColor(info.class) or {r=1, g=1, b=1}
                local statusText = ""
                if info.status == 1 then
                    statusText = " |cffFFFF00(AFK)|r"
                elseif info.status == 2 then
                    statusText = " |cffFF0000(DND)|r"
                end

                local lr, lg, lb = GetLevelColor(info.level)
                local levelStr = format("|cff%02x%02x%02x%d|r ", lr*255, lg*255, lb*255, info.level or 0)
                local timerunning = (info.timerunningID and info.timerunningID ~= 0) and (" " .. TIMERUNNING_ICON) or ""
                local inGroupMark = IsPlayerInGroup(info.name) and " |cffaaaaaa*|r" or ""
                local mobileIcon = (info.isMobile and not info.online) and (" " .. MOBILE_ICON) or ""

                -- StripMyRealm: removes only YOUR realm suffix, keeps cross-realm names intact
                local displayName = StripMyRealm(info.name)

                -- Format: "Level Name[-Realm] - Rank" on left, "Zone" on right
                -- Gray dash separator, white rank text
                GameTooltip:AddDoubleLine(
                    levelStr .. displayName .. inGroupMark .. statusText .. timerunning .. mobileIcon .. " |cff999999-|cffffffff " .. info.rank .. "|r",
                    info.zone or "Unknown",
                    classColor.r, classColor.g, classColor.b,
                    0.7, 0.7, 0.7
                )
            end

            if memberCount == 0 then
                GameTooltip:AddLine("No members online", 0.7, 0.7, 0.7)
            end

            GameTooltip:AddLine(" ")
            local ar, ag, ab = GetValueColor(); ar, ag, ab = ar/255, ag/255, ab/255
            GameTooltip:AddLine("|cffFFFFFFLeft Click:|r Open Guild", ar, ag, ab)
            GameTooltip:AddLine("|cffFFFFFFRight Click:|r Whisper/Invite Menu", ar, ag, ab)
            GameTooltip:Show()
        end)
        slotFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
        
        -- Click
        slotFrame:RegisterForClicks("AnyUp")
        slotFrame:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                ToggleGuildFrame()
            elseif button == "RightButton" and IsInGuild() then
                -- Rebuild cache if needed
                if GetTime() - guildCache.lastUpdate > 1 then
                    BuildGuildCache()
                end

                local playerName = UnitName("player") .. "-" .. GetNormalizedRealmName()

                MenuUtil.CreateContextMenu(self, function(_, root)
                    root:CreateTitle("Guild Menu")

                    -- Whisper submenu
                    local whisperMenu = root:CreateButton("Whisper")
                    local hasWhisperTargets = false

                    for _, info in ipairs(guildCache.members) do
                        if info.name ~= playerName and (info.online or info.isMobile) then
                            hasWhisperTargets = true
                            local classColor = GetClassColor(info.class)
                            local colorCode = classColor and format("|cff%02x%02x%02x", classColor.r*255, classColor.g*255, classColor.b*255) or "|cffffffff"
                            local levelStr = format("|cffffffff%d|r ", info.level or 0)
                            -- Capture fullName in local for closure
                            local whisperName = info.name
                            whisperMenu:CreateButton(levelStr .. colorCode .. info.name .. "|r", function()
                                SendWhisperTo(whisperName, false)
                            end)
                        end
                    end

                    if not hasWhisperTargets then
                        local noMembers = whisperMenu:CreateButton("No members online")
                        noMembers:SetEnabled(false)
                    end

                    -- Invite submenu (exclude mobile-only and already grouped)
                    local inviteMenu = root:CreateButton("Invite")
                    local hasInviteTargets = false

                    for _, info in ipairs(guildCache.members) do
                        local isMobileOnly = info.isMobile and not info.online
                        if info.name ~= playerName and info.online and not isMobileOnly and not IsPlayerInGroup(info.name) then
                            hasInviteTargets = true
                            local classColor = GetClassColor(info.class)
                            local colorCode = classColor and format("|cff%02x%02x%02x", classColor.r*255, classColor.g*255, classColor.b*255) or "|cffffffff"
                            local levelStr = format("|cffffffff%d|r ", info.level or 0)
                            -- Capture values in locals for closure
                            local inviteName, inviteGuid = info.name, info.guid
                            inviteMenu:CreateButton(levelStr .. colorCode .. info.name .. "|r", function()
                                InvitePlayerToGroup(inviteName, inviteGuid, false)
                            end)
                        end
                    end

                    if not hasInviteTargets then
                        local noInvite = inviteMenu:CreateButton("No invitable members")
                        noInvite:SetEnabled(false)
                    end

                    root:CreateDivider()
                    root:CreateButton("Open Guild Panel", function()
                        ToggleGuildFrame()
                    end)
                end)
            end
        end)

        -- Initial update
        if IsInGuild() then
            C_GuildInfo.GuildRoster()
        end
        Update()

        return frame
    end,

    OnDisable = function(frame)
        frame:UnregisterAllEvents()
    end,
})

-- Loot Spec datatext
Datatexts:Register("lootspec", {
    displayName = "Loot Specialization",
    category = "Character",
    description = "Displays and changes loot specialization",
    
    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()
        
        local text = slotFrame.text
        if not text then
            text = slotFrame:CreateFontString(nil, "OVERLAY")
            text:SetPoint("CENTER")
            slotFrame.text = text
        end
        
        local function Update()
            local label = GetLabel("Loot: ", "L: ", slotFrame.shortLabel, slotFrame.noLabel)
            local specIndex = GetSpecialization()
            if not specIndex then
                local r, g, b = GetValueColor()
                text:SetFormattedText(label .. "|cff%02x%02x%02x%s|r", r, g, b, "?")
                return
            end

            local specID, specName, _, icon = GetSpecializationInfo(specIndex)
            -- Guard against specID being nil or 0 during zone transitions
            if not specID or specID == 0 then
                local r, g, b = GetValueColor()
                text:SetFormattedText(label .. "|cff%02x%02x%02x%s|r", r, g, b, "?")
                return
            end

            local lootSpec = GetLootSpecialization()
            local r, g, b = GetValueColor()

            -- Determine which spec name to display
            local displayName = specName
            if lootSpec ~= 0 and lootSpec ~= specID then
                -- Loot spec differs from current spec, show loot spec name
                for i = 1, GetNumSpecializations() or 0 do
                    local id, name = GetSpecializationInfo(i)
                    if id == lootSpec then
                        displayName = name
                        break
                    end
                end
            end

            text:SetFormattedText(label .. "|cff%02x%02x%02x%s|r", r, g, b, displayName or "?")
        end
        
        frame.Update = Update
        
        -- Events
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
        frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
        frame:RegisterEvent("PLAYER_TALENT_UPDATE")
        frame:SetScript("OnEvent", function(self, event)
            -- Delay update for spec changes to allow API to update
            if event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
                C_Timer.After(0.1, Update)
            else
                Update()
            end
        end)

        -- Tooltip
        slotFrame:EnableMouse(true)
        slotFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Loot Specialization", 1, 1, 1)
            GameTooltip:AddLine(" ")
            
            local specIndex = GetSpecialization()
            if specIndex then
                local lootSpec = GetLootSpecialization()
                local sameSpec = (lootSpec == 0) and specIndex or nil
                local displaySpecIndex = sameSpec or lootSpec
                
                if displaySpecIndex and displaySpecIndex ~= 0 then
                    local specID, specName, _, icon = GetSpecializationInfo((displaySpecIndex ~= 0 and displaySpecIndex) or specIndex)
                    if specName then
                        if lootSpec == 0 then
                            GameTooltip:AddLine(string.format("Current: %s (Auto)", specName), 1, 1, 1)
                        else
                            GameTooltip:AddLine(string.format("Current: %s", specName), 1, 1, 1)
                        end
                    end
                end
            end
            
            GameTooltip:AddLine(" ")
            local ar, ag, ab = GetValueColor(); ar, ag, ab = ar/255, ag/255, ab/255
            GameTooltip:AddLine("|cffFFFFFFLeft Click:|r Change Loot Spec", ar, ag, ab)
            GameTooltip:AddLine("|cffFFFFFFShift+Left Click:|r Open Talents", ar, ag, ab)
            GameTooltip:Show()
        end)
        slotFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Click
        slotFrame:RegisterForClicks("AnyUp")
        slotFrame:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                if IsShiftKeyDown() then
                    if not InCombatLockdown() then
                        TogglePlayerSpellsFrame()
                    end
                else
                    -- Simple toggle through loot specs
                    local currentSpec = GetSpecialization()
                    local currentLoot = GetLootSpecialization()
                    local numSpecs = GetNumSpecializations() or 0
                    
                    if currentLoot == 0 then
                        -- Currently auto, switch to spec 1
                        local specID = select(1, GetSpecializationInfo(1))
                        if specID then
                            SetLootSpecialization(specID)
                        end
                    else
                        -- Find current loot spec index
                        local lootIndex = 0
                        for i = 1, numSpecs do
                            local id = select(1, GetSpecializationInfo(i))
                            if id == currentLoot then
                                lootIndex = i
                                break
                            end
                        end
                        
                        -- Cycle to next
                        if lootIndex >= numSpecs then
                            SetLootSpecialization(0)  -- Back to auto
                        else
                            local nextID = select(1, GetSpecializationInfo(lootIndex + 1))
                            if nextID then
                                SetLootSpecialization(nextID)
                            end
                        end
                    end
                end
            end
        end)
        
        Update()
        return frame
    end,
    
    OnDisable = function(frame)
        frame:UnregisterAllEvents()
    end,
})

-- Bags datatext
Datatexts:Register("bags", {
    displayName = "Bags",
    category = "Character",
    description = "Displays bag space usage",

    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()

        local text = slotFrame.text
        if not text then
            text = slotFrame:CreateFontString(nil, "OVERLAY")
            text:SetPoint("CENTER")
            slotFrame.text = text
        end

        -- Number of bag slots (add 1 for reagent bag on retail)
        local NUM_BAGS = NUM_BAG_SLOTS + 1
        local REAGENT_BAG = Enum.BagIndex and Enum.BagIndex.ReagentBag or 5

        -- Color gradient for bag fullness (green=empty, red=full)
        local function ColorGradient(percent)
            if percent <= 0 then return 0.1, 1, 0.1 end
            if percent >= 1 then return 1, 0.1, 0.1 end
            if percent < 0.5 then
                return 0.1 + 1.8 * percent, 1, 0.1
            else
                return 1, 1 - 1.8 * (percent - 0.5), 0.1
            end
        end

        -- Store bag data for tooltip
        local bagData = {}

        local function Update()
            local totalSlots, usedSlots = 0, 0
            wipe(bagData)

            for i = 0, NUM_BAGS do
                local numSlots = C_Container.GetContainerNumSlots(i)
                if numSlots and numSlots > 0 then
                    local freeSlots, bagType = C_Container.GetContainerNumFreeSlots(i)
                    -- Only count normal bags (bagType 0 or nil) and reagent bags
                    if not bagType or bagType == 0 then
                        totalSlots = totalSlots + numSlots
                        usedSlots = usedSlots + (numSlots - freeSlots)
                        bagData[i] = {
                            free = freeSlots,
                            total = numSlots,
                            used = numSlots - freeSlots,
                        }
                    end
                end
            end

            local r, g, b = GetValueColor()
            local label = GetLabel("Bags: ", "B: ", slotFrame.shortLabel, slotFrame.noLabel)
            text:SetFormattedText(label .. "|cff%02x%02x%02x%d/%d|r", r, g, b, usedSlots, totalSlots)
        end

        frame.Update = Update

        -- Events
        frame:RegisterEvent("BAG_UPDATE")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:SetScript("OnEvent", Update)

        -- Tooltip
        slotFrame:EnableMouse(true)
        slotFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Bags", 1, 1, 1)
            GameTooltip:AddLine(" ")

            local iconString = "|T%s:14:14:0:0:64:64:4:60:4:60|t  %s"

            for i = 0, NUM_BAGS do
                local bagName = C_Container.GetBagName(i)
                if bagName and bagData[i] then
                    local data = bagData[i]
                    local percent = data.total > 0 and (data.used / data.total) or 0
                    local r2, g2, b2 = ColorGradient(percent)

                    if i > 0 then
                        -- Get bag icon and quality
                        local invID = C_Container.ContainerIDToInventoryID(i)
                        local icon = GetInventoryItemTexture("player", invID)
                        local quality = GetInventoryItemQuality("player", invID) or 1
                        local r1, g1, b1 = GetItemQualityColor(quality)

                        GameTooltip:AddDoubleLine(
                            string.format(iconString, icon or "", bagName),
                            string.format("%d / %d", data.used, data.total),
                            r1, g1, b1, r2, g2, b2
                        )
                    else
                        -- Backpack (bag 0)
                        GameTooltip:AddDoubleLine(
                            bagName,
                            string.format("%d / %d", data.used, data.total),
                            1, 1, 1, r2, g2, b2
                        )
                    end
                end
            end

            GameTooltip:AddLine(" ")
            local ar, ag, ab = GetValueColor(); ar, ag, ab = ar/255, ag/255, ab/255
            GameTooltip:AddLine("|cffFFFFFFLeft Click:|r Toggle Bags", ar, ag, ab)
            GameTooltip:Show()
        end)
        slotFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Click handler
        slotFrame:RegisterForClicks("AnyUp")
        slotFrame:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                ToggleAllBags()
            end
        end)

        Update()
        return frame
    end,

    OnDisable = function(frame)
        frame:UnregisterAllEvents()
    end,
})

-- Coordinates datatext
Datatexts:Register("coords", {
    displayName = "Coordinates",
    category = "Character",
    description = "Displays player map coordinates",

    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()

        local text = slotFrame.text
        if not text then
            text = slotFrame:CreateFontString(nil, "OVERLAY")
            text:SetPoint("CENTER")
            slotFrame.text = text
        end

        local function Update()
            local mapID = C_Map.GetBestMapForUnit("player")
            local r, g, b = GetValueColor()
            local label = GetLabel("Coords: ", "", slotFrame.shortLabel, slotFrame.noLabel)

            if mapID then
                local pos = C_Map.GetPlayerMapPosition(mapID, "player")
                if pos and pos.GetXY then
                    local x, y = pos:GetXY()
                    if x and y then
                        text:SetFormattedText(label .. "|cff%02x%02x%02x%d, %d|r", r, g, b, x * 100, y * 100)
                        return
                    end
                end
            end
            -- Fallback if no coords available (instanced content, etc)
            text:SetFormattedText(label .. "|cff%02x%02x%02x--|r", r, g, b)
        end

        frame.Update = Update
        frame.ticker = C_Timer.NewTicker(0.5, Update)

        -- Tooltip shows zone name
        slotFrame:EnableMouse(true)
        slotFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Coordinates", 1, 1, 1)
            GameTooltip:AddLine(GetZoneText() or "Unknown", 1, 1, 1)
            local subzone = GetSubZoneText()
            if subzone and subzone ~= "" then
                GameTooltip:AddLine(subzone, 0.7, 0.7, 0.7)
            end
            GameTooltip:AddLine(" ")
            local ar, ag, ab = GetValueColor(); ar, ag, ab = ar/255, ag/255, ab/255
            GameTooltip:AddLine("|cffFFFFFFLeft Click:|r Open Map", ar, ag, ab)
            GameTooltip:Show()
        end)
        slotFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Click to open world map
        slotFrame:RegisterForClicks("AnyUp")
        slotFrame:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                ToggleWorldMap()
            end
        end)

        Update()
        return frame
    end,

    OnDisable = function(frame)
        if frame.ticker then
            frame.ticker:Cancel()
            frame.ticker = nil
        end
    end,
})

---=================================================================================
--- CURRENCIES DATATEXT
---=================================================================================

local currenciesHookApplied = false
local activeCurrenciesFrame = nil  -- Track the active currencies frame for hook callback

Datatexts:Register("currencies", {
    displayName = "Currencies",
    category = "Character",
    description = "Displays backpack currencies (adaptive to slot size)",

    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()

        local text = slotFrame.text
        if not text then
            text = slotFrame:CreateFontString(nil, "OVERLAY")
            text:SetPoint("CENTER")
            slotFrame.text = text
        end

        local iconString = "|T%s:14:14:0:0:64:64:4:60:4:60|t"
        local goldIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:0:0|t"

        local function Update()
            -- Determine how many currencies to show based on slot width
            local slotWidth = slotFrame:GetWidth() or 0
            local maxToShow
            if slotWidth <= 0 or slotWidth < 80 then
                maxToShow = 1      -- Compact: 1 currency (also handles 0/nil)
            elseif slotWidth < 120 then
                maxToShow = 2      -- Medium: 2 currencies
            else
                maxToShow = 3      -- Full: all 3 currencies
            end

            local displayString = ""
            local shown = 0

            for i = 1, 3 do
                if shown >= maxToShow then break end
                local info = C_CurrencyInfo.GetBackpackCurrencyInfo(i)
                if info and info.quantity then
                    shown = shown + 1
                    local icon = format(iconString, info.iconFileID)
                    local quantity = AbbreviateLargeNumbers and AbbreviateLargeNumbers(info.quantity) or tostring(info.quantity)
                    if displayString ~= "" then
                        displayString = displayString .. " "
                    end
                    displayString = displayString .. icon .. " " .. quantity
                end
            end

            if displayString ~= "" then
                text:SetText(displayString)
            else
                local r, g, b = GetValueColor()
                text:SetFormattedText("|cff%02x%02x%02x%s|r", r, g, b, "No Currencies")
            end
        end

        frame.Update = Update

        -- Track this as the active currencies frame for hook callback
        activeCurrenciesFrame = frame

        -- Events
        frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:SetScript("OnEvent", Update)

        -- Hook BackpackTokenFrame.Update to catch when user changes tracked currencies
        -- Only hook once; uses module-level activeCurrenciesFrame to avoid closure leak
        if BackpackTokenFrame and BackpackTokenFrame.Update and not currenciesHookApplied then
            hooksecurefunc(BackpackTokenFrame, "Update", function()
                if activeCurrenciesFrame and activeCurrenciesFrame.Update then
                    activeCurrenciesFrame.Update()
                end
            end)
            currenciesHookApplied = true
        end

        -- Tooltip: Always shows gold + all currencies
        slotFrame:EnableMouse(true)
        slotFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Currencies", 1, 1, 1)
            GameTooltip:AddLine(" ")

            -- Gold (always shown in tooltip)
            local money = GetMoney() or 0
            local gold = floor(money / 10000)
            local silver = floor((money % 10000) / 100)
            local copper = money % 100
            GameTooltip:AddDoubleLine(goldIcon .. " Gold", format("%dg %ds %dc", gold, silver, copper), 1, 0.82, 0, 1, 1, 1)

            -- All backpack currencies
            local hasAny = false
            for i = 1, 3 do
                local info = C_CurrencyInfo.GetBackpackCurrencyInfo(i)
                if info and info.name then
                    hasAny = true
                    local icon = format(iconString, info.iconFileID)
                    local quantityText = tostring(info.quantity)
                    if info.maxQuantity and info.maxQuantity > 0 then
                        quantityText = format("%d / %d", info.quantity, info.maxQuantity)
                    end
                    GameTooltip:AddDoubleLine(icon .. " " .. info.name, quantityText, 1, 1, 1, 1, 1, 1)
                end
            end

            if not hasAny then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("No currencies tracked", 0.7, 0.7, 0.7)
                GameTooltip:AddLine("Open Currency Panel to add currencies", 0.7, 0.7, 0.7)
            end

            GameTooltip:AddLine(" ")
            local ar, ag, ab = GetValueColor(); ar, ag, ab = ar/255, ag/255, ab/255
            GameTooltip:AddLine("|cffFFFFFFLeft Click:|r Open Currency Panel", ar, ag, ab)
            GameTooltip:Show()
        end)
        slotFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Click
        slotFrame:RegisterForClicks("AnyUp")
        slotFrame:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                ToggleCharacter("TokenFrame")
            end
        end)

        Update()
        return frame
    end,

    OnDisable = function(frame)
        frame:UnregisterAllEvents()
        -- Clear the active frame reference if this was the active one
        if activeCurrenciesFrame == frame then
            activeCurrenciesFrame = nil
        end
    end,
})

---=================================================================================
--- MYTHIC KEY DATATEXT
---=================================================================================

-- Short dungeon names for compact display (challengeMapID -> short name)
-- Full names shown in tooltip via C_ChallengeMode.GetMapUIInfo()
-- Data sourced from MDT and MDungeonTeleports
-- Ordered by expansion release (oldest first)
-- Use shared dungeon data from qui_dungeon_data.lua
local function GetShortDungeonName(mapID)
    if _G.QUI_DungeonData then
        return _G.QUI_DungeonData.GetShortName(mapID)
    end
    -- Fallback if shared data not loaded yet
    local name = C_ChallengeMode.GetMapUIInfo(mapID)
    if name then
        return name:match("^(%S+)") or name
    end
    return "?"
end

-- Get color based on keystone level
local function GetKeyColor(level)
    if not level or level == 0 then return 0.7, 0.7, 0.7 end
    if level >= 20 then return 1, 0.5, 0 end      -- Orange for 20+
    if level >= 15 then return 0.64, 0.21, 0.93 end -- Purple for 15-19
    if level >= 10 then return 0, 0.44, 0.87 end  -- Blue for 10-14
    if level >= 5 then return 0.12, 1, 0 end      -- Green for 5-9
    return 1, 1, 1                                 -- White for 2-4
end

Datatexts:Register("mythickey", {
    displayName = "Mythic+ Key",
    category = "Character",
    description = "Displays current Mythic+ keystone",

    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()

        local text = slotFrame.text
        if not text then
            text = slotFrame:CreateFontString(nil, "OVERLAY")
            text:SetPoint("CENTER")
            slotFrame.text = text
        end

        local function Update()
            local keystoneLevel = C_MythicPlus.GetOwnedKeystoneLevel()
            local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()

            if keystoneLevel and keystoneLevel > 0 and mapID then
                local shortName = GetShortDungeonName(mapID)
                local kr, kg, kb = GetKeyColor(keystoneLevel)
                local vr, vg, vb = GetValueColor()
                text:SetFormattedText("|cff%02x%02x%02x+%d|r |cff%02x%02x%02x%s|r", kr*255, kg*255, kb*255, keystoneLevel, vr, vg, vb, shortName)
            else
                local r, g, b = GetValueColor()
                text:SetFormattedText("|cff%02x%02x%02x%s|r", r, g, b, "No Key")
            end
        end

        frame.Update = Update

        -- Events
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
        frame:RegisterEvent("BAG_UPDATE")
        frame:SetScript("OnEvent", Update)

        -- Tooltip
        slotFrame:EnableMouse(true)
        slotFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Mythic+ Keystone", 1, 1, 1)
            GameTooltip:AddLine(" ")

            local keystoneLevel = C_MythicPlus.GetOwnedKeystoneLevel()
            local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()

            if keystoneLevel and keystoneLevel > 0 and mapID then
                local name = C_ChallengeMode.GetMapUIInfo(mapID)
                local r, g, b = GetKeyColor(keystoneLevel)
                GameTooltip:AddDoubleLine("Current Key:", format("|cff%02x%02x%02x+%d %s|r", r*255, g*255, b*255, keystoneLevel, name or "Unknown"), 1, 1, 1)
            else
                GameTooltip:AddLine("No keystone in bags", 0.7, 0.7, 0.7)
            end

            GameTooltip:AddLine(" ")
            local ar, ag, ab = GetValueColor(); ar, ag, ab = ar/255, ag/255, ab/255
            GameTooltip:AddLine("|cffFFFFFFLeft Click:|r Open Group Finder", ar, ag, ab)
            GameTooltip:Show()
        end)
        slotFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Click
        slotFrame:RegisterForClicks("AnyUp")
        slotFrame:SetScript("OnClick", function(self, button)
            if InCombatLockdown() then return end
            if button == "LeftButton" then
                PVEFrame_ToggleFrame("GroupFinderFrame", LFDParentFrame)
            end
        end)

        Update()
        return frame
    end,

    OnDisable = function(frame)
        frame:UnregisterAllEvents()
    end,
})

---=================================================================================
--- PLAYER SPEC DATATEXT
---=================================================================================

Datatexts:Register("playerspec", {
    displayName = "Player Spec",
    category = "Character",
    description = "Displays current spec, talent loadout, and loot spec with switching",

    OnEnable = function(slotFrame, settings)
        local frame = CreateFrame("Frame", nil, slotFrame)
        frame:SetAllPoints()

        local text = slotFrame.text
        if not text then
            text = slotFrame:CreateFontString(nil, "OVERLAY")
            text:SetPoint("CENTER")
            slotFrame.text = text
        end

        local iconString = "|T%s:14:14:0:0:64:64:4:60:4:60|t"
        -- Store activeLoadoutID on frame to avoid scope issues with multiple instances
        frame.activeLoadoutID = nil

        local function GetLoadoutName(specID)
            if not PlayerUtil.CanUseClassTalents() then return nil end

            -- Check for starter build
            if C_ClassTalents.GetHasStarterBuild() and C_ClassTalents.GetStarterBuildActive() then
                frame.activeLoadoutID = nil  -- Clear when using starter
                return "Starter Build"
            end

            local configID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
            if configID then
                frame.activeLoadoutID = configID
                local configInfo = C_Traits.GetConfigInfo(configID)
                if configInfo and configInfo.name then
                    return configInfo.name
                end
            end

            return nil
        end

        local function Update()
            local specIndex = GetSpecialization()
            if not specIndex then
                text:SetText("No Spec")
                return
            end

            local specID, specName, _, icon = GetSpecializationInfo(specIndex)
            -- Guard against specID being nil or 0, or missing icon/name during zone transitions
            if not specID or specID == 0 or not icon or not specName then
                text:SetText("?")
                return
            end

            local iconText = format(iconString, icon)
            local loadoutName = GetLoadoutName(specID)
            local r, g, b = GetValueColor()

            -- Get display mode setting: "icon", "loadout", or "full" (default)
            local db = QUICore and QUICore.db
            local dtSettings = db and db.profile and db.profile.datatext
            local displayMode = dtSettings and dtSettings.specDisplayMode or "full"

            if displayMode == "icon" then
                -- Icon only
                text:SetText(iconText)
            elseif displayMode == "loadout" then
                -- Icon + loadout name (or just icon if no loadout)
                if loadoutName then
                    text:SetFormattedText("%s |cff%02x%02x%02x%s|r", iconText, r, g, b, loadoutName)
                else
                    text:SetText(iconText)
                end
            else  -- "full" (default, current behavior)
                if loadoutName then
                    text:SetFormattedText("%s |cff%02x%02x%02x%s / %s|r", iconText, r, g, b, specName, loadoutName)
                else
                    text:SetFormattedText("%s |cff%02x%02x%02x%s|r", iconText, r, g, b, specName)
                end
            end
        end

        frame.Update = Update

        -- Events
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("PLAYER_TALENT_UPDATE")
        frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
        frame:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
        frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
        frame:RegisterEvent("TRAIT_CONFIG_DELETED")
        frame:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
        frame:SetScript("OnEvent", function(self, event)
            -- Delay update for spec/loadout changes to allow API to update
            if event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_TALENT_UPDATE"
               or event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_CONFIG_LIST_UPDATED" then
                C_Timer.After(0.1, Update)
            else
                Update()
            end
        end)

        -- Tooltip
        slotFrame:EnableMouse(true)
        slotFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Talent Specialization", 1, 1, 1)
            GameTooltip:AddLine(" ")

            -- Get configured accent color for headers and active indicators
            local vr, vg, vb = GetValueColor()
            local ar, ag, ab = vr/255, vg/255, vb/255  -- For AddLine (0-1 range)
            local activeColor = format("|cff%02x%02x%02x", vr, vg, vb)  -- For inline color codes

            local currentSpec = GetSpecialization()
            local numSpecs = GetNumSpecializations() or 0

            -- Show all specs
            GameTooltip:AddLine("Specializations", ar, ag, ab)
            for i = 1, numSpecs do
                local specID, specName, _, icon = GetSpecializationInfo(i)
                if specName then
                    local iconText = format(iconString, icon)
                    local status = (i == currentSpec) and " " .. activeColor .. "(Active)|r" or ""
                    GameTooltip:AddLine(iconText .. " " .. specName .. status, 1, 1, 1)
                end
            end

            -- Show loadouts
            if currentSpec and PlayerUtil.CanUseClassTalents() then
                local specID = GetSpecializationInfo(currentSpec)
                if specID then
                    local builds = C_ClassTalents.GetConfigIDsBySpecID(specID)
                    if builds and #builds > 0 then
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("Loadouts", ar, ag, ab)

                        -- Starter build
                        if C_ClassTalents.GetHasStarterBuild() then
                            local isActive = C_ClassTalents.GetStarterBuildActive()
                            local status = isActive and " " .. activeColor .. "(Active)|r" or ""
                            GameTooltip:AddLine("|cff0070DD" .. "Starter Build" .. "|r" .. status, 1, 1, 1)
                        end

                        for _, configID in ipairs(builds) do
                            local configInfo = C_Traits.GetConfigInfo(configID)
                            if configInfo and configInfo.name then
                                local isActive = (configID == frame.activeLoadoutID)
                                local status = isActive and " " .. activeColor .. "(Active)|r" or ""
                                GameTooltip:AddLine(configInfo.name .. status, 1, 1, 1)
                            end
                        end
                    end
                end
            end

            -- Show loot spec
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Loot Specialization", ar, ag, ab)
            local lootSpec = GetLootSpecialization()
            if lootSpec == 0 then
                local _, specName = GetSpecializationInfo(currentSpec)
                GameTooltip:AddLine(format("%s (Auto)", specName or "Current Spec"), 1, 1, 1)
            else
                for i = 1, numSpecs do
                    local specID, specName = GetSpecializationInfo(i)
                    if specID == lootSpec then
                        GameTooltip:AddLine(specName, 1, 1, 1)
                        break
                    end
                end
            end

            GameTooltip:AddLine(" ")
            local ar, ag, ab = GetValueColor(); ar, ag, ab = ar/255, ag/255, ab/255
            GameTooltip:AddLine("|cffFFFFFFLeft Click:|r Change Spec", ar, ag, ab)
            GameTooltip:AddLine("|cffFFFFFFShift + Left Click:|r Open Talents", ar, ag, ab)
            GameTooltip:AddLine("|cffFFFFFFCtrl + Left Click:|r Change Loadout", ar, ag, ab)
            GameTooltip:AddLine("|cffFFFFFFRight Click:|r Change Loot Spec", ar, ag, ab)
            GameTooltip:Show()
        end)
        slotFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Click
        slotFrame:RegisterForClicks("AnyUp")
        slotFrame:SetScript("OnClick", function(self, button)
            local specIndex = GetSpecialization()
            if not specIndex then return end

            -- Get configured accent color for active indicators in menus
            local vr, vg, vb = GetValueColor()
            local activeMarker = format(" |cff%02x%02x%02x*|r", vr, vg, vb)

            if button == "LeftButton" then
                if IsShiftKeyDown() then
                    -- Open talents
                    if not InCombatLockdown() then
                        TogglePlayerSpellsFrame()
                    end
                elseif IsControlKeyDown() then
                    -- Loadout menu
                    local specID = GetSpecializationInfo(specIndex)
                    if not specID or not PlayerUtil.CanUseClassTalents() then return end

                    MenuUtil.CreateContextMenu(self, function(_, root)
                        root:CreateTitle("Switch Loadout")

                        -- Starter build
                        if C_ClassTalents.GetHasStarterBuild() then
                            local isActive = C_ClassTalents.GetStarterBuildActive()
                            root:CreateButton("|cff0070DDStarter Build|r" .. (isActive and activeMarker or ""), function()
                                if not _G.PlayerSpellsFrame then
                                    if _G.PlayerSpellsFrame_LoadUI then
                                        _G.PlayerSpellsFrame_LoadUI()
                                    else
                                        return
                                    end
                                end
                                local starterID = Constants.TraitConsts.STARTER_BUILD_TRAIT_CONFIG_ID
                                if _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.TalentsFrame then
                                    _G.PlayerSpellsFrame.TalentsFrame:LoadConfigByPredicate(function(_, configID)
                                        return configID == starterID
                                    end)
                                end
                            end)
                        end

                        local builds = C_ClassTalents.GetConfigIDsBySpecID(specID)
                        if builds then
                            for _, configID in ipairs(builds) do
                                local configInfo = C_Traits.GetConfigInfo(configID)
                                if configInfo and configInfo.name then
                                    local isActive = (configID == frame.activeLoadoutID)
                                    root:CreateButton(configInfo.name .. (isActive and activeMarker or ""), function()
                                        if not _G.PlayerSpellsFrame then
                                            if _G.PlayerSpellsFrame_LoadUI then
                                                _G.PlayerSpellsFrame_LoadUI()
                                            else
                                                return
                                            end
                                        end
                                        local targetID = configID
                                        if _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.TalentsFrame then
                                            _G.PlayerSpellsFrame.TalentsFrame:LoadConfigByPredicate(function(_, cID)
                                                return cID == targetID
                                            end)
                                        end
                                    end)
                                end
                            end
                        end
                    end)
                else
                    -- Spec menu
                    local numSpecs = GetNumSpecializations() or 0
                    MenuUtil.CreateContextMenu(self, function(_, root)
                        root:CreateTitle("Switch Specialization")
                        for i = 1, numSpecs do
                            local specID, specName, _, icon = GetSpecializationInfo(i)
                            if specName then
                                local iconText = format(iconString, icon)
                                local isActive = (i == specIndex)
                                root:CreateButton(iconText .. " " .. specName .. (isActive and activeMarker or ""), function()
                                    if InCombatLockdown() then
                                        print("|cffFF6B6BQuaziiUI:|r Cannot change specialization in combat")
                                        return
                                    end
                                    C_SpecializationInfo.SetSpecialization(i)
                                end)
                            end
                        end
                    end)
                end
            elseif button == "RightButton" then
                -- Loot spec menu
                local numSpecs = GetNumSpecializations() or 0
                local currentLoot = GetLootSpecialization()

                MenuUtil.CreateContextMenu(self, function(_, root)
                    root:CreateTitle("Loot Specialization")

                    -- Auto option
                    local _, currentSpecName = GetSpecializationInfo(specIndex)
                    local isAuto = (currentLoot == 0)
                    root:CreateButton(format("%s (Auto)", currentSpecName or "Current") .. (isAuto and activeMarker or ""), function()
                        SetLootSpecialization(0)
                    end)

                    root:CreateDivider()

                    for i = 1, numSpecs do
                        local specID, specName, _, icon = GetSpecializationInfo(i)
                        if specID then
                            local iconText = format(iconString, icon)
                            local isActive = (specID == currentLoot)
                            root:CreateButton(iconText .. " " .. specName .. (isActive and activeMarker or ""), function()
                                SetLootSpecialization(specID)
                            end)
                        end
                    end
                end)
            end
        end)

        Update()
        return frame
    end,

    OnDisable = function(frame)
        frame:UnregisterAllEvents()
    end,
})

