-- Lifeprint Client Script
-- Handles NUI interactions, commands, and client-side logic
-- All commands are safe - never crash on nil data, missing config, or framework errors

local isOpen = false
local currentData = {
    memories = {},
    relationships = {},
    reputation = {},
    rumors = {}
}

-- ============================================================================
-- Caching (performance optimization)
-- ============================================================================

local cachedIdentifier = nil
local cachedPlayerName = nil
local lastUIDataRequest = 0  -- Timestamp for UI refresh throttling

-- Client-side time function (os.time not available client-side)
-- Returns seconds since game start
local function GetClientTime()
    return math.floor(GetGameTimer() / 1000)
end

-- Get performance config safely
local function GetPerfConfig(key, default)
    if Config and Config.Performance and Config.Performance[key] ~= nil then
        return Config.Performance[key]
    end
    return default
end

-- Get Face Memory config safely
local function GetFaceMemoryConfig(key, default)
    if Config and Config.FaceMemory and Config.FaceMemory[key] ~= nil then
        return Config.FaceMemory[key]
    end
    return default
end

-- Get NPC Violence config safely (forward declaration for use in event handlers)
local function GetNPCViolenceConfig(key, default)
    if Config and Config.NPCViolence and Config.NPCViolence[key] ~= nil then
        return Config.NPCViolence[key]
    end
    return default
end

-- Get NPC Witness config safely (forward declaration for use in event handlers)
local function GetNPCWitnessConfig(key, default)
    if Config and Config.NPCWitness and Config.NPCWitness[key] ~= nil then
        return Config.NPCWitness[key]
    end
    return default
end

-- Get cached identifier (avoids repeated framework calls)
local function GetMyIdentifier()
    if cachedIdentifier then return cachedIdentifier end
    if Bridge and Bridge.GetIdentifier then
        cachedIdentifier = Bridge.GetIdentifier(PlayerId())
    end
    return cachedIdentifier
end

-- Get cached player name
local function GetMyPlayerName()
    if cachedPlayerName then return cachedPlayerName end
    if Bridge and Bridge.GetCharacterName then
        cachedPlayerName = Bridge.GetCharacterName(PlayerId())
    end
    return cachedPlayerName or GetPlayerName(PlayerId())
end

-- ============================================================================
-- Debug Logging (Safe - checks Config exists)
-- ============================================================================

local function DebugLog(message)
    if Config and Config.Debug then
        print(('[Lifeprint Client] %s'):format(tostring(message)))
    end
end

-- ============================================================================
-- NUI Helper Functions
-- ============================================================================

local function SendNuiMessage(action, data)
    SendNUIMessage({
        action = action or 'unknown',
        data = data or {}
    })
end

-- ============================================================================
-- Character Photo System (Headshot Capture)
-- ============================================================================

local currentHeadshotHandle = nil
local currentPhotoTxd = nil

-- Capture character headshot photo
local function CaptureCharacterPhoto()
    -- Unregister any existing headshot first
    if currentHeadshotHandle then
        UnregisterPedheadshot(currentHeadshotHandle)
        currentHeadshotHandle = nil
        currentPhotoTxd = nil
    end
    
    local playerPed = PlayerPedId()
    if not DoesEntityExist(playerPed) then
        DebugLog('Cannot capture photo: player ped does not exist')
        return nil
    end
    
    -- Register transparent headshot (better for UI display)
    local handle = RegisterPedheadshotTransparent(playerPed)
    if not handle or handle == 0 then
        -- Fallback to regular headshot
        handle = RegisterPedheadshot(playerPed)
        DebugLog('Using regular headshot (transparent unavailable)')
    end
    
    if not handle or handle == 0 then
        DebugLog('Failed to register headshot')
        return nil
    end
    
    currentHeadshotHandle = handle
    
    -- Wait for headshot to be ready (with timeout)
    local timeout = 0
    local maxWait = 3000 -- 3 seconds max
    
    while not IsPedheadshotReady(handle) and timeout < maxWait do
        Wait(50)
        timeout = timeout + 50
    end
    
    if not IsPedheadshotReady(handle) then
        DebugLog('Headshot capture timed out')
        UnregisterPedheadshot(handle)
        currentHeadshotHandle = nil
        return nil
    end
    
    -- Get the texture dictionary string
    local txdString = GetPedheadshotTxdString(handle)
    if not txdString or txdString == '' then
        DebugLog('Failed to get headshot texture string')
        UnregisterPedheadshot(handle)
        currentHeadshotHandle = nil
        return nil
    end
    
    currentPhotoTxd = txdString
    DebugLog('Headshot captured successfully: ' .. tostring(txdString))
    
    return txdString
end

-- Send avatar data to NUI (with optional headshot texture)
local function SendAvatarToNUI()
    local playerName = GetMyPlayerName() or 'Unknown Player'
    
    -- Generate initials from name
    local initials = ''
    for word in playerName:gmatch('%S+') do
        initials = initials .. (word:sub(1,1):upper() or '')
        if #initials >= 2 then break end
    end
    if #initials < 2 then initials = playerName:sub(1,2):upper() end
    
    -- Generate a consistent color from the name (same color for same name)
    local hash = 0
    for i = 1, #playerName do
        hash = (hash * 31 + string.byte(playerName, i)) % 360
    end
    local hue = hash
    local avatarColor = string.format('hsl(%d, 45%%, 35%%)', hue)
    
    -- Capture a fresh headshot for the player profile
    local headshotTxd = CaptureCharacterPhoto()
    
    SendNUIMessage({
        action = 'updateAvatar',
        data = { 
            initials = initials, 
            color = avatarColor,
            name = playerName,
            headshotTxd = headshotTxd -- May be nil if capture failed
        }
    })
    DebugLog('Avatar sent to NUI: ' .. initials .. ' for ' .. playerName .. ', headshot: ' .. tostring(headshotTxd))
end

-- Clean up headshot resources
local function CleanupHeadshot()
    if currentHeadshotHandle then
        UnregisterPedheadshot(currentHeadshotHandle)
        currentHeadshotHandle = nil
        currentPhotoTxd = nil
        DebugLog('Headshot resources cleaned up')
    end
end

-- ============================================================================
-- Target Headshot Capture (for face memories)
-- ============================================================================

local targetHeadshotHandles = {} -- Track multiple headshots

-- Capture a headshot of a target ped
-- Returns: txdString or nil if failed
local function CaptureTargetHeadshot(targetPed)
    if not DoesEntityExist(targetPed) then
        DebugLog('Cannot capture target headshot: ped does not exist')
        return nil
    end
    
    -- Check config for ped headshot usage
    if not GetFaceMemoryConfig('usePedHeadshot', true) then
        DebugLog('Ped headshot disabled in config')
        return nil
    end
    
    local timeout = GetFaceMemoryConfig('headshotTimeout', 3000)
    
    -- Register transparent headshot (better for UI display)
    local handle = RegisterPedheadshotTransparent(targetPed)
    if not handle or handle == 0 then
        -- Fallback to regular headshot
        handle = RegisterPedheadshot(targetPed)
        DebugLog('Using regular headshot for target (transparent unavailable)')
    end
    
    if not handle or handle == 0 then
        DebugLog('Failed to register target headshot')
        return nil
    end
    
    -- Track the handle for cleanup
    targetHeadshotHandles[handle] = true
    
    -- Wait for headshot to be ready (with timeout)
    local waited = 0
    local waitInterval = 50
    
    while waited < timeout do
        if IsPedheadshotReady(handle) then
            break
        end
        Wait(waitInterval)
        waited = waited + waitInterval
    end
    
    if not IsPedheadshotReady(handle) then
        DebugLog('Target headshot capture timed out after ' .. timeout .. 'ms')
        UnregisterPedheadshot(handle)
        targetHeadshotHandles[handle] = nil
        return nil
    end
    
    -- Validate the headshot
    if not IsPedheadshotValid(handle) then
        DebugLog('Target headshot is not valid')
        UnregisterPedheadshot(handle)
        targetHeadshotHandles[handle] = nil
        return nil
    end
    
    -- Get the texture dictionary string
    local txdString = GetPedheadshotTxdString(handle)
    if not txdString or txdString == '' then
        DebugLog('Failed to get target headshot texture string')
        UnregisterPedheadshot(handle)
        targetHeadshotHandles[handle] = nil
        return nil
    end
    
    DebugLog('Target headshot captured successfully: ' .. tostring(txdString))
    
    -- Unregister immediately after getting the string (the texture is now cached)
    UnregisterPedheadshot(handle)
    targetHeadshotHandles[handle] = nil
    
    return txdString
end

-- Clean up all target headshots
local function CleanupAllTargetHeadshots()
    for handle, _ in pairs(targetHeadshotHandles) do
        if handle then
            UnregisterPedheadshot(handle)
        end
    end
    targetHeadshotHandles = {}
    DebugLog('All target headshots cleaned up')
end

 local function CloseNUI()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNuiMessage('close')
    -- Clean up headshot when closing UI
    CleanupHeadshot()
    DebugLog('NUI closed')
end

-- ============================================================================
-- Open Command (/lifeprint)
-- ============================================================================

RegisterCommand('lifeprint', function()
    DebugLog('lifeprint command triggered')
    
    -- Toggle: close if already open
    if isOpen then
        DebugLog('Closing NUI (toggle)')
        CloseNUI()
        return
    end
    
    -- Show loading screen immediately, THEN request data from server
    CreateThread(function()
        -- Set NUI focus first
        isOpen = true
        SetNuiFocus(true, true)
        
        -- Show loading screen immediately (no delay needed)
        SendNUIMessage({
            action = 'showLoading'
        })
        
        DebugLog('Loading screen shown, now requesting data from server')
        
        -- Now request data from server (server validates everything)
        TriggerServerEvent('lifeprint:server:getData')
    end)
end, false)

-- Also register using Config.OpenCommand if it exists
CreateThread(function()
    local cmdName = Config and Config.OpenCommand or 'lifeprint'
    if cmdName ~= 'lifeprint' then
        RegisterCommand(cmdName, function()
            if isOpen then
                CloseNUI()
                return
            end
            TriggerServerEvent('lifeprint:server:getData')
        end, false)
    end
end)

-- ============================================================================
-- Admin Commands (all validated server-side)
-- ============================================================================

-- /lpdemo - Generate demo data (admin only)
RegisterCommand('lpdemo', function(source, args, raw)
    TriggerServerEvent('lifeprint:server:adminDemo')
    DebugLog('lpdemo command sent to server')
end, false)

-- /lpwipe - Wipe own data (admin only)
RegisterCommand('lpwipe', function(source, args, raw)
    TriggerServerEvent('lifeprint:server:adminWipe')
    DebugLog('lpwipe command sent to server')
end, false)

-- /lpaddmemory - Add test memory (admin only, accepts optional args)
RegisterCommand('lpaddmemory', function(source, args, raw)
    -- Parse optional arguments: [type] [description]
    local memoryType = args[1] or 'other'
    local description = table.concat(args, ' ', 2) or 'Test memory added via admin command'
    
    TriggerServerEvent('lifeprint:server:adminAddMemoryCustom', {
        memoryType = memoryType,
        description = description
    })
    DebugLog('lpaddmemory command sent to server')
end, false)

-- /lpadmin - Open admin management panel (admin only)
RegisterCommand('lpadmin', function(source, args, raw)
    DebugLog('lpadmin command triggered')
    
    -- Toggle: close if already open
    if isOpen then
        DebugLog('Closing NUI (admin toggle)')
        CloseNUI()
        return
    end
    
    -- Request admin panel (server validates permission)
    TriggerServerEvent('lifeprint:server:adminOpenPanel')
end, false)

-- /lpreport [serverId] - Generate evidence dossier for a player (admin only)
RegisterCommand('lpreport', function(source, args, raw)
    DebugLog('lpreport command triggered')
    
    local targetServerId = tonumber(args[1])
    if not targetServerId or targetServerId <= 0 then
        Bridge.Notify('Usage: /lpreport [serverId]', 'error')
        return
    end
    
    -- Request report (server validates permission)
    TriggerServerEvent('lifeprint:server:generateReport', targetServerId)
end, false)

-- /lpdebug - Show debug information panel (admin only)
RegisterCommand('lpdebug', function(source, args, raw)
    DebugLog('lpdebug command triggered')
    
    -- Request debug info (server validates permission)
    TriggerServerEvent('lifeprint:server:adminDebug')
end, false)

-- /lpsettings - Open privacy settings panel
RegisterCommand('lpsettings', function(source, args, raw)
    DebugLog('lpsettings command triggered')
    
    -- Toggle: close if already open
    if isOpen then
        DebugLog('Closing NUI (settings toggle)')
        CloseNUI()
        return
    end
    
    isOpen = true
    SetNuiFocus(true, true)
    
    -- Request settings from server
    TriggerServerEvent('lifeprint:server:getSettings')
end, false)

-- ============================================================================
-- Server Event Handlers (receive data from server)
-- ============================================================================

RegisterNetEvent('lifeprint:client:openNUI', function(data)
    DebugLog('Received openNUI event with data')
    
    -- Validate data
    data = data or {}
    data.memories = data.memories or {}
    data.relationships = data.relationships or {}
    data.reputation = data.reputation or {}
    data.rumors = data.rumors or {}
    data.player = data.player or { name = 'Unknown', identifier = 'unknown' }
    data.counters = data.counters or {}
    data.tags = data.tags or {}
    data.characterRead = data.characterRead or ''
    
    -- Set state
    isOpen = true
    currentData = data
    
    -- NUI focus should already be set, but ensure it
    SetNuiFocus(true, true)
    
    -- Keep loading screen visible for configured duration, then show main UI
    CreateThread(function()
        local duration = Config and Config.LoadingScreenDuration or 6000
        DebugLog(('Loading screen visible, waiting %dms...'):format(duration))
        Wait(duration)
        
        -- Send data to NUI after delay (loading screen transitions to main UI)
        SendNUIMessage({
            action = 'open',
            data = data
        })
        
        -- Send avatar (initials-based) after UI opens
        Wait(100) -- Small delay to let UI settle
        SendAvatarToNUI()
        
        DebugLog('Data sent to NUI, UI should now render')
    end)
end)

RegisterNetEvent('lifeprint:client:closeNUI', function()
    CloseNUI()
end)

RegisterNetEvent('lifeprint:client:updateData', function(data)
    if data then
        currentData = data
        SendNuiMessage('updateData', data)
    end
end)

RegisterNetEvent('lifeprint:client:demoComplete', function(data)
    DebugLog('Demo complete - auto-opening NUI')
    
    -- Validate data
    data = data or {}
    data.memories = data.memories or {}
    data.relationships = data.relationships or {}
    data.reputation = data.reputation or {}
    data.rumors = data.rumors or {}
    data.player = data.player or { name = 'Unknown', identifier = 'unknown' }
    data.counters = data.counters or {}
    data.tags = data.tags or {}
    data.characterRead = data.characterRead or ''
    
    -- Set state and focus
    isOpen = true
    currentData = data
    SetNuiFocus(true, true)
    
    -- Show loading screen immediately
    SendNUIMessage({
        action = 'showLoading'
    })
    
    -- Wait for loading duration, then show main UI with data
    CreateThread(function()
        local duration = Config and Config.LoadingScreenDuration or 6000
        DebugLog(('Loading screen visible, waiting %dms...'):format(duration))
        Wait(duration)
        
        SendNUIMessage({
            action = 'open',
            data = data
        })
        
        DebugLog('Demo UI opened with cinematic data')
    end)
end)

RegisterNetEvent('lifeprint:client:showReport', function(reportData)
    DebugLog('Received report data for dossier')
    
    if not reportData then
        Bridge.Notify('Failed to generate report', 'error')
        return
    end
    
    isOpen = true
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        action = 'showReport',
        data = reportData
    })
end)

-- Debug Panel Event Handler
RegisterNetEvent('lifeprint:client:showDebugPanel', function(debugInfo)
    DebugLog('Received debug info for panel display')
    
    if not debugInfo then
        Bridge.Notify('Failed to gather debug information', 'error')
        return
    end
    
    -- Send to NUI debug panel
    SendNUIMessage({
        action = 'showDebugPanel',
        data = debugInfo
    })
end)

RegisterNetEvent('lifeprint:client:notify', function(message, notifyType)
    -- Native GTA notification (safe fallback)
    local ok, err = pcall(function()
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(tostring(message or 'Notification'))
        EndTextCommandThefeedPostTicker(false, true)
    end)
    
    if not ok then
        -- Final fallback: chat message
        TriggerEvent('chat:addMessage', {
            color = { 167, 139, 250 },
            args = { 'Lifeprint', tostring(message) }
        })
    end
end)

RegisterNetEvent('lifeprint:client:searchResults', function(results)
    SendNuiMessage('searchResults', results or {})
end)

-- ============================================================================
-- Admin Panel Events
-- ============================================================================

RegisterNetEvent('lifeprint:client:openAdminPanel', function(data)
    DebugLog('Received openAdminPanel event')
    
    data = data or {}
    data.players = data.players or {}
    data.isAdmin = data.isAdmin or false
    
    isOpen = true
    currentData = data
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        action = 'openAdminPanel',
        data = data
    })
    
    DebugLog('Admin panel opened successfully')
end)

RegisterNetEvent('lifeprint:client:adminPlayerData', function(data)
    SendNuiMessage('adminPlayerData', data or {})
end)

-- ============================================================================
-- Settings Panel Events
-- ============================================================================

RegisterNetEvent('lifeprint:client:openSettings', function(data)
    DebugLog('Received openSettings event')
    
    data = data or {}
    data.settings = data.settings or {
        face_reminders = true,
        proximity_memories = true,
        rumor_notifications = true,
        memory_popups = true
    }
    
    isOpen = true
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        action = 'openSettings',
        data = data
    })
    
    DebugLog('Settings panel opened successfully')
end)

-- ============================================================================
-- NUI Callbacks (always acknowledge with cb(), validate server-side)
-- ============================================================================

RegisterNUICallback('close', function(data, cb)
    CloseNUI()
    cb({ success = true })
end)

RegisterNUICallback('requestData', function(data, cb)
    cb({ success = true })
    
    -- Throttle refresh requests
    local now = GetGameTimer()
    local cooldown = GetPerfConfig('uiRefreshCooldown', 500)
    if (now - lastUIDataRequest) < cooldown then
        DebugLog('UI refresh throttled')
        return
    end
    lastUIDataRequest = now
    
    TriggerServerEvent('lifeprint:server:getData')
end)

RegisterNUICallback('addMemory', function(data, cb)
    cb({ success = true })
    -- Server validates all data
    TriggerServerEvent('lifeprint:server:addMemory', data or {})
end)

RegisterNUICallback('updateRelationship', function(data, cb)
    cb({ success = true })
    TriggerServerEvent('lifeprint:server:updateRelationship', data or {})
end)

RegisterNUICallback('saveRelationshipNote', function(data, cb)
    cb({ success = true })
    TriggerServerEvent('lifeprint:server:saveRelationshipNote', data or {})
end)

RegisterNUICallback('addReputation', function(data, cb)
    cb({ success = true })
    TriggerServerEvent('lifeprint:server:addReputation', data or {})
end)

RegisterNUICallback('addRumor', function(data, cb)
    cb({ success = true })
    TriggerServerEvent('lifeprint:server:addRumor', data or {})
end)

RegisterNUICallback('deleteMemory', function(data, cb)
    cb({ success = true })
    if data and data.memoryId then
        TriggerServerEvent('lifeprint:server:deleteMemory', data.memoryId)
    end
end)

RegisterNUICallback('deleteRumor', function(data, cb)
    cb({ success = true })
    if data and data.rumorId then
        TriggerServerEvent('lifeprint:server:deleteRumor', data.rumorId)
    end
end)

RegisterNUICallback('searchPlayers', function(data, cb)
    cb({ success = true })
    if data and data.query and #data.query >= 2 then
        TriggerServerEvent('lifeprint:server:searchPlayers', data.query)
    else
        SendNuiMessage('searchResults', {})
    end
end)

-- Admin NUI Callbacks (server validates permission)
RegisterNUICallback('adminSearchPlayer', function(data, cb)
    cb({ success = true })
    if data and data.serverId then
        TriggerServerEvent('lifeprint:server:adminSearchPlayer', tonumber(data.serverId))
    end
end)

RegisterNUICallback('adminAddMemory', function(data, cb)
    cb({ success = true })
    TriggerServerEvent('lifeprint:server:adminAddMemoryToPlayer', data or {})
end)

RegisterNUICallback('adminAddRumor', function(data, cb)
    cb({ success = true })
    TriggerServerEvent('lifeprint:server:adminAddRumorToPlayer', data or {})
end)

RegisterNUICallback('adminSetCounter', function(data, cb)
    cb({ success = true })
    TriggerServerEvent('lifeprint:server:adminSetCounter', data or {})
end)

RegisterNUICallback('adminWipePlayer', function(data, cb)
    cb({ success = true })
    if data and data.targetIdentifier then
        TriggerServerEvent('lifeprint:server:adminWipePlayer', data.targetIdentifier)
    end
end)

RegisterNUICallback('adminRefreshPlayer', function(data, cb)
    cb({ success = true })
    if data and data.targetIdentifier then
        TriggerServerEvent('lifeprint:server:adminRefreshPlayer', data.targetIdentifier)
    end
end)

-- Handle wipe completion from server
RegisterNetEvent('lifeprint:client:adminWipeComplete', function(targetIdentifier)
    DebugLog('Wipe complete for: ' .. tostring(targetIdentifier))
    
    -- Send empty data to NUI to refresh the admin panel
    SendNUIMessage({
        action = 'adminWipeComplete',
        data = { targetIdentifier = targetIdentifier }
    })
end)

-- Settings NUI Callbacks
RegisterNUICallback('saveSettings', function(data, cb)
    cb({ success = true })
    if data and type(data) == 'table' then
        TriggerServerEvent('lifeprint:server:saveSettings', data)
    end
end)

-- Character Photo NUI Callback
RegisterNUICallback('refreshPhoto', function(data, cb)
    cb({ success = true })
    DebugLog('Refresh photo requested')
    
    -- Send avatar data
    SendAvatarToNUI()
end)

-- ============================================================================
-- Key Controls (interval-based, not every frame)
-- ============================================================================

CreateThread(function()
    local keyInterval = Config and Config.Performance and Config.Performance.keyHandlerInterval or 100
    while true do
        Wait(keyInterval)
        if isOpen and IsControlJustPressed(0, 322) then -- ESC
            CloseNUI()
        end
    end
end)

-- ============================================================================
-- Automatic Tracking System
-- Passive tracking that runs in the background:
--   - Proximity: Creates "Known Contact" after 20s within 3m
--   - Vehicle Crash: Records significant vehicle damage
--   - Injury: Records health drops below threshold
-- ============================================================================

local proximityTimers = {}
local lastHealth = 200
local lastVehicleHealth = 1000
local lastVehicle = nil
local wasInVehicle = false

-- Safe config access
local function GetTrackingConfig(key, default)
    if Config and Config.AutoTracking and Config.AutoTracking[key] ~= nil then
        return Config.AutoTracking[key]
    end
    return default
end

local function GetNearbyPlayers(maxDistance)
    local players = {}
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local activePlayers = GetActivePlayers()
    
    for _, player in ipairs(activePlayers) do
        local playerPed = GetPlayerPed(player)
        if playerPed and playerPed ~= myPed then
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(myCoords - playerCoords)
            if distance <= maxDistance then
                local serverId = GetPlayerServerId(player)
                if serverId and serverId > 0 then
                    table.insert(players, {
                        serverId = serverId,
                        distance = distance
                    })
                end
            end
        end
    end
    
    return players
end

local function GetLocationName()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local streetHash, crossHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetHash)
    local areaName = GetNameOfZone(coords.x, coords.y, coords.z)
    
    if streetName and streetName ~= '' then
        return streetName .. ', ' .. (areaName or '')
    end
    return areaName or 'Unknown Location'
end

-- Proximity Tracking
CreateThread(function()
    if not GetTrackingConfig('proximity', true) then return end
    
    local distance = GetTrackingConfig('proximityDistance', 3.0)
    local requiredTime = GetTrackingConfig('proximityTime', 20)
    local checkInterval = GetPerfConfig('proximityInterval', 2000)
    
    DebugLog(('Proximity tracking: %.1fm for %ds'):format(distance, requiredTime))
    
    while true do
        Wait(checkInterval)
        
        if isOpen then goto continue end
        
        local nearbyPlayers = GetNearbyPlayers(distance)
        local currentTime = GetGameTimer()
        
        -- Process (limit to 20 players)
        local count = 0
        for _, player in ipairs(nearbyPlayers) do
            count = count + 1
            if count > 20 then break end
            
            local serverId = player.serverId
            
            if not proximityTimers[serverId] then
                proximityTimers[serverId] = { startTime = currentTime, triggered = false }
            end
            
            local timer = proximityTimers[serverId]
            if timer and not timer.triggered then
                local timeSpent = (currentTime - timer.startTime) / 1000
                if timeSpent >= requiredTime then
                    TriggerServerEvent('lifeprint:tracking:proximity', serverId, GetLocationName())
                    timer.triggered = true
                    DebugLog(('Proximity triggered with player %d'):format(serverId))
                end
            end
        end
        
        -- Cleanup
        local cleanup = {}
        for serverId, timer in pairs(proximityTimers) do
            local stillNear = false
            for _, player in ipairs(nearbyPlayers) do
                if player.serverId == serverId then stillNear = true break end
            end
            if not stillNear and not timer.triggered then
                cleanup[serverId] = true
            end
        end
        for serverId in pairs(cleanup) do
            proximityTimers[serverId] = nil
        end
        
        ::continue::
    end
end)

-- Social Web Tracking (Seen With)
-- Tracks players seen together for extended periods to build social patterns
CreateThread(function()
    local socialConfig = Config and Config.SocialWeb or {}
    if not socialConfig.enabled then return end
    
    local distance = socialConfig.proximityDistance or 5.0
    local requiredTime = socialConfig.minProximityTime or 30  -- 30 seconds
    local checkInterval = socialConfig.checkInterval or 3000  -- 3 seconds
    
    -- Track time spent near each player
    local socialTimers = {}
    
    DebugLog(('Social web tracking: %.1fm for %ds'):format(distance, requiredTime))
    
    while true do
        Wait(checkInterval)
        
        if isOpen then goto continue end
        
        local nearbyPlayers = GetNearbyPlayers(distance)
        local currentTime = GetGameTimer()
        
        -- Process nearby players
        local count = 0
        for _, player in ipairs(nearbyPlayers) do
            count = count + 1
            if count > 20 then break end
            
            local serverId = player.serverId
            
            if not socialTimers[serverId] then
                socialTimers[serverId] = { startTime = currentTime, triggered = false }
            end
            
            local timer = socialTimers[serverId]
            if timer and not timer.triggered then
                local timeSpent = (currentTime - timer.startTime) / 1000
                if timeSpent >= requiredTime then
                    TriggerServerEvent('lifeprint:tracking:socialWeb', serverId)
                    timer.triggered = true
                    DebugLog(('Social web triggered with player %d'):format(serverId))
                end
            end
        end
        
        -- Cleanup timers for players no longer nearby
        local cleanup = {}
        for serverId, timer in pairs(socialTimers) do
            local stillNear = false
            for _, player in ipairs(nearbyPlayers) do
                if player.serverId == serverId then stillNear = true break end
            end
            if not stillNear and not timer.triggered then
                cleanup[serverId] = true
            end
        end
        for serverId in pairs(cleanup) do
            socialTimers[serverId] = nil
        end
        
        ::continue::
    end
end)

-- Vehicle Crash Tracking
CreateThread(function()
    if not GetTrackingConfig('vehicleCrash', true) then return end
    
    local checkInterval = GetPerfConfig('vehicleCheckInterval', 1000)
    local healthThreshold = GetTrackingConfig('crashHealthThreshold', 30)
    local velocityThreshold = GetTrackingConfig('crashVelocityThreshold', 20.0)
    
    DebugLog('Vehicle crash tracking started')
    
    while true do
        Wait(checkInterval)
        
        if isOpen then goto continue end
        
        local ped = PlayerPedId()
        local currentVehicle = GetVehiclePedIsIn(ped, false)
        
        if currentVehicle and currentVehicle ~= 0 then
            if not wasInVehicle then
                lastVehicle = currentVehicle
                lastVehicleHealth = GetVehicleBodyHealth(currentVehicle)
                wasInVehicle = true
            elseif currentVehicle == lastVehicle then
                local currentVehicleHealth = GetVehicleBodyHealth(currentVehicle)
                local healthDrop = lastVehicleHealth - currentVehicleHealth
                
                if healthDrop > (healthThreshold * 10) then
                    local velocity = GetEntityVelocity(currentVehicle)
                    local speed = #velocity
                    
                    if speed > velocityThreshold or healthDrop > 200 then
                        TriggerServerEvent('lifeprint:tracking:vehicleCrash', {
                            location = GetLocationName(),
                            healthDrop = math.floor(healthDrop),
                            speed = math.floor(speed * 3.6)
                        })
                        DebugLog(('Crash: %d damage at %d km/h'):format(healthDrop, speed * 3.6))
                    end
                    lastVehicleHealth = currentVehicleHealth
                end
            end
        else
            if wasInVehicle then
                lastVehicle = nil
                wasInVehicle = false
            end
        end
        
        ::continue::
    end
end)

-- Injury Tracking
CreateThread(function()
    if not GetTrackingConfig('injury', true) then return end
    
    local checkInterval = GetPerfConfig('healthCheckInterval', 2000)
    local healthThreshold = GetTrackingConfig('injuryHealthThreshold', 120)
    
    DebugLog(('Injury tracking: threshold %d'):format(healthThreshold))
    
    while true do
        Wait(checkInterval)
        
        if isOpen then goto continue end
        
        local ped = PlayerPedId()
        local currentHealth = GetEntityHealth(ped)
        
        if currentHealth < healthThreshold and lastHealth >= healthThreshold then
            local healthLost = lastHealth - currentHealth
            if healthLost > 20 then
                TriggerServerEvent('lifeprint:tracking:injury', {
                    location = GetLocationName(),
                    healthLost = healthLost,
                    currentHealth = currentHealth
                })
                DebugLog(('Injury: lost %d health'):format(healthLost))
            end
        end
        
        lastHealth = currentHealth
        
        ::continue::
    end
end)

-- ============================================================================
-- Combat Tracking
-- Detects kills and combat encounters
-- ============================================================================

local lastKillTime = 0
local killedPeds = {}  -- Track which peds we've already counted

-- Get Combat config safely
local function GetCombatConfig(key, default)
    if Config and Config.CombatTracking and Config.CombatTracking[key] ~= nil then
        return Config.CombatTracking[key]
    end
    return default
end

-- Combat tracking thread
CreateThread(function()
    if not GetCombatConfig('enabled', true) then return end
    
    local checkInterval = GetCombatConfig('checkInterval', 500)
    local trackNPCKills = GetCombatConfig('trackNPCKills', true)
    local trackPlayerKills = GetCombatConfig('trackPlayerKills', true)
    
    DebugLog('Combat tracking started')
    
    while true do
        Wait(checkInterval)
        
        if isOpen then goto continue end
        
        local ped = PlayerPedId()
        
        -- Check for kills using GetPedCauseOfDeath
        local nearbyPeds = GetGamePool('CPed')
        for _, nearbyPed in ipairs(nearbyPeds) do
            if nearbyPed ~= ped and IsPedDeadOrDying(nearbyPed, true) then
                -- Use entity pointer as unique key
                local pedKey = tostring(nearbyPed)
                
                if not killedPeds[pedKey] then
                    -- Check if player caused this death
                    local cause = GetPedCauseOfDeath(nearbyPed)
                    if cause == ped then
                        -- We killed this ped
                        killedPeds[pedKey] = true
                        
                        -- Check cooldown
                        local now = GetGameTimer()
                        if (now - lastKillTime) > (GetCombatConfig('killCooldown', 300) * 1000) then
                            lastKillTime = now
                            
                            -- Determine if NPC or Player
                            local isPlayer = IsPedAPlayer(nearbyPed)
                            
                            if (isPlayer and trackPlayerKills) or (not isPlayer and trackNPCKills) then
                                local targetName = 'Unknown'
                                local targetServerId = nil
                                
                                if isPlayer then
                                    -- Get player info from the ped
                                    local playerIdx = NetworkGetPlayerIndexFromPed(nearbyPed)
                                    if playerIdx and playerIdx ~= -1 then
                                        targetServerId = GetPlayerServerId(playerIdx)
                                        if targetServerId and targetServerId > 0 then
                                            targetName = GetPlayerName(playerIdx) or 'Unknown'
                                        end
                                    end
                                else
                                    targetName = 'Civilian'
                                end
                                
                                -- Weapon detection: GetPedCauseOfDeath returns the killer entity
                                -- For simplicity, just report 'Unknown Weapon'
                                local weaponName = 'Unknown Weapon'
                                
                                TriggerServerEvent('lifeprint:tracking:combat', {
                                    isPlayer = isPlayer,
                                    targetName = targetName,
                                    targetServerId = targetServerId,
                                    weapon = weaponName,
                                    location = GetLocationName()
                                })
                                
                                DebugLog(('Combat: Killed %s (%s)'):format(targetName, isPlayer and 'Player' or 'NPC'))
                            end
                        end
                    end
                end
            end
        end
        
        -- Clean up killedPeds table periodically
        local count = 0
        for _ in pairs(killedPeds) do count = count + 1 end
        if count > 50 then
            killedPeds = {}
        end
        
        ::continue::
    end
end)

-- Helper: Get weapon name from hash
function GetWeaponName(weaponHash)
    local weapons = {
        [2725352035] = "Unarmed",
        [2578778090] = "Knife",
        [1737195953] = "Bat",
        [1317494615] = "Crowbar",
        [2508868205] = "Flashlight",
        [1141786504] = "Golf Club",
        [2227010557] = "Hammer",
        [2842669180] = "Hatchet",
        [3407207442] = "Machete",
        [2548138729] = "Switchblade",
        [4191993649] = "Dagger",
        [4222086598] = "Baseball",
        [2874557184] = "Pistol",
        [3249783971] = "Combat Pistol",
        [2017224191] = "SMG",
        [2639543090] = "Assault Rifle",
        [4208068199] = "Carbine Rifle",
        [1649403952] = "Shotgun",
        [487013001] = "Sawed-Off Shotgun",
        [100416529] = "Sniper Rifle",
        [205991906] = "Heavy Sniper",
        [2725944767] = "MG",
        [2142690083] = "Grenade",
        [2815754682] = "Molotov",
        [1313152798] = "RPG",
        [1255157839] = "Minigun",
    }
    return weapons[weaponHash] or "Unknown Weapon"
end

RegisterNetEvent('lifeprint:client:resetProximityTimer', function(targetServerId)
    if proximityTimers[targetServerId] then
        proximityTimers[targetServerId] = nil
    end
end)

-- ============================================================================
-- Death/Kill Tracking
-- ONLY triggers on confirmed player death (not normal damage)
-- Uses CEventNetworkEntityDamage with IsEntityDead confirmation + fallback loop
-- ============================================================================

local lastDeathTime = 0
local lastKillEventTime = 0
local isDead = false
local hasRecordedDeath = false  -- Prevents duplicate death memories while player remains dead
local lastHealthCheck = 200

-- Get DeathTracking config safely
local function GetDeathConfig(key, default)
    if Config and Config.DeathTracking and Config.DeathTracking[key] ~= nil then
        return Config.DeathTracking[key]
    end
    return default
end

-- Get location name helper (reused)
local function GetLocationName()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    
    local streetHash = 0
    local crossingHash = 0
    GetStreetNameAtCoord(coords.x, coords.y, coords.z, streetHash, crossingHash)
    
    local streetName = GetStreetNameFromHashKey(streetHash)
    local crossingName = GetStreetNameFromHashKey(crossingHash)
    
    if streetName and streetName ~= '' then
        if crossingName and crossingName ~= '' and crossingName ~= streetName then
            return streetName .. ' & ' .. crossingName
        end
        return streetName
    end
    
    -- Fallback to zone name
    local zone = GetNameOfZone(coords.x, coords.y, coords.z)
    local zoneNames = {
        ['DOWNTOWN'] = 'Downtown',
        ['VESPUCCI'] = 'Vespucci',
        ['ROCKFORD'] = 'Rockford Hills',
        ['BURTON'] = 'Burton',
        ['STRAWBERRY'] = 'Strawberry',
        ['RANCHO'] = 'Rancho',
        ['MIRROR'] = 'Mirror Park',
        ['PILLBOX'] = 'Pillbox Hill',
        ['LEGION'] = 'Legion Square',
        ['DELBEACH'] = 'Del Perro Beach',
        ['DELPERRO'] = 'Del Perro',
        ['BEACH'] = 'Vespucci Beach',
        ['KOREATWN'] = 'Little Seoul',
        ['MORNINGS'] = 'Morningwood',
        ['HAWICK'] = 'Hawick',
        ['DLMESA'] = 'Downtown Vinewood',
        ['EAST_V'] = 'East Vinewood',
        ['ALTU'] = 'Alta',
        ['VINE'] = 'Vinewood Hills',
        ['TATAMO'] = 'Tataviam Mountains',
        ['SANCHIA'] = 'San Chianski Mountains',
        ['GALLI'] = 'Galileo Park',
        ['LMESA'] = 'La Mesa',
        ['TEXTI'] = 'Textile City',
        ['GOLF'] = 'GWC and Golfing Society',
        ['MOVIE'] = 'Richards Majestic',
        ['STAD'] = 'Maze Bank Arena',
        ['SKID'] = 'Mission Row',
        ['AIRP'] = 'LSIA',
        ['ISHEI'] = 'International Airport'
    }
    
    return zoneNames[zone] or zone or 'Los Santos'
end

-- Internal function to record player death (called once per death)
local function RecordPlayerDeath(killerName, killerServerId, isPlayerKill, weaponName, location, coords)
    if hasRecordedDeath then return end  -- Already recorded this death
    
    local now = GetGameTimer()
    local cooldown = (GetDeathConfig('cooldown', 10) * 1000)
    
    if (now - lastDeathTime) < cooldown then return end  -- Cooldown not expired
    
    lastDeathTime = now
    hasRecordedDeath = true
    isDead = true
    
    -- Send death event to server
    TriggerServerEvent('lifeprint:tracking:playerDeath', {
        killerName = killerName or 'Unknown',
        killerServerId = killerServerId,
        isPlayerKill = isPlayerKill or false,
        weapon = weaponName or 'Unknown',
        location = location or 'Unknown',
        x = coords and coords.x,
        y = coords and coords.y,
        z = coords and coords.z
    })
    
    DebugLog(('Death confirmed: killed by %s with %s at %s'):format(killerName or 'Unknown', weaponName or 'Unknown', location or 'Unknown'))
end

-- Internal function to record player kill (called once per kill)
local function RecordPlayerKill(targetName, targetServerId, weaponName, location, coords)
    if not targetServerId or targetServerId <= 0 then return end
    
    local now = GetGameTimer()
    local cooldown = (GetDeathConfig('cooldown', 10) * 1000)
    
    if (now - lastKillEventTime) < cooldown then return end  -- Cooldown not expired
    
    lastKillEventTime = now
    
    -- Send kill event to server
    TriggerServerEvent('lifeprint:tracking:playerKill', {
        targetName = targetName or 'Unknown',
        targetServerId = targetServerId,
        weapon = weaponName or 'Unknown',
        location = location or 'Unknown',
        x = coords and coords.x,
        y = coords and coords.y,
        z = coords and coords.z
    })
    
    DebugLog(('Kill confirmed: killed %s (ID %d) with %s at %s'):format(targetName or 'Unknown', targetServerId, weaponName or 'Unknown', location or 'Unknown'))
end

-- Event handler for death detection using gameEventTriggered
-- ONLY triggers if IsEntityDead confirms the player is actually dead
AddEventHandler('gameEventTriggered', function(event, data)
    if not GetDeathConfig('enabled', true) then return end
    
    -- CEventNetworkEntityDamage is triggered when an entity takes damage or dies
    if event == 'CEventNetworkEntityDamage' then
        local victim = data[1]  -- Entity that was damaged
        local culprit = data[2]  -- Entity that caused damage
        local isDeadFlag = data[4]  -- Boolean if this killed the victim (can be unreliable)
        local weaponHash = data[5] or 0  -- Weapon hash used
        
        local myPed = PlayerPedId()
        local weaponName = GetWeaponName(weaponHash)
        
        -- Handle player death - MUST confirm with IsEntityDead
        if victim == myPed and isDeadFlag then
            -- CRITICAL: Double-check that player is actually dead
            if not IsEntityDead(myPed) then
                -- Player took damage but is NOT dead - do NOT create death memory
                DebugLog('Damage event received but player is NOT dead - skipping death memory')
                return
            end
            
            -- Player is confirmed dead - record death memory
            local killerName = 'Unknown'
            local killerServerId = nil
            local isPlayerKill = false
            
            if culprit and culprit ~= 0 then
                if IsPedAPlayer(culprit) then
                    -- Killer is a player (not self)
                    if culprit ~= myPed then
                        local playerIdx = NetworkGetPlayerIndexFromPed(culprit)
                        if playerIdx and playerIdx ~= -1 then
                            killerServerId = GetPlayerServerId(playerIdx)
                            if killerServerId and killerServerId > 0 then
                                killerName = GetPlayerName(playerIdx) or 'Unknown'
                                isPlayerKill = true
                            end
                        end
                    else
                        -- Self-death (suicide) - don't count as player kill
                        killerName = 'Self'
                        isPlayerKill = false
                    end
                else
                    -- Killer is an NPC
                    killerName = 'NPC'
                end
            else
                -- Environmental death (fall, drowning, etc.)
                killerName = 'Environment'
            end
            
            local location = GetLocationName()
            local coords = GetEntityCoords(myPed)
            
            RecordPlayerDeath(killerName, killerServerId, isPlayerKill, weaponName, location, coords)
        end
        
        -- Handle player kill (we killed another player)
        -- MUST confirm victim is dead AND is a player AND is not self
        if culprit == myPed and IsPedAPlayer(victim) and victim ~= myPed then
            -- CRITICAL: Double-check that victim is actually dead
            if not IsEntityDead(victim) then
                -- Victim took damage but is NOT dead - do NOT create kill memory
                DebugLog('Damage event received but victim is NOT dead - skipping kill memory')
                return
            end
            
            -- Victim is confirmed dead - record kill memory
            local playerIdx = NetworkGetPlayerIndexFromPed(victim)
            if playerIdx and playerIdx ~= -1 then
                local targetServerId = GetPlayerServerId(playerIdx)
                local targetName = GetPlayerName(playerIdx) or 'Unknown'
                local location = GetLocationName()
                local coords = GetEntityCoords(victim)
                
                RecordPlayerKill(targetName, targetServerId, weaponName, location, coords)
            end
        end
        
        -- ============================================================================
        -- NPC COMBAT TRACKING (Assaults and Kills)
        -- Detects when player damages or kills NPCs (non-player peds)
        -- ============================================================================
        if culprit == myPed and not IsPedAPlayer(victim) and victim ~= myPed then
            -- Player attacked an NPC
            local isKill = isDeadFlag or IsEntityDead(victim)
            local eventType = isKill and 'npc_kill' or 'npc_assault'
            
            -- Check CombatTracking config
            if not GetCombatConfig then
                -- Define helper if not exists
                GetCombatConfig = function(key, default)
                    if Config and Config.CombatTracking and Config.CombatTracking[key] ~= nil then
                        return Config.CombatTracking[key]
                    end
                    return default
                end
            end
            
            -- Check NPCViolence config
            local violenceEnabled = GetNPCViolenceConfig and GetNPCViolenceConfig('enabled', true)
            if not violenceEnabled then
                DebugLog('NPC Combat: NPCViolence disabled')
                goto npcCombatSkip
            end
            
            -- Check specific event toggles
            if isKill and not GetNPCViolenceConfig('trackKills', true) then
                DebugLog('NPC Combat: NPC kills tracking disabled')
                goto npcCombatSkip
            end
            if not isKill and not GetNPCViolenceConfig('trackAssault', true) then
                DebugLog('NPC Combat: NPC assault tracking disabled')
                goto npcCombatSkip
            end
            
            -- Get victim model name for metadata
            local victimModel = GetEntityModel(victim)
            local modelName = GetLabelText(GetDisplayNameFromVehicleModel(victimModel))
            if not modelName or modelName == 'NULL' or modelName == '' then
                modelName = 'Civilian'
            end
            
            local coords = GetEntityCoords(victim)
            local location = GetLocationName and GetLocationName() or GetStreetNameFromCoords(coords)
            local weaponName = GetWeaponName and GetWeaponName(weaponHash) or 'Unknown'
            
            DebugLog(('NPC Combat: Player %s NPC (%s) with %s at %s'):format(
                isKill and 'killed' or 'assaulted', modelName, weaponName, location))
            
            -- Fire server event to record memory and update counters
            TriggerServerEvent('lifeprint:npcWitness:report', {
                eventType = eventType,
                coords = coords,
                location = location,
                witnessCount = 1,  -- Always record, don't require witnesses
                metadata = {
                    victimType = modelName,
                    weapon = weaponName
                }
            })
            
            ::npcCombatSkip::
        end
    end
end)

-- Fallback death detection loop (every 1000ms)
-- Catches deaths that might miss the gameEventTriggered
CreateThread(function()
    if not GetDeathConfig('enabled', true) then return end
    
    while true do
        Wait(1000)
        
        local ped = PlayerPedId()
        local health = GetEntityHealth(ped)
        
        -- Check if player just died (health dropped to 0 or player is dead)
        if IsEntityDead(ped) and not hasRecordedDeath then
            -- Player is dead but we haven't recorded it yet
            local location = GetLocationName()
            local coords = GetEntityCoords(ped)
            
            -- Record as environmental/unknown death (fallback)
            RecordPlayerDeath('Unknown', nil, false, 'Unknown', location, coords)
            DebugLog('Death detected via fallback loop (missed event)')
        end
        
        -- Reset tracking when player respawns/revives (health restored above death threshold)
        if hasRecordedDeath and health > 100 then
            isDead = false
            hasRecordedDeath = false
            lastHealthCheck = health
            DebugLog('Player respawned/revived - death tracking reset')
        end
        
        lastHealthCheck = health
    end
end)

-- ============================================================================
-- Non-Fatal Injury Tracking
-- Records memories when player is hurt but survives (NOT death)
-- ============================================================================

local lastInjuryTime = 0
local lastHealthValue = 200  -- Default max health
local injuryCooldowns = {}  -- Per-injury-type cooldowns

-- Get InjuryTracking config safely
local function GetInjuryConfig(key, default)
    if Config and Config.InjuryTracking and Config.InjuryTracking[key] ~= nil then
        return Config.InjuryTracking[key]
    end
    return default
end

-- Determine injury cause from damage source
local function GetInjuryCause(culprit, weaponHash)
    -- Vehicle hit
    if culprit and DoesEntityExist(culprit) then
        if IsEntityAVehicle(culprit) then
            return 'vehicle_hit'
        end
        -- Ped attacking (but player survived)
        if IsEntityAPed(culprit) then
            -- Check weapon type
            if weaponHash and weaponHash ~= 0 then
                local weaponGroup = GetWeapontypeGroup(weaponHash)
                -- Melee weapons
                if weaponGroup == 2685387236 or weaponGroup == 416676503 then
                    return 'melee'
                end
                -- Pistols, SMGs, Rifles
                if weaponGroup == 416676503 or weaponGroup == -957766203 or weaponGroup == 860033945 then
                    return 'gunshot'
                end
            end
            return 'assault'
        end
    end
    
    -- Check weapon hash for explosion
    if weaponHash then
        -- Explosion types
        if weaponHash == -1568386805 or weaponHash == 1305664598 or weaponHash == -1312131151 then
            return 'explosion'
        end
    end
    
    return 'unknown'
end

-- Get injury title and description
local function GetInjuryTexts(cause, location)
    local titles = {
        vehicle_hit = 'Hit by Vehicle',
        gunshot = 'Gunshot Wound',
        melee = 'Beaten Down',
        explosion = 'Explosion Injury',
        assault = 'Assaulted',
        fall = 'Hard Fall',
        unknown = 'Injured'
    }
    
    local descriptions = {
        vehicle_hit = 'Struck by a vehicle near {location}.',
        gunshot = 'Took a bullet near {location}.',
        melee = 'Beaten in a fight near {location}.',
        explosion = 'Caught in an explosion near {location}.',
        assault = 'Assaulted near {location}.',
        fall = 'Took a hard fall near {location}.',
        unknown = 'Sustained injuries near {location}.'
    }
    
    local title = titles[cause] or titles.unknown
    local desc = (descriptions[cause] or descriptions.unknown):gsub('{location}', location)
    
    return title, desc
end

-- Record a non-fatal injury
local function RecordInjury(cause, culprit, weaponHash, coords)
    if not GetInjuryConfig('enabled', true) then return end
    
    local ped = PlayerPedId()
    local location = GetLocationName(coords)
    local title, description = GetInjuryTexts(cause, location)
    
    -- Check cooldown for this injury type
    local now = GetGameTimer()
    local cooldown = GetInjuryConfig('cooldown', 300) * 1000
    local lastInjuryOfType = injuryCooldowns[cause] or 0
    
    if (now - lastInjuryOfType) < cooldown then
        DebugLog(('Injury tracking: %s on cooldown'):format(cause))
        return
    end
    
    -- Set cooldown
    injuryCooldowns[cause] = now
    
    -- Send to server
    TriggerServerEvent('lifeprint:tracking:injury', {
        cause = cause,
        title = title,
        description = description,
        location = location,
        coords = coords,
        weaponHash = weaponHash
    })
    
    DebugLog(('Injury recorded: %s at %s'):format(title, location))
end

-- Injury detection using game event (same as death but checks survival)
AddEventHandler('gameEventTriggered', function(event, data)
    if not GetInjuryConfig('enabled', true) then return end
    
    if event == 'CEventNetworkEntityDamage' then
        local victim = data[1]  -- Entity that was damaged
        local culprit = data[2]  -- Entity that caused damage
        local isDeadFlag = data[4]  -- Boolean if killed
        local weaponHash = data[5] or 0
        
        local ped = PlayerPedId()
        
        -- Only process if this is the local player
        if victim ~= ped then return end
        
        -- Don't record if player died (death tracking handles that)
        if IsEntityDead(ped) then return end
        
        -- Check health loss threshold
        local currentHealth = GetEntityHealth(ped)
        local healthLoss = lastHealthValue - currentHealth
        local minHealthLoss = GetInjuryConfig('minHealthLoss', 25)
        
        if healthLoss < minHealthLoss then
            -- Not significant enough
            lastHealthValue = currentHealth
            return
        end
        
        -- Player was hurt but survived - record injury
        local cause = GetInjuryCause(culprit, weaponHash)
        
        -- Check if this cause type is tracked
        local trackTypes = {
            vehicle_hit = GetInjuryConfig('trackVehicleHits', true),
            gunshot = GetInjuryConfig('trackGunshots', true),
            melee = GetInjuryConfig('trackMelee', true),
            explosion = GetInjuryConfig('trackExplosions', true),
            fall = GetInjuryConfig('trackFalls', true),
            assault = GetInjuryConfig('trackAssaults', true),
            unknown = false
        }
        
        if trackTypes[cause] then
            local coords = GetEntityCoords(ped)
            RecordInjury(cause, culprit, weaponHash, coords)
        end
        
        lastHealthValue = currentHealth
    end
end)

-- Update health tracking on respawn/revive
CreateThread(function()
    while true do
        Wait(2000)
        
        local ped = PlayerPedId()
        local health = GetEntityHealth(ped)
        
        -- Update last health if alive
        if not IsEntityDead(ped) then
            if health > lastHealthValue then
                -- Health increased (heal/respawn)
                lastHealthValue = health
            end
        end
    end
end)

-- ============================================================================
-- Resource Cleanup
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if isOpen then
            SetNuiFocus(false, false)
        end
    end
end)

-- ============================================================================
-- Face Memory System
-- Players can remember other players' faces and get reminders when nearby
-- ============================================================================

local faceMemoryCache = {}  -- Cache of remembered faces { targetIdentifier = { name, note, location, timestamp } }
local reminderCooldowns = {}  -- Cooldowns for walk-by reminders { targetIdentifier = lastReminderTime }
local faceMemoryLoaded = false

-- Load face memories from server (called on resource start or when updated)
RegisterNetEvent('lifeprint:client:loadFaceMemories', function(memories)
    faceMemoryCache = {}
    for _, mem in ipairs(memories or {}) do
        if mem.target_identifier then
            faceMemoryCache[mem.target_identifier] = {
                name = mem.target_name or 'Unknown',
                note = mem.notes or '',
                location = mem.first_location or '',
                timestamp = mem.first_met or GetClientTime(),
                relationshipId = mem.id
            }
        end
    end
    faceMemoryLoaded = true
    DebugLog(('Loaded %d face memories'):format(#memories or 0))
end)

-- Request face memories on resource start
CreateThread(function()
    Wait(2000)  -- Wait for player to load
    TriggerServerEvent('lifeprint:server:getFaceMemories')
end)

-- /lpremember [serverId] [note] command
RegisterCommand('lpremember', function(source, args, raw)
    if not GetFaceMemoryConfig('enabled', true) then
        TriggerEvent('chat:addMessage', { color = { 239, 68, 68 }, args = { 'Lifeprint', 'Face memory feature is disabled.' } })
        return
    end
    
    local targetServerId = tonumber(args[1])
    local note = table.concat(args, ' ', 2) or ''
    
    if not targetServerId or targetServerId <= 0 then
        TriggerEvent('chat:addMessage', { color = { 251, 191, 36 }, args = { 'Lifeprint', 'Usage: /lpremember [serverId] [note]' } })
        return
    end
    
    -- Validate target is nearby
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local targetPlayer = GetPlayerFromServerId(targetServerId)
    
    if not targetPlayer or targetPlayer == -1 then
        TriggerEvent('chat:addMessage', { color = { 239, 68, 68 }, args = { 'Lifeprint', 'Player not found.' } })
        return
    end
    
    local targetPed = GetPlayerPed(targetPlayer)
    if not targetPed or targetPed == 0 then
        TriggerEvent('chat:addMessage', { color = { 239, 68, 68 }, args = { 'Lifeprint', 'Player not nearby.' } })
        return
    end
    
    local targetCoords = GetEntityCoords(targetPed)
    local distance = #(myCoords - targetCoords)
    local maxDistance = GetFaceMemoryConfig('maxDistance', 5.0)
    
    if distance > maxDistance then
        TriggerEvent('chat:addMessage', { color = { 239, 68, 68 }, args = { 'Lifeprint', ('Player is too far away (%.1fm). Max: %.1fm'):format(distance, maxDistance) } })
        return
    end
    
    -- Get location name
    local location = GetLocationName()
    
    -- Capture target headshot (async - runs in thread to not block)
    local headshotTxd = nil
    if GetFaceMemoryConfig('usePedHeadshot', true) then
        CreateThread(function()
            headshotTxd = CaptureTargetHeadshot(targetPed)
            
            -- Send to server (server validates everything)
            TriggerServerEvent('lifeprint:server:rememberFace', {
                targetServerId = targetServerId,
                note = note,
                location = location,
                headshotTxd = headshotTxd
            })
            
            DebugLog(('Face memory request sent for player %d with headshot: %s'):format(targetServerId, tostring(headshotTxd)))
        end)
    else
        -- Send without headshot
        TriggerServerEvent('lifeprint:server:rememberFace', {
            targetServerId = targetServerId,
            note = note,
            location = location,
            headshotTxd = nil
        })
        
        DebugLog(('Face memory request sent for player %d'):format(targetServerId))
    end
end, false)

-- /lpcamera [serverId] command - Capture a headshot photo of a nearby player
RegisterCommand('lpcamera', function(source, args, raw)
    if not GetFaceMemoryConfig('enabled', true) then
        TriggerEvent('chat:addMessage', { color = { 239, 68, 68 }, args = { 'Lifeprint', 'Face memory feature is disabled.' } })
        return
    end
    
    local targetServerId = tonumber(args[1])
    
    if not targetServerId or targetServerId <= 0 then
        TriggerEvent('chat:addMessage', { color = { 251, 191, 36 }, args = { 'Lifeprint', 'Usage: /lpcamera [serverId]' } })
        return
    end
    
    -- Validate target is nearby
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local targetPlayer = GetPlayerFromServerId(targetServerId)
    
    if not targetPlayer or targetPlayer == -1 then
        TriggerEvent('chat:addMessage', { color = { 239, 68, 68 }, args = { 'Lifeprint', 'Player not found.' } })
        return
    end
    
    if targetServerId == GetPlayerServerId(PlayerId()) then
        TriggerEvent('chat:addMessage', { color = { 239, 68, 68 }, args = { 'Lifeprint', 'You cannot take a photo of yourself.' } })
        return
    end
    
    local targetPed = GetPlayerPed(targetPlayer)
    if not targetPed or targetPed == 0 then
        TriggerEvent('chat:addMessage', { color = { 239, 68, 68 }, args = { 'Lifeprint', 'Player not nearby.' } })
        return
    end
    
    local targetCoords = GetEntityCoords(targetPed)
    local distance = #(myCoords - targetCoords)
    local maxDistance = GetFaceMemoryConfig('maxDistance', 5.0)
    
    if distance > maxDistance then
        TriggerEvent('chat:addMessage', { color = { 239, 68, 68 }, args = { 'Lifeprint', ('Player is too far away (%.1fm). Max: %.1fm'):format(distance, maxDistance) } })
        return
    end
    
    -- Capture headshot in a thread
    CreateThread(function()
        local headshotTxd = CaptureTargetHeadshot(targetPed)
        
        if headshotTxd then
            -- Send to server to update existing relationship
            TriggerServerEvent('lifeprint:server:updateFacePhoto', {
                targetServerId = targetServerId,
                headshotTxd = headshotTxd
            })
            
            TriggerEvent('chat:addMessage', { color = { 52, 211, 153 }, args = { 'Lifeprint', 'Photo captured successfully!' } })
            DebugLog(('Photo captured for player %d: %s'):format(targetServerId, headshotTxd))
        else
            if GetFaceMemoryConfig('fallbackToInitials', true) then
                TriggerEvent('chat:addMessage', { color = { 251, 191, 36 }, args = { 'Lifeprint', 'Photo capture failed. Initials will be used instead.' } })
            else
                TriggerEvent('chat:addMessage', { color = { 239, 68, 68 }, args = { 'Lifeprint', 'Photo capture failed. Try again.' } })
            end
            DebugLog('Photo capture failed for player ' .. targetServerId)
        end
    end)
end, false)

-- /lpforgetface [serverId] command (admin only)
RegisterCommand('lpforgetface', function(source, args, raw)
    local targetServerId = tonumber(args[1])
    
    if not targetServerId or targetServerId <= 0 then
        TriggerEvent('chat:addMessage', { color = { 251, 191, 36 }, args = { 'Lifeprint', 'Usage: /lpforgetface [serverId]' } })
        return
    end
    
    TriggerServerEvent('lifeprint:server:forgetFace', targetServerId)
    DebugLog(('Forget face request sent for player %d'):format(targetServerId))
end, false)

-- /lpfacephoto [serverId] [imageUrl] - Set a photo for a remembered face
RegisterCommand('lpfacephoto', function(source, args, raw)
    local facePhotoConfig = Config and Config.FacePhoto or {}
    
    if not facePhotoConfig.enabled then
        TriggerEvent('chat:addMessage', { color = { 239, 68, 68 }, args = { 'Lifeprint', 'Face photo feature is disabled.' } })
        return
    end
    
    local targetServerId = tonumber(args[1])
    local photoUrl = args[2]
    
    if not targetServerId or targetServerId <= 0 then
        TriggerEvent('chat:addMessage', { color = { 251, 191, 36 }, args = { 'Lifeprint', 'Usage: /lpfacephoto [serverId] [imageUrl]' } })
        return
    end
    
    if not photoUrl or photoUrl == '' then
        TriggerEvent('chat:addMessage', { color = { 251, 191, 36 }, args = { 'Lifeprint', 'Usage: /lpfacephoto [serverId] [imageUrl]' } })
        return
    end
    
    -- Validate target is nearby
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local targetPlayer = GetPlayerFromServerId(targetServerId)
    
    if not targetPlayer or targetPlayer == -1 then
        TriggerEvent('chat:addMessage', { color = { 239, 68, 68 }, args = { 'Lifeprint', 'Player not found.' } })
        return
    end
    
    local targetPed = GetPlayerPed(targetPlayer)
    if not targetPed or targetPed == 0 then
        TriggerEvent('chat:addMessage', { color = { 239, 68, 68 }, args = { 'Lifeprint', 'Player ped not found.' } })
        return
    end
    
    local targetCoords = GetEntityCoords(targetPed)
    local distance = #(myCoords - targetCoords)
    local maxDistance = facePhotoConfig.maxDistance or 5.0
    
    if distance > maxDistance then
        TriggerEvent('chat:addMessage', { color = { 239, 68, 68 }, args = { 'Lifeprint', ('Player is too far away (%.1fm). Max: %.1fm'):format(distance, maxDistance) } })
        return
    end
    
    -- Send to server for validation and saving
    TriggerServerEvent('lifeprint:server:setFacePhoto', targetServerId, photoUrl)
    DebugLog(('Face photo request sent for player %d'):format(targetServerId))
end, false)

-- Walk-by reminder system (interval-based, performance friendly)
CreateThread(function()
    if not GetFaceMemoryConfig('enabled', true) then return end
    
    local reminderDistance = GetFaceMemoryConfig('reminderDistance', 8.0)
    local checkInterval = GetPerfConfig('faceMemoryCheckInterval', 3000)
    local cooldown = GetFaceMemoryConfig('reminderCooldown', 900)
    
    DebugLog(('Face memory reminder system: %.1fm, cooldown %ds'):format(reminderDistance, cooldown))
    
    while true do
        Wait(checkInterval)
        
        -- Skip if UI is open or memories not loaded
        if isOpen or not faceMemoryLoaded then goto continue end
        if not next(faceMemoryCache) then goto continue end  -- No face memories
        
        local myPed = PlayerPedId()
        local myCoords = GetEntityCoords(myPed)
        local activePlayers = GetActivePlayers()
        
        -- Check each nearby player (limit to 20 for performance)
        local count = 0
        for _, player in ipairs(activePlayers) do
            count = count + 1
            if count > 20 then break end
            
            local playerPed = GetPlayerPed(player)
            if playerPed and playerPed ~= myPed then
                local playerCoords = GetEntityCoords(playerPed)
                local distance = #(myCoords - playerCoords)
                
                if distance <= reminderDistance then
                    local serverId = GetPlayerServerId(player)
                    if serverId and serverId > 0 then
                        -- Get target identifier from server (we need to check cache)
                        -- We'll request identifier from server and check in callback
                        TriggerServerEvent('lifeprint:server:checkFaceMemoryProximity', serverId, distance)
                    end
                end
            end
        end
        
        ::continue::
    end
end)

-- Receive proximity check result from server
RegisterNetEvent('lifeprint:client:faceMemoryReminder', function(targetIdentifier, targetName, note, distance)
    if not targetIdentifier then return end
    
    local currentTime = GetClientTime()
    local cooldown = GetFaceMemoryConfig('reminderCooldown', 900)
    
    -- Check cooldown
    if reminderCooldowns[targetIdentifier] then
        local timeSinceLastReminder = currentTime - reminderCooldowns[targetIdentifier]
        if timeSinceLastReminder < cooldown then
            return  -- Still on cooldown
        end
    end
    
    -- Show notification
    local message = ('You recognize %s. %s'):format(targetName, note ~= '' and note or 'You remember their face.')
    
    -- Use Bridge notification if available, otherwise native
    if Bridge and Bridge.Notify then
        Bridge.Notify(nil, message, 'info')
    else
        -- Native notification
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(message)
        EndTextCommandThefeedPostTicker(false, true)
    end
    
    -- Set cooldown
    reminderCooldowns[targetIdentifier] = currentTime
    
    DebugLog(('Face memory reminder: %s'):format(targetName))
end)

-- Clear face memory cache when forgotten
RegisterNetEvent('lifeprint:client:removeFaceMemory', function(targetIdentifier)
    if targetIdentifier and faceMemoryCache[targetIdentifier] then
        faceMemoryCache[targetIdentifier] = nil
        reminderCooldowns[targetIdentifier] = nil
        DebugLog('Face memory removed from cache')
    end
end)

-- ============================================================================
-- Memory Brought Up Popup System
-- Cinematic notification when near someone with shared history
-- ============================================================================

local memoryPopupCooldowns = {}  -- Cooldowns for memory popups { serverId = lastCheckTime }

-- Get MemoryPulse config safely (supports both new and legacy names)
local function GetMemoryPulseConfig(key, default)
    local pulseConfig = (Config and Config.MemoryPulse) or (Config and Config.MemoryPopup) or nil
    if pulseConfig and pulseConfig[key] ~= nil then
        return pulseConfig[key]
    end
    return default
end

-- Memory Pulse proximity check (interval-based, performance friendly)
CreateThread(function()
    if not GetMemoryPulseConfig('enabled', true) then return end
    
    local checkDistance = GetMemoryPulseConfig('distance', 8.0)
    local checkInterval = GetPerfConfig('faceMemoryCheckInterval', 3000)
    local cooldown = GetMemoryPulseConfig('cooldown', 900)
    
    DebugLog(('Memory popup system: %.1fm, cooldown %ds'):format(checkDistance, cooldown))
    
    while true do
        Wait(checkInterval)
        
        -- Skip if UI is open
        if isOpen then goto continue end
        
        local myPed = PlayerPedId()
        local myCoords = GetEntityCoords(myPed)
        local activePlayers = GetActivePlayers()
        local currentTime = GetClientTime()
        
        -- Check each nearby player (limit to 20 for performance)
        local count = 0
        for _, player in ipairs(activePlayers) do
            count = count + 1
            if count > 20 then break end
            
            local playerPed = GetPlayerPed(player)
            if playerPed and playerPed ~= myPed then
                local playerCoords = GetEntityCoords(playerPed)
                local distance = #(myCoords - playerCoords)
                
                if distance <= checkDistance then
                    local serverId = GetPlayerServerId(player)
                    if serverId and serverId > 0 then
                        -- Check local cooldown before sending to server
                        if memoryPopupCooldowns[serverId] then
                            local timeSinceLastPopup = currentTime - memoryPopupCooldowns[serverId]
                            if timeSinceLastPopup < cooldown then
                                goto nextPlayer  -- Still on cooldown
                            end
                        end
                        
                        -- Request popup data from server (server validates everything)
                        TriggerServerEvent('lifeprint:server:getMemoryPopup', serverId)
                        
                        -- Set local cooldown to prevent rapid requests
                        memoryPopupCooldowns[serverId] = currentTime
                    end
                end
                
                ::nextPlayer::
            end
        end
        
        -- Cleanup old cooldowns (keep memory manageable)
        for serverId, lastTime in pairs(memoryPopupCooldowns) do
            if (currentTime - lastTime) > (cooldown * 2) then
                memoryPopupCooldowns[serverId] = nil
            end
        end
        
        ::continue::
    end
end)

-- Receive memory popup data from server
RegisterNetEvent('lifeprint:client:showMemoryPopup', function(popupData)
    if not popupData then return end
    
    DebugLog(('Memory popup received: %s'):format(popupData.targetName or 'Unknown'))
    
    -- Send to NUI
    SendNUIMessage({
        action = 'showMemoryPopup',
        data = popupData
    })
end)

-- ============================================================================
-- Memory Pulse System (Immersive Notification Feedback)
-- Cinematic screen-edge pulse and scaling notification intensity
-- ============================================================================

-- Get MemoryPulse config safely
local function GetMemoryPulseConfig(key, default)
    if Config and Config.MemoryPulse and Config.MemoryPulse[key] ~= nil then
        return Config.MemoryPulse[key]
    end
    return default
end

-- Determine memory importance based on data
local function GetMemoryImportance(data)
    local strength = data and data.strength or 1
    local eventType = data and data.eventType or 'encounter'
    
    -- Check thresholds
    local thresholds = GetMemoryPulseConfig('thresholds', {})
    
    -- Life-changing events
    if strength >= 9 then
        return 'lifechanging'
    -- Major events
    elseif strength >= 6 then
        return 'major'
    -- Notable events
    elseif strength >= 3 then
        return 'notable'
    end
    
    -- Default to minor
    return 'minor'
end

-- Play sound if enabled and file exists (safe fallback)
local function PlayMemoryPulseSound(importance)
    if not GetMemoryPulseConfig('sound', false) then return end
    
    -- Only play for major/lifechanging if majorOnlyPulse is true
    if GetMemoryPulseConfig('majorOnlyPulse', true) then
        if importance ~= 'major' and importance ~= 'lifechanging' then
            return
        end
    end
    
    -- Try to play sound (fails silently if file doesn't exist)
    local soundFile = 'memory_pulse.ogg'
    pcall(function()
        PlaySoundFrontend(-1, soundFile, 'LIFEPRINT_SOUNDS', true)
    end)
end

-- Handle memory notification from server with pulse effects
RegisterNetEvent('lifeprint:client:showMemoryNotification', function(data)
    if not data then return end
    
    local pulseEnabled = GetMemoryPulseConfig('enabled', true)
    if not pulseEnabled then return end
    
    -- Determine importance level
    local importance = GetMemoryImportance(data)
    
    -- Get intensity settings for this importance level
    local intensity = GetMemoryPulseConfig('intensity', {})
    local settings = intensity[importance] or intensity.minor or {}
    
    -- Check if majorOnlyPulse and not major/lifechanging
    local majorOnly = GetMemoryPulseConfig('majorOnlyPulse', true)
    local showPulse = settings.pulse and (not majorOnly or importance == 'major' or importance == 'lifechanging')
    
    -- Send notification to NUI
    SendNUIMessage({
        action = 'showMemoryNotification',
        data = {
            type = data.type or 'memory',
            title = settings.specialText or data.title or 'Memory Surfaced',
            message = data.message or '',
            duration = data.duration or GetMemoryPulseConfig('duration', 5000),
            importance = importance,
            showGlow = settings.glow or false,
            showPulse = showPulse or false,
            colors = GetMemoryPulseConfig('colors', {})[data.type or 'memory']
        }
    })
    
    -- Play sound if enabled
    PlayMemoryPulseSound(importance)
    
    DebugLog(('Memory notification: [%s] %s'):format(importance, data.message or ''))
end)

-- Handle standard notifications (backward compatible)
RegisterNetEvent('lifeprint:client:notify', function(data)
    if type(data) == 'string' then
        -- Legacy format: just a string message
        data = { message = data, type = 'info' }
    end
    
    if not data or not data.message then return end
    
    -- Send to NUI toast system
    SendNUIMessage({
        action = 'notify',
        data = {
            type = data.type or 'info',
            title = data.title or 'Lifeprint',
            message = data.message,
            duration = data.duration or 4000
        }
    })
end)

-- ============================================================================
-- Reputation Change Notifications
-- Triggered when player gains new reputation tag
-- ============================================================================

RegisterNetEvent('lifeprint:client:reputationNotification', function(data)
    if not data or not data.tag then return end
    
    -- Map tag style to notification type
    local notifyType = 'info'
    if data.style == 'danger' then
        notifyType = 'error'
    elseif data.style == 'warning' then
        notifyType = 'warning'
    elseif data.style == 'success' then
        notifyType = 'success'
    end
    
    -- Send to NUI toast system with special formatting
    SendNUIMessage({
        action = 'reputationNotification',
        data = {
            tag = data.tag,
            style = data.style or 'info',
            message = data.message or ('Reputation changed: ' .. data.tag),
            priority = data.priority or 1,
            type = notifyType,
            title = 'Lifeprint',
            duration = 5000
        }
    })
    
    DebugLog(('Reputation notification received: %s'):format(data.tag))
end)

-- Live update Reputation tab while UI is open
RegisterNetEvent('lifeprint:client:updateReputation', function(data)
    if not data then return end
    
    -- Send live update to NUI (only processed if UI is open)
    SendNUIMessage({
        action = 'updateReputationLive',
        data = {
            tags = data.tags or {},
            counters = data.counters or {},
            characterRead = data.characterRead or ''
        }
    })
    
    DebugLog('Reputation tab updated live')
end)

-- ============================================================================
-- Journal Update Notifications
-- Notify player when Lifeprint is updated
-- ============================================================================

RegisterNetEvent('lifeprint:client:journalNotification', function(data)
    if not data then return end
    
    -- Send to NUI toast system
    SendNUIMessage({
        action = 'journalNotification',
        data = {
            type = data.type or 'info',
            message = data.message or 'Your Lifeprint has been updated.',
            flavor = data.flavor or nil,  -- Immersive RP flavor text
            data = data.data or nil,
            duration = data.duration or 4000
        }
    })
    
    DebugLog(('Journal notification received: %s'):format(data.type))
end)

-- Refresh current tab when data changes (only if UI is open)
RegisterNetEvent('lifeprint:client:refreshCurrentTab', function(data)
    if not data then return end
    
    -- Send refresh signal to NUI
    SendNUIMessage({
        action = 'refreshTab',
        data = {
            tab = data.affectedTab or nil
        }
    })
    
    DebugLog(('Tab refresh requested: %s'):format(data.affectedTab or 'unknown'))
end)

-- Badge notification (new badge unlocked)
RegisterNetEvent('lifeprint:client:badgeNotification', function(data)
    if not data then return end
    
    -- Send to NUI toast system
    SendNUIMessage({
        action = 'badgeNotification',
        data = {
            badge = data.badge,
            message = data.message or 'New badge unlocked!',
            duration = 5000
        }
    })
    
    DebugLog(('Badge notification received: %s'):format(data.badge and data.badge.label or 'unknown'))
end)

-- Update badges live (when UI is open)
RegisterNetEvent('lifeprint:client:updateBadges', function(data)
    if not data then return end
    
    SendNUIMessage({
        action = 'updateBadges',
        data = {
            badges = data.badges or {}
        }
    })
    
    DebugLog('Badges updated live')
end)

-- Nickname notification (city nickname changed)
RegisterNetEvent('lifeprint:client:nicknameNotification', function(data)
    if not data then return end
    
    -- Send to NUI toast system
    SendNUIMessage({
        action = 'nicknameNotification',
        data = {
            nickname = data.nickname,
            style = data.style,
            message = data.message or 'The city has a new name for you.',
            duration = 5000
        }
    })
    
    DebugLog(('Nickname notification received: %s'):format(data.nickname or 'unknown'))
end)

-- Update nickname live (when UI is open)
RegisterNetEvent('lifeprint:client:updateNickname', function(data)
    if not data then return end
    
    SendNUIMessage({
        action = 'updateNickname',
        data = {
            nickname = data.nickname
        }
    })
    
    DebugLog('Nickname updated live')
end)

-- ============================================================================
-- Memory Brain System
-- Visual brain that changes color based on player's story
-- ============================================================================

-- Update Memory Brain data (called when UI opens or data changes)
RegisterNetEvent('lifeprint:client:updateMemoryBrain', function(brainData)
    if not brainData then return end
    
    SendNUIMessage({
        action = 'updateMemoryBrain',
        data = brainData
    })
    
    DebugLog('Memory Brain updated: ' .. tostring(brainData.dominant))
end)

-- Memory Brain notification (when a major memory is added)
RegisterNetEvent('lifeprint:client:memoryBrainNotification', function(category)
    if not category then return end
    
    local templates = Config and Config.MemoryBrain and Config.MemoryBrain.notificationTemplates or {
        "Memory Brain updated: {category} memory added."
    }
    
    local template = templates[math.random(1, #templates)]
    local message = template:gsub('{category}', category)
    
    SendNUIMessage({
        action = 'showToast',
        data = {
            message = message,
            type = 'memory'
        }
    })
    
    DebugLog('Memory Brain notification: ' .. category)
end)

-- ============================================================================
-- Recent Faces System
-- Temporary proximity tracking for saving face memories later
-- ============================================================================

local recentFaces = {}  -- { serverId = { name, lastSeen, location, timestamp } }
local recentFacesNearbyTime = {}  -- { serverId = startTime }
local recentFacesVisible = false

-- Get RecentFaces config safely
local function GetRecentFacesConfig(key, default)
    if Config and Config.RecentFaces and Config.RecentFaces[key] ~= nil then
        return Config.RecentFaces[key]
    end
    return default
end

-- Clean up expired entries
local function CleanupRecentFaces()
    local currentTime = GetClientTime()
    local expireSeconds = (GetRecentFacesConfig('expireMinutes', 10) * 60)
    local maxEntries = GetRecentFacesConfig('maxEntries', 10)
    
    -- Remove expired entries
    for serverId, data in pairs(recentFaces) do
        if (currentTime - data.timestamp) > expireSeconds then
            recentFaces[serverId] = nil
            DebugLog(('Removed expired recent face: %s'):format(serverId))
        end
    end
    
    -- If still over max entries, remove oldest
    local count = 0
    local entries = {}
    for serverId, data in pairs(recentFaces) do
        table.insert(entries, { serverId = serverId, timestamp = data.timestamp })
        count = count + 1
    end
    
    if count > maxEntries then
        -- Sort by timestamp (oldest first)
        table.sort(entries, function(a, b) return a.timestamp < b.timestamp end)
        
        -- Remove oldest entries
        local toRemove = count - maxEntries
        for i = 1, toRemove do
            recentFaces[entries[i].serverId] = nil
            DebugLog(('Removed oldest recent face to make room: %s'):format(entries[i].serverId))
        end
    end
end

-- Add or update a recent face
local function AddRecentFace(serverId, name, location)
    if not serverId or serverId <= 0 then return end
    
    recentFaces[serverId] = {
        name = name or 'Unknown',
        location = location or 'Unknown',
        timestamp = GetClientTime(),
        serverId = serverId
    }
    
    DebugLog(('Added recent face: %s (ID: %d)'):format(name, serverId))
    
    -- Cleanup after adding
    CleanupRecentFaces()
end

-- Recent Faces proximity scanner (interval-based, performance friendly)
CreateThread(function()
    if not GetRecentFacesConfig('enabled', true) then return end
    
    local detectionDistance = GetRecentFacesConfig('detectionDistance', 10.0)
    local scanInterval = GetRecentFacesConfig('scanInterval', 5000)
    local minNearbyTime = GetRecentFacesConfig('minNearbyTime', 3000)
    
    DebugLog(('Recent faces scanner: %.1fm, interval %dms'):format(detectionDistance, scanInterval))
    
    while true do
        Wait(scanInterval)
        
        -- Skip if UI is open
        if isOpen then goto continue end
        
        local myPed = PlayerPedId()
        local myCoords = GetEntityCoords(myPed)
        local activePlayers = GetActivePlayers()
        local currentGameTime = GetGameTimer()
        
        -- Track who is currently nearby
        local currentlyNearby = {}
        
        -- Check each nearby player (limit to 20 for performance)
        local count = 0
        for _, player in ipairs(activePlayers) do
            count = count + 1
            if count > 20 then break end
            
            local playerPed = GetPlayerPed(player)
            if playerPed and playerPed ~= myPed then
                local playerCoords = GetEntityCoords(playerPed)
                local distance = #(myCoords - playerCoords)
                
                if distance <= detectionDistance then
                    local serverId = GetPlayerServerId(player)
                    if serverId and serverId > 0 then
                        currentlyNearby[serverId] = true
                        
                        -- Start tracking time if not already
                        if not recentFacesNearbyTime[serverId] then
                            recentFacesNearbyTime[serverId] = currentGameTime
                            DebugLog(('Started tracking nearby player: %d'):format(serverId))
                        end
                    end
                end
            end
        end
        
        -- Check for players who have been nearby long enough
        for serverId, startTime in pairs(recentFacesNearbyTime) do
            if currentlyNearby[serverId] then
                local timeNearby = currentGameTime - startTime
                if timeNearby >= minNearbyTime then
                    -- Request name from server (don't have it client-side in standalone)
                    TriggerServerEvent('lifeprint:server:getRecentFaceInfo', serverId, GetLocationName())
                    -- Remove from tracking (already added)
                    recentFacesNearbyTime[serverId] = nil
                end
            else
                -- Player left area, reset timer
                recentFacesNearbyTime[serverId] = nil
            end
        end
        
        -- Periodic cleanup
        CleanupRecentFaces()
        
        ::continue::
    end
end)

-- Receive recent face info from server
RegisterNetEvent('lifeprint:client:addRecentFace', function(serverId, name, location)
    if serverId and name then
        AddRecentFace(serverId, name, location)
    end
end)

-- /lpfaces command to open recent faces UI
RegisterCommand('lpfaces', function(source, args, raw)
    if not GetRecentFacesConfig('enabled', true) then
        TriggerEvent('chat:addMessage', { color = { 239, 68, 68 }, args = { 'Lifeprint', 'Recent faces feature is disabled.' } })
        return
    end
    
    DebugLog('Opening recent faces panel')
    
    -- Build list for NUI
    local facesList = {}
    local currentTime = GetClientTime()
    
    for serverId, data in pairs(recentFaces) do
        table.insert(facesList, {
            serverId = serverId,
            name = data.name,
            location = data.location,
            timestamp = data.timestamp,
            timeAgo = currentTime - data.timestamp
        })
    end
    
    -- Sort by most recent first
    table.sort(facesList, function(a, b) return a.timestamp > b.timestamp end)
    
    -- Set focus and send to NUI
    recentFacesVisible = true
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        action = 'openRecentFaces',
        data = { faces = facesList }
    })
    
    DebugLog(('Opened recent faces panel with %d entries'):format(#facesList))
end, false)

-- Close recent faces panel
RegisterNUICallback('closeRecentFaces', function(data, cb)
    cb({ success = true })
    recentFacesVisible = false
    SetNuiFocus(false, false)
    DebugLog('Recent faces panel closed')
end)

-- Remember a face from recent faces list
RegisterNUICallback('rememberRecentFace', function(data, cb)
    cb({ success = true })
    
    local serverId = data and tonumber(data.serverId)
    
    if not serverId or serverId <= 0 then
        SendNuiMessage('rememberFaceResult', { success = false, error = 'Invalid server ID' })
        return
    end
    
    -- Request server to remember this face (server validates target still exists)
    TriggerServerEvent('lifeprint:server:rememberRecentFace', serverId)
    DebugLog(('Remember face request sent for recent face: %d'):format(serverId))
end)

-- Receive remember face result from server
RegisterNetEvent('lifeprint:client:rememberFaceResult', function(success, message, serverId)
    if success then
        -- Remove from recent faces list (now permanent)
        if serverId and recentFaces[serverId] then
            recentFaces[serverId] = nil
            DebugLog(('Removed %d from recent faces (now permanent)'):format(serverId))
        end
    end
    
    -- Send result to NUI
    SendNUIMessage({
        action = 'rememberFaceResult',
        data = { success = success, message = message, serverId = serverId }
    })
end)

-- ============================================================================
-- NPC Witness System
-- NPCs act as city witnesses - detect suspicious/violent actions near NPCs
-- ============================================================================

local npcWitnessCooldowns = {}  -- Cooldowns per event type: { eventType = lastTriggerTime }
local stolenVehicles = {}       -- Track vehicles we've already flagged as stolen

-- Get NPC Witness config safely
local function GetNPCWitnessConfig(key, default)
    if Config and Config.NPCWitness and Config.NPCWitness[key] ~= nil then
        return Config.NPCWitness[key]
    end
    return default
end

-- Get NPC Violence config safely (for assault/kill/gunshot events)
local function GetNPCViolenceConfig(key, default)
    if Config and Config.NPCViolence and Config.NPCViolence[key] ~= nil then
        return Config.NPCViolence[key]
    end
    return default
end

-- Check if any NPCs are nearby
local function GetNearbyNPCCount(coords, radius)
    if not coords then return 0 end
    
    local count = 0
    local peds = GetGamePool('CPed')
    local myPed = PlayerPedId()
    
    for _, ped in ipairs(peds) do
        if ped ~= myPed and not IsPedAPlayer(ped) and DoesEntityExist(ped) then
            local pedCoords = GetEntityCoords(ped)
            local distance = #(coords - pedCoords)
            if distance <= radius then
                count = count + 1
            end
        end
    end
    
    return count
end

-- Get street name from coords
local function GetStreetNameFromCoords(coords)
    if not coords then return "Unknown Location" end
    
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetHash)
    
    if streetName and streetName ~= "" then
        return streetName
    end
    
    return "Unknown Location"
end

-- Check cooldown and trigger server event
local function TriggerNPCWitnessEvent(eventType, data)
    if not eventType then return false end
    
    local cooldown = GetNPCWitnessConfig('cooldown', 300)
    local now = GetGameTimer()
    
    -- Check cooldown (in milliseconds)
    local lastTrigger = npcWitnessCooldowns[eventType] or 0
    if (now - lastTrigger) < (cooldown * 1000) then
        DebugLog(('NPC Witness: %s on cooldown'):format(eventType))
        return false
    end
    
    -- Set cooldown
    npcWitnessCooldowns[eventType] = now
    
    -- Add coords and location if not provided
    if not data.coords then
        local ped = PlayerPedId()
        data.coords = GetEntityCoords(ped)
    end
    
    if not data.location then
        data.location = GetStreetNameFromCoords(data.coords)
    end
    
    -- Trigger server event
    TriggerServerEvent('lifeprint:npcWitness:report', {
        eventType = eventType,
        coords = data.coords,
        location = data.location,
        witnessCount = data.witnessCount or 1,
        metadata = data.metadata or {}
    })
    
    DebugLog(('NPC Witness: Reported %s at %s'):format(eventType, data.location))
    return true
end

-- Clean up cooldowns periodically
CreateThread(function()
    while true do
        Wait(60000)  -- Every minute
        
        local now = GetGameTimer()
        local cooldown = GetNPCWitnessConfig('cooldown', 300)
        
        for eventType, lastTime in pairs(npcWitnessCooldowns) do
            if (now - lastTime) > (cooldown * 1000 * 2) then
                npcWitnessCooldowns[eventType] = nil
            end
        end
    end
end)

-- ============================================================================
-- NPC Vehicle Theft Tracking
-- Detects when player drives a vehicle they don't own for 10s or 50m
-- ============================================================================

local function GetVehicleTheftConfig(key, default)
    if Config and Config.NPCVehicleTheft and Config.NPCVehicleTheft[key] ~= nil then
        return Config.NPCVehicleTheft[key]
    end
    return default
end

-- Check if vehicle class is ignored (emergency, service, etc.)
local function IsVehicleClassIgnored(vehicle)
    local ignoredClasses = GetVehicleTheftConfig('ignoredClasses', {})
    local vehicleClass = GetVehicleClass(vehicle)
    
    for _, classId in ipairs(ignoredClasses) do
        if classId == vehicleClass then
            return true
        end
    end
    return false
end

-- Check if vehicle model is ignored (police, ambulance, etc.)
local function IsVehicleModelIgnored(vehicle)
    local ignoredModels = GetVehicleTheftConfig('ignoredModels', {})
    local model = GetEntityModel(vehicle)
    local modelName = GetDisplayNameFromVehicleModel(model):lower()
    
    for _, ignoredName in ipairs(ignoredModels) do
        if modelName == ignoredName:lower() then
            return true
        end
    end
    return false
end

-- Track active vehicle theft monitoring
local theftMonitoring = {
    active = false,
    vehicle = nil,
    startTime = 0,
    startPos = nil,
    triggered = false
}

-- Vehicle Theft Detection Thread
CreateThread(function()
    if not GetVehicleTheftConfig('enabled', true) then return end
    
    local driveTimeRequired = GetVehicleTheftConfig('driveTimeRequired', 10)
    local distanceRequired = GetVehicleTheftConfig('distanceRequired', 50.0)
    local checkInterval = GetVehicleTheftConfig('checkInterval', 1000)
    local requireWitness = GetVehicleTheftConfig('requireWitness', true)
    local witnessDistance = GetVehicleTheftConfig('witnessDistance', 35.0)
    local minWitnessCount = GetVehicleTheftConfig('minWitnessCount', 1)
    
    DebugLog(('Vehicle Theft: Monitoring (time=%ds, distance=%.1fm)'):format(driveTimeRequired, distanceRequired))
    
    while true do
        Wait(checkInterval)
        
        if isOpen then goto theftContinue end
        
        local ped = PlayerPedId()
        local inVehicle = IsPedInAnyVehicle(ped, false)
        
        -- Player entered a vehicle as driver
        if inVehicle then
            local vehicle = GetVehiclePedIsIn(ped, false)
            local isDriver = GetPedInVehicleSeat(vehicle, -1) == ped
            
            if isDriver and vehicle and vehicle ~= 0 then
                -- Check if we should start monitoring this vehicle
                if not theftMonitoring.active or theftMonitoring.vehicle ~= vehicle then
                    -- Check if this vehicle should be ignored
                    if IsVehicleClassIgnored(vehicle) then
                        DebugLog('Vehicle Theft: Ignored vehicle class')
                        goto theftContinue
                    end
                    
                    if IsVehicleModelIgnored(vehicle) then
                        DebugLog('Vehicle Theft: Ignored vehicle model')
                        goto theftContinue
                    end
                    
                    -- Start monitoring
                    theftMonitoring = {
                        active = true,
                        vehicle = vehicle,
                        startTime = GetGameTimer(),
                        startPos = GetEntityCoords(ped),
                        triggered = false,
                        plate = GetVehicleNumberPlateText(vehicle),
                        model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
                    }
                    
                    DebugLog(('Vehicle Theft: Started monitoring %s (Plate: %s)'):format(
                        theftMonitoring.model, theftMonitoring.plate or 'N/A'))
                end
                
                -- Check if conditions are met (but not already triggered)
                if theftMonitoring.active and not theftMonitoring.triggered then
                    local currentPos = GetEntityCoords(ped)
                    local timeElapsed = (GetGameTimer() - theftMonitoring.startTime) / 1000
                    local distanceTraveled = #(currentPos - theftMonitoring.startPos)
                    
                    -- Trigger if either condition is met
                    if timeElapsed >= driveTimeRequired or distanceTraveled >= distanceRequired then
                        theftMonitoring.triggered = true
                        
                        -- Check for witnesses
                        local npcCount = GetNearbyNPCCount(currentPos, witnessDistance)
                        
                        if not requireWitness or npcCount >= minWitnessCount then
                            -- Send to server for ownership validation and memory creation
                            TriggerServerEvent('lifeprint:vehicleTheft:checkOwnership', {
                                plate = theftMonitoring.plate,
                                model = theftMonitoring.model,
                                coords = currentPos,
                                location = GetLocationName(),
                                witnessCount = npcCount,
                                timeDriven = math.floor(timeElapsed),
                                distanceDriven = math.floor(distanceTraveled)
                            })
                            
                            DebugLog(('Vehicle Theft: Triggered after %ds/%.1fm'):format(
                                math.floor(timeElapsed), distanceTraveled))
                        else
                            DebugLog(('Vehicle Theft: No witnesses nearby (%d < %d)'):format(
                                npcCount, minWitnessCount))
                        end
                    end
                end
            end
        else
            -- Player left vehicle, reset monitoring
            if theftMonitoring.active then
                DebugLog('Vehicle Theft: Player left vehicle, resetting')
            end
            theftMonitoring = {
                active = false,
                vehicle = nil,
                startTime = 0,
                startPos = nil,
                triggered = false
            }
        end
        
        ::theftContinue::
    end
end)

-- Gunshot Detection
-- Detects when player fires a weapon near NPCs
CreateThread(function()
    if not GetNPCViolenceConfig('enabled', true) then return end
    if not GetNPCViolenceConfig('trackGunshots', true) then return end
    
    local witnessDistance = GetNPCViolenceConfig('witnessDistance', 35.0)
    local checkInterval = GetNPCViolenceConfig('checkInterval', 1000)
    
    DebugLog('NPC Violence: Gunshot tracking started')
    
    -- Track weapon firing using game event
    local lastShotTime = 0
    
    while true do
        Wait(100)  -- Check frequently for shots
        
        if isOpen then goto gunshotContinue end
        
        local ped = PlayerPedId()
        
        -- Check if player is shooting
        if IsPedShooting(ped) then
            local now = GetGameTimer()
            
            -- Small delay between shots (500ms) to prevent spam
            if (now - lastShotTime) > 500 then
                lastShotTime = now
                
                local coords = GetEntityCoords(ped)
                local npcCount = GetNearbyNPCCount(coords, witnessDistance)
                
                -- Only trigger if NPCs are nearby to witness
                if npcCount >= 1 then
                    -- Get weapon info
                    local weapon = GetSelectedPedWeapon(ped)
                    
                    TriggerNPCWitnessEvent('gunshots', {
                        coords = coords,
                        witnessCount = npcCount,
                        metadata = {
                            weaponHash = weapon,
                            suppressed = false
                        }
                    })
                end
            end
        end
        
        ::gunshotContinue::
    end
end)

-- Reckless Driving Detection
-- Detects when player drives recklessly near NPCs
CreateThread(function()
    if not GetNPCWitnessConfig('enabled', true) then return end
    if not GetNPCWitnessConfig('trackRecklessDriving', true) then return end
    
    local witnessDistance = GetNPCWitnessConfig('witnessDistance', 35.0)
    local checkInterval = 3000  -- Check every 3 seconds
    local requireNPC = GetNPCWitnessConfig('requireNPCNearby', true)
    local minWitnessCount = GetNPCWitnessConfig('minWitnessCount', 1)
    local speedThreshold = 50.0  -- m/s (about 180 km/h)
    
    DebugLog('NPC Witness: Reckless driving tracking started')
    
    local recklessWarnings = 0
    
    while true do
        Wait(checkInterval)
        
        if isOpen then goto drivingContinue end
        
        local ped = PlayerPedId()
        
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            
            if vehicle and vehicle ~= 0 then
                -- Check if player is driving
                if GetPedInVehicleSeat(vehicle, -1) == ped then
                    local coords = GetEntityCoords(ped)
                    local velocity = GetEntityVelocity(vehicle)
                    local speed = #velocity  -- Magnitude of velocity vector
                    
                    -- Check for reckless behavior
                    local isReckless = false
                    
                    -- High speed
                    if speed > speedThreshold then
                        isReckless = true
                    end
                    
                    -- Hitting other vehicles or peds
                    if HasEntityCollidedWithAnything(vehicle) then
                        recklessWarnings = recklessWarnings + 1
                        if recklessWarnings >= 3 then
                            isReckless = true
                            recklessWarnings = 0
                        end
                    end
                    
                    -- Driving on wrong side or sidewalks (simplified check)
                    local isOnRoad = IsPointOnRoad(coords.x, coords.y, coords.z)
                    if not isOnRoad and speed > 20.0 then
                        recklessWarnings = recklessWarnings + 1
                    end
                    
                    if isReckless then
                        local npcCount = GetNearbyNPCCount(coords, witnessDistance)
                        
                        if (not requireNPC or npcCount >= minWitnessCount) then
                            TriggerNPCWitnessEvent('reckless_driving', {
                                coords = coords,
                                witnessCount = npcCount,
                                metadata = {
                                    speed = speed,
                                    onRoad = isOnRoad
                                }
                            })
                        end
                    end
                end
            end
        else
            recklessWarnings = 0
        end
        
        ::drivingContinue::
    end
end)

-- NPC Assault/Kill Detection
-- Detects when player harms or kills NPC civilians
CreateThread(function()
    if not GetNPCViolenceConfig('enabled', true) then return end
    if not GetNPCViolenceConfig('trackAssault', true) and not GetNPCViolenceConfig('trackKills', true) then return end
    
    local witnessDistance = GetNPCViolenceConfig('witnessDistance', 35.0)
    local checkInterval = GetNPCViolenceConfig('checkInterval', 1000)
    local minAssaultDamage = GetNPCViolenceConfig('minAssaultDamage', 10)
    local trackedPeds = {}  -- Track which peds we've already reported
    
    DebugLog('NPC Violence: Assault/Kill tracking started')
    
    while true do
        Wait(500)
        
        if isOpen then goto assaultContinue end
        
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        
        -- Check nearby peds for damage we caused
        local nearbyPeds = GetGamePool('CPed')
        for _, nearbyPed in ipairs(nearbyPeds) do
            if nearbyPed ~= ped and not IsPedAPlayer(nearbyPed) and DoesEntityExist(nearbyPed) then
                local pedKey = tostring(nearbyPed)
                
                if not trackedPeds[pedKey] then
                    -- Check if we damaged this NPC
                    local health = GetEntityHealth(nearbyPed)
                    local maxHealth = GetEntityMaxHealth(nearbyPed)
                    
                    -- Check if this ped was damaged by player
                    if health < maxHealth then
                        local lastDamagedBy = GetPedCauseOfDeath(nearbyPed)
                        
                        if lastDamagedBy == ped then
                            trackedPeds[pedKey] = true
                            
                            -- Determine if assault or kill
                            local isKill = IsPedDeadOrDying(nearbyPed, true)
                            local eventType = isKill and 'npc_kill' or 'npc_assault'
                            
                            -- Check config for each type
                            if isKill and not GetNPCViolenceConfig('trackKills', true) then
                                goto nextPed
                            end
                            if not isKill and not GetNPCViolenceConfig('trackAssault', true) then
                                goto nextPed
                            end
                            
                            -- Check for nearby NPCs (witnesses)
                            local pedCoords = GetEntityCoords(nearbyPed)
                            local npcCount = GetNearbyNPCCount(pedCoords, witnessDistance)
                            
                            -- Don't count the victim as a witness
                            npcCount = math.max(0, npcCount - 1)
                            
                            -- Only trigger if NPCs witnessed
                            if npcCount >= 1 then
                                TriggerNPCWitnessEvent(eventType, {
                                    coords = pedCoords,
                                    witnessCount = npcCount,
                                    metadata = {
                                        victimType = 'Civilian'
                                    }
                                })
                            end
                        end
                    end
                end
            end
            
            ::nextPed::
        end
        
        -- Clean up tracked peds periodically
        local count = 0
        for _ in pairs(trackedPeds) do count = count + 1 end
        if count > 100 then
            trackedPeds = {}
        end
        
        ::assaultContinue::
    end
end)

-- Drug Deal Integration Event (called by external scripts)
RegisterNetEvent('lifeprint:npcWitness:drugDeal', function(data)
    if not GetNPCWitnessConfig('enabled', true) then return end
    
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local witnessDistance = GetNPCWitnessConfig('witnessDistance', 35.0)
    local npcCount = GetNearbyNPCCount(coords, witnessDistance)
    local requireNPC = GetNPCWitnessConfig('requireNPCNearby', true)
    local minWitnessCount = GetNPCWitnessConfig('minWitnessCount', 1)
    
    if (not requireNPC or npcCount >= minWitnessCount) then
        TriggerNPCWitnessEvent('drug_deal', {
            coords = coords,
            witnessCount = npcCount,
            metadata = data or {}
        })
    end
end)
