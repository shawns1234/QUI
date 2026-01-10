--[[
    QuaziiUI Module Registry
    Centralized system for registering, enabling, and disabling feature modules
    When a module is disabled, all its files exit early and its options pages are hidden
]]

local ADDON_NAME, ns = ...
local QUI = QuaziiUI

-- Module Registry
local ModuleRegistry = {
    modules = {},  -- {id = {name, dependencies, enabled, initFunc}}
    db = nil,  -- Will be set during initialization
}

ns.ModuleRegistry = ModuleRegistry

---------------------------------------------------------------------------
-- INITIALIZE
---------------------------------------------------------------------------
function ModuleRegistry:Initialize(db)
    self.db = db
    
    -- Ensure modules table exists in DB
    if not db.modules then
        db.modules = {}
    end
    
    -- Initialize enabled state from DB for all registered modules
    for id, module in pairs(self.modules) do
        if db.modules[id] ~= nil then
            module.enabled = db.modules[id].enabled
        else
            -- First time: use default enabled state
            db.modules[id] = { enabled = module.enabled }
        end
    end
end

---------------------------------------------------------------------------
-- REGISTER MODULE
---------------------------------------------------------------------------
--[[
    Register a module with the registry
    @param id string - Unique module identifier (e.g., "unitframes", "castbars")
    @param config table - Module configuration:
        - name: string - Display name
        - dependencies: table - Array of module IDs this depends on
        - enabled: boolean - Default enabled state (default: true)
        - initFunc: function - Optional initialization function
]]
function ModuleRegistry:RegisterModule(id, config)
    if not id or type(id) ~= "string" then
        error("ModuleRegistry:RegisterModule requires a string id")
    end
    
    if self.modules[id] then
        error(string.format("Module '%s' is already registered", id))
    end
    
    local module = {
        id = id,
        name = config.name or id,
        dependencies = config.dependencies or {},
        enabled = config.enabled ~= false,  -- Default to true
        initFunc = config.initFunc,
    }
    
    self.modules[id] = module
    
    -- If DB is already initialized, sync enabled state
    if self.db and self.db.modules then
        if self.db.modules[id] ~= nil then
            module.enabled = self.db.modules[id].enabled
        else
            self.db.modules[id] = { enabled = module.enabled }
        end
    end
end

---------------------------------------------------------------------------
-- CHECK IF MODULE IS ENABLED
---------------------------------------------------------------------------
function ModuleRegistry:IsModuleEnabled(id)
    local module = self.modules[id]
    if not module then
        return false
    end
    
    -- Check dependencies first
    for _, depId in ipairs(module.dependencies) do
        if not self:IsModuleEnabled(depId) then
            return false  -- Dependency disabled, so this module is effectively disabled
        end
    end
    
    return module.enabled
end

---------------------------------------------------------------------------
-- HELPER: Check and Register Module (for module files)
-- Returns true if module should load, false if it should exit early
-- Auto-registers module if not already registered
---------------------------------------------------------------------------
function ModuleRegistry:ShouldLoadModule(id, config)
    -- Register if not already registered
    if not self.modules[id] then
        self:RegisterModule(id, config or { name = id, enabled = true })
    end
    
    -- Return whether module is enabled
    return self:IsModuleEnabled(id)
end

-- Standalone helper function for module files (handles nil registry)
-- Usage: if not ns.ShouldLoadModule("castbars", { name = "Castbars" }) then return end
function ns.ShouldLoadModule(id, config)
    if not ModuleRegistry then
        return false  -- Registry doesn't exist
    end
    return ModuleRegistry:ShouldLoadModule(id, config)
end

-- Helper for options files (just checks enabled state, no registration)
-- Usage: if not ns.IsModuleEnabled("castbars") then return end
function ns.IsModuleEnabled(id)
    if not ModuleRegistry then
        return false  -- Registry doesn't exist
    end
    return ModuleRegistry:IsModuleEnabled(id)
end

---------------------------------------------------------------------------
-- SET MODULE ENABLED STATE
---------------------------------------------------------------------------
function ModuleRegistry:SetModuleEnabled(id, enabled)
    local module = self.modules[id]
    if not module then
        error(string.format("Module '%s' is not registered", id))
    end
    
    module.enabled = enabled
    
    -- Persist to DB
    if self.db and self.db.modules then
        if not self.db.modules[id] then
            self.db.modules[id] = {}
        end
        self.db.modules[id].enabled = enabled
    end
end

---------------------------------------------------------------------------
-- GET ALL ENABLED MODULES
---------------------------------------------------------------------------
function ModuleRegistry:GetEnabledModules()
    local enabled = {}
    for id, module in pairs(self.modules) do
        if self:IsModuleEnabled(id) then
            table.insert(enabled, module)
        end
    end
    return enabled
end

---------------------------------------------------------------------------
-- GET ALL MODULES
---------------------------------------------------------------------------
function ModuleRegistry:GetAllModules()
    local all = {}
    for id, module in pairs(self.modules) do
        table.insert(all, module)
    end
    return all
end

---------------------------------------------------------------------------
-- GET MODULE INFO
---------------------------------------------------------------------------
function ModuleRegistry:GetModule(id)
    return self.modules[id]
end

---------------------------------------------------------------------------
-- INITIALIZE ENABLED MODULES
---------------------------------------------------------------------------
function ModuleRegistry:InitializeEnabledModules()
    for id, module in pairs(self.modules) do
        if self:IsModuleEnabled(id) and module.initFunc then
            local success, err = pcall(module.initFunc)
            if not success then
                print(string.format("|cFF56D1FFQuaziiUI:|r Error initializing module '%s': %s", id, tostring(err)))
            end
        end
    end
end

return ModuleRegistry
