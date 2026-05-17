-- Lifeprint Framework Bridge
-- Ultra-reliable interface for QBCore, Qbox, ESX, and Standalone
-- Never errors on missing framework - always falls back safely

Bridge = {}

-- ============================================================================
-- Local State
-- ============================================================================

local FrameworkName = "standalone"
local FrameworkLoaded = false
local QBCoreObj = nil
local ESXObj = nil

-- ============================================================================
-- Debug Helpers (safe - check Config exists)
-- ============================================================================

local function DebugPrint(msg)
    if Config and Config.Debug then
        print(("[Lifeprint Bridge] %s"):format(tostring(msg)))
    end
end

local function DebugPrintError(msg)
    -- Always print errors, but mark as bridge error
    print(("[Lifeprint Bridge ERROR] %s"):format(tostring(msg)))
end

-- ============================================================================
-- Framework Detection
-- Detection order: qbx_core → qb-core → es_extended → standalone
-- ============================================================================

local function DetectFramework()
    -- 1. Qbox (qbx_core)
    local qbxState = GetResourceState("qbx_core")
    if qbxState == "started" then
        return "qbox"
    end

    -- 2. QBCore (qb-core)
    local qbState = GetResourceState("qb-core")
    if qbState == "started" then
        return "qbcore"
    end

    -- 3. ESX (es_extended)
    local esxState = GetResourceState("es_extended")
    if esxState == "started" then
        return "esx"
    end

    -- 4. Standalone fallback
    return "standalone"
end

-- ============================================================================
-- Framework Initialization
-- ============================================================================

function Bridge.Initialize()
    -- Get framework from config (safe access)
    local configFramework = "auto"
    if Config and Config.Framework then
        configFramework = Config.Framework:lower()
    end

    -- Determine actual framework
    if configFramework == "auto" then
        FrameworkName = DetectFramework()
    else
        FrameworkName = configFramework
    end

    DebugPrint(("Initializing framework: %s"):format(FrameworkName))

    -- Wait for framework if still starting
    local waitResource
    if FrameworkName == "qbox" then
        waitResource = "qbx_core"
    elseif FrameworkName == "qbcore" then
        waitResource = "qb-core"
    elseif FrameworkName == "esx" then
        waitResource = "es_extended"
    end

    if waitResource and GetResourceState(waitResource) == "starting" then
        DebugPrint(("Waiting for %s to start..."):format(waitResource))
        Wait(1500)
    end

    -- Initialize framework objects with pcall safety
    local ok, err

    if FrameworkName == "qbcore" then
        ok, err = pcall(function()
            QBCoreObj = exports["qb-core"]:GetCoreObject()
            return QBCoreObj ~= nil
        end)
        if ok and QBCoreObj then
            FrameworkLoaded = true
            DebugPrint("QBCore loaded successfully")
        else
            DebugPrintError(("QBCore load failed: %s, falling back to standalone"):format(tostring(err)))
            FrameworkName = "standalone"
        end

    elseif FrameworkName == "qbox" then
        -- Qbox uses exports directly, just verify it exists
        ok, err = pcall(function()
            return exports.qbx_core:GetPlayer(1) -- Test export exists
        end)
        -- Even if it errors on invalid player, export exists
        FrameworkLoaded = true
        DebugPrint("Qbox mode initialized")

    elseif FrameworkName == "esx" then
        ok, err = pcall(function()
            ESXObj = exports["es_extended"]:getSharedObject()
            return ESXObj ~= nil
        end)
        if ok and ESXObj then
            FrameworkLoaded = true
            DebugPrint("ESX loaded successfully")
        else
            DebugPrintError(("ESX load failed: %s, falling back to standalone"):format(tostring(err)))
            FrameworkName = "standalone"
        end

    else
        -- Standalone
        FrameworkLoaded = true
        DebugPrint("Standalone mode initialized")
    end

    -- Always mark loaded even if we fell back
    if not FrameworkLoaded then
        FrameworkLoaded = true
        FrameworkName = "standalone"
        DebugPrint("Fallback to standalone complete")
    end

    return FrameworkLoaded
end

-- ============================================================================
-- Bridge.GetFramework()
-- Returns: string ("qbox" | "qbcore" | "esx" | "standalone")
-- ============================================================================

function Bridge.GetFramework()
    return FrameworkName or "standalone"
end

function Bridge.IsLoaded()
    return FrameworkLoaded
end

-- Internal accessors (for server-side use only)
function Bridge._GetQBCore()
    return QBCoreObj
end

function Bridge._GetESX()
    return ESXObj
end

-- ============================================================================
-- Bridge.GetPlayer(source)
-- Returns: player object (framework-specific) or nil
-- Never errors - returns nil on any failure
-- ============================================================================

function Bridge.GetPlayer(source)
    -- Validate input
    if not FrameworkLoaded then return nil end
    if not source or type(source) ~= "number" or source <= 0 then return nil end

    local ok, result = pcall(function()
        if FrameworkName == "qbcore" then
            if QBCoreObj then
                return QBCoreObj.Functions.GetPlayer(source)
            end
            return nil

        elseif FrameworkName == "qbox" then
            return exports.qbx_core:GetPlayer(source)

        elseif FrameworkName == "esx" then
            if ESXObj then
                return ESXObj.GetPlayerFromId(source)
            end
            return nil

        else
            -- Standalone: return minimal player table
            local identifier = Bridge.GetIdentifier(source)
            local name = GetPlayerName(source) or "Unknown"
            return {
                source = source,
                identifier = identifier,
                name = name
            }
        end
    end)

    if not ok then
        DebugPrint(("GetPlayer error for source %s: %s"):format(tostring(source), tostring(result)))
        return nil
    end

    return result
end

function Bridge.GetPlayerByIdentifier(identifier)
    if not FrameworkLoaded then return nil end
    if not identifier or type(identifier) ~= "string" then return nil end

    local ok, result = pcall(function()
        if FrameworkName == "qbcore" then
            if QBCoreObj then
                return QBCoreObj.Functions.GetPlayerByCitizenId(identifier)
            end
            return nil

        elseif FrameworkName == "qbox" then
            return exports.qbx_core:GetPlayerByCitizenId(identifier)

        elseif FrameworkName == "esx" then
            if ESXObj then
                return ESXObj.GetPlayerFromIdentifier(identifier)
            end
            return nil

        else
            -- Standalone: cannot resolve identifier to source
            return nil
        end
    end)

    if not ok then
        DebugPrint(("GetPlayerByIdentifier error: %s"):format(tostring(result)))
        return nil
    end

    return result
end

-- ============================================================================
-- Bridge.GetIdentifier(source)
-- Returns: string identifier or nil
-- Standalone: prefers "license:", falls back to first identifier
-- ============================================================================

function Bridge.GetIdentifier(source)
    if not FrameworkLoaded then return nil end
    if not source or type(source) ~= "number" or source <= 0 then return nil end

    local ok, result = pcall(function()
        if FrameworkName == "qbcore" then
            if QBCoreObj then
                local player = QBCoreObj.Functions.GetPlayer(source)
                if player and player.PlayerData then
                    return player.PlayerData.citizenid
                end
            end
            return nil

        elseif FrameworkName == "qbox" then
            local player = exports.qbx_core:GetPlayer(source)
            if player and player.PlayerData then
                return player.PlayerData.citizenid
            end
            return nil

        elseif FrameworkName == "esx" then
            if ESXObj then
                local player = ESXObj.GetPlayerFromId(source)
                if player then
                    return player.identifier
                end
            end
            return nil

        else
            -- Standalone: license first, then first available identifier
            local identifiers = GetPlayerIdentifiers(source)
            if not identifiers or #identifiers == 0 then
                return nil
            end

            -- Prefer license
            for _, id in ipairs(identifiers) do
                if id:find("^license:") then
                    return id:gsub("^license:", "")
                end
            end

            -- Fall back to first identifier (strip prefix)
            local first = identifiers[1]
            if first then
                local stripped = first:match("^[^:]+:(.+)$")
                return stripped or first
            end

            return nil
        end
    end)

    if not ok then
        DebugPrint(("GetIdentifier error for source %s: %s"):format(tostring(source), tostring(result)))
        return nil
    end

    return result
end

function Bridge.GetAllIdentifiers(source)
    if not source or type(source) ~= "number" or source <= 0 then
        return {}
    end

    local ok, result = pcall(function()
        local identifiers = {}

        if FrameworkName == "qbcore" or FrameworkName == "qbox" then
            local player = Bridge.GetPlayer(source)
            if player and player.PlayerData then
                table.insert(identifiers, player.PlayerData.citizenid)
            end

        elseif FrameworkName == "esx" then
            if ESXObj then
                local player = ESXObj.GetPlayerFromId(source)
                if player then
                    table.insert(identifiers, player.identifier)
                end
            end

        else
            -- Standalone: get all raw identifiers
            local raw = GetPlayerIdentifiers(source)
            if raw then
                for _, id in ipairs(raw) do
                    table.insert(identifiers, id)
                end
            end
        end

        return identifiers
    end)

    if not ok then
        DebugPrint(("GetAllIdentifiers error: %s"):format(tostring(result)))
        return {}
    end

    return result or {}
end

-- ============================================================================
-- Bridge.GetCharacterName(source)
-- Returns: string (character name) or nil
-- Standalone: uses GetPlayerName()
-- ============================================================================

function Bridge.GetCharacterName(source)
    if not FrameworkLoaded then return nil end
    if not source or type(source) ~= "number" or source <= 0 then return nil end

    local ok, result = pcall(function()
        if FrameworkName == "qbcore" then
            if QBCoreObj then
                local player = QBCoreObj.Functions.GetPlayer(source)
                if player and player.PlayerData and player.PlayerData.charinfo then
                    local c = player.PlayerData.charinfo
                    return (c.firstname or "") .. " " .. (c.lastname or "")
                end
            end
            return nil

        elseif FrameworkName == "qbox" then
            local player = exports.qbx_core:GetPlayer(source)
            if player and player.PlayerData and player.PlayerData.charinfo then
                local c = player.PlayerData.charinfo
                return (c.firstname or "") .. " " .. (c.lastname or "")
            end
            return nil

        elseif FrameworkName == "esx" then
            if ESXObj then
                local player = ESXObj.GetPlayerFromId(source)
                if player then
                    return player.name or nil
                end
            end
            return nil

        else
            -- Standalone: use GetPlayerName
            local name = GetPlayerName(source)
            return name or nil
        end
    end)

    if not ok then
        DebugPrint(("GetCharacterName error for source %s: %s"):format(tostring(source), tostring(result)))
        return nil
    end

    return result
end

function Bridge.GetCharacterNameByIdentifier(identifier)
    if not FrameworkLoaded then return nil end
    if not identifier or type(identifier) ~= "string" then return nil end

    local ok, result = pcall(function()
        if FrameworkName == "qbcore" then
            if QBCoreObj then
                local player = QBCoreObj.Functions.GetPlayerByCitizenId(identifier)
                if player and player.PlayerData and player.PlayerData.charinfo then
                    local c = player.PlayerData.charinfo
                    return (c.firstname or "") .. " " .. (c.lastname or "")
                end
            end
            return nil

        elseif FrameworkName == "qbox" then
            local player = exports.qbx_core:GetPlayerByCitizenId(identifier)
            if player and player.PlayerData and player.PlayerData.charinfo then
                local c = player.PlayerData.charinfo
                return (c.firstname or "") .. " " .. (c.lastname or "")
            end
            return nil

        elseif FrameworkName == "esx" then
            if ESXObj then
                local player = ESXObj.GetPlayerFromIdentifier(identifier)
                if player then
                    return player.name or nil
                end
            end
            return nil

        else
            -- Standalone: cannot resolve without custom mapping
            return identifier
        end
    end)

    if not ok then
        DebugPrint(("GetCharacterNameByIdentifier error: %s"):format(tostring(result)))
        return nil
    end

    return result
end

-- ============================================================================
-- Bridge.HasPermission(source, permission)
-- Returns: boolean
-- Always checks ACE as fallback with "lifeprint.admin"
-- ============================================================================

function Bridge.HasPermission(source, permission)
    -- Validate input
    if not FrameworkLoaded then return false end
    if not source or type(source) ~= "number" or source <= 0 then return false end

    local method = "both"
    if Config and Config.PermissionMethod then
        method = Config.PermissionMethod:lower()
    end

    -- Check ACE permission (always available)
    local hasACE = false
    local aceGroup = "lifeprint.admin"
    if Config and Config.ACEAdminGroup then
        aceGroup = Config.ACEAdminGroup
    end
    
    local ok, aceResult = pcall(function()
        return IsPlayerAceAllowed(source, aceGroup) or IsPlayerAceAllowed(source, "command." .. (permission or ""))
    end)
    hasACE = ok and aceResult or false

    -- If ACE-only mode, return ACE result
    if method == "ace" then
        return hasACE
    end

    -- Check framework permission
    local hasFramework = false
    local ok2, fwResult = pcall(function()
        return Bridge._CheckFrameworkPermission(source)
    end)
    hasFramework = ok2 and fwResult or false

    -- If framework-only mode, return framework result
    if method == "framework" then
        return hasFramework
    end

    -- "both" mode: pass if either succeeds
    return hasACE or hasFramework
end

function Bridge._CheckFrameworkPermission(source)
    if FrameworkName == "qbcore" then
        if QBCoreObj then
            local player = QBCoreObj.Functions.GetPlayer(source)
            if player and player.PlayerData then
                local rank = player.PlayerData.permission
                return rank == "admin" or rank == "god"
            end
        end
        return false

    elseif FrameworkName == "qbox" then
        local ok, result = pcall(function()
            local permLevel = Config and Config.QBCorePermission or "admin"
            return exports.qbx_core:HasPermission(source, permLevel)
        end)
        return ok and result or false

    elseif FrameworkName == "esx" then
        if ESXObj then
            local player = ESXObj.GetPlayerFromId(source)
            if player then
                local group = player.getGroup()
                return group == "superadmin" or group == "admin"
            end
        end
        return false

    else
        -- Standalone: ACE fallback
        local aceGroup = "lifeprint.admin"
        if Config and Config.StandaloneAdminACE then
            aceGroup = Config.StandaloneAdminACE
        end
        local ok, result = pcall(function()
            return IsPlayerAceAllowed(source, aceGroup)
        end)
        return ok and result or false
    end
end

-- ============================================================================
-- Bridge.Notify(source, message, type)
-- Server-side notification trigger
-- Falls back to chat:addMessage if ox_lib unavailable
-- ============================================================================

function Bridge.Notify(source, message, notifyType)
    -- Validate input
    if not source or type(source) ~= "number" or source <= 0 then return end
    notifyType = notifyType or "inform"

    -- Try ox_lib first if configured
    local useOxLib = Config and Config.UseOxLibNotify
    
    if useOxLib then
        local ok, _ = pcall(function()
            if GetResourceState("ox_lib") == "started" then
                TriggerClientEvent("ox_lib:notify", source, {
                    title = "Lifeprint",
                    description = tostring(message),
                    type = notifyType
                })
                return true
            end
            return false
        end)
        if ok then return end
    end

    -- Fallback: trigger client-side notification handler
    TriggerClientEvent("lifeprint:client:notify", source, tostring(message), notifyType)
end

-- Client-side notification (call from client script)
function Bridge.NotifyClient(message, notifyType)
    notifyType = notifyType or "inform"

    -- Try ox_lib first
    local useOxLib = Config and Config.UseOxLibNotify
    
    if useOxLib then
        local ok, _ = pcall(function()
            if GetResourceState("ox_lib") == "started" then
                exports.ox_lib:notify({
                    title = "Lifeprint",
                    description = tostring(message),
                    type = notifyType
                })
                return true
            end
            return false
        end)
        if ok then return end
    end

    -- Fallback: native GTA notification
    local ok, _ = pcall(function()
        BeginTextCommandThefeedPost("STRING")
        AddTextComponentSubstringPlayerName(tostring(message))
        EndTextCommandThefeedPostTicker(false, true)
    end)
    
    -- Final fallback: chat message (only if native failed)
    if not ok then
        TriggerEvent("chat:addMessage", {
            color = { 167, 139, 250 },
            args = { "Lifeprint", tostring(message) }
        })
    end
end

-- ============================================================================
-- Exports
-- ============================================================================

exports("GetFramework", Bridge.GetFramework)
exports("GetPlayer", Bridge.GetPlayer)
exports("GetIdentifier", Bridge.GetIdentifier)
exports("GetCharacterName", Bridge.GetCharacterName)
exports("HasPermission", Bridge.HasPermission)
exports("Notify", Bridge.Notify)
