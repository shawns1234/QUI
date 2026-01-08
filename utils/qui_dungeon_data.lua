local addonName, ns = ...

---------------------------------------------------------------------------
-- SHARED DUNGEON DATA
-- Central source of truth for dungeon mapIDs, short names, and teleport spells
-- Used by: qui_datatexts.lua, qui_dungeon_teleport.lua, qui_mplus_timer.lua
---------------------------------------------------------------------------

-- Faction-specific spells
local factionGroup = UnitFactionGroup("player")
local SIEGE_SPELL = factionGroup == "Horde" and 464256 or 445418
local MOTHERLODE_SPELL = factionGroup == "Horde" and 467555 or 467553

-- Master dungeon table: mapID -> { short, spellID }
-- spellID is nil for dungeons without teleport portals
local DUNGEON_DATA = {
    -- Wrath of the Lich King
    [556] = { short = "PIT",   spellID = 1254555 }, -- Pit of Saron (Midnight S1) - spellID datamined

    -- Mists of Pandaria
    [2]   = { short = "TJS",   spellID = 131204 },  -- Temple of the Jade Serpent
    [56]  = { short = "SSB",   spellID = 131205 },  -- Stormstout Brewery
    [57]  = { short = "SPM",   spellID = 131206 },  -- Shado-Pan Monastery
    [58]  = { short = "SNT",   spellID = 131228 },  -- Siege of Niuzao Temple
    [59]  = { short = "GOTSS", spellID = 131225 },  -- Gate of the Setting Sun
    [60]  = { short = "MSP",   spellID = 131222 },  -- Mogu'shan Palace
    [76]  = { short = "SCHOLO", spellID = 131232 }, -- Scholomance
    [77]  = { short = "SH",    spellID = 131231 },  -- Scarlet Halls
    [78]  = { short = "SM",    spellID = 131229 },  -- Scarlet Monastery

    -- Warlords of Draenor
    [161] = { short = "BSM",   spellID = 159895 },  -- Bloodmaul Slag Mines
    [163] = { short = "AUCH",  spellID = 159897 },  -- Auchindoun
    [164] = { short = "SR",    spellID = 159898 },  -- Skyreach / Spires of Arak
    [165] = { short = "SBG",   spellID = 159899 },  -- Shadowmoon Burial Grounds
    [166] = { short = "GD",    spellID = 159900 },  -- Grimrail Depot
    [167] = { short = "UBRS",  spellID = 159902 },  -- Upper Blackrock Spire
    [168] = { short = "EB",    spellID = 159901 },  -- The Everbloom
    [169] = { short = "ID",    spellID = 159896 },  -- Iron Docks

    -- Legion
    [197] = { short = "EOA",   spellID = nil },     -- Eye of Azshara (no portal)
    [198] = { short = "DT",    spellID = 424163 },  -- Darkheart Thicket
    [199] = { short = "BRH",   spellID = 424153 },  -- Black Rook Hold
    [200] = { short = "HOV",   spellID = 393764 },  -- Halls of Valor
    [206] = { short = "NL",    spellID = 410078 },  -- Neltharion's Lair
    [207] = { short = "VAULT", spellID = nil },     -- Vault of the Wardens (no portal)
    [208] = { short = "MOS",   spellID = nil },     -- Maw of Souls (no portal)
    [209] = { short = "ARC",   spellID = nil },     -- The Arcway (no portal)
    [210] = { short = "COS",   spellID = 393766 },  -- Court of Stars
    [227] = { short = "KARA",  spellID = 373262 },  -- Lower Karazhan
    [234] = { short = "KARA",  spellID = 373262 },  -- Upper Karazhan
    [239] = { short = "SEAT",  spellID = 1254551 }, -- Seat of the Triumvirate (Midnight S1) - spellID datamined

    -- Battle for Azeroth
    [244] = { short = "AD",    spellID = 424187 },  -- Atal'Dazar
    [245] = { short = "FH",    spellID = 410071 },  -- Freehold
    [247] = { short = "ML",    spellID = MOTHERLODE_SPELL }, -- The MOTHERLODE!!
    [248] = { short = "WM",    spellID = 424167 },  -- Waycrest Manor
    [249] = { short = "KR",    spellID = nil },     -- Kings' Rest (no portal)
    [250] = { short = "SETH",  spellID = nil },     -- Temple of Sethraliss (no portal)
    [251] = { short = "UNDR",  spellID = 410074 },  -- The Underrot
    [252] = { short = "SHRINE", spellID = nil },    -- Shrine of the Storm (no portal)
    [353] = { short = "SIEGE", spellID = SIEGE_SPELL }, -- Siege of Boralus
    [369] = { short = "YARD",  spellID = 373274 },  -- Mechagon Junkyard
    [370] = { short = "MECHA", spellID = 373274 },  -- Mechagon Workshop

    -- Shadowlands
    [375] = { short = "MISTS", spellID = 354464 },  -- Mists of Tirna Scithe
    [376] = { short = "NW",    spellID = 354462 },  -- The Necrotic Wake
    [377] = { short = "DOS",   spellID = 354468 },  -- De Other Side
    [378] = { short = "HOA",   spellID = 354465 },  -- Halls of Atonement
    [379] = { short = "PF",    spellID = 354463 },  -- Plaguefall
    [380] = { short = "SD",    spellID = 354469 },  -- Sanguine Depths
    [381] = { short = "SOA",   spellID = 354466 },  -- Spires of Ascension
    [382] = { short = "TOP",   spellID = 354467 },  -- Theater of Pain
    [391] = { short = "STRT",  spellID = 367416 },  -- Tazavesh: Streets of Wonder
    [392] = { short = "GMBT",  spellID = 367416 },  -- Tazavesh: So'leah's Gambit

    -- Dragonflight
    [399] = { short = "RLP",   spellID = 393256 },  -- Ruby Life Pools
    [400] = { short = "NO",    spellID = 393262 },  -- The Nokhud Offensive
    [401] = { short = "AV",    spellID = 393279 },  -- The Azure Vault
    [402] = { short = "AA",    spellID = 393273 },  -- Algeth'ar Academy
    [403] = { short = "ULD",   spellID = 393222 },  -- Uldaman: Legacy of Tyr
    [404] = { short = "NELTH", spellID = 393276 },  -- Neltharus
    [405] = { short = "BH",    spellID = 393267 },  -- Brackenhide Hollow
    [406] = { short = "HOI",   spellID = 393283 },  -- Halls of Infusion
    [463] = { short = "DOTI",  spellID = 424197 },  -- Dawn of the Infinite: Galakrond's Fall
    [464] = { short = "DOTI",  spellID = 424197 },  -- Dawn of the Infinite: Murozond's Rise

    -- The War Within
    [499] = { short = "PSF",   spellID = 445444 },  -- Priory of the Sacred Flame
    [500] = { short = "ROOK",  spellID = 445443 },  -- The Rookery
    [501] = { short = "SV",    spellID = 445269 },  -- The Stonevault
    [502] = { short = "COT",   spellID = 445416 },  -- City of Threads
    [503] = { short = "ARAK",  spellID = 445417 },  -- Ara-Kara, City of Echoes
    [504] = { short = "DFC",   spellID = 445441 },  -- Darkflame Cleft
    [505] = { short = "DAWN",  spellID = 445414 },  -- The Dawnbreaker
    [506] = { short = "BREW",  spellID = 445440 },  -- Cinderbrew Meadery
    [507] = { short = "GB",    spellID = 445424 },  -- Grim Batol
    [525] = { short = "FLOOD", spellID = 1216786 }, -- Operation: Floodgate
    [542] = { short = "EDA",   spellID = 1237215 }, -- Eco-Dome Al'dani

    -- Cataclysm (added via Timewalking/M+)
    [438] = { short = "VP",    spellID = 410080 },  -- Vortex Pinnacle
    [456] = { short = "TOTT",  spellID = 424142 },  -- Throne of the Tides

    -- Midnight (12.x) Season 1 dungeons
    -- Using confirmed challengeModeMapIDs (557-560) with datamined spellIDs
    [557] = { short = "WIND",  spellID = 1254840 }, -- Windrunner Spire
    [558] = { short = "MAGI",  spellID = 1254572 }, -- Magisters' Terrace
    [559] = { short = "XENAS", spellID = 1254563 }, -- Nexus-Point Xenas
    [560] = { short = "CAVNS", spellID = 1255247 }, -- Maisara Caverns
    -- Legacy datamined mapIDs (kept for compatibility)
    [15808] = { short = "WIND",  spellID = 1254840 }, -- Windrunner Spire
    [15829] = { short = "MAGI",  spellID = 1254572 }, -- Magisters' Terrace
    [16573] = { short = "XENAS", spellID = 1254563 }, -- Nexus-Point Xenas
    [16395] = { short = "CAVNS", spellID = 1255247 }, -- Maisara Caverns
    -- Other Midnight dungeons (spellIDs TBD)
    [16091] = { short = "MURDR", spellID = nil },     -- Murder Row
    [16359] = { short = "BLIND", spellID = nil },     -- The Blinding Vale
    [16368] = { short = "NALO",  spellID = nil },     -- Den of Nalorakk
    [16388] = { short = "FORAG", spellID = nil },     -- The Foraging
    [16425] = { short = "VSCAR", spellID = nil },     -- Voidscar Arena
    [16641] = { short = "RAGE",  spellID = nil },     -- The Heart of Rage
    [16479] = { short = "VSTORM", spellID = nil },    -- Voidstorm (Dungeon)
}

---------------------------------------------------------------------------
-- ACCESSOR FUNCTIONS
---------------------------------------------------------------------------

-- Get short name for a dungeon mapID
local function GetShortName(mapID)
    local data = DUNGEON_DATA[mapID]
    if data then
        return data.short
    end
    -- Fallback: get full name and abbreviate
    local name = C_ChallengeMode.GetMapUIInfo(mapID)
    if name then
        -- Take first word or first 4 chars
        local firstWord = name:match("^(%S+)")
        if firstWord and #firstWord <= 6 then
            return firstWord:upper()
        end
        return name:sub(1, 4):upper()
    end
    return "???"
end

-- Get teleport spell ID for a dungeon mapID
local function GetTeleportSpellID(mapID)
    local data = DUNGEON_DATA[mapID]
    return data and data.spellID or nil
end

-- Get full dungeon data for a mapID
local function GetDungeonData(mapID)
    return DUNGEON_DATA[mapID]
end

-- Check if a dungeon has a teleport spell
local function HasTeleport(mapID)
    local data = DUNGEON_DATA[mapID]
    return data and data.spellID ~= nil
end

-- Get key level color (shared utility)
local function GetKeyColor(level)
    if not level or level == 0 then return 0.7, 0.7, 0.7 end
    if level >= 12 then return 1, 0.5, 0 end      -- Orange for 12+
    if level >= 10 then return 0.64, 0.21, 0.93 end -- Purple for 10-11
    if level >= 7 then return 0, 0.44, 0.87 end   -- Blue for 7-9
    if level >= 5 then return 0.12, 0.75, 0.26 end -- Green for 5-6
    return 1, 1, 1                                 -- White for 2-4
end

---------------------------------------------------------------------------
-- EXPORT TO NAMESPACE
---------------------------------------------------------------------------

ns.DungeonData = {
    data = DUNGEON_DATA,
    GetShortName = GetShortName,
    GetTeleportSpellID = GetTeleportSpellID,
    GetDungeonData = GetDungeonData,
    HasTeleport = HasTeleport,
    GetKeyColor = GetKeyColor,
}

-- Also expose globally for cross-file access
_G.QUI_DungeonData = ns.DungeonData
