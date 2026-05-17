-- Lifeprint Server Script
-- Handles database operations, security, and exports
-- All commands and events are safe - never crash on nil data, missing identifiers, or SQL errors

local resourceName = GetCurrentResourceName()

-- ============================================================================
-- Debug Logging (defined first - used throughout file)
-- ============================================================================

local function DebugLog(message, level)
    if not Config or not Config.Debug then return end
    level = level or 'info'
    print(('[Lifeprint] [%s] %s'):format(level:upper(), tostring(message)))
end

-- ============================================================================
-- Safe Default Tables (always return these instead of nil)
-- ============================================================================

local EMPTY_TABLE = {}
local SAFE_DEFAULTS = {
    memories = {},
    relationships = {},
    reputation = {},
    rumors = {},
    counters = {},
    tags = {},
    characterRead = ""
}

-- ============================================================================
-- Performance Caching
-- ============================================================================

-- Identifier cache: source -> { identifier, name, timestamp }
local IdentifierCache = {}
local CacheTTL = 300  -- 5 minutes default

local function GetPerfConfig(key, default)
    if Config and Config.Performance and Config.Performance[key] ~= nil then
        return Config.Performance[key]
    end
    return default
end

-- Get cached identifier (avoids repeated framework calls)
local function GetCachedIdentifier(source)
    if not source or type(source) ~= 'number' or source <= 0 then return nil end
    
    local now = os.time()
    local ttl = GetPerfConfig('identifierCacheTTL', CacheTTL)
    
    -- Check cache
    if IdentifierCache[source] then
        local cached = IdentifierCache[source]
        if (now - cached.timestamp) < ttl then
            return cached.identifier, cached.name
        end
    end
    
    -- Resolve and cache
    local identifier = Bridge.GetIdentifier(source)
    local name = Bridge.GetCharacterName(source) or GetPlayerName(source)
    
    if identifier then
        IdentifierCache[source] = {
            identifier = identifier,
            name = name,
            timestamp = now
        }
    end
    
    return identifier, name
end

-- Clear cache for a player
local function ClearPlayerCache(source)
    if source then
        IdentifierCache[source] = nil
        DebugLog('Cleared cache for source: ' .. tostring(source))
    end
end

-- Clear all caches
local function ClearAllCaches()
    IdentifierCache = {}
    TrackingCooldowns = {}
    FaceMemoryReminderCooldowns = {}
    RecentRumorTexts = {}
    DebugLog('All caches cleared')
end

-- ============================================================================
-- Player Drop Handler - Clear caches when players disconnect
-- ============================================================================

AddEventHandler('playerDropped', function(reason)
    local source = tonumber(source)
    if not source then return end
    
    -- Clear caches for this player if enabled
    if GetPerfConfig('clearCacheOnDrop', true) then
        ClearPlayerCache(source)
        
        -- Clear tracking cooldowns involving this player
        if TrackingCooldowns then
            for key, _ in pairs(TrackingCooldowns) do
                if type(key) == 'string' and key:find(tostring(source)) then
                    TrackingCooldowns[key] = nil
                end
            end
        end
    end
    
    DebugLog('Player dropped: ' .. tostring(source) .. ' (' .. tostring(reason) .. ')')
end)

-- ============================================================================
-- Debug & Error Logging
-- ============================================================================

local function LogError(message)
    print(('[Lifeprint] [ERROR] %s'):format(tostring(message)))
end

-- ============================================================================
-- Security: Validate Source
-- ============================================================================

local function ValidateSource(source)
    if not source or type(source) ~= "number" or source <= 0 then
        return false, 'Invalid source'
    end
    return true, nil
end

-- ============================================================================
-- Safe Database Operations (always wrapped in pcall)
-- ============================================================================

local function SafeQuery(queryFn)
    local ok, result = pcall(queryFn)
    if not ok then
        LogError('Database error: ' .. tostring(result))
        return nil
    end
    return result
end

-- ============================================================================
-- Valid Visibility Values
-- ============================================================================

local VALID_VISIBILITIES = { private = true, public = true, admin = true }

local function IsValidVisibility(visibility)
    return VALID_VISIBILITIES[visibility] == true
end

-- ============================================================================
-- Data Retrieval Functions (always return safe tables)
-- ============================================================================

-- Get memories for the owner (filters out admin-only if not admin)
local function GetPlayerMemories(identifier, isAdmin)
    if not identifier then return {} end
    
    local maxEntries = GetPerfConfig('maxTimelineEntries', 50)
    
    local result = SafeQuery(function()
        if isAdmin then
            -- Admins see all memories they own
            return MySQL.query.await([[
                SELECT * FROM lifeprint_memories
                WHERE identifier = ?
                ORDER BY timestamp DESC
                LIMIT ?
            ]], { identifier, maxEntries })
        else
            -- Regular players see private + public (but not admin-only)
            return MySQL.query.await([[
                SELECT * FROM lifeprint_memories
                WHERE identifier = ? AND (visibility = 'private' OR visibility = 'public' OR visibility IS NULL)
                ORDER BY timestamp DESC
                LIMIT ?
            ]], { identifier, maxEntries })
        end
    end)
    
    return result or {}
end

-- Get all public memories for a player (for exports)
local function GetPublicMemories(identifier)
    if not identifier then return {} end
    
    local result = SafeQuery(function()
        return MySQL.query.await([[
            SELECT * FROM lifeprint_memories
            WHERE identifier = ? AND visibility = 'public'
            ORDER BY timestamp DESC
        ]], { identifier })
    end)
    
    return result or {}
end

-- Get all memories regardless of visibility (admin only)
local function GetAllMemoriesAdmin(identifier)
    if not identifier then return {} end
    
    local result = SafeQuery(function()
        return MySQL.query.await([[
            SELECT * FROM lifeprint_memories
            WHERE identifier = ?
            ORDER BY timestamp DESC
            LIMIT ?
        ]], { identifier, Config.MaxMemoriesPerCharacter or 100 })
    end)
    
    return result or {}
end

-- Get memory locations for location-based triggers (memories with coordinates)
local function GetPlayerRelationships(identifier)
    if not identifier then return {} end
    
    local maxRelations = GetPerfConfig('maxRelationships', 50)
    
    local result = SafeQuery(function()
        return MySQL.query.await([[
            SELECT * FROM lifeprint_relationships
            WHERE identifier = ?
            ORDER BY last_interaction DESC
            LIMIT ?
        ]], { identifier, maxRelations })
    end)
    
    return result or {}
end

local function GetPlayerReputation(identifier)
    if not identifier then return {} end
    
    local result = SafeQuery(function()
        return MySQL.query.await([[
            SELECT * FROM lifeprint_reputation
            WHERE identifier = ?
        ]], { identifier })
    end)
    
    return result or {}
end

local function GetPlayerRumors(identifier)
    if not identifier then return {} end
    
    local maxRumors = GetPerfConfig('maxRumors', 25)
    
    local result = SafeQuery(function()
        return MySQL.query.await([[
            SELECT * FROM lifeprint_rumors
            WHERE identifier = ? OR source_identifier = ?
            ORDER BY created_at DESC
            LIMIT ?
        ]], { identifier, identifier, maxRumors })
    end)
    
    return result or {}
end

local function GetPlayerCounters(identifier)
    if not identifier then return nil end
    
    local result = SafeQuery(function()
        return MySQL.query.await([[
            SELECT * FROM lifeprint_reputation_counters
            WHERE identifier = ?
        ]], { identifier })
    end)
    
    if result and #result > 0 then
        return result[1]
    end
    return nil
end

-- ============================================================================
-- Memory Brain Functions
-- Visual brain that changes color based on player's story
-- ============================================================================

-- Classify a single memory type into a category
local function ClassifyMemoryType(memoryType)
    if not memoryType then return 'other' end
    
    local classifications = Config and Config.MemoryBrain and Config.MemoryBrain.classifications
    if not classifications then
        classifications = {
            good = { 'friendship', 'helpful', 'business_positive', 'trusted', 'ems_helped', 'positive', 'rescue', 'romantic' },
            bad = { 'death', 'kill', 'crime', 'arrest', 'npc_kill', 'npc_assault', 'vehicle_theft', 'hostile', 'negative', 'betrayal', 'conflict', 'npc_vehicle_theft', 'gunshots', 'reckless_driving', 'drug_deal' },
            rumors = { 'rumor', 'city_whisper' },
            other = { 'social', 'encounter', 'vehicle', 'location', 'business', 'unknown', 'injury', 'vehicle_hit', 'gunshot' }
        }
    end
    
    memoryType = string.lower(tostring(memoryType))
    
    -- Check each category
    for _, categoryType in ipairs(classifications.good or {}) do
        if memoryType == string.lower(tostring(categoryType)) then
            return 'good'
        end
    end
    
    for _, categoryType in ipairs(classifications.bad or {}) do
        if memoryType == string.lower(tostring(categoryType)) then
            return 'bad'
        end
    end
    
    for _, categoryType in ipairs(classifications.rumors or {}) do
        if memoryType == string.lower(tostring(categoryType)) then
            return 'rumors'
        end
    end
    
    return 'other'
end

-- Generate Brain Read paragraph based on dominant category
local function GenerateBrainRead(counts)
    local templates = Config and Config.MemoryBrain and Config.MemoryBrain.brainReadTemplates
    if not templates then
        templates = {
            good_dominant = { "Your Lifeprint is mostly positive. The city remembers your good deeds." },
            bad_dominant = { "Your memories are stained red. Bad choices are becoming part of your story." },
            rumors_dominant = { "Purple dominates your Lifeprint. Rumors are spreading faster than facts." },
            other_dominant = { "Your story is balanced. The city has not decided who you are yet." },
            balanced = { "Your Lifeprint weaves all colors equally. A complex story unfolds." },
            empty = { "Your Lifeprint is empty. The city doesn't know you yet." }
        }
    end
    
    local total = counts.good + counts.bad + counts.rumors + counts.other
    
    -- Empty state
    if total == 0 then
        local pool = templates.empty or { "Your Lifeprint is empty." }
        return pool[math.random(1, #pool)]
    end
    
    -- Calculate percentages
    local goodPct = (counts.good / total) * 100
    local badPct = (counts.bad / total) * 100
    local rumorsPct = (counts.rumors / total) * 100
    local otherPct = (counts.other / total) * 100
    
    -- Determine dominant category (must be > 40% to be dominant)
    local dominantThreshold = 40
    local dominant = nil
    local maxPct = 0
    
    if goodPct > dominantThreshold and goodPct > maxPct then
        dominant = 'good'
        maxPct = goodPct
    end
    if badPct > dominantThreshold and badPct > maxPct then
        dominant = 'bad'
        maxPct = badPct
    end
    if rumorsPct > dominantThreshold and rumorsPct > maxPct then
        dominant = 'rumors'
        maxPct = rumorsPct
    end
    if otherPct > dominantThreshold and otherPct > maxPct then
        dominant = 'other'
        maxPct = otherPct
    end
    
    -- If no clear dominant, use balanced
    if not dominant then
        dominant = 'balanced'
    end
    
    local pool = templates[dominant .. '_dominant'] or templates.balanced or { "Your story is still being written." }
    return pool[math.random(1, #pool)]
end

-- Get Memory Brain data for a player
local function GetMemoryBrain(identifier)
    if not identifier then
        return {
            good = 0,
            bad = 0,
            rumors = 0,
            other = 0,
            total = 0,
            dominant = 'other',
            brainRead = "Your Lifeprint is empty. The city doesn't know you yet.",
            recent = { good = {}, bad = {}, rumors = {}, other = {} }
        }
    end
    
    -- Get all memories for classification
    local memories = SafeQuery(function()
        return MySQL.query.await([[
            SELECT id, memory_type, title, description, location, timestamp
            FROM lifeprint_memories
            WHERE identifier = ?
            ORDER BY timestamp DESC
            LIMIT 50
        ]], { identifier })
    end) or {}
    
    -- Get rumors count
    local rumors = SafeQuery(function()
        return MySQL.query.await([[
            SELECT id, rumor_type, content, created_at
            FROM lifeprint_rumors
            WHERE identifier = ? OR source_identifier = ?
            ORDER BY created_at DESC
            LIMIT 25
        ]], { identifier, identifier })
    end) or {}
    
    -- Classify memories
    local counts = { good = 0, bad = 0, rumors = 0, other = 0 }
    local recent = { good = {}, bad = {}, rumors = {}, other = {} }
    local maxRecent = 3
    
    -- Process memories
    for _, mem in ipairs(memories) do
        local category = ClassifyMemoryType(mem.memory_type)
        counts[category] = counts[category] + 1
        
        -- Add to recent if we haven't filled the slot
        if #recent[category] < maxRecent then
            table.insert(recent[category], {
                id = mem.id,
                type = mem.memory_type,
                title = mem.title,
                description = mem.description,
                location = mem.location,
                timestamp = mem.timestamp
            })
        end
    end
    
    -- Process rumors (they go into the rumors category)
    counts.rumors = counts.rumors + #rumors
    for _, rum in ipairs(rumors) do
        if #recent.rumors < maxRecent then
            table.insert(recent.rumors, {
                id = rum.id,
                type = rum.rumor_type,
                content = rum.content,
                timestamp = rum.created_at
            })
        end
    end
    
    local total = counts.good + counts.bad + counts.rumors + counts.other
    
    -- Determine dominant category
    local dominant = 'other'
    local maxCount = counts.other
    
    if counts.good > maxCount then
        dominant = 'good'
        maxCount = counts.good
    end
    if counts.bad > maxCount then
        dominant = 'bad'
        maxCount = counts.bad
    end
    if counts.rumors > maxCount then
        dominant = 'rumors'
        maxCount = counts.rumors
    end
    
    -- Generate brain read
    local brainRead = GenerateBrainRead(counts)
    
    return {
        good = counts.good,
        bad = counts.bad,
        rumors = counts.rumors,
        other = counts.other,
        total = total,
        dominant = dominant,
        brainRead = brainRead,
        recent = recent
    }
end

-- ============================================================================
-- Social Web Functions (Seen With)
-- ============================================================================

-- Social web tracking cooldowns: identifier_targetIdentifier -> timestamp
local SocialWebCooldowns = {}

-- Get player social links
local function GetPlayerSocialLinks(identifier)
    if not identifier then return {} end
    
    local maxLinks = Config and Config.SocialWeb and Config.SocialWeb.maxLinks or 20
    local minCount = Config and Config.SocialWeb and Config.SocialWeb.minSeenCountForUI or 2
    
    local result = SafeQuery(function()
        return MySQL.query.await([[
            SELECT target_identifier, target_name, seen_count, last_seen, first_seen
            FROM lifeprint_social_links
            WHERE identifier = ? AND seen_count >= ?
            ORDER BY seen_count DESC, last_seen DESC
            LIMIT ?
        ]], { identifier, minCount, maxLinks })
    end)
    
    if result and #result > 0 then
        local links = {}
        for i, row in ipairs(result) do
            table.insert(links, {
                targetIdentifier = row.target_identifier,
                targetName = row.target_name or 'Unknown',
                seenCount = tonumber(row.seen_count) or 1,
                lastSeen = row.last_seen,
                firstSeen = row.first_seen
            })
        end
        return links
    end
    return {}
end

-- Update or create social link
local function UpdateSocialLink(identifier, targetIdentifier, targetName)
    if not identifier or not targetIdentifier then return false end
    if identifier == targetIdentifier then return false end -- Don't track self
    
    -- Check cooldown
    local cooldownKey = identifier .. '_' .. targetIdentifier
    local cooldownTime = Config and Config.SocialWeb and Config.SocialWeb.cooldown or 1800
    
    if SocialWebCooldowns[cooldownKey] then
        local timeSince = os.time() - SocialWebCooldowns[cooldownKey]
        if timeSince < cooldownTime then
            DebugLog('Social web cooldown active for ' .. cooldownKey)
            return false
        end
    end
    
    -- Upsert social link
    local success = SafeQuery(function()
        MySQL.insert.await([[
            INSERT INTO lifeprint_social_links (identifier, target_identifier, target_name, seen_count, last_seen)
            VALUES (?, ?, ?, 1, NOW())
            ON DUPLICATE KEY UPDATE 
                seen_count = seen_count + 1,
                target_name = COALESCE(VALUES(target_name), target_name),
                last_seen = NOW()
        ]], { identifier, targetIdentifier, targetName })
    end)
    
    if success then
        -- Set cooldown
        SocialWebCooldowns[cooldownKey] = os.time()
        DebugLog('Social link updated: ' .. identifier .. ' -> ' .. targetIdentifier)
        
        -- Check for rumor generation
        local newCount = SafeQuery(function()
            local result = MySQL.query.await([[
                SELECT seen_count FROM lifeprint_social_links 
                WHERE identifier = ? AND target_identifier = ?
            ]], { identifier, targetIdentifier })
            return result and result[1] and tonumber(result[1].seen_count) or 0
        end)
        
        if newCount then
            local rumorThreshold = Config and Config.SocialWeb and Config.SocialWeb.rumorThreshold or 5
            
            -- Generate rumor when reaching threshold
            if newCount == rumorThreshold then
                local playerName = Bridge.GetCharacterNameFromIdentifier(identifier) or 'Someone'
                local otherName = targetName or 'someone'
                local rumorText = 'People keep seeing ' .. playerName .. ' around ' .. otherName .. '.'
                
                AddRumor(identifier, {
                    rumorType = 'social',
                    content = rumorText,
                    targetIdentifier = targetIdentifier,
                    targetName = otherName
                })
                DebugLog('Social web rumor generated for ' .. identifier)
            end
        end
        
        return true
    end
    
    return false
end

-- Export for external use
exports('UpdateSocialLink', UpdateSocialLink)
exports('GetPlayerSocialLinks', GetPlayerSocialLinks)

-- Returns memories with coordinates for client-side proximity checking
local function GetMemoryLocations(identifier, limit)
    if not identifier then return {} end
    
    limit = limit or (Config and Config.LocationMemories and Config.LocationMemories.maxLocationsToSend) or 100
    
    local rows = SafeQuery(function()
        return MySQL.query.await([[
            SELECT id, memory_type, title, description, location, x, y, z, timestamp, target_name
            FROM lifeprint_memories
            WHERE identifier = ? 
            AND x IS NOT NULL 
            AND y IS NOT NULL 
            AND z IS NOT NULL
            ORDER BY timestamp DESC
            LIMIT ?
        ]], { identifier, limit })
    end)
    
    if not rows then return {} end
    
    local locations = {}
    for _, row in ipairs(rows) do
        table.insert(locations, {
            id = row.id,
            memoryType = row.memory_type,
            title = row.title,
            description = row.description,
            location = row.location,
            x = row.x,
            y = row.y,
            z = row.z,
            timestamp = row.timestamp,
            targetName = row.target_name
        })
    end
    
    return locations
end

local function GetPlayerLifeprint(identifier, isAdmin)
    DebugLog('GetPlayerLifeprint for: ' .. tostring(identifier) .. (isAdmin and ' (admin)' or ''))
    
    return {
        memories = GetPlayerMemories(identifier, isAdmin) or {},
        relationships = GetPlayerRelationships(identifier) or {},
        reputation = GetPlayerReputation(identifier) or {},
        rumors = GetPlayerRumors(identifier) or {},
        socialLinks = GetPlayerSocialLinks(identifier) or {},
        memoryLocations = GetMemoryLocations(identifier) or {}
    }
end

-- ============================================================================
-- Settings Functions (Privacy Controls)
-- ============================================================================

-- Default settings (used when no row exists)
local DEFAULT_SETTINGS = {
    face_reminders = true,
    proximity_memories = true,
    rumor_notifications = true,
    memory_popups = true
}

-- Get player settings (returns defaults if no row exists)
local function GetPlayerSettings(identifier)
    if not identifier then return DEFAULT_SETTINGS end
    
    local result = SafeQuery(function()
        return MySQL.query.await([[
            SELECT face_reminders, proximity_memories, rumor_notifications, memory_popups
            FROM lifeprint_settings
            WHERE identifier = ?
        ]], { identifier })
    end)
    
    if result and #result > 0 then
        local row = result[1]
        return {
            face_reminders = row.face_reminders == 1,
            proximity_memories = row.proximity_memories == 1,
            rumor_notifications = row.rumor_notifications == 1,
            memory_popups = row.memory_popups == 1
        }
    end
    
    -- Return defaults if no row exists
    return DEFAULT_SETTINGS
end

-- Save player settings
local function SavePlayerSettings(identifier, settings)
    if not identifier or not settings then return false end
    
    -- Validate settings (clamp to 0 or 1)
    local faceReminders = settings.face_reminders and 1 or 0
    local proximityMemories = settings.proximity_memories and 1 or 0
    local rumorNotifications = settings.rumor_notifications and 1 or 0
    local memoryPopups = settings.memory_popups and 1 or 0
    
    local result = SafeQuery(function()
        return MySQL.insert.await([[
            INSERT INTO lifeprint_settings (identifier, face_reminders, proximity_memories, rumor_notifications, memory_popups)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                face_reminders = VALUES(face_reminders),
                proximity_memories = VALUES(proximity_memories),
                rumor_notifications = VALUES(rumor_notifications),
                memory_popups = VALUES(memory_popups)
        ]], { identifier, faceReminders, proximityMemories, rumorNotifications, memoryPopups })
    end)
    
    if result then
        DebugLog(('Saved settings for %s'):format(identifier))
        return true
    end
    
    return false
end

-- Check if a specific setting is enabled for a player
local function IsSettingEnabled(identifier, settingKey)
    if not identifier or not settingKey then return true end
    
    local settings = GetPlayerSettings(identifier)
    return settings[settingKey] == true
end

-- ============================================================================
-- Memory Functions
-- ============================================================================

local function AddMemory(source, memoryType, title, description, location, relatedIdentifier, relatedName, visibility)
    -- Handle both old (identifier, data) and new (source, params...) calling patterns
    local identifier, data
    
    if type(source) == 'string' and memoryType == nil then
        -- Old pattern: AddMemory(identifier, dataTable)
        identifier = source
        data = title or {}
        visibility = data.visibility or 'private'
    else
        -- New pattern: AddMemory(source, memoryType, title, description, location, relatedIdentifier, relatedName, visibility)
        identifier = Bridge and Bridge.GetIdentifier(source)
        if not identifier then return false, 'Invalid source' end
        data = {
            memoryType = memoryType,
            description = description or title,
            location = location,
            targetIdentifier = relatedIdentifier,
            targetName = relatedName
        }
    end
    
    if not identifier or not data then
        return false, 'Missing identifier or data'
    end
    
    -- Validate visibility (default to private)
    visibility = visibility or data.visibility or 'private'
    if not IsValidVisibility(visibility) then
        visibility = 'private'
    end
    
    -- Validate memory type
    local validType = false
    if Config and Config.MemoryTypes then
        for _, mt in ipairs(Config.MemoryTypes) do
            if mt.id == data.memoryType then
                validType = true
                break
            end
        end
    end
    
    if not validType then
        data.memoryType = 'other'
    end
    
    local result = SafeQuery(function()
        return MySQL.insert.await([[
            INSERT INTO lifeprint_memories 
            (identifier, target_identifier, memory_type, description, location, x, y, z, timestamp, visibility, metadata, is_demo)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
        ]], {
            identifier,
            data.targetIdentifier or nil,
            data.memoryType,
            data.description or '',
            data.location or nil,
            data.x or nil,
            data.y or nil,
            data.z or nil,
            data.timestamp or os.time(),
            visibility,
            data.metadata and json.encode(data.metadata) or nil
        })
    end)
    
    if result then
        DebugLog(('Added memory for %s (visibility: %s)'):format(identifier, visibility))
        
        -- Send journal notification
        SendJournalNotification(identifier, 'memoryAdded', {
            memoryType = data.memoryType
        })
        
        return true, result
    end
    
    return false, 'Database insert failed'
end

local function DeleteMemory(identifier, memoryId)
    if not identifier or not memoryId then return false end
    
    local result = SafeQuery(function()
        return MySQL.update.await([[
            DELETE FROM lifeprint_memories
            WHERE id = ? AND identifier = ?
        ]], { memoryId, identifier })
    end)
    
    return result and result > 0
end

-- ============================================================================
-- Relationship Functions
-- ============================================================================

local function AddRelationship(identifier, data)
    if not identifier or not data or not data.targetIdentifier then
        return false, 'Missing identifier or target'
    end
    
    -- Clamp value
    local value = math.max(-100, math.min(100, data.value or 0))
    local now = os.time()
    
    -- Use UPSERT logic (INSERT ... ON DUPLICATE KEY UPDATE)
    -- This is atomic and prevents race conditions
    local result = SafeQuery(function()
        return MySQL.insert.await([[
            INSERT INTO lifeprint_relationships
            (identifier, target_identifier, target_name, relationship_value, relationship_type, first_met, last_interaction, interaction_count, notes, first_location, is_demo)
            VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?, 0)
            ON DUPLICATE KEY UPDATE
                relationship_value = LEAST(100, GREATEST(-100, relationship_value + ?)),
                relationship_type = COALESCE(VALUES(relationship_type), relationship_type),
                last_interaction = VALUES(last_interaction),
                interaction_count = interaction_count + 1,
                notes = COALESCE(VALUES(notes), notes),
                target_name = COALESCE(VALUES(target_name), target_name)
        ]], {
            identifier,
            data.targetIdentifier,
            data.targetName or nil,
            value,
            data.relationshipType or 'stranger',
            now,
            now,
            data.notes and string.sub(data.notes, 1, 200) or nil,
            data.location or nil,
            data.change or value  -- For the increment in ON DUPLICATE KEY UPDATE
        })
    end)
    
    if result then
        DebugLog(('Upserted relationship: %s -> %s'):format(identifier, data.targetIdentifier))
        
        -- Send journal notification
        local relationshipLabel = GetRelationshipLabel(data.relationshipType or 'stranger')
        SendJournalNotification(identifier, 'relationshipUpdated', {
            name = data.targetName or 'Unknown',
            label = relationshipLabel
        })
        
        return true, result
    end
    
    return false, 'Database operation failed'
end

-- Get human-readable relationship label
function GetRelationshipLabel(relationshipType)
    local labels = Config and Config.RelationshipLabels or {
        stranger = 'Stranger',
        contact = 'Contact',
        acquaintance = 'Acquaintance',
        friend = 'Friend',
        close_friend = 'Close Friend',
        rival = 'Rival',
        enemy = 'Enemy',
        nemesis = 'Nemesis',
        known_contact = 'Known Contact',
        familiar = 'Familiar'
    }
    return labels[relationshipType] or relationshipType:gsub('_', ' '):gsub('^%l', string.upper)
end

local function UpdateRelationshipNotes(identifier, targetIdentifier, notes)
    if not identifier or not targetIdentifier then
        return false, 'Missing identifier or target'
    end
    
    local existing = SafeQuery(function()
        return MySQL.query.await([[
            SELECT id FROM lifeprint_relationships
            WHERE identifier = ? AND target_identifier = ?
        ]], { identifier, targetIdentifier })
    end)
    
    if not existing or #existing == 0 then
        return false, 'Relationship not found'
    end
    
    local truncatedNotes = notes and #notes > 0 and string.sub(notes, 1, 200) or nil
    
    SafeQuery(function()
        return MySQL.update.await([[
            UPDATE lifeprint_relationships SET notes = ? WHERE id = ?
        ]], { truncatedNotes, existing[1].id })
    end)
    
    return true
end

-- ============================================================================
-- Reputation Functions
-- ============================================================================

local function AddReputation(identifier, data)
    if not identifier or not data or not data.category then
        return false, 'Missing identifier or category'
    end
    
    local existing = SafeQuery(function()
        return MySQL.query.await([[
            SELECT id, reputation_value FROM lifeprint_reputation
            WHERE identifier = ? AND category = ?
        ]], { identifier, data.category })
    end)
    
    local newValue, id
    
    if existing and #existing > 0 then
        newValue = math.max(-100, math.min(100, (existing[1].reputation_value or 0) + (data.change or 0)))
        SafeQuery(function()
            return MySQL.update.await([[
                UPDATE lifeprint_reputation
                SET reputation_value = ?, last_updated = ?
                WHERE id = ?
            ]], { newValue, os.time(), existing[1].id })
        end)
        id = existing[1].id
    else
        newValue = math.max(-100, math.min(100, data.change or 0))
        id = SafeQuery(function()
            return MySQL.insert.await([[
                INSERT INTO lifeprint_reputation
                (identifier, category, reputation_value, last_updated, is_demo)
                VALUES (?, ?, ?, ?, 0)
            ]], { identifier, data.category, newValue, os.time() })
        end)
    end
    
    -- Log the change
    if id and data.reason then
        SafeQuery(function()
            return MySQL.insert.await([[
                INSERT INTO lifeprint_reputation_log
                (identifier, category, change_amount, reason, source, created_at)
                VALUES (?, ?, ?, ?, ?, ?)
            ]], { identifier, data.category, data.change, data.reason, data.source or 'system', os.time() })
        end)
    end
    
    return true, id
end

-- ============================================================================
-- Counter Functions
-- ============================================================================

-- Tag Generation (must be defined before IncrementCounter)
-- ============================================================================

local function GenerateTagsFromCounters(counters)
    local tags = {}
    if not counters then return tags end
    if not Config or not Config.ReputationTagThresholds then return tags end
    
    for counterType, thresholds in pairs(Config.ReputationTagThresholds) do
        local counterValue = tonumber(counters[counterType]) or 0
        
        local sorted = {}
        for _, t in ipairs(thresholds) do table.insert(sorted, t) end
        table.sort(sorted, function(a, b) return a.threshold > b.threshold end)
        
        for _, th in ipairs(sorted) do
            if counterValue >= th.threshold then
                table.insert(tags, {
                    label = th.label,
                    priority = th.priority,
                    style = th.style,
                    counter = counterType,
                    value = counterValue
                })
                break
            end
        end
    end
    
    table.sort(tags, function(a, b) return a.priority > b.priority end)
    return tags
end

local function GenerateCharacterRead(tags, counters)
    if not tags or #tags == 0 then
        return (Config and Config.CharacterReadTemplates and Config.CharacterReadTemplates.neutral) or "Your Lifeprint is still being written."
    end
    
    local templates = Config and Config.CharacterReadTemplates or {}
    local positiveTags, negativeTags = {}, {}
    
    for _, tag in ipairs(tags) do
        if tag.style == "success" then
            table.insert(positiveTags, tag.label:lower())
        elseif tag.style == "danger" or tag.style == "warning" then
            table.insert(negativeTags, tag.label:lower())
        end
    end
    
    local hasRecord = false
    for _, tag in ipairs(tags) do
        if tag.counter == "arrests" then hasRecord = true break end
    end
    
    local template = templates.neutral or "Your Lifeprint is still being written."
    
    if hasRecord and #negativeTags > #positiveTags and templates.record then
        template = templates.record:gsub("{record_tags}", table.concat(negativeTags, " and "))
    elseif #positiveTags > #negativeTags and templates.positive_strong then
        template = templates.positive_strong:gsub("{positive_tags}", table.concat(positiveTags, " and "))
    elseif #negativeTags > 0 and templates.negative_strong then
        template = templates.negative_strong:gsub("{negative_tags}", table.concat(negativeTags, " and "))
    end
    
    return template
end

local CounterQueries = {
    increment = {
        arrests = "UPDATE lifeprint_reputation_counters SET arrests = arrests + ?, last_updated = ? WHERE identifier = ?",
        ems_visits = "UPDATE lifeprint_reputation_counters SET ems_visits = ems_visits + ?, last_updated = ? WHERE identifier = ?",
        crashes = "UPDATE lifeprint_reputation_counters SET crashes = crashes + ?, last_updated = ? WHERE identifier = ?",
        meetings = "UPDATE lifeprint_reputation_counters SET meetings = meetings + ?, last_updated = ? WHERE identifier = ?",
        helpful_actions = "UPDATE lifeprint_reputation_counters SET helpful_actions = helpful_actions + ?, last_updated = ? WHERE identifier = ?",
        suspicious_actions = "UPDATE lifeprint_reputation_counters SET suspicious_actions = suspicious_actions + ?, last_updated = ? WHERE identifier = ?"
    },
    set = {
        arrests = "UPDATE lifeprint_reputation_counters SET arrests = ?, last_updated = ? WHERE identifier = ?",
        ems_visits = "UPDATE lifeprint_reputation_counters SET ems_visits = ?, last_updated = ? WHERE identifier = ?",
        crashes = "UPDATE lifeprint_reputation_counters SET crashes = ?, last_updated = ? WHERE identifier = ?",
        meetings = "UPDATE lifeprint_reputation_counters SET meetings = ?, last_updated = ? WHERE identifier = ?",
        helpful_actions = "UPDATE lifeprint_reputation_counters SET helpful_actions = ?, last_updated = ? WHERE identifier = ?",
        suspicious_actions = "UPDATE lifeprint_reputation_counters SET suspicious_actions = ?, last_updated = ? WHERE identifier = ?"
    }
}

local function IsValidCounterType(counterType)
    if not Config or not Config.ReputationCounterTypes then return false end
    for _, ct in ipairs(Config.ReputationCounterTypes) do
        if ct == counterType then return true end
    end
    return false
end

local function InitializeCounters(identifier)
    if not identifier then return false end
    
    SafeQuery(function()
        return MySQL.insert.await([[
            INSERT IGNORE INTO lifeprint_reputation_counters
            (identifier, arrests, ems_visits, crashes, meetings, helpful_actions, suspicious_actions, last_updated)
            VALUES (?, 0, 0, 0, 0, 0, 0, ?)
        ]], { identifier, os.time() })
    end)
    
    return true
end

local function IncrementCounter(identifier, counterType, amount)
    if not identifier or not IsValidCounterType(counterType) then return false end
    amount = amount or 1
    
    InitializeCounters(identifier)
    
    -- Get old counters and generate old tags (for comparison)
    local oldCounters = GetPlayerCounters(identifier)
    local oldTags = oldCounters and GenerateTagsFromCounters(oldCounters) or {}
    local oldTagLabels = {}
    for _, tag in ipairs(oldTags) do
        oldTagLabels[tag.label] = true
    end
    
    local query = CounterQueries.increment[counterType]
    if not query then return false end
    
    local result = SafeQuery(function()
        return MySQL.update.await(query, { amount, os.time(), identifier })
    end)
    
    if result and result > 0 then
        -- Get new counters and generate new tags
        local newCounters = GetPlayerCounters(identifier)
        local newTags = newCounters and GenerateTagsFromCounters(newCounters) or {}
        
        -- Find newly acquired tags
        for _, tag in ipairs(newTags) do
            if not oldTagLabels[tag.label] then
                -- New tag detected!
                CheckAndNotifyNewTag(identifier, tag)
            end
        end
        
        return true
    end
    
    return false
end

local function SetCounter(identifier, counterType, value)
    if not identifier or not IsValidCounterType(counterType) then return false end
    value = value or 0
    
    InitializeCounters(identifier)
    
    -- Get old counters and generate old tags (for comparison)
    local oldCounters = GetPlayerCounters(identifier)
    local oldTags = oldCounters and GenerateTagsFromCounters(oldCounters) or {}
    local oldTagLabels = {}
    for _, tag in ipairs(oldTags) do
        oldTagLabels[tag.label] = true
    end
    
    local query = CounterQueries.set[counterType]
    if not query then return false end
    
    local result = SafeQuery(function()
        return MySQL.update.await(query, { value, os.time(), identifier })
    end)
    
    if result and result > 0 then
        -- Get new counters and generate new tags
        local newCounters = GetPlayerCounters(identifier)
        local newTags = newCounters and GenerateTagsFromCounters(newCounters) or {}
        
        -- Find newly acquired tags
        for _, tag in ipairs(newTags) do
            if not oldTagLabels[tag.label] then
                -- New tag detected!
                CheckAndNotifyNewTag(identifier, tag)
            end
        end
        
        return true
    end
    
    return false
end

-- ============================================================================
-- Reputation Change Notification
-- ============================================================================

-- Cooldown tracker for reputation notifications: identifier -> timestamp
local ReputationNotificationCooldowns = {}

-- Check if a new tag should trigger a notification and send it
function CheckAndNotifyNewTag(identifier, tag)
    -- Check if feature is enabled
    local config = Config and Config.ReputationNotifications
    if not config or not config.enabled then return end
    
    -- Check minimum priority
    local minPriority = config.minPriority or 1
    if (tag.priority or 0) < minPriority then return end
    
    -- Check cooldown
    local cooldown = config.cooldown or 60
    local now = os.time()
    local lastNotification = ReputationNotificationCooldowns[identifier] or 0
    
    if now - lastNotification < cooldown then
        DebugLog(('Reputation notification on cooldown for %s'):format(identifier))
        return
    end
    
    -- Get notification template
    local template = nil
    local styleTemplates = config.styleTemplates and config.styleTemplates[tag.style]
    
    if styleTemplates and #styleTemplates > 0 then
        -- Use style-specific template
        template = styleTemplates[math.random(1, #styleTemplates)]
    elseif config.templates and #config.templates > 0 then
        -- Use generic template
        template = config.templates[math.random(1, #config.templates)]
    else
        template = "Your reputation has changed. You are now known as {tag}."
    end
    
    -- Replace placeholder
    local message = template:gsub("{tag}", tag.label)
    
    -- Update cooldown
    ReputationNotificationCooldowns[identifier] = now
    
    -- Find player source from identifier
    local src = GetSourceFromIdentifier(identifier)
    if not src then
        DebugLog(('Could not find source for identifier %s'):format(identifier))
        return
    end
    
    -- Send notification to client
    TriggerClientEvent('lifeprint:client:reputationNotification', src, {
        tag = tag.label,
        style = tag.style,
        message = message,
        priority = tag.priority
    })
    
    -- Update Reputation tab live if UI is open
    if config.liveUpdate then
        local counters = GetPlayerCounters(identifier)
        local tags = GenerateTagsFromCounters(counters)
        local characterRead = GenerateCharacterRead(tags, counters)
        
        TriggerClientEvent('lifeprint:client:updateReputation', src, {
            tags = tags,
            counters = counters,
            characterRead = characterRead
        })
    end
    
    DebugLog(('Reputation notification sent to %s: %s'):format(identifier, tag.label))
end

-- Helper: Get player source from identifier (searches all connected players)
function GetSourceFromIdentifier(identifier)
    if not identifier then return nil end
    
    local players = GetPlayers()
    for _, playerSrc in ipairs(players) do
        local playerId = tonumber(playerSrc)
        if playerId then
            local playerIdStr = Bridge and Bridge.GetIdentifier and Bridge.GetIdentifier(playerId)
            if playerIdStr == identifier then
                return playerId
            end
        end
    end
    
    return nil
end

-- ============================================================================
-- Journal Update Notifications
-- Notify players when their Lifeprint is updated
-- ============================================================================

-- Cooldown tracker for journal notifications: identifier_type -> timestamp
local JournalNotificationCooldowns = {}

-- Demo batching: track if we're in demo generation mode
local DemoBatchMode = {}  -- identifier -> true/false
local DemoBatchedNotifications = {}  -- identifier -> array of notification types

-- Start demo batch mode (suppress individual notifications)
function StartDemoBatch(identifier)
    if not identifier then return end
    DemoBatchMode[identifier] = true
    DemoBatchedNotifications[identifier] = {}
    DebugLog(('Started demo batch mode for %s'):format(identifier))
end

-- End demo batch mode and send summary notification
function EndDemoBatch(identifier)
    if not identifier then return end
    DemoBatchMode[identifier] = nil
    
    local notifications = DemoBatchedNotifications[identifier] or {}
    DemoBatchedNotifications[identifier] = nil
    
    -- If there were any notifications, send the summary
    if #notifications > 0 then
        local src = GetSourceFromIdentifier(identifier)
        if src then
            local config = Config and Config.JournalNotifications
            local templates = config and config.templates and config.templates.demoGenerated or {'Lifeprint demo profile generated.'}
            local message = templates[math.random(1, #templates)]
            
            TriggerClientEvent('lifeprint:client:journalNotification', src, {
                type = 'demo',
                message = message,
                duration = 5000
            })
        end
    end
    
    DebugLog(('Ended demo batch mode for %s (%d notifications batched)'):format(identifier, #notifications))
end

-- Send a journal notification (respects batch mode and cooldowns)
function SendJournalNotification(identifier, notificationType, data)
    if not identifier or not notificationType then return end
    
    local config = Config and Config.JournalNotifications
    if not config or not config.enabled then return end
    
    -- Check if this notification type is enabled
    local toggleKey = 'show' .. notificationType:gsub('^%l', string.upper)
    if config[toggleKey] == false then return end
    
    -- If in demo batch mode, queue the notification instead of sending
    if DemoBatchMode[identifier] then
        if not DemoBatchedNotifications[identifier] then
            DemoBatchedNotifications[identifier] = {}
        end
        table.insert(DemoBatchedNotifications[identifier], notificationType)
        return
    end
    
    -- Check cooldown
    local cooldown = config.cooldown or 30
    local cooldownKey = identifier .. '_' .. notificationType
    local now = os.time()
    local lastNotification = JournalNotificationCooldowns[cooldownKey] or 0
    
    if now - lastNotification < cooldown then
        DebugLog(('Journal notification on cooldown: %s'):format(cooldownKey))
        return
    end
    
    -- Update cooldown
    JournalNotificationCooldowns[cooldownKey] = now
    
    -- Get message template
    local templateKey = notificationType:gsub('^%l', string.upper) .. (notificationType == 'relationshipUpdated' and '' or 'Added')
    if notificationType == 'reputationChanged' then
        templateKey = 'reputationChanged'
    end
    
    local templates = config.templates and (config.templates[templateKey] or config.templates[notificationType])
    if not templates or #templates == 0 then
        templates = { 'Your Lifeprint has been updated.' }
    end
    
    local message = templates[math.random(1, #templates)]
    
    -- Replace placeholders
    if data then
        message = message:gsub('{name}', data.name or 'Unknown')
        message = message:gsub('{label}', data.label or 'Contact')
        message = message:gsub('{type}', notificationType)
    end
    
    -- Try to get flavor text for this notification type
    local flavorCategory = GetFlavorCategoryForNotification(notificationType, data)
    local flavorText = nil
    if flavorCategory and Config and Config.GetFlavorText then
        flavorText = Config.GetFlavorText(flavorCategory, data)
    end
    
    -- Find player source
    local src = GetSourceFromIdentifier(identifier)
    if not src then
        DebugLog(('Could not find source for journal notification: %s'):format(identifier))
        return
    end
    
    -- Send notification to client (with optional flavor text)
    TriggerClientEvent('lifeprint:client:journalNotification', src, {
        type = notificationType,
        message = message,
        flavor = flavorText,  -- Immersive RP flavor
        data = data,
        duration = config.duration or 4000
    })
    
    -- Trigger live UI refresh if enabled
    if config.liveUpdate then
        TriggerClientEvent('lifeprint:client:refreshCurrentTab', src, {
            affectedTab = GetAffectedTab(notificationType)
        })
    end
    
    DebugLog(('Journal notification sent to %s: %s'):format(identifier, notificationType))
end

-- Determine which tab is affected by the notification type
function GetAffectedTab(notificationType)
    if notificationType == 'memoryAdded' then return 'timeline' end
    if notificationType == 'relationshipUpdated' then return 'people' end
    if notificationType == 'rumorAdded' then return 'rumors' end
    if notificationType == 'reputationChanged' then return 'reputation' end
    return nil
end

-- Map notification types to flavor text categories
function GetFlavorCategoryForNotification(notificationType, data)
    -- Memory types with specific flavor
    if notificationType == 'memoryAdded' then
        local memoryType = data and data.memoryType
        if memoryType == 'death' then return 'deathMemory' end
        if memoryType == 'kill' then return 'killMemory' end
        if memoryType == 'rescue' or memoryType == 'ems' then return 'emsMemory' end
        if memoryType == 'conflict' or memoryType == 'arrest' then return 'policeMemory' end
        if memoryType == 'location' then return 'locationRevisited' end
        return 'memorySurfaced'
    end
    
    -- Relationship types with context
    if notificationType == 'relationshipUpdated' then
        local value = data and data.value or 0
        local relType = data and data.relationshipType
        if value < -25 then return 'dangerousNearby' end
        if value > 25 then return 'trustedNearby' end
        return 'faceRecognized'
    end
    
    -- Other notification types
    if notificationType == 'rumorAdded' then return 'rumorReceived' end
    if notificationType == 'reputationChanged' then return 'reputationChanged' end
    
    return nil
end

-- ============================================================================
-- Rumor Functions
-- ============================================================================

local function AddRumor(identifier, data)
    if not identifier or not data or not data.content then
        return false, 'Missing identifier or content'
    end
    
    -- Validate rumor type
    local validType = false
    if Config and Config.RumorTypes then
        for _, rt in ipairs(Config.RumorTypes) do
            if rt.id == data.rumorType then validType = true break end
        end
    end
    if not validType then data.rumorType = 'hearsay' end
    
    local expiresAt = nil
    if Config and Config.RumorExpirationDays and Config.RumorExpirationDays > 0 then
        expiresAt = os.time() + (Config.RumorExpirationDays * 86400)
    end
    
    local result = SafeQuery(function()
        return MySQL.insert.await([[
            INSERT INTO lifeprint_rumors
            (identifier, source_identifier, target_identifier, target_name, rumor_type, content, expires_at, created_at, is_demo)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)
        ]], {
            identifier,
            identifier,
            data.targetIdentifier or nil,
            data.targetName or nil,
            data.rumorType,
            data.content,
            data.expiresAt or expiresAt,
            os.time()
        })
    end)
    
    if result then
        DebugLog(('Added rumor for %s'):format(identifier))
        
        -- Send journal notification
        SendJournalNotification(identifier, 'rumorAdded', {
            rumorType = data.rumorType
        })
        
        return true, result
    end
    
    return false, 'Database insert failed'
end

local function DeleteRumor(identifier, rumorId)
    if not identifier or not rumorId then return false end
    
    local result = SafeQuery(function()
        return MySQL.update.await([[
            DELETE FROM lifeprint_rumors
            WHERE id = ? AND (identifier = ? OR source_identifier = ?)
        ]], { rumorId, identifier, identifier })
    end)
    
    return result and result > 0
end

-- ============================================================================
-- Rumor Template System
-- ============================================================================

-- Cache for recent rumor texts to prevent duplicates
local RecentRumorTexts = {}
local MAX_RECENT_RUMORS = 10

--- GenerateRumor: Creates a rumor from category templates
--- @param category string: Category key (police, ems, vehicle, social, suspicious, business, trucking, dot, gang)
--- @param data table: { name, other, location, event } - placeholders to fill
--- @return string|nil: Generated rumor text or nil if disabled/no templates
local function GenerateRumor(category, data)
    -- Check if rumors are enabled
    if not Config or not Config.Rumors or not Config.Rumors.Enabled then
        DebugLog('Rumors disabled in config')
        return nil
    end
    
    -- Check chance percentage
    local chance = Config.Rumors.Chance or 75
    if math.random(1, 100) > chance then
        DebugLog('Rumor chance check failed')
        return nil
    end
    
    -- Validate category
    if not category or type(category) ~= 'string' then
        category = 'hearsay'
    end
    
    -- Get templates for category
    local templates = Config.RumorTemplates and Config.RumorTemplates[category]
    if not templates or #templates == 0 then
        -- Fall back to social category
        templates = Config.RumorTemplates and Config.RumorTemplates.social
        if not templates or #templates == 0 then
            DebugLog('No templates found for category: ' .. tostring(category))
            return nil
        end
    end
    
    -- Ensure data table exists with safe defaults
    data = data or {}
    local placeholders = {
        ['{name}'] = data.name or 'Someone',
        ['{other}'] = data.other or 'an acquaintance',
        ['{location}'] = data.location or 'the city',
        ['{event}'] = data.event or 'an incident'
    }
    
    -- Try to find a non-duplicate rumor (max 5 attempts)
    local generatedText = nil
    local attempts = 0
    local maxAttempts = 5
    
    while attempts < maxAttempts do
        attempts = attempts + 1
        
        -- Pick random template
        local templateIndex = math.random(1, #templates)
        local selectedTemplate = templates[templateIndex]
        
        -- Replace placeholders safely
        generatedText = selectedTemplate
        for placeholder, value in pairs(placeholders) do
            generatedText = generatedText:gsub(placeholder, value)
        end
        
        -- Check for duplicate in recent rumors
        local isDuplicate = false
        for _, recentText in ipairs(RecentRumorTexts) do
            if recentText == generatedText then
                isDuplicate = true
                break
            end
        end
        
        if not isDuplicate then
            -- Add to recent rumors cache
            table.insert(RecentRumorTexts, generatedText)
            if #RecentRumorTexts > MAX_RECENT_RUMORS then
                table.remove(RecentRumorTexts, 1)
            end
            return generatedText
        end
    end
    
    -- All attempts resulted in duplicates, return last generated
    return generatedText
end

-- Clear the recent rumor cache (useful for testing)
function ClearRecentRumorCache()
    RecentRumorTexts = {}
    DebugLog('Recent rumor cache cleared')
end

-- ============================================================================
-- Story Badges System
-- Cosmetic RP achievements based on player history
-- ============================================================================

-- Track unlocked badges per player: identifier -> { badgeId = timestamp }
local PlayerBadges = {}

-- Evaluate a single badge criterion
local function EvaluateBadgeCriterion(identifier, criterion, counters, relationships)
    if not criterion then return false end
    
    local criterionType = criterion.type
    local operator = criterion.operator or '>='
    local requiredValue = criterion.value or 0
    
    local currentValue = 0
    
    if criterionType == 'counter' then
        -- Counter-based criterion (kills, deaths, ems_visits, etc.)
        currentValue = counters and counters[criterion.counter] or 0
        
    elseif criterionType == 'relationship_count' then
        -- Total number of relationships
        currentValue = relationships and #relationships or 0
        
    elseif criterionType == 'face_memory_count' then
        -- Count of remembered faces (relationships with is_face_memory = 1)
        currentValue = 0
        if relationships then
            for _, rel in ipairs(relationships) do
                if rel.is_face_memory then
                    currentValue = currentValue + 1
                end
            end
        end
        
    elseif criterionType == 'negative_relationships' then
        -- Count of negative relationships (score < 0)
        currentValue = 0
        if relationships then
            for _, rel in ipairs(relationships) do
                local score = tonumber(rel.score) or 0
                if score < 0 then
                    currentValue = currentValue + 1
                end
            end
        end
        
    elseif criterionType == 'positive_relationships' then
        -- Count of positive relationships (score > 0)
        currentValue = 0
        if relationships then
            for _, rel in ipairs(relationships) do
                local score = tonumber(rel.score) or 0
                if score > 0 then
                    currentValue = currentValue + 1
                end
            end
        end
        
    elseif criterionType == 'rumor_count' then
        -- Count of rumors about this player
        SafeQuery(function()
            local result = MySQL.query.await('SELECT COUNT(*) as count FROM lifeprint_rumors WHERE identifier = ?', { identifier })
            if result and result[1] then
                currentValue = result[1].count or 0
            end
        end)
        
    elseif criterionType == 'total_activity' then
        -- Sum of all counter values as activity measure
        currentValue = 0
        if counters then
            for _, v in pairs(counters) do
                currentValue = currentValue + (tonumber(v) or 0)
            end
        end
    else
        return false
    end
    
    -- Apply operator
    if operator == '>=' then
        return currentValue >= requiredValue
    elseif operator == '>' then
        return currentValue > requiredValue
    elseif operator == '==' then
        return currentValue == requiredValue
    elseif operator == '<=' then
        return currentValue <= requiredValue
    elseif operator == '<' then
        return currentValue < requiredValue
    end
    
    return false
end

-- Evaluate all criteria for a composite badge
local function EvaluateCompositeBadge(identifier, conditions, requireAll, counters, relationships)
    if not conditions or #conditions == 0 then return false end
    
    local passedCount = 0
    
    for _, condition in ipairs(conditions) do
        if EvaluateBadgeCriterion(identifier, condition, counters, relationships) then
            passedCount = passedCount + 1
            if not requireAll then
                -- OR logic: one pass is enough
                return true
            end
        elseif requireAll then
            -- AND logic: one fail fails all
            return false
        end
    end
    
    return requireAll and passedCount == #conditions
end

-- Check if a badge should be unlocked
local function ShouldUnlockBadge(identifier, badgeDef, counters, relationships)
    if not badgeDef or not badgeDef.criteria then return false end
    
    local criteria = badgeDef.criteria
    
    if criteria.type == 'composite' then
        -- Composite badge with multiple conditions
        return EvaluateCompositeBadge(
            identifier,
            criteria.conditions,
            criteria.requireAll or false,
            counters,
            relationships
        )
    else
        -- Single criterion badge
        return EvaluateBadgeCriterion(identifier, criteria, counters, relationships)
    end
end

-- Get all unlocked badges for a player
function GetPlayerBadges(identifier)
    if not identifier then return {} end
    
    -- Return cached badges if available
    if PlayerBadges[identifier] then
        local badgeIds = {}
        for badgeId, _ in pairs(PlayerBadges[identifier]) do
            table.insert(badgeIds, badgeId)
        end
        return badgeIds
    end
    
    -- Calculate badges from current data
    return CalculatePlayerBadges(identifier)
end

-- Calculate which badges a player should have
function CalculatePlayerBadges(identifier)
    if not identifier then return {} end
    
    local badges = {}
    local config = Config and Config.Badges
    
    if not config or not config.enabled then
        return badges
    end
    
    -- Get player data for evaluation
    local counters = GetPlayerCounters(identifier) or {}
    local relationships = GetPlayerRelationships(identifier) or {}
    
    -- Check each badge definition
    local definitions = config.definitions or {}
    
    for _, badgeDef in ipairs(definitions) do
        if ShouldUnlockBadge(identifier, badgeDef, counters, relationships) then
            table.insert(badges, {
                id = badgeDef.id,
                label = badgeDef.label,
                description = badgeDef.description,
                icon = badgeDef.icon,
                style = badgeDef.style,
                unlockedAt = PlayerBadges[identifier] and PlayerBadges[identifier][badgeDef.id] or os.time()
            })
        end
    end
    
    return badges
end

-- Check for new badge unlocks and notify player
function CheckAndNotifyBadges(identifier, src)
    local config = Config and Config.Badges
    if not config or not config.enabled then return end
    if not identifier or not src then return end
    
    -- Get current badges
    local currentBadges = CalculatePlayerBadges(identifier)
    
    -- Initialize player badge cache if needed
    if not PlayerBadges[identifier] then
        PlayerBadges[identifier] = {}
    end
    
    -- Check for newly unlocked badges
    for _, badge in ipairs(currentBadges) do
        if not PlayerBadges[identifier][badge.id] then
            -- New badge unlocked!
            PlayerBadges[identifier][badge.id] = os.time()
            
            -- Send notification if enabled
            if config.notifyOnUnlock then
                local templates = config.notificationTemplates or { "New badge unlocked: {badge}!" }
                local template = templates[math.random(1, #templates)]
                local message = template:gsub("{badge}", badge.label)
                
                TriggerClientEvent('lifeprint:client:badgeNotification', src, {
                    badge = badge,
                    message = message
                })
                
                DebugLog(('Badge unlocked for %s: %s'):format(identifier, badge.label))
            end
        end
    end
    
    -- Update NUI if open
    TriggerClientEvent('lifeprint:client:updateBadges', src, {
        badges = currentBadges
    })
end

-- Export badge functions
exports('GetPlayerBadges', GetPlayerBadges)
exports('CalculatePlayerBadges', CalculatePlayerBadges)

-- ============================================================================
-- City Nicknames System
-- Dynamic RP identity based on reputation and memories
-- ============================================================================

-- Track current nickname per player: identifier -> { id, nickname, changedAt }
local PlayerNicknames = {}

-- Evaluate a nickname rule against player data
local function EvaluateNicknameRule(identifier, rule, counters, relationships)
    if not rule or not rule.criteria then return false end
    
    local criteria = rule.criteria
    
    if criteria.type == 'composite' then
        return EvaluateCompositeBadge(
            identifier,
            criteria.conditions,
            criteria.requireAll or false,
            counters,
            relationships
        )
    else
        return EvaluateBadgeCriterion(identifier, criteria, counters, relationships)
    end
end

-- Generate a city nickname for a player based on their reputation
function GenerateCityNickname(identifier)
    if not identifier then
        return {
            id = 'default',
            nickname = Config.CityNicknames and Config.CityNicknames.defaultNickname or 'Newcomer',
            style = Config.CityNicknames and Config.CityNicknames.defaultStyle or 'neutral',
            description = 'A new arrival to the city'
        }
    end
    
    local config = Config and Config.CityNicknames
    if not config or not config.enabled then
        return {
            id = 'default',
            nickname = config and config.defaultNickname or 'Newcomer',
            style = config and config.defaultStyle or 'neutral',
            description = 'A new arrival to the city'
        }
    end
    
    -- Get player data for evaluation
    local counters = GetPlayerCounters(identifier) or {}
    local relationships = GetPlayerRelationships(identifier) or {}
    
    -- Sort rules by priority (highest first)
    local sortedRules = {}
    for _, rule in ipairs(config.rules or {}) do
        table.insert(sortedRules, rule)
    end
    table.sort(sortedRules, function(a, b) return (a.priority or 0) > (b.priority or 0) end)
    
    -- Find first matching rule
    for _, rule in ipairs(sortedRules) do
        if EvaluateNicknameRule(identifier, rule, counters, relationships) then
            return {
                id = rule.id,
                nickname = rule.nickname,
                style = rule.style,
                description = rule.description
            }
        end
    end
    
    -- No match, return default
    return {
        id = 'default',
        nickname = config.defaultNickname or 'Newcomer',
        style = config.defaultStyle or 'neutral',
        description = 'A new arrival to the city'
    }
end

-- Get the player's current city nickname
function GetPlayerNickname(identifier)
    if not identifier then
        return GenerateCityNickname(nil)
    end
    
    -- Return cached nickname if available and recent (within 5 minutes)
    if PlayerNicknames[identifier] then
        local cached = PlayerNicknames[identifier]
        if os.time() - (cached.changedAt or 0) < 300 then
            return {
                id = cached.id,
                nickname = cached.nickname,
                style = cached.style,
                description = cached.description
            }
        end
    end
    
    -- Generate fresh nickname
    return GenerateCityNickname(identifier)
end

-- Check if nickname has changed and notify player
function CheckAndNotifyNicknameChange(identifier, src)
    local config = Config and Config.CityNicknames
    if not config or not config.enabled then return end
    if not identifier or not src then return end
    
    -- Get new nickname
    local newNickname = GenerateCityNickname(identifier)
    
    -- Get old nickname
    local oldNickname = PlayerNicknames[identifier]
    
    -- Check if nickname changed
    local changed = false
    if not oldNickname then
        -- First time getting a nickname
        changed = true
    elseif oldNickname.id ~= newNickname.id then
        -- Nickname actually changed
        changed = true
    end
    
    if changed then
        -- Cache new nickname
        PlayerNicknames[identifier] = {
            id = newNickname.id,
            nickname = newNickname.nickname,
            style = newNickname.style,
            description = newNickname.description,
            changedAt = os.time()
        }
        
        -- Send notification if enabled (skip for first-time/default nickname)
        if config.notifyOnChange and oldNickname and newNickname.id ~= 'default' then
            local templates = config.notificationTemplates or { "The city has a new name for you: {nickname}" }
            local template = templates[math.random(1, #templates)]
            local message = template:gsub("{nickname}", newNickname.nickname)
            
            TriggerClientEvent('lifeprint:client:nicknameNotification', src, {
                nickname = newNickname.nickname,
                style = newNickname.style,
                message = message
            })
            
            DebugLog(('Nickname changed for %s: %s'):format(identifier, newNickname.nickname))
        end
        
        -- Update NUI if open
        TriggerClientEvent('lifeprint:client:updateNickname', src, {
            nickname = newNickname
        })
    end
    
    return newNickname
end

-- Export nickname functions
exports('GetPlayerNickname', GetPlayerNickname)
exports('GenerateCityNickname', GenerateCityNickname)

-- Determine rumor category from integration module
local function GetRumorCategoryFromModule(moduleName)
    local categoryMap = {
        Police = 'police',
        EMS = 'ems',
        Jail = 'police',
        Billing = 'business',
        Gang = 'gang',
        Business = 'business',
        Trucking = 'trucking',
        DOT = 'dot'
    }
    return categoryMap[moduleName] or 'hearsay'
end

-- Determine rumor type from category
local function GetRumorTypeFromCategory(category)
    local typeMap = {
        police = 'crime',
        ems = 'hearsay',
        vehicle = 'hearsay',
        social = 'hearsay',
        suspicious = 'secret',
        business = 'business',
        trucking = 'business',
        dot = 'hearsay',
        gang = 'secret'
    }
    return typeMap[category] or 'hearsay'
end

-- ============================================================================
-- Initialization
-- ============================================================================

CreateThread(function()
    -- Wait for framework
    Wait(500)
    
    -- Initialize bridge
    if Bridge and Bridge.Initialize then
        Bridge.Initialize()
    end
    
    DebugLog(('Initialized with framework: %s'):format(Bridge and Bridge.GetFramework and Bridge.GetFramework() or 'unknown'))
end)

-- ============================================================================
-- Server Event: Get Player Data
-- ============================================================================

RegisterNetEvent('lifeprint:server:getData', function()
    local src = source
    
    if not ValidateSource(src) then return end
    
    DebugLog('getData from source: ' .. tostring(src))
    
    local identifier = Bridge and Bridge.GetIdentifier and Bridge.GetIdentifier(src)
    
    if not identifier then
        DebugLog('No identifier for source: ' .. tostring(src), 'warn')
        -- Send fallback data
        TriggerClientEvent('lifeprint:client:openNUI', src, {
            player = { identifier = 'unknown', name = GetPlayerName(src) or 'Unknown', lastUpdated = os.time() },
            memories = {}, relationships = {}, reputation = {}, rumors = {},
            counters = {}, tags = {},
            characterRead = (Config and Config.CharacterReadTemplates and Config.CharacterReadTemplates.neutral) or '',
            config = {
                memoryTypes = Config and Config.MemoryTypes or {},
                relationshipTypes = Config and Config.RelationshipTypes or {},
                reputationCategories = Config and Config.ReputationCategories or {},
                reputationRanges = Config and Config.ReputationRanges or {},
                rumorTypes = Config and Config.RumorTypes or {}
            }
        })
        return
    end
    
    -- Get data with pcall wrapper
    local ok, err = pcall(function()
        local playerName = Bridge.GetCharacterName(src) or GetPlayerName(src) or 'Unknown'
        local lifeprint = GetPlayerLifeprint(identifier)
        local counters = GetPlayerCounters(identifier)
        local tags = GenerateTagsFromCounters(counters)
        local characterRead = GenerateCharacterRead(tags, counters)
        
        -- Add names and photo fields
        for _, rel in ipairs(lifeprint.relationships) do
            rel.targetName = rel.target_name or (Bridge.GetCharacterNameByIdentifier and Bridge.GetCharacterNameByIdentifier(rel.target_identifier)) or rel.target_identifier
            -- Ensure photo/avatar fields are set (prefer photo over avatar_url)
            rel.photo = rel.photo or nil
            rel.avatar_url = rel.avatar_url or nil
            rel.is_face_memory = rel.is_face_memory or 0
            rel.memory_strength = rel.memory_strength or 1
            -- Debug log photo data
            if Config and Config.Debug then
                DebugLog(('Relationship %s: photo=%s, avatar=%s, is_face_memory=%s'):format(
                    rel.targetName or 'Unknown',
                    rel.photo and 'YES' or 'NO',
                    rel.avatar_url and 'YES' or 'NO',
                    tostring(rel.is_face_memory)
                ))
            end
        end
        for _, mem in ipairs(lifeprint.memories) do
            if mem.target_identifier then
                mem.targetName = (Bridge.GetCharacterNameByIdentifier and Bridge.GetCharacterNameByIdentifier(mem.target_identifier)) or mem.target_identifier
            end
        end
        for _, rum in ipairs(lifeprint.rumors) do
            if rum.target_identifier then
                rum.targetName = rum.target_name or (Bridge.GetCharacterNameByIdentifier and Bridge.GetCharacterNameByIdentifier(rum.target_identifier))
            end
        end
        
        -- Get player settings
        local settings = GetPlayerSettings(identifier)
        
        -- Get player badges
        local badges = CalculatePlayerBadges(identifier)
        
        -- Get player city nickname
        local nickname = GetPlayerNickname(identifier)
        
        TriggerClientEvent('lifeprint:client:openNUI', src, {
            player = { identifier = identifier, name = playerName, lastUpdated = os.time(), nickname = nickname },
            memories = lifeprint.memories,
            relationships = lifeprint.relationships,
            reputation = lifeprint.reputation,
            rumors = lifeprint.rumors,
            counters = counters or {},
            tags = tags,
            characterRead = characterRead,
            settings = settings,
            badges = badges,
            nickname = nickname,
            config = {
                memoryTypes = Config and Config.MemoryTypes or {},
                relationshipTypes = Config and Config.RelationshipTypes or {},
                reputationCategories = Config and Config.ReputationCategories or {},
                reputationRanges = Config and Config.ReputationRanges or {},
                rumorTypes = Config and Config.RumorTypes or {},
                tagStyles = Config and Config.ReputationTagStyles or {}
            }
        })
    end)
    
    if not ok then
        LogError('getData error: ' .. tostring(err))
        -- Send safe fallback
        TriggerClientEvent('lifeprint:client:openNUI', src, {
            player = { identifier = identifier or 'error', name = GetPlayerName(src) or 'Unknown', lastUpdated = os.time() },
            memories = {}, relationships = {}, reputation = {}, rumors = {},
            counters = {}, tags = {},
            characterRead = 'Error loading data. Please try again.',
            config = {}
        })
    end
end)

-- ============================================================================
-- Settings Events (Privacy Controls)
-- ============================================================================

-- Get player settings
RegisterNetEvent('lifeprint:server:getSettings', function()
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    local settings = GetPlayerSettings(identifier)
    
    TriggerClientEvent('lifeprint:client:openSettings', src, { settings = settings })
end)

-- Save player settings
RegisterNetEvent('lifeprint:server:saveSettings', function(settings)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    -- Validate settings table
    if type(settings) ~= 'table' then return end
    
    local success = SavePlayerSettings(identifier, settings)
    
    if success then
        if Bridge and Bridge.Notify then
            Bridge.Notify(src, 'Privacy settings saved', 'success')
        else
            TriggerClientEvent('lifeprint:client:notify', src, 'Privacy settings saved')
        end
    else
        if Bridge and Bridge.Notify then
            Bridge.Notify(src, 'Failed to save settings', 'error')
        end
    end
end)

-- ============================================================================
-- Memory Brain Event
-- ============================================================================

RegisterNetEvent('lifeprint:server:getMemoryBrain', function()
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then
        TriggerClientEvent('lifeprint:client:updateMemoryBrain', src, {
            good = 0, bad = 0, rumors = 0, other = 0, total = 0,
            dominant = 'other',
            brainRead = "Your Lifeprint is empty. The city doesn't know you yet.",
            recent = { good = {}, bad = {}, rumors = {}, other = {} }
        })
        return
    end
    
    local brainData = GetMemoryBrain(identifier)
    TriggerClientEvent('lifeprint:client:updateMemoryBrain', src, brainData)
end)

-- ============================================================================
-- Admin Command: /lpdemo (Cinematic Demo for Contest Judging)
-- Creates a polished, story-driven profile showcasing all Lifeprint features
-- ============================================================================

RegisterNetEvent('lifeprint:server:adminDemo', function()
    local src = source
    if not ValidateSource(src) then return end
    
    -- Check permission
    if not (Bridge and Bridge.HasPermission and Bridge.HasPermission(src, 'lifeprint.admin')) then
        if Bridge and Bridge.Notify then Bridge.Notify(src, 'You do not have permission', 'error') end
        return
    end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then
        if Bridge.Notify then Bridge.Notify(src, 'Unable to get your identifier', 'error') end
        return
    end
    
    -- Start batch mode to suppress individual notifications during demo generation
    StartDemoBatch(identifier)
    
    -- Clear ALL old demo data for this player (prevents any duplicates)
    SafeQuery(function() MySQL.update('DELETE FROM lifeprint_memories WHERE identifier = ? AND is_demo = 1', { identifier }) end)
    SafeQuery(function() MySQL.update('DELETE FROM lifeprint_relationships WHERE identifier = ? AND is_demo = 1', { identifier }) end)
    SafeQuery(function() MySQL.update('DELETE FROM lifeprint_rumors WHERE identifier = ? AND is_demo = 1', { identifier }) end)
    SafeQuery(function() MySQL.update('DELETE FROM lifeprint_reputation WHERE identifier = ?', { identifier }) end)
    SafeQuery(function() MySQL.update('DELETE FROM lifeprint_reputation_counters WHERE identifier = ?', { identifier }) end)
    
    local playerName = Bridge.GetCharacterName(src) or GetPlayerName(src) or 'Someone'
    local now = os.time()
    
    -- =========================================================================
    -- CINEMATIC TIMELINE (Story Arc: 7 days in the life)
    -- =========================================================================
    -- Day 1: Social Contact - Meet Mara Voss at Legion Square
    -- Day 2: Vehicle Crash - Sultan wreck on Vespucci coast
    -- Day 2: EMS Treatment - Dr. Bishop at Pillbox
    -- Day 3: Police Arrest - Officer Hill detains for questioning
    -- Day 3: Release - Walk out of Mission Row
    -- Day 5: Helpful Act - Help Lena Cross with flat tire
    -- Day 6: Suspicious Activity - Dex Carter spots something
    -- Day 7: Reputation Growth - City starting to recognize
    -- =========================================================================
    
    -- Define relationships FIRST (needed for memory target name lookup)
    local relationships = {
        { target = 'demo_mara_voss', name = 'Mara Voss' },
        { target = 'demo_officer_hill', name = 'Officer Hill' },
        { target = 'demo_dr_bishop', name = 'Dr. Bishop' },
        { target = 'demo_lena_cross', name = 'Lena Cross' },
        { target = 'demo_dex_carter', name = 'Dex Carter' }
    }
    
    -- Helper to lookup name from target identifier
    local function getDemoTargetName(targetId)
        if not targetId then return nil end
        for _, rel in ipairs(relationships) do
            if rel.target == targetId then
                return rel.name
            end
        end
        return nil
    end
    
    local memories = {
        -- Day 1: First Contact
        {
            target = 'demo_mara_voss',
            type = 'encounter',
            title = 'First Day in Los Santos',
            desc = 'Met Mara Voss by the Legion Square fountain. She was sketching the skyline, said she\'d just moved here too. We talked about finding our footing in a new city.',
            loc = 'Legion Square',
            time = now - 604800,
            visibility = 'private'
        },
        -- Day 2: The Crash
        {
            target = nil,
            type = 'crime',
            title = 'Coastal Wreck',
            desc = 'Lost the Sultan RS on a tight curve near Vespucci. The guardrail caught the driver side. Walked away with cuts and bruises, but the car was beyond saving.',
            loc = 'Vespucci Beach Coast',
            time = now - 518400,
            visibility = 'private'
        },
        -- Day 2: EMS Response
        {
            target = 'demo_dr_bishop',
            type = 'rescue',
            title = 'Pillbox Emergency',
            desc = 'Dr. Bishop was on shift when EMS brought me in. Calm hands, steady voice. She stitched the gash on my forearm and told me I was lucky. Said she sees worse every night.',
            loc = 'Pillbox Hill Medical Center',
            time = now - 517800,
            visibility = 'public'
        },
        -- Day 3: Police Encounter
        {
            target = 'demo_officer_hill',
            type = 'conflict',
            title = 'Traffic Stop Gone Wrong',
            desc = 'Officer Hill pulled me over on Vespucci. Said my vehicle matched a suspect description from last night. Handcuffs, back of the cruiser, downtown. The city looks different through those windows.',
            loc = 'Vespucci Boulevard',
            time = now - 432000,
            visibility = 'private'
        },
        -- Day 3: Release
        {
            target = 'demo_officer_hill',
            type = 'encounter',
            title = 'Released Without Charges',
            desc = 'Walked out of Mission Row at dawn. Officer Hill handed back my things with an apology that felt genuine. Said the real suspect was caught an hour ago. Small comfort, but something.',
            loc = 'Mission Row Station',
            time = now - 430200,
            visibility = 'public'
        },
        -- Day 5: Good Deed
        {
            target = 'demo_lena_cross',
            type = 'friendship',
            title = 'Stranded at Mirror Park',
            desc = 'Found Lena Cross on the side of Palomino Ave, jack in hand, tire shredded. Helped her swap the spare in the rain. She insisted on buying me coffee after. Turned into a two-hour conversation about the city, about what we\'re all looking for.',
            loc = 'Mirror Park',
            time = now - 259200,
            visibility = 'public'
        },
        -- Day 6: Uncomfortable Moment
        {
            target = 'demo_dex_carter',
            type = 'encounter',
            title = 'Docks After Dark',
            desc = 'Took a wrong turn near the Port of Los Santos. Dex Carter was there, standing beside a shipping container that had no business being open at this hour. He noticed me noticing. We exchanged names before I walked away. His eyes stayed on my back.',
            loc = 'La Puerta Docks',
            time = now - 86400,
            visibility = 'private'
        },
        -- Day 7: Growth
        {
            target = nil,
            type = 'business',
            title = 'The City Remembers',
            desc = 'A week in Los Santos. I\'m starting to recognize faces on the street. The barista at the cafe on Hawick knows my order. A shop owner on Legion nodded at me today. The city\'s a web, and I\'m finding my thread.',
            loc = 'Los Santos',
            time = now - 7200,
            visibility = 'public'
        }
    }
    
    for _, mem in ipairs(memories) do
        local targetName = getDemoTargetName(mem.target)
        
        SafeQuery(function()
            MySQL.insert.await([[
                INSERT INTO lifeprint_memories 
                (identifier, target_identifier, target_name, memory_type, title, description, location, timestamp, visibility, is_demo)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
            ]], { identifier, mem.target, targetName, mem.type, mem.title, mem.desc, mem.loc, mem.time, mem.visibility or 'private' })
        end)
    end
    
    -- =========================================================================
    -- RELATIONSHIPS (Realistic notes, meaningful connections)
    -- =========================================================================
    
    local relationships = {
        {
            target = 'demo_mara_voss',
            name = 'Mara Voss',
            value = 35,
            rtype = 'acquaintance',
            notes = 'Artist. New to the city like me. Met at Legion Square fountain. She draws the skyline at sunset.',
            location = 'Legion Square'
        },
        {
            target = 'demo_officer_hill',
            name = 'Officer Hill',
            value = -10,
            rtype = 'adversary',
            notes = 'LSPD traffic division. Arrested then released me. Genuinely apologized afterward. Complicated.',
            location = 'Mission Row'
        },
        {
            target = 'demo_dr_bishop',
            name = 'Dr. Bishop',
            value = 40,
            rtype = 'acquaintance',
            notes = 'Emergency physician at Pillbox. Steady hands, calm voice. Patched me up after the crash.',
            location = 'Pillbox Medical'
        },
        {
            target = 'demo_lena_cross',
            name = 'Lena Cross',
            value = 65,
            rtype = 'friend',
            notes = 'Met when her tire blew on Palomino. Talked for hours over coffee. She knows the city better than most.',
            location = 'Mirror Park'
        },
        {
            target = 'demo_dex_carter',
            name = 'Dex Carter',
            value = -5,
            rtype = 'stranger',
            notes = 'Found him at the docks after dark. Something wasn\'t right. He made sure I knew he saw me.',
            location = 'La Puerta'
        }
    }
    
    for _, rel in ipairs(relationships) do
        SafeQuery(function()
            MySQL.insert.await([[
                INSERT INTO lifeprint_relationships 
                (identifier, target_identifier, target_name, relationship_value, relationship_type, first_met, last_interaction, notes, first_location, is_demo)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
            ]], { identifier, rel.target, rel.name, rel.value, rel.rtype, now - 604800, now - 7200, rel.notes, rel.location })
        end)
    end
    
    -- =========================================================================
    -- CITY RUMORS (Anonymous whispers, gossip style)
    -- =========================================================================
    
    local rumors = {
        {
            content = 'Someone matching that description came into Pillbox bleeding bad. Nurse said they were lucky to walk.',
            rtype = 'hearsay'
        },
        {
            content = 'Word is LSPD picked them up, then cut them loose a day later. Don\'t know what that\'s about.',
            rtype = 'crime'
        },
        {
            content = 'Heard they helped a girl with a flat tire near Mirror Park. She bought them coffee. Doesn\'t sound like the type.',
            rtype = 'achievement'
        },
        {
            content = 'Dex was asking around about someone new. Said they saw something at the port. Wouldn\'t say what.',
            rtype = 'secret'
        },
        {
            content = 'People around Legion Square are starting to recognize that face. New regular, maybe. Or something else.',
            rtype = 'social'
        }
    }
    
    for _, rum in ipairs(rumors) do
        SafeQuery(function()
            MySQL.insert.await([[
                INSERT INTO lifeprint_rumors 
                (identifier, source_identifier, rumor_type, content, target_name, created_at, is_demo)
                VALUES (?, ?, ?, ?, ?, ?, 1)
            ]], { identifier, identifier, rum.rtype, rum.content, playerName, now })
        end)
    end
    
    -- =========================================================================
    -- REPUTATION COUNTERS & TAGS
    -- =========================================================================
    
    InitializeCounters(identifier)
    SetCounter(identifier, 'arrests', 1)           -- One arrest on record
    SetCounter(identifier, 'ems_visits', 1)        -- One hospital visit
    SetCounter(identifier, 'crashes', 1)           -- One vehicle incident
    SetCounter(identifier, 'meetings', 5)          -- Five meaningful contacts
    SetCounter(identifier, 'helpful_actions', 1)    -- One good deed
    SetCounter(identifier, 'suspicious_actions', 1) -- One questionable sighting
    
    -- =========================================================================
    -- REPUTATION ENTRIES (Per-category standing)
    -- =========================================================================
    
    SafeQuery(function()
        MySQL.insert.await([[
            INSERT INTO lifeprint_reputation (identifier, category, reputation_value, notes, last_updated)
            VALUES (?, 'general', 15, 'New to the city, making connections', ?)
        ]], { identifier, now })
    end)
    
    SafeQuery(function()
        MySQL.insert.await([[
            INSERT INTO lifeprint_reputation (identifier, category, reputation_value, notes, last_updated)
            VALUES (?, 'law', -5, 'Detained and released, no charges', ?)
        ]], { identifier, now })
    end)
    
    SafeQuery(function()
        MySQL.insert.await([[
            INSERT INTO lifeprint_reputation (identifier, category, reputation_value, notes, last_updated)
            VALUES (?, 'medical', 10, 'Known patient at Pillbox', ?)
        ]], { identifier, now })
    end)
    
    SafeQuery(function()
        MySQL.insert.await([[
            INSERT INTO lifeprint_reputation (identifier, category, reputation_value, notes, last_updated)
            VALUES (?, 'underground', -10, 'Spotted in sensitive area', ?)
        ]], { identifier, now })
    end)
    
    DebugLog(('Cinematic demo created for %s'):format(identifier))
    
    -- =========================================================================
    -- SEND TO CLIENT
    -- =========================================================================
    
    if Bridge.Notify then Bridge.Notify(src, 'Lifeprint demo profile generated.', 'success') end
    
    -- Get fresh data
    local lifeprint = GetPlayerLifeprint(identifier)
    local counters = GetPlayerCounters(identifier)
    local tags = GenerateTagsFromCounters(counters)
    local characterRead = GenerateCharacterRead(tags, counters)
    
    -- Generate strong character read if server version is generic
    if not characterRead or characterRead == '' then
        characterRead = 'A week in Los Santos has marked this one. They\'ve seen the inside of a patrol car and an emergency room, walked away from a totaled car and a misunderstanding with the law. But they\'ve also stopped in the rain to help a stranger. The city\'s still figuring them out—and they\'re still figuring out the city.'
    end
    
    TriggerClientEvent('lifeprint:client:demoComplete', src, {
        player = { identifier = identifier, name = playerName, lastUpdated = now },
        memories = lifeprint.memories,
        relationships = lifeprint.relationships,
        reputation = lifeprint.reputation,
        rumors = lifeprint.rumors,
        counters = counters or {},
        tags = tags,
        characterRead = characterRead,
        config = {
            memoryTypes = Config and Config.MemoryTypes or {},
            relationshipTypes = Config and Config.RelationshipTypes or {},
            reputationCategories = Config and Config.ReputationCategories or {},
            rumorTypes = Config and Config.RumorTypes or {}
        }
    })
end)

-- ============================================================================
-- Admin Command: /lpwipe (admin only, wipes own data)
-- ============================================================================

RegisterNetEvent('lifeprint:server:adminWipe', function()
    local src = source
    if not ValidateSource(src) then return end
    
    if not (Bridge and Bridge.HasPermission and Bridge.HasPermission(src, 'lifeprint.admin')) then
        if Bridge.Notify then Bridge.Notify(src, 'You do not have permission', 'error') end
        return
    end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then
        if Bridge.Notify then Bridge.Notify(src, 'Unable to get your identifier', 'error') end
        return
    end
    
    SafeQuery(function() MySQL.update('DELETE FROM lifeprint_memories WHERE identifier = ?', { identifier }) end)
    SafeQuery(function() MySQL.update('DELETE FROM lifeprint_relationships WHERE identifier = ?', { identifier }) end)
    SafeQuery(function() MySQL.update('DELETE FROM lifeprint_reputation WHERE identifier = ?', { identifier }) end)
    SafeQuery(function() MySQL.update('DELETE FROM lifeprint_reputation_counters WHERE identifier = ?', { identifier }) end)
    SafeQuery(function() MySQL.update('DELETE FROM lifeprint_rumors WHERE identifier = ?', { identifier }) end)
    
    DebugLog(('Data wiped for %s'):format(identifier))
    if Bridge.Notify then Bridge.Notify(src, 'Your Lifeprint data has been wiped', 'success') end
end)

-- ============================================================================
-- Admin Command: /lpaddmemory (admin only, accepts args)
-- ============================================================================

RegisterNetEvent('lifeprint:server:adminAddMemoryCustom', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    if not (Bridge and Bridge.HasPermission and Bridge.HasPermission(src, 'lifeprint.admin')) then
        if Bridge.Notify then Bridge.Notify(src, 'You do not have permission', 'error') end
        return
    end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then
        if Bridge.Notify then Bridge.Notify(src, 'Unable to get your identifier', 'error') end
        return
    end
    
    local success, result = AddMemory(identifier, {
        memoryType = data.memoryType or 'other',
        description = data.description or 'Test memory',
        location = 'Admin Location',
        timestamp = os.time()
    })
    
    if success then
        if Bridge.Notify then Bridge.Notify(src, 'Memory added: ' .. (data.description or 'Test memory'), 'success') end
    else
        if Bridge.Notify then Bridge.Notify(src, 'Failed to add memory', 'error') end
    end
end)

RegisterNetEvent('lifeprint:server:adminAddMemory', function()
    -- Legacy handler (no args)
    TriggerEvent('lifeprint:server:adminAddMemoryCustom', { memoryType = 'other', description = 'Test memory added via command' })
end)

-- ============================================================================
-- Other Server Events (addMemory, updateRelationship, etc.)
-- ============================================================================

RegisterNetEvent('lifeprint:server:addMemory', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    local success = AddMemory(identifier, data or {})
    if Bridge.Notify then Bridge.Notify(src, success and 'Memory added' or 'Failed to add memory', success and 'success' or 'error') end
end)

RegisterNetEvent('lifeprint:server:updateRelationship', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    local success = AddRelationship(identifier, data or {})
    if Bridge.Notify then Bridge.Notify(src, success and 'Relationship updated' or 'Failed', success and 'success' or 'error') end
end)

RegisterNetEvent('lifeprint:server:saveRelationshipNote', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    if not data or not data.targetIdentifier then
        if Bridge.Notify then Bridge.Notify(src, 'No target specified', 'error') end
        return
    end
    
    local success, err = UpdateRelationshipNotes(identifier, data.targetIdentifier, data.notes)
    if success then
        if Bridge.Notify then Bridge.Notify(src, 'Note saved', 'success') end
    else
        if Bridge.Notify then Bridge.Notify(src, 'Failed: ' .. (err or 'unknown'), 'error') end
    end
end)

-- Save face photo for a relationship
RegisterNetEvent('lifeprint:server:saveFacePhoto', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    -- Validate data
    if not data or not data.targetIdentifier or not data.photoUrl then
        if Bridge.Notify then Bridge.Notify(src, 'Invalid photo data', 'error') end
        return
    end
    
    -- Validate URL length
    local maxLen = (Config and Config.FacePhoto and Config.FacePhoto.maxUrlLength) or 500
    if #data.photoUrl > maxLen then
        if Bridge.Notify then Bridge.Notify(src, 'Photo URL too long', 'error') end
        return
    end
    
    -- Validate URL protocol if allowUrls is enabled
    local facePhotoConfig = Config and Config.FacePhoto or {}
    if facePhotoConfig.allowUrls then
        local validProtocol = false
        local allowedProtocols = facePhotoConfig.allowedProtocols or { "http://", "https://", "nui://" }
        for _, protocol in ipairs(allowedProtocols) do
            if data.photoUrl:sub(1, #protocol) == protocol then
                validProtocol = true
                break
            end
        end
        if not validProtocol then
            if Bridge.Notify then Bridge.Notify(src, 'Invalid photo URL format', 'error') end
            return
        end
    end
    
    -- Verify player owns this relationship
    local relCheck = SafeQuery(function()
        return MySQL.query.await([[
            SELECT id FROM lifeprint_relationships
            WHERE identifier = ? AND target_identifier = ?
        ]], { identifier, data.targetIdentifier })
    end)
    
    if not relCheck or #relCheck == 0 then
        if Bridge.Notify then Bridge.Notify(src, 'Relationship not found', 'error') end
        return
    end
    
    -- Update the photo
    local success = SafeQuery(function()
        MySQL.update.await([[
            UPDATE lifeprint_relationships
            SET photo = ?, is_face_memory = 1, updated_at = NOW()
            WHERE identifier = ? AND target_identifier = ?
        ]], { data.photoUrl, identifier, data.targetIdentifier })
        return true
    end)
    
    if success then
        if Bridge.Notify then Bridge.Notify(src, 'Face photo saved', 'success') end
        DebugLog(('Face photo saved for %s -> %s'):format(identifier, data.targetIdentifier))
    else
        if Bridge.Notify then Bridge.Notify(src, 'Failed to save photo', 'error') end
    end
end)

-- Face photo command handler (called from client)
RegisterNetEvent('lifeprint:server:setFacePhoto', function(targetServerId, photoUrl)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    -- Validate target exists
    local targetIdentifier = Bridge.GetIdentifier(targetServerId)
    if not targetIdentifier then
        if Bridge.Notify then Bridge.Notify(src, 'Target player not found', 'error') end
        return
    end
    
    -- Validate URL
    local maxLen = (Config and Config.FacePhoto and Config.FacePhoto.maxUrlLength) or 500
    if not photoUrl or #photoUrl > maxLen then
        if Bridge.Notify then Bridge.Notify(src, 'Invalid photo URL', 'error') end
        return
    end
    
    -- Check if relationship exists
    local existingRel = SafeQuery(function()
        return MySQL.query.await([[
            SELECT id FROM lifeprint_relationships
            WHERE identifier = ? AND target_identifier = ?
        ]], { identifier, targetIdentifier })
    end)
    
    if existingRel and #existingRel > 0 then
        -- Update existing
        SafeQuery(function()
            MySQL.update.await([[
                UPDATE lifeprint_relationships
                SET photo = ?, is_face_memory = 1, updated_at = NOW()
                WHERE identifier = ? AND target_identifier = ?
            ]], { photoUrl, identifier, targetIdentifier })
        end)
    else
        -- Create new relationship with photo
        local targetName = Bridge.GetCharacterName(targetServerId) or GetPlayerName(targetServerId) or 'Unknown'
        SafeQuery(function()
            MySQL.insert.await([[
                INSERT INTO lifeprint_relationships
                (identifier, target_identifier, target_name, relationship_value, relationship_type, photo, is_face_memory, first_met, last_interaction)
                VALUES (?, ?, ?, 10, 'acquaintance', ?, 1, ?, ?)
                ON DUPLICATE KEY UPDATE photo = ?, is_face_memory = 1, updated_at = NOW()
            ]], { identifier, targetIdentifier, targetName, photoUrl, os.time(), os.time(), photoUrl })
        end)
    end
    
    if Bridge.Notify then Bridge.Notify(src, 'Face photo saved successfully', 'success') end
    DebugLog(('Face photo set via command: %s -> %s'):format(identifier, targetIdentifier))
end)

RegisterNetEvent('lifeprint:server:addReputation', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    local success = AddReputation(identifier, data or {})
    if Bridge.Notify then Bridge.Notify(src, success and 'Reputation updated' or 'Failed', success and 'success' or 'error') end
end)

RegisterNetEvent('lifeprint:server:addRumor', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    local success = AddRumor(identifier, data or {})
    if Bridge.Notify then Bridge.Notify(src, success and 'Rumor recorded' or 'Failed', success and 'success' or 'error') end
end)

RegisterNetEvent('lifeprint:server:deleteMemory', function(memoryId)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier or not memoryId then return end
    
    local success = DeleteMemory(identifier, memoryId)
    if Bridge.Notify then Bridge.Notify(src, success and 'Memory removed' or 'Failed', success and 'success' or 'error') end
end)

RegisterNetEvent('lifeprint:server:deleteRumor', function(rumorId)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier or not rumorId then return end
    
    local success = DeleteRumor(identifier, rumorId)
    if Bridge.Notify then Bridge.Notify(src, success and 'Rumor removed' or 'Failed', success and 'success' or 'error') end
end)

RegisterNetEvent('lifeprint:server:searchPlayers', function(query)
    local src = source
    if not ValidateSource(src) then return end
    
    if not query or #query < 2 then
        TriggerClientEvent('lifeprint:client:searchResults', src, {})
        return
    end
    
    local results = {}
    local framework = Bridge and Bridge.GetFramework and Bridge.GetFramework()
    
    -- Framework-specific search (simplified, with pcall)
    pcall(function()
        local players = GetPlayers()
        for _, pSrc in ipairs(players) do
            local pSource = tonumber(pSrc)
            if pSource and pSource > 0 then
                local name = Bridge.GetCharacterName(pSource) or GetPlayerName(pSource)
                if name and name:lower():find(query:lower()) then
                    table.insert(results, {
                        identifier = Bridge.GetIdentifier(pSource) or 'unknown',
                        name = name
                    })
                    if #results >= 10 then break end
                end
            end
        end
    end)
    
    TriggerClientEvent('lifeprint:client:searchResults', src, results)
end)

-- ============================================================================
-- Admin Panel Events
-- ============================================================================

RegisterNetEvent('lifeprint:server:adminOpenPanel', function()
    local src = source
    if not ValidateSource(src) then return end
    
    if not (Bridge and Bridge.HasPermission and Bridge.HasPermission(src, 'lifeprint.admin')) then
        if Bridge.Notify then Bridge.Notify(src, 'You do not have permission', 'error') end
        return
    end
    
    DebugLog(('Admin panel opened by %d'):format(src))
    
    local players = {}
    pcall(function()
        for _, pSrc in ipairs(GetPlayers()) do
            local pSource = tonumber(pSrc)
            if pSource and pSource > 0 then
                table.insert(players, {
                    serverId = pSource,
                    identifier = Bridge.GetIdentifier(pSource) or 'unknown',
                    name = Bridge.GetCharacterName(pSource) or GetPlayerName(pSource) or 'Unknown'
                })
            end
        end
    end)
    
    TriggerClientEvent('lifeprint:client:openAdminPanel', src, {
        players = players,
        isAdmin = true,
        config = {
            memoryTypes = Config and Config.MemoryTypes or {},
            rumorTypes = Config and Config.RumorTypes or {},
            counterTypes = Config and Config.ReputationCounterTypes or {}
        }
    })
end)

RegisterNetEvent('lifeprint:server:adminSearchPlayer', function(serverId)
    local src = source
    if not ValidateSource(src) then return end
    
    if not (Bridge and Bridge.HasPermission and Bridge.HasPermission(src, 'lifeprint.admin')) then
        if Bridge.Notify then Bridge.Notify(src, 'No permission', 'error') end
        return
    end
    
    serverId = tonumber(serverId)
    if not serverId or serverId <= 0 then
        if Bridge.Notify then Bridge.Notify(src, 'Invalid server ID', 'error') end
        return
    end
    
    local identifier = Bridge.GetIdentifier(serverId)
    if not identifier then
        if Bridge.Notify then Bridge.Notify(src, 'Player not found', 'error') end
        return
    end
    
    local name = Bridge.GetCharacterName(serverId) or GetPlayerName(serverId) or 'Unknown'
    -- Admin sees all memories regardless of visibility
    local memories = GetAllMemoriesAdmin(identifier)
    local relationships = GetPlayerRelationships(identifier)
    local reputation = GetPlayerReputation(identifier)
    local rumors = GetPlayerRumors(identifier)
    local counters = GetPlayerCounters(identifier)
    local tags = GenerateTagsFromCounters(counters)
    
    -- Add target names to memories
    for _, mem in ipairs(memories) do
        if mem.target_identifier then
            mem.targetName = (Bridge.GetCharacterNameByIdentifier and Bridge.GetCharacterNameByIdentifier(mem.target_identifier)) or mem.target_identifier
        end
        -- Ensure visibility is set
        mem.visibility = mem.visibility or 'private'
    end
    
    TriggerClientEvent('lifeprint:client:adminPlayerData', src, {
        player = { serverId = serverId, identifier = identifier, name = name },
        memories = memories,
        relationships = relationships,
        reputation = reputation,
        rumors = rumors,
        counters = counters or {},
        tags = tags,
        characterRead = GenerateCharacterRead(tags, counters)
    })
end)

RegisterNetEvent('lifeprint:server:adminAddMemoryToPlayer', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    if not (Bridge and Bridge.HasPermission and Bridge.HasPermission(src, 'lifeprint.admin')) then
        if Bridge.Notify then Bridge.Notify(src, 'No permission', 'error') end
        return
    end
    
    if not data or not data.targetIdentifier then
        if Bridge.Notify then Bridge.Notify(src, 'No target specified', 'error') end
        return
    end
    
    -- Validate visibility (default to private for admin-added memories)
    local visibility = data.visibility or 'private'
    if not IsValidVisibility(visibility) then
        visibility = 'private'
    end
    
    local success = AddMemory(data.targetIdentifier, {
        memoryType = data.memoryType or 'other',
        description = data.description or '',
        location = data.location,
        timestamp = os.time(),
        visibility = visibility
    })
    
    if success then
        if Bridge.Notify then Bridge.Notify(src, 'Memory added (' .. visibility .. ')', 'success') end
    else
        if Bridge.Notify then Bridge.Notify(src, 'Failed to add memory', 'error') end
    end
end)

RegisterNetEvent('lifeprint:server:adminAddRumorToPlayer', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    if not (Bridge and Bridge.HasPermission and Bridge.HasPermission(src, 'lifeprint.admin')) then
        if Bridge.Notify then Bridge.Notify(src, 'No permission', 'error') end
        return
    end
    
    if not data or not data.targetIdentifier then
        if Bridge.Notify then Bridge.Notify(src, 'No target specified', 'error') end
        return
    end
    
    local success = AddRumor(data.targetIdentifier, {
        rumorType = data.rumorType or 'hearsay',
        content = data.content or ''
    })
    
    if Bridge.Notify then Bridge.Notify(src, success and 'Rumor added' or 'Failed', success and 'success' or 'error') end
end)

RegisterNetEvent('lifeprint:server:adminSetCounter', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    if not (Bridge and Bridge.HasPermission and Bridge.HasPermission(src, 'lifeprint.admin')) then
        if Bridge.Notify then Bridge.Notify(src, 'No permission', 'error') end
        return
    end
    
    if not data or not data.targetIdentifier or not data.counterType then
        if Bridge.Notify then Bridge.Notify(src, 'Missing data', 'error') end
        return
    end
    
    if not IsValidCounterType(data.counterType) then
        if Bridge.Notify then Bridge.Notify(src, 'Invalid counter type', 'error') end
        return
    end
    
    local success = SetCounter(data.targetIdentifier, data.counterType, tonumber(data.value) or 0)
    if Bridge.Notify then Bridge.Notify(src, success and 'Counter updated' or 'Failed', success and 'success' or 'error') end
end)

RegisterNetEvent('lifeprint:server:adminWipePlayer', function(targetIdentifier)
    local src = source
    if not ValidateSource(src) then return end
    
    if not (Bridge and Bridge.HasPermission and Bridge.HasPermission(src, 'lifeprint.admin')) then
        if Bridge.Notify then Bridge.Notify(src, 'No permission', 'error') end
        return
    end
    
    if not targetIdentifier then
        if Bridge.Notify then Bridge.Notify(src, 'No target specified', 'error') end
        return
    end
    
    -- Use await versions for proper blocking
    SafeQuery(function() return MySQL.update.await('DELETE FROM lifeprint_memories WHERE identifier = ?', { targetIdentifier }) end)
    SafeQuery(function() return MySQL.update.await('DELETE FROM lifeprint_relationships WHERE identifier = ?', { targetIdentifier }) end)
    SafeQuery(function() return MySQL.update.await('DELETE FROM lifeprint_reputation WHERE identifier = ?', { targetIdentifier }) end)
    SafeQuery(function() return MySQL.update.await('DELETE FROM lifeprint_reputation_counters WHERE identifier = ?', { targetIdentifier }) end)
    SafeQuery(function() return MySQL.update.await('DELETE FROM lifeprint_rumors WHERE identifier = ?', { targetIdentifier }) end)
    SafeQuery(function() return MySQL.update.await('DELETE FROM lifeprint_social_links WHERE identifier = ?', { targetIdentifier }) end)
    SafeQuery(function() return MySQL.update.await('DELETE FROM lifeprint_settings WHERE identifier = ?', { targetIdentifier }) end)
    
    DebugLog(('Wiped all data for identifier: %s'):format(targetIdentifier))
    
    if Bridge.Notify then Bridge.Notify(src, 'Player data wiped successfully', 'success') end
    
    -- Trigger client to update the admin panel with empty data
    TriggerClientEvent('lifeprint:client:adminWipeComplete', src, targetIdentifier)
end)

RegisterNetEvent('lifeprint:server:adminRefreshPlayer', function(targetIdentifier)
    local src = source
    if not ValidateSource(src) then return end
    
    if not (Bridge and Bridge.HasPermission and Bridge.HasPermission(src, 'lifeprint.admin')) then
        if Bridge.Notify then Bridge.Notify(src, 'No permission', 'error') end
        return
    end
    
    if not targetIdentifier then return end
    
    local lifeprint = GetPlayerLifeprint(targetIdentifier)
    local counters = GetPlayerCounters(targetIdentifier)
    local tags = GenerateTagsFromCounters(counters)
    
    TriggerClientEvent('lifeprint:client:adminPlayerData', src, {
        player = { identifier = targetIdentifier, name = Bridge.GetCharacterNameByIdentifier(targetIdentifier) or targetIdentifier },
        memories = lifeprint.memories,
        relationships = lifeprint.relationships,
        reputation = lifeprint.reputation,
        rumors = lifeprint.rumors,
        counters = counters or {},
        tags = tags,
        characterRead = GenerateCharacterRead(tags, counters)
    })
end)

-- Admin Report Generation (Evidence Dossier)
-- Generates a printable report for staff, court RP, or police RP
RegisterNetEvent('lifeprint:server:generateReport', function(targetServerId)
    local src = source
    if not ValidateSource(src) then return end
    
    -- Validate admin permission
    if not (Bridge and Bridge.HasPermission and Bridge.HasPermission(src, 'lifeprint.admin')) then
        if Bridge.Notify then Bridge.Notify(src, 'No permission for reports', 'error') end
        return
    end
    
    -- Validate target exists
    local targetSource = tonumber(targetServerId)
    if not targetSource or targetSource <= 0 then
        if Bridge.Notify then Bridge.Notify(src, 'Invalid target', 'error') end
        return
    end
    
    local targetIdentifier = Bridge.GetIdentifier(targetSource)
    if not targetIdentifier then
        if Bridge.Notify then Bridge.Notify(src, 'Could not resolve target', 'error') end
        return
    end
    
    DebugLog(('Report generated for %d by admin %d'):format(targetSource, src))
    
    -- Gather all data
    local lifeprint = GetPlayerLifeprint(targetIdentifier, true)  -- admin mode = all visibilities
    local counters = GetPlayerCounters(targetIdentifier)
    local tags = GenerateTagsFromCounters(counters)
    local socialLinks = GetPlayerSocialLinks(targetIdentifier)
    
    -- Mask identifier for privacy (show only first/last 4 chars)
    local maskedIdentifier = targetIdentifier
    if #targetIdentifier > 12 then
        maskedIdentifier = string.sub(targetIdentifier, 1, 4) .. '****' .. string.sub(targetIdentifier, -4)
    end
    
    -- Build report data
    local reportData = {
        generatedAt = os.date('%Y-%m-%d %H:%M:%S'),
        generatedBy = Bridge.GetCharacterName(src) or GetPlayerName(src) or 'Admin',
        subject = {
            name = Bridge.GetCharacterName(targetSource) or GetPlayerName(targetSource) or 'Unknown',
            identifier = maskedIdentifier,
            serverId = targetSource
        },
        memories = lifeprint.memories or {},
        relationships = lifeprint.relationships or {},
        reputation = lifeprint.reputation or {},
        rumors = lifeprint.rumors or {},
        counters = counters or {},
        tags = tags,
        characterRead = GenerateCharacterRead(tags, counters),
        socialLinks = socialLinks or {}
    }
    
    TriggerClientEvent('lifeprint:client:showReport', src, reportData)
end)

-- ============================================================================
-- Tracking Events
-- ============================================================================

local TrackingCooldowns = { 
    proximity = {}, 
    vehicleCrash = {}, 
    injury = {},
    -- Memory notification cooldowns
    faceMemory = {},
    relationshipHistory = {},
    locationMemory = {},
    rumorNotification = {},
    reputationTag = {}
}

local function CheckCooldown(cooldownType, key, seconds)
    local now = os.time()
    local last = TrackingCooldowns[cooldownType] and TrackingCooldowns[cooldownType][key]
    if last and (now - last) < seconds then
        return false
    end
    TrackingCooldowns[cooldownType] = TrackingCooldowns[cooldownType] or {}
    TrackingCooldowns[cooldownType][key] = now
    return true
end

RegisterNetEvent('lifeprint:tracking:proximity', function(targetServerId, location)
    local src = source
    if not ValidateSource(src) then return end
    
    local playerIdentifier = Bridge.GetIdentifier(src)
    local targetIdentifier = Bridge.GetIdentifier(targetServerId)
    
    if not playerIdentifier or not targetIdentifier or playerIdentifier == targetIdentifier then return end
    
    -- Check if player has proximity memories enabled
    if not IsSettingEnabled(playerIdentifier, 'proximity_memories') then
        DebugLog(('Proximity memory skipped for %s - setting disabled'):format(playerIdentifier))
        return
    end
    
    local key = playerIdentifier < targetIdentifier and (playerIdentifier .. ":" .. targetIdentifier) or (targetIdentifier .. ":" .. playerIdentifier)
    
    if not CheckCooldown('proximity', key, 86400) then return end
    
    AddRelationship(playerIdentifier, { targetIdentifier = targetIdentifier, change = 10, relationshipType = 'acquaintance', notes = 'Met near ' .. (location or 'Unknown') })
    AddRelationship(targetIdentifier, { targetIdentifier = playerIdentifier, change = 10, relationshipType = 'acquaintance', notes = 'Met near ' .. (location or 'Unknown') })
    IncrementCounter(playerIdentifier, 'meetings', 1)
    IncrementCounter(targetIdentifier, 'meetings', 1)
    
    TriggerClientEvent('lifeprint:client:resetProximityTimer', src, targetServerId)
end)

RegisterNetEvent('lifeprint:tracking:vehicleCrash', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    if not CheckCooldown('vehicleCrash', identifier, 600) then return end
    
    AddMemory(identifier, { memoryType = 'encounter', description = 'Vehicle incident at ' .. (data.location or 'Unknown'), location = data.location, timestamp = os.time() })
    IncrementCounter(identifier, 'crashes', 1)
end)

RegisterNetEvent('lifeprint:tracking:injury', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    if not CheckCooldown('injury', identifier, 600) then return end
    
    AddMemory(identifier, { memoryType = 'encounter', description = 'Sustained injury at ' .. (data.location or 'Unknown'), location = data.location, timestamp = os.time() })
end)

-- Combat Tracking Event
-- Called when player kills another entity (NPC or player)
RegisterNetEvent('lifeprint:tracking:combat', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    -- Get config settings
    local combatConfig = Config and Config.CombatTracking or {}
    if not combatConfig.enabled then return end
    
    -- Check cooldown
    local cooldown = combatConfig.killCooldown or 300
    if not CheckCooldown('combat', identifier, cooldown) then return end
    
    local isPlayer = data and data.isPlayer
    local targetName = data and data.targetName or 'Unknown'
    local location = data and data.location or 'Unknown'
    local weapon = data and data.weapon or 'Unknown'
    
    -- Create memory
    local memoryType = combatConfig.killMemoryType or 'conflict'
    local memoryTitle = combatConfig.killMemoryTitle or 'Violent Encounter'
    local description = isPlayer 
        and ('Conflict with ' .. targetName .. ' at ' .. location)
        or ('Incident involving a ' .. targetName:lower() .. ' at ' .. location)
    
    AddMemory(identifier, {
        memoryType = memoryType,
        title = memoryTitle,
        description = description,
        location = location,
        timestamp = os.time(),
        visibility = 'private'
    })
    
    -- Update reputation
    local repChange = isPlayer 
        and (combatConfig.playerKillReputationChange or -10)
        or (combatConfig.npcKillReputationChange or -3)
    
    if repChange ~= 0 then
        AddReputation(identifier, { category = 'criminal', change = repChange })
        AddReputation(identifier, { category = 'general', change = repChange })
    end
    
    -- Increment counter
    local counterType = isPlayer 
        and (combatConfig.playerKillCounter or 'suspicious_actions')
        or (combatConfig.npcKillCounter or 'suspicious_actions')
    IncrementCounter(identifier, counterType, 1)
    
    -- Create relationship if it was a player kill
    if isPlayer and data.targetServerId then
        local targetIdentifier = Bridge.GetIdentifier(data.targetServerId)
        if targetIdentifier and targetIdentifier ~= identifier then
            AddRelationship(identifier, {
                targetIdentifier = targetIdentifier,
                targetName = targetName,
                relationshipType = 'enemy',
                value = -50,
                memoryStrength = 3
            })
        end
    end
    
    -- Generate rumor for player kills
    if isPlayer and combatConfig.createRumorOnPlayerKill then
        local templates = combatConfig.playerKillRumorTemplates or {
            "Word on the street is {name} was involved in a violent incident."
        }
        local playerName = Bridge.GetCharacterName(src) or GetPlayerName(src) or 'Someone'
        local rumorText = templates[math.random(1, #templates)]:gsub('{name}', playerName):gsub('{location}', location)
        AddRumor(identifier, {
            rumorType = 'conflict',
            content = rumorText,
            location = location
        })
    end
    
    -- Notify the player
    TriggerClientEvent('lifeprint:client:notify', src, {
        type = 'memory',
        title = 'Memory Recorded',
        message = isPlayer and ('Conflict with ' .. targetName .. ' recorded') or 'Incident recorded'
    })
    
    DebugLog(('Combat event: %s killed %s at %s'):format(
        Bridge.GetCharacterName(src) or GetPlayerName(src),
        targetName,
        location
    ))
end)

-- Player Death Tracking Event
-- Called when player dies (killed by player, NPC, or environment)
RegisterNetEvent('lifeprint:tracking:playerDeath', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    -- Get config settings
    local deathConfig = Config and Config.DeathTracking or {}
    if not deathConfig.enabled or not deathConfig.trackDeaths then return end
    
    -- Check cooldown (server-side backup)
    local cooldown = deathConfig.cooldown or 10
    if not CheckCooldown('death', identifier, cooldown) then return end
    
    local killerName = data and data.killerName or 'Unknown'
    local killerServerId = data and data.killerServerId
    local isPlayerKill = data and data.isPlayerKill or false
    local location = data and data.location or 'Unknown'
    local weapon = data and data.weapon or 'Unknown'
    local coordsX = data and data.x
    local coordsY = data and data.y
    local coordsZ = data and data.z
    
    -- Create death memory with proper title
    local memoryType = 'death'  -- Fixed type for death memories
    local memoryTitle
    local description
    
    if isPlayerKill and killerName and killerName ~= 'Self' then
        memoryTitle = ('You were killed by %s'):format(killerName)
        description = ('You were killed by %s with %s near %s.'):format(killerName, weapon, location)
    elseif killerName == 'Self' then
        memoryTitle = 'You Died'
        description = ('You took your own life near %s.'):format(location)
    elseif killerName == 'Environment' then
        memoryTitle = 'You Died'
        description = ('You died from environmental causes near %s.'):format(location)
    elseif killerName == 'NPC' then
        memoryTitle = 'You Died'
        description = ('You were killed by an NPC with %s near %s.'):format(weapon, location)
    else
        memoryTitle = 'You Died'
        description = ('You died under unknown circumstances near %s.'):format(location)
    end
    
    -- Add memory with coordinates for location triggers
    AddMemory(identifier, {
        memoryType = memoryType,
        title = memoryTitle,
        description = description,
        location = location,
        x = coordsX,
        y = coordsY,
        z = coordsZ,
        timestamp = os.time(),
        visibility = 'private'
    })
    
    -- Increment deaths counter
    IncrementCounter(identifier, 'deaths', 1)
    
    -- Create/update relationship if killed by another player
    if isPlayerKill and killerServerId and killerName ~= 'Self' then
        local killerIdentifier = Bridge.GetIdentifier(killerServerId)
        if killerIdentifier and killerIdentifier ~= identifier then
            -- Create "Deadly History" relationship (victim's perspective)
            AddRelationship(identifier, {
                targetIdentifier = killerIdentifier,
                targetName = killerName,
                relationshipType = 'Deadly History',
                value = -25,  -- Major negative
                memoryStrength = 2,
                location = location
            })
        end
    end
    
    -- Send journal notification
    SendJournalNotification(identifier, 'memoryAdded', {
        memoryType = memoryType
    })
    
    DebugLog(('Death event: %s died at %s (killer: %s)'):format(
        Bridge.GetCharacterName(src) or GetPlayerName(src),
        location,
        killerName
    ))
end)

-- Player Kill Tracking Event
-- Called when player kills another player (confirmed death)
RegisterNetEvent('lifeprint:tracking:playerKill', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    -- Get config settings
    local deathConfig = Config and Config.DeathTracking or {}
    if not deathConfig.enabled or not deathConfig.trackKills then return end
    
    -- Check cooldown (server-side backup)
    local cooldown = deathConfig.cooldown or 10
    if not CheckCooldown('kill', identifier, cooldown) then return end
    
    local targetName = data and data.targetName or 'Unknown'
    local targetServerId = data and data.targetServerId
    local location = data and data.location or 'Unknown'
    local weapon = data and data.weapon or 'Unknown'
    local coordsX = data and data.x
    local coordsY = data and data.y
    local coordsZ = data and data.z
    
    -- Get target identifier (validate server-side)
    local targetIdentifier = nil
    if targetServerId and targetServerId > 0 then
        targetIdentifier = Bridge.GetIdentifier(targetServerId)
    end
    
    -- Create kill memory with proper title
    local memoryType = 'kill'  -- Fixed type for kill memories
    local memoryTitle = 'Took a Life'
    local description = ('You killed %s near %s.'):format(targetName, location)
    
    -- Add memory with coordinates for location triggers
    AddMemory(identifier, {
        memoryType = memoryType,
        title = memoryTitle,
        description = description,
        location = location,
        x = coordsX,
        y = coordsY,
        z = coordsZ,
        timestamp = os.time(),
        visibility = 'private',
        targetIdentifier = targetIdentifier,
        targetName = targetName
    })
    
    -- Update reputation (killing hurts reputation)
    local repChange = deathConfig.killReputationChange or -15
    if repChange ~= 0 then
        AddReputation(identifier, { category = 'criminal', change = repChange })
        AddReputation(identifier, { category = 'general', change = repChange })
    end
    
    -- Increment kills counter
    IncrementCounter(identifier, 'kills', 1)
    
    -- Increment suspicious_actions counter (killing is suspicious)
    IncrementCounter(identifier, 'suspicious_actions', 1)
    
    -- Create/update "Deadly History" relationship with victim
    if targetIdentifier and targetIdentifier ~= identifier then
        AddRelationship(identifier, {
            targetIdentifier = targetIdentifier,
            targetName = targetName,
            relationshipType = 'Deadly History',
            value = -25,  -- Major negative
            memoryStrength = 2,
            location = location
        })
        
        -- Also update victim's relationship with killer (if victim is online)
        -- This creates a bidirectional "Deadly History" relationship
        local victimSrc = GetSourceFromIdentifier(targetIdentifier)
        if victimSrc then
            local killerName = Bridge.GetCharacterName(src) or GetPlayerName(src) or 'Unknown'
            AddRelationship(targetIdentifier, {
                targetIdentifier = identifier,
                targetName = killerName,
                relationshipType = 'Deadly History',
                value = -25,
                memoryStrength = 2,
                location = location
            })
        end
    end
    
    -- Generate rumor if enabled
    if deathConfig.createRumors then
        local templates = deathConfig.killRumorTemplates or {
            "Word on the street is {name} was involved in something final."
        }
        local playerName = Bridge.GetCharacterName(src) or GetPlayerName(src) or 'Someone'
        local rumorText = templates[math.random(1, #templates)]:gsub('{name}', playerName):gsub('{location}', location)
        AddRumor(identifier, {
            rumorType = 'conflict',
            content = rumorText,
            location = location
        })
    end
    
    -- Send journal notification
    SendJournalNotification(identifier, 'memoryAdded', {
        memoryType = memoryType
    })
    
    DebugLog(('Kill event: %s killed %s at %s with %s'):format(
        Bridge.GetCharacterName(src) or GetPlayerName(src),
        targetName,
        location,
        weapon
    ))
end)

-- ============================================================================
-- Non-Fatal Injury Tracking
-- Records memories when player is hurt but survives (does NOT trigger on death)
-- ============================================================================

RegisterNetEvent('lifeprint:tracking:injury', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    -- Check if injury tracking is enabled
    local injuryConfig = Config and Config.InjuryTracking
    if not injuryConfig or not injuryConfig.enabled then return end
    
    local cause = data and data.cause or 'unknown'
    local title = data and data.title or 'Injured'
    local description = data and data.description or 'Sustained injuries.'
    local location = data and data.location or 'Unknown'
    local coords = data and data.coords
    
    -- Determine memory type based on cause
    local memoryType = 'injury'
    if cause == 'vehicle_hit' then
        memoryType = 'vehicle_hit'
    elseif cause == 'gunshot' then
        memoryType = 'gunshot'
    end
    
    -- Add memory
    AddMemory(identifier, {
        memoryType = memoryType,
        title = title,
        description = description,
        location = location,
        visibility = 'private',
        timestamp = os.time(),
        x = coords and coords.x,
        y = coords and coords.y,
        z = coords and coords.z
    })
    
    -- Update reputation counters
    IncrementCounter(identifier, 'injuries', 1)
    
    if cause == 'vehicle_hit' then
        IncrementCounter(identifier, 'vehicle_hits', 1)
    elseif cause == 'gunshot' then
        IncrementCounter(identifier, 'gunshot_wounds', 1)
    end
    
    -- Send journal notification
    SendJournalNotification(identifier, 'memoryAdded', {
        memoryType = memoryType
    })
    
    DebugLog(('Injury recorded: %s at %s for %s'):format(
        title,
        location,
        Bridge.GetCharacterName(src) or GetPlayerName(src) or 'Unknown'
    ))
end)

-- Social Web Tracking Event
-- Called when player has been near another player for required time
RegisterNetEvent('lifeprint:tracking:socialWeb', function(targetServerId)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    local targetIdentifier = Bridge.GetIdentifier(targetServerId)
    
    if not identifier or not targetIdentifier then return end
    if identifier == targetIdentifier then return end
    
    -- Get names
    local targetName = Bridge.GetCharacterName(targetServerId) or GetPlayerName(targetServerId) or 'Unknown'
    
    -- Check if feature enabled
    if not Config or not Config.SocialWeb or not Config.SocialWeb.enabled then return end
    
    -- Update social link
    UpdateSocialLink(identifier, targetIdentifier, targetName)
    
    -- Also update reverse (target seen player too)
    local playerName = Bridge.GetCharacterName(src) or GetPlayerName(src) or 'Unknown'
    UpdateSocialLink(targetIdentifier, identifier, playerName)
end)

-- ============================================================================
-- Memory Notifications (Memory Surfaced)
-- Cinematic RP-friendly notifications when near people/places from the past
-- ============================================================================

-- Helper: Get random template from config
local function GetNotificationTemplate(templateType)
    local config = Config and Config.MemoryNotifications
    if not config or not config.templates or not config.templates[templateType] then
        return nil
    end
    local templates = config.templates[templateType]
    return templates[math.random(1, #templates)]
end

-- Helper: Get strength-based message
local function GetStrengthMessage(strength, name)
    local config = Config and Config.MemoryNotifications
    if not config or not config.strengthMessages then
        return nil
    end
    
    local category = 'faint'
    if strength >= 7 then category = 'strong'
    elseif strength >= 4 then category = 'moderate' end
    
    local messages = config.strengthMessages[category]
    if not messages or #messages == 0 then return nil end
    
    return messages[math.random(1, #messages)]:gsub('{name}', name)
end

-- Server event: Trigger memory notification for player
RegisterNetEvent('lifeprint:notification:trigger', function(notificationType, data)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    -- Check if notifications enabled
    local notifConfig = Config and Config.MemoryNotifications
    if not notifConfig or not notifConfig.enabled then return end
    
    -- Check player settings
    if not IsSettingEnabled(identifier, 'memory_popups') then return end
    
    local title = ''
    local message = ''
    local notifType = 'memory'
    local cooldownType = nil
    local cooldownKey = nil
    
    if notificationType == 'faceMemory' then
        -- Face memory notification
        local targetName = data and data.targetName or 'Someone'
        local strength = data and data.strength or 1
        local targetIdentifier = data and data.targetIdentifier
        
        -- Use strength-based message if strength >= 7
        if strength >= 7 then
            message = GetStrengthMessage(strength, targetName) or ('You instantly recognize ' .. targetName .. '.')
        else
            local template = GetNotificationTemplate('faceMemory')
            message = template and template:gsub('{name}', targetName) or ('Memory surfaced: You recognize ' .. targetName .. '.')
        end
        
        title = 'Memory Surfaced'
        notifType = 'face'
        cooldownType = 'faceMemory'
        cooldownKey = targetIdentifier or targetName
        
    elseif notificationType == 'relationshipHistory' then
        -- Relationship history notification
        local targetName = data and data.targetName or 'Someone'
        local relationshipNote = data and data.relationshipNote or 'You have history.'
        local strength = data and data.strength or 1
        local targetIdentifier = data and data.targetIdentifier
        
        -- Use strength-based message if strong
        if strength >= 7 then
            message = GetStrengthMessage(strength, targetName)
        end
        
        if not message then
            local template = GetNotificationTemplate('relationshipHistory')
            message = template and template:gsub('{name}', targetName):gsub('{relationshipNote}', relationshipNote)
                or ('Your Lifeprint stirs. You have history with ' .. targetName .. '.')
        end
        
        title = 'Memory Surfaced'
        notifType = 'relationship'
        cooldownType = 'relationshipHistory'
        cooldownKey = targetIdentifier or targetName
        
    elseif notificationType == 'locationMemory' then
        -- Location memory notification
        local memoryTitle = data and data.memoryTitle or 'Something happened here'
        local location = data and data.location or 'this area'
        
        local template = GetNotificationTemplate('locationMemory')
        message = template and template:gsub('{memoryTitle}', memoryTitle):gsub('{location}', location)
            or 'This area feels familiar. Something happened here.'
        
        title = 'Memory Surfaced'
        notifType = 'location'
        cooldownType = 'locationMemory'
        cooldownKey = location
        
    elseif notificationType == 'rumorHeard' then
        -- Rumor notification
        local rumorSnippet = data and data.rumorSnippet or 'Word spreads...'
        
        local template = GetNotificationTemplate('rumorHeard')
        message = template and template:gsub('{rumorSnippet}', rumorSnippet:sub(1, 80))
            or ('The city whispers: ' .. rumorSnippet:sub(1, 80))
        
        title = 'City Whispers'
        notifType = 'rumor'
        cooldownType = 'rumorNotification'
        cooldownKey = rumorSnippet:sub(1, 50)
        
    elseif notificationType == 'reputationTag' then
        -- Reputation tag change notification
        local tag = data and data.tag or 'Unknown'
        
        local template = GetNotificationTemplate('reputationTag')
        message = template and template:gsub('{tag}', tag)
            or ('Your reputation shifts. The city now sees you as: ' .. tag)
        
        title = 'Reputation Changed'
        notifType = 'reputation'
        cooldownType = 'reputationTag'
        cooldownKey = tag
    end
    
    -- Check cooldown
    if cooldownType and cooldownKey then
        local cooldownSeconds = notifConfig.cooldowns and notifConfig.cooldowns[cooldownType] or 600
        if not CheckCooldown(cooldownType, identifier .. ':' .. cooldownKey, cooldownSeconds) then
            DebugLog(('Memory notification cooldown active: %s:%s'):format(cooldownType, cooldownKey))
            return
        end
    end
    
    -- Send notification to client
    TriggerClientEvent('lifeprint:client:showMemoryNotification', src, {
        type = notifType,
        title = title,
        message = message,
        duration = notifConfig.autoHideDuration or 5000
    })
    
    DebugLog(('Memory notification sent to %d: [%s] %s'):format(src, notificationType, message:sub(1, 50)))
end)

-- Server event: Check for nearby relationship history
RegisterNetEvent('lifeprint:notification:checkRelationshipProximity', function(targetServerId, distance)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    local targetIdentifier = Bridge.GetIdentifier(targetServerId)
    
    if not identifier or not targetIdentifier then return end
    if identifier == targetIdentifier then return end
    
    -- Check if notifications enabled
    local notifConfig = Config and Config.MemoryNotifications
    if not notifConfig or not notifConfig.enabled then return end
    
    -- Get relationship
    local relationship = GetFaceMemoryByTarget and GetFaceMemoryByTarget(identifier, targetIdentifier)
    if not relationship then
        -- Try getting from relationships
        local relationships = GetPlayerRelationships(identifier)
        for _, rel in ipairs(relationships) do
            if rel.target_identifier == targetIdentifier then
                relationship = rel
                break
            end
        end
    end
    
    if not relationship then return end
    
    -- Check if within notification distance
    local maxDistance = notifConfig.distances and notifConfig.distances.relationshipHistory or 12.0
    if distance > maxDistance then return end
    
    -- Get relationship note
    local targetName = relationship.target_name or Bridge.GetCharacterName(targetServerId) or GetPlayerName(targetServerId) or 'Someone'
    local relationshipNote = ''
    if relationship.relationship_type and relationship.relationship_type ~= 'stranger' then
        relationshipNote = 'They are your ' .. relationship.relationship_type .. '.'
    end
    if relationship.notes and #relationship.notes > 0 then
        relationshipNote = relationship.notes:sub(1, 60)
    end
    
    -- Trigger notification
    TriggerEvent('lifeprint:notification:trigger', 'relationshipHistory', {
        targetName = targetName,
        targetIdentifier = targetIdentifier,
        relationshipNote = relationshipNote,
        strength = relationship.memory_strength or 1
    })
end)

RegisterNetEvent('lifeprint:server:incrementCounter', function(counterType, amount)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    IncrementCounter(identifier, counterType, amount)
end)

-- ============================================================================
-- Integration Events
-- External resources can trigger these to automatically:
--   - Add memories, update relationships, track counters, generate rumors
-- ============================================================================

--- Police Arrest Integration
--- @param playerSource number: Source of arrested player
--- @param officerSource number|nil: Source of arresting officer (optional)
--- @param location string: Location of arrest
--- @param details table|nil: Additional details { charges, notes }
RegisterNetEvent('lifeprint:integration:policeArrest', function(playerSource, officerSource, location, details)
    local src = source
    if not ValidateSource(src) then return end
    
    -- Get identifier for arrested player (server resolves, not client)
    local playerIdentifier = Bridge.GetIdentifier(playerSource)
    if not playerIdentifier then return end
    
    local playerName = Bridge.GetCharacterName(playerSource) or GetPlayerName(playerSource) or 'Unknown'
    local officerName = officerSource and (Bridge.GetCharacterName(officerSource) or GetPlayerName(officerSource)) or nil
    
    -- Add memory
    local memoryDesc = 'Arrested at ' .. (location or 'Unknown')
    if details and details.charges then
        memoryDesc = memoryDesc .. ' - Charges: ' .. details.charges
    end
    AddMemory(playerIdentifier, {
        memoryType = 'crime',
        description = memoryDesc,
        location = location,
        visibility = 'private',
        timestamp = os.time()
    })
    
    -- Update counter
    IncrementCounter(playerIdentifier, 'arrests', 1)
    
    -- Update relationship with officer if provided
    if officerSource then
        local officerIdentifier = Bridge.GetIdentifier(officerSource)
        if officerIdentifier and officerIdentifier ~= playerIdentifier then
            AddRelationship(playerIdentifier, {
                targetIdentifier = officerIdentifier,
                change = -10,
                relationshipType = 'adversary',
                notes = 'Arresting officer'
            })
        end
    end
    
    -- Generate rumor from template
    local rumorText = GenerateRumor('police', {
        name = playerName,
        other = officerName or 'an officer',
        location = location or 'the city',
        event = 'arrest'
    })
    
    if rumorText then
        AddRumor(playerIdentifier, {
            content = rumorText,
            rumorType = 'crime',
            targetIdentifier = officerSource and Bridge.GetIdentifier(officerSource) or nil,
            targetName = officerName
        })
    end
    
    DebugLog('Police arrest integration processed for: ' .. playerName)
end)

--- EMS Treatment Integration
--- @param playerSource number: Source of treated player
--- @param medicSource number|nil: Source of treating medic (optional)
--- @param location string: Location of treatment
--- @param details table|nil: Additional details { injury, notes }
RegisterNetEvent('lifeprint:integration:emsTreatment', function(playerSource, medicSource, location, details)
    local src = source
    if not ValidateSource(src) then return end
    
    local playerIdentifier = Bridge.GetIdentifier(playerSource)
    if not playerIdentifier then return end
    
    local playerName = Bridge.GetCharacterName(playerSource) or GetPlayerName(playerSource) or 'Unknown'
    local medicName = medicSource and (Bridge.GetCharacterName(medicSource) or GetPlayerName(medicSource)) or nil
    
    -- Add memory
    local memoryDesc = 'Received medical treatment at ' .. (location or 'Unknown')
    if details and details.injury then
        memoryDesc = memoryDesc .. ' for ' .. details.injury
    end
    AddMemory(playerIdentifier, {
        memoryType = 'rescue',
        description = memoryDesc,
        location = location,
        visibility = 'private',
        timestamp = os.time()
    })
    
    -- Update counter
    IncrementCounter(playerIdentifier, 'ems_visits', 1)
    
    -- Update relationship with medic if provided
    if medicSource then
        local medicIdentifier = Bridge.GetIdentifier(medicSource)
        if medicIdentifier and medicIdentifier ~= playerIdentifier then
            AddRelationship(playerIdentifier, {
                targetIdentifier = medicIdentifier,
                change = 5,
                relationshipType = 'acquaintance',
                notes = 'Treated by medic'
            })
        end
    end
    
    -- Generate rumor from template (EMS rumors are usually quieter)
    local rumorText = GenerateRumor('ems', {
        name = playerName,
        other = medicName or 'EMS',
        location = location or 'Pillbox Hill Medical Center',
        event = 'treatment'
    })
    
    if rumorText then
        AddRumor(playerIdentifier, {
            content = rumorText,
            rumorType = 'hearsay',
            targetIdentifier = medicSource and Bridge.GetIdentifier(medicSource) or nil,
            targetName = medicName
        })
    end
    
    DebugLog('EMS treatment integration processed for: ' .. playerName)
end)

--- Jail Integration
--- @param playerSource number: Source of jailed player
--- @param duration number: Jail time in minutes
--- @param details table|nil: Additional details { charges, location }
RegisterNetEvent('lifeprint:integration:jail', function(playerSource, duration, details)
    local src = source
    if not ValidateSource(src) then return end
    
    local playerIdentifier = Bridge.GetIdentifier(playerSource)
    if not playerIdentifier then return end
    
    local playerName = Bridge.GetCharacterName(playerSource) or GetPlayerName(playerSource) or 'Unknown'
    
    -- Add memory
    local memoryDesc = 'Sentenced to ' .. (duration or 0) .. ' minutes in jail'
    if details and details.charges then
        memoryDesc = memoryDesc .. ' - Charges: ' .. details.charges
    end
    AddMemory(playerIdentifier, {
        memoryType = 'crime',
        description = memoryDesc,
        location = details and details.location or 'Bolingbroke Penitentiary',
        visibility = 'private',
        timestamp = os.time()
    })
    
    -- Update counter (jail counts as arrest for reputation)
    IncrementCounter(playerIdentifier, 'arrests', 1)
    
    -- Generate rumor from template
    local rumorText = GenerateRumor('police', {
        name = playerName,
        other = 'the system',
        location = details and details.location or 'Bolingbroke',
        event = 'jail sentence'
    })
    
    if rumorText then
        AddRumor(playerIdentifier, {
            content = rumorText,
            rumorType = 'crime'
        })
    end
    
    DebugLog('Jail integration processed for: ' .. playerName)
end)

--- Billing Integration
--- @param playerSource number: Source of player receiving bill
--- @param amount number: Bill amount
--- @param reason string: Reason for bill
--- @param isPaid boolean|nil: Whether bill was paid (false = unpaid, affects reputation)
RegisterNetEvent('lifeprint:integration:bill', function(playerSource, amount, reason, isPaid)
    local src = source
    if not ValidateSource(src) then return end
    
    local playerIdentifier = Bridge.GetIdentifier(playerSource)
    if not playerIdentifier then return end
    
    local playerName = Bridge.GetCharacterName(playerSource) or GetPlayerName(playerSource) or 'Unknown'
    
    -- Add memory
    local memoryDesc = isPaid and 'Paid a bill of $' .. (amount or 0) or 'Received a bill of $' .. (amount or 0)
    if reason then
        memoryDesc = memoryDesc .. ' - ' .. reason
    end
    AddMemory(playerIdentifier, {
        memoryType = 'business',
        description = memoryDesc,
        visibility = 'private',
        timestamp = os.time()
    })
    
    -- Update reputation based on payment status
    local repChange = isPaid and 2 or -2
    AddReputation(playerIdentifier, {
        category = 'business',
        change = repChange,
        reason = isPaid and 'Paid bill' or 'Unpaid bill'
    })
    
    DebugLog('Billing integration processed for: ' .. playerName)
end)

--- Gang Interaction Integration
--- @param playerSource number: Source of player
--- @param otherSource number: Source of other gang member
--- @param interactionType string: 'ally' | 'rival' | 'conflict' | 'meeting'
--- @param location string|nil: Location of interaction
RegisterNetEvent('lifeprint:integration:gangInteraction', function(playerSource, otherSource, interactionType, location)
    local src = source
    if not ValidateSource(src) then return end
    
    local playerIdentifier = Bridge.GetIdentifier(playerSource)
    local otherIdentifier = Bridge.GetIdentifier(otherSource)
    if not playerIdentifier or not otherIdentifier then return end
    
    local playerName = Bridge.GetCharacterName(playerSource) or GetPlayerName(playerSource) or 'Unknown'
    local otherName = Bridge.GetCharacterName(otherSource) or GetPlayerName(otherSource) or 'Unknown'
    
    -- Determine relationship change based on interaction type
    local relChange = 0
    local relType = 'acquaintance'
    local memoryDesc = ''
    
    if interactionType == 'ally' then
        relChange = 15
        relType = 'associate'
        memoryDesc = 'Allied with ' .. otherName .. ' at ' .. (location or 'Unknown')
    elseif interactionType == 'rival' then
        relChange = -15
        relType = 'rival'
        memoryDesc = 'Became rivals with ' .. otherName .. ' at ' .. (location or 'Unknown')
    elseif interactionType == 'conflict' then
        relChange = -25
        relType = 'enemy'
        memoryDesc = 'Had a conflict with ' .. otherName .. ' at ' .. (location or 'Unknown')
        -- Update suspicious counter for conflicts
        IncrementCounter(playerIdentifier, 'suspicious_actions', 1)
    else
        relChange = 10
        relType = 'acquaintance'
        memoryDesc = 'Met with ' .. otherName .. ' at ' .. (location or 'Unknown')
    end
    
    -- Add memory
    AddMemory(playerIdentifier, {
        memoryType = 'encounter',
        description = memoryDesc,
        location = location,
        visibility = 'private',
        targetIdentifier = otherIdentifier,
        timestamp = os.time()
    })
    
    -- Update relationship (bidirectional)
    AddRelationship(playerIdentifier, {
        targetIdentifier = otherIdentifier,
        change = relChange,
        relationshipType = relType,
        notes = 'Gang interaction'
    })
    AddRelationship(otherIdentifier, {
        targetIdentifier = playerIdentifier,
        change = relChange,
        relationshipType = relType,
        notes = 'Gang interaction'
    })
    
    -- Update meetings counter
    IncrementCounter(playerIdentifier, 'meetings', 1)
    IncrementCounter(otherIdentifier, 'meetings', 1)
    
    -- Generate rumor from template
    local rumorText = GenerateRumor('gang', {
        name = playerName,
        other = otherName,
        location = location or 'the block',
        event = interactionType
    })
    
    if rumorText then
        AddRumor(playerIdentifier, {
            content = rumorText,
            rumorType = 'secret',
            targetIdentifier = otherIdentifier,
            targetName = otherName
        })
    end
    
    DebugLog('Gang interaction processed: ' .. playerName .. ' + ' .. otherName .. ' (' .. interactionType .. ')')
end)

--- Business Interaction Integration
--- @param playerSource number: Source of player
--- @param otherSource number|nil: Source of business partner (optional)
--- @param transactionType string: 'sale' | 'purchase' | 'deal' | 'meeting'
--- @param details table|nil: { amount, business, location }
RegisterNetEvent('lifeprint:integration:businessInteraction', function(playerSource, otherSource, transactionType, details)
    local src = source
    if not ValidateSource(src) then return end
    
    local playerIdentifier = Bridge.GetIdentifier(playerSource)
    if not playerIdentifier then return end
    
    local playerName = Bridge.GetCharacterName(playerSource) or GetPlayerName(playerSource) or 'Unknown'
    local otherName = otherSource and (Bridge.GetCharacterName(otherSource) or GetPlayerName(otherSource)) or nil
    local otherIdentifier = otherSource and Bridge.GetIdentifier(otherSource) or nil
    
    -- Add memory
    local memoryDesc = 'Business ' .. (transactionType or 'transaction')
    if details and details.amount then
        memoryDesc = memoryDesc .. ' - $' .. details.amount
    end
    if details and details.business then
        memoryDesc = memoryDesc .. ' at ' .. details.business
    end
    AddMemory(playerIdentifier, {
        memoryType = 'business',
        description = memoryDesc,
        location = details and details.location,
        visibility = 'private',
        targetIdentifier = otherIdentifier,
        timestamp = os.time()
    })
    
    -- Update counter
    IncrementCounter(playerIdentifier, 'meetings', 1)
    
    -- Update relationship if other party involved
    if otherIdentifier then
        AddRelationship(playerIdentifier, {
            targetIdentifier = otherIdentifier,
            change = 5,
            relationshipType = 'acquaintance',
            notes = 'Business ' .. transactionType
        })
        IncrementCounter(otherIdentifier, 'meetings', 1)
    end
    
    -- Generate rumor from template
    local rumorText = GenerateRumor('business', {
        name = playerName,
        other = otherName or 'a business contact',
        location = details and details.location or 'a business location',
        event = transactionType or 'deal'
    })
    
    if rumorText then
        AddRumor(playerIdentifier, {
            content = rumorText,
            rumorType = 'business',
            targetIdentifier = otherIdentifier,
            targetName = otherName
        })
    end
    
    DebugLog('Business interaction processed for: ' .. playerName)
end)

--- Trucking Event Integration
--- @param playerSource number: Source of trucker
--- @param eventType string: 'delivery' | 'crash' | 'completed' | 'failed'
--- @param details table|nil: { location, cargo, earnings }
RegisterNetEvent('lifeprint:integration:truckingEvent', function(playerSource, eventType, details)
    local src = source
    if not ValidateSource(src) then return end
    
    local playerIdentifier = Bridge.GetIdentifier(playerSource)
    if not playerIdentifier then return end
    
    local playerName = Bridge.GetCharacterName(playerSource) or GetPlayerName(playerSource) or 'Unknown'
    
    -- Determine memory description
    local memoryDesc = ''
    local counterType = 'helpful_actions'
    
    if eventType == 'delivery' or eventType == 'completed' then
        memoryDesc = 'Completed delivery run'
        if details and details.earnings then
            memoryDesc = memoryDesc .. ' - Earned $' .. details.earnings
        end
    elseif eventType == 'crash' then
        memoryDesc = 'Trucking accident at ' .. (details and details.location or 'Unknown')
        counterType = 'crashes'
    elseif eventType == 'failed' then
        memoryDesc = 'Failed delivery run'
        counterType = nil -- Don't increment for failures
    end
    
    -- Add memory
    AddMemory(playerIdentifier, {
        memoryType = 'business',
        description = memoryDesc,
        location = details and details.location,
        visibility = 'private',
        timestamp = os.time()
    })
    
    -- Update counter
    if counterType then
        IncrementCounter(playerIdentifier, counterType, 1)
    end
    
    -- Generate rumor from template
    local rumorText = GenerateRumor('trucking', {
        name = playerName,
        other = 'a delivery company',
        location = details and details.location or 'the highway',
        event = eventType
    })
    
    if rumorText then
        AddRumor(playerIdentifier, {
            content = rumorText,
            rumorType = 'business'
        })
    end
    
    DebugLog('Trucking event processed for: ' .. playerName .. ' (' .. eventType .. ')')
end)

--- DOT Interaction Integration
--- @param playerSource number: Source of player
--- @param eventType string: 'inspection' | 'citation' | 'clean' | 'stop'
--- @param details table|nil: { location, officer, notes }
RegisterNetEvent('lifeprint:integration:dotInteraction', function(playerSource, eventType, details)
    local src = source
    if not ValidateSource(src) then return end
    
    local playerIdentifier = Bridge.GetIdentifier(playerSource)
    if not playerIdentifier then return end
    
    local playerName = Bridge.GetCharacterName(playerSource) or GetPlayerName(playerSource) or 'Unknown'
    
    -- Determine memory and counter
    local memoryDesc = ''
    local counterType = nil
    
    if eventType == 'citation' then
        memoryDesc = 'Received DOT citation at ' .. (details and details.location or 'Unknown')
        counterType = 'suspicious_actions'
    elseif eventType == 'inspection' then
        memoryDesc = 'DOT inspection at ' .. (details and details.location or 'Unknown')
        counterType = 'meetings'
    elseif eventType == 'clean' then
        memoryDesc = 'Passed DOT inspection with clean record'
        counterType = 'helpful_actions'
    else
        memoryDesc = 'DOT stop at ' .. (details and details.location or 'Unknown')
    end
    
    -- Add memory
    AddMemory(playerIdentifier, {
        memoryType = 'encounter',
        description = memoryDesc,
        location = details and details.location,
        visibility = 'private',
        timestamp = os.time()
    })
    
    -- Update counter
    if counterType then
        IncrementCounter(playerIdentifier, counterType, 1)
    end
    
    -- Generate rumor from template
    local rumorText = GenerateRumor('dot', {
        name = playerName,
        other = details and details.officer or 'a DOT officer',
        location = details and details.location or 'a checkpoint',
        event = eventType
    })
    
    if rumorText then
        AddRumor(playerIdentifier, {
            content = rumorText,
            rumorType = 'hearsay'
        })
    end
    
    DebugLog('DOT interaction processed for: ' .. playerName .. ' (' .. eventType .. ')')
end)

-- ============================================================================
-- Face Memory System
-- Players can remember faces and get walk-by reminders
-- ============================================================================

-- Face memory reminder cooldowns (in-memory cache)
local FaceMemoryReminderCooldowns = {}

--- Get face memories for a player
--- @param identifier string: Player identifier
--- @return table: Array of face memory relationships
local function GetFaceMemories(identifier)
    if not identifier then return {} end
    
    local result = SafeQuery(function()
        return MySQL.query.await([[
            SELECT * FROM lifeprint_relationships
            WHERE identifier = ? AND is_face_memory = 1
            ORDER BY first_met DESC
        ]], { identifier })
    end)
    
    return result or {}
end

--- Get face memory by target identifier
--- @param identifier string: Player identifier
--- @param targetIdentifier string: Target identifier
--- @return table|nil: Face memory relationship or nil
local function GetFaceMemoryByTarget(identifier, targetIdentifier)
    if not identifier or not targetIdentifier then return nil end
    
    local result = SafeQuery(function()
        return MySQL.query.await([[
            SELECT * FROM lifeprint_relationships
            WHERE identifier = ? AND target_identifier = ? AND is_face_memory = 1
            LIMIT 1
        ]], { identifier, targetIdentifier })
    end)
    
    return result and #result > 0 and result[1] or nil
end

--- Create or update face memory
--- @param identifier string: Player identifier
--- @param targetIdentifier string: Target identifier
--- @param targetName string: Target character name
--- @param note string: Note about the person
--- @param location string: Location where remembered
--- @param headshotTxd string|nil: Ped headshot TXD string
--- @return boolean, string|number: success, error message or ID
local function SaveFaceMemory(identifier, targetIdentifier, targetName, note, location, headshotTxd)
    if not identifier or not targetIdentifier then
        return false, 'Missing identifier or target'
    end
    
    -- Check if face memory already exists
    local existing = GetFaceMemoryByTarget(identifier, targetIdentifier)
    
    if existing then
        -- Update existing (include headshot if provided)
        SafeQuery(function()
            if headshotTxd and headshotTxd ~= '' then
                return MySQL.update.await([[
                    UPDATE lifeprint_relationships
                    SET notes = ?, first_location = ?, last_interaction = ?, target_name = ?, headshot_txd = ?
                    WHERE id = ?
                ]], { note, location, os.time(), targetName, headshotTxd, existing.id })
            else
                return MySQL.update.await([[
                    UPDATE lifeprint_relationships
                    SET notes = ?, first_location = ?, last_interaction = ?, target_name = ?
                    WHERE id = ?
                ]], { note, location, os.time(), targetName, existing.id })
            end
        end)
        DebugLog(('Updated face memory: %s -> %s'):format(identifier, targetIdentifier))
        return true, existing.id
    end
    
    -- Create new face memory
    local result = SafeQuery(function()
        return MySQL.insert.await([[
            INSERT INTO lifeprint_relationships
            (identifier, target_identifier, target_name, relationship_value, relationship_type, first_met, last_interaction, notes, first_location, is_face_memory, headshot_txd, is_demo)
            VALUES (?, ?, ?, 0, 'remembered_face', ?, ?, ?, ?, 1, ?, 0)
        ]], {
            identifier,
            targetIdentifier,
            targetName,
            os.time(),
            os.time(),
            note and string.sub(note, 1, 200) or nil,
            location,
            headshotTxd
        })
    end)
    
    if result then
        DebugLog(('Created face memory: %s -> %s'):format(identifier, targetIdentifier))
        return true, result
    end
    
    return false, 'Database insert failed'
end

--- Delete face memory
--- @param identifier string: Player identifier
--- @param targetIdentifier string: Target identifier
--- @return boolean: success
local function DeleteFaceMemory(identifier, targetIdentifier)
    if not identifier or not targetIdentifier then return false end
    
    SafeQuery(function()
        return MySQL.update.await([[
            DELETE FROM lifeprint_relationships
            WHERE identifier = ? AND target_identifier = ? AND is_face_memory = 1
        ]], { identifier, targetIdentifier })
    end)
    
    DebugLog(('Deleted face memory: %s -> %s'):format(identifier, targetIdentifier))
    return true
end

-- Server event: Get face memories for client cache
RegisterNetEvent('lifeprint:server:getFaceMemories', function()
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    local memories = GetFaceMemories(identifier)
    TriggerClientEvent('lifeprint:client:loadFaceMemories', src, memories)
    DebugLog(('Sent %d face memories to client %d'):format(#memories, src))
end)

-- Server event: Remember a face
RegisterNetEvent('lifeprint:server:rememberFace', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    -- Check if feature is enabled
    if not Config or not Config.FaceMemory or not Config.FaceMemory.enabled then
        if Bridge.Notify then Bridge.Notify(src, 'Face memory feature is disabled', 'error') end
        return
    end
    
    -- Validate target
    local targetServerId = data and tonumber(data.targetServerId)
    if not targetServerId or targetServerId <= 0 then
        if Bridge.Notify then Bridge.Notify(src, 'Invalid target player', 'error') end
        return
    end
    
    -- Can't remember self
    if targetServerId == src then
        if Bridge.Notify then Bridge.Notify(src, 'You cannot remember your own face', 'error') end
        return
    end
    
    -- Resolve identifiers
    local identifier = Bridge.GetIdentifier(src)
    local targetIdentifier = Bridge.GetIdentifier(targetServerId)
    
    if not identifier then
        if Bridge.Notify then Bridge.Notify(src, 'Could not resolve your identifier', 'error') end
        return
    end
    
    if not targetIdentifier then
        if Bridge.Notify then Bridge.Notify(src, 'Could not resolve target player identifier', 'error') end
        return
    end
    
    -- Get names
    local playerName = Bridge.GetCharacterName(src) or GetPlayerName(src) or 'Unknown'
    local targetName = Bridge.GetCharacterName(targetServerId) or GetPlayerName(targetServerId) or 'Unknown'
    
    -- Extract headshot TXD from client (validated server-side)
    local headshotTxd = data.headshotTxd
    
    -- Save face memory with headshot
    local success, result = SaveFaceMemory(identifier, targetIdentifier, targetName, data.note, data.location, headshotTxd)
    
    if success then
        -- Add timeline memory
        local memoryDesc = 'You remembered ' .. targetName .. '.'
        if data.note and #data.note > 0 then
            memoryDesc = memoryDesc .. ' ' .. data.note
        end
        
        SafeQuery(function()
            MySQL.insert.await([[
                INSERT INTO lifeprint_memories
                (identifier, target_identifier, memory_type, description, location, timestamp, visibility, is_demo)
                VALUES (?, ?, 'encounter', ?, ?, ?, 'private', 0)
            ]], { identifier, targetIdentifier, memoryDesc, data.location, os.time() })
        end)
        
        -- Update client cache
        local memories = GetFaceMemories(identifier)
        TriggerClientEvent('lifeprint:client:loadFaceMemories', src, memories)
        
        -- Notify
        if Bridge.Notify then
            Bridge.Notify(src, 'Face remembered: ' .. targetName, 'success')
        else
            TriggerClientEvent('lifeprint:client:notify', src, 'Face remembered: ' .. targetName, 'success')
        end
        
        DebugLog(('Face memory created: %s (%s) -> %s (%s)'):format(playerName, identifier, targetName, targetIdentifier))
    else
        if Bridge.Notify then
            Bridge.Notify(src, 'Failed to save face memory', 'error')
        end
    end
end)

-- Server event: Forget a face (admin only)
RegisterNetEvent('lifeprint:server:forgetFace', function(targetServerId)
    local src = source
    if not ValidateSource(src) then return end
    
    -- Check admin permission
    if not (Bridge and Bridge.HasPermission and Bridge.HasPermission(src, 'lifeprint.admin')) then
        if Bridge.Notify then Bridge.Notify(src, 'You do not have permission', 'error') end
        return
    end
    
    -- Validate target
    targetServerId = tonumber(targetServerId)
    if not targetServerId or targetServerId <= 0 then
        if Bridge.Notify then Bridge.Notify(src, 'Invalid target server ID', 'error') end
        return
    end
    
    -- Resolve identifiers
    local identifier = Bridge.GetIdentifier(src)
    local targetIdentifier = Bridge.GetIdentifier(targetServerId)
    
    if not identifier or not targetIdentifier then
        if Bridge.Notify then Bridge.Notify(src, 'Could not resolve identifiers', 'error') end
        return
    end
    
    -- Delete face memory
    DeleteFaceMemory(identifier, targetIdentifier)
    
    -- Update client cache
    local memories = GetFaceMemories(identifier)
    TriggerClientEvent('lifeprint:client:loadFaceMemories', src, memories)
    TriggerClientEvent('lifeprint:client:removeFaceMemory', src, targetIdentifier)
    
    if Bridge.Notify then
        Bridge.Notify(src, 'Face memory forgotten', 'success')
    end
    
    DebugLog(('Face memory forgotten by admin: source %d, target %d'):format(src, targetServerId))
end)

-- Server event: Update face photo (used by /lpcamera)
RegisterNetEvent('lifeprint:server:updateFacePhoto', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    -- Check if feature is enabled
    if not Config or not Config.FaceMemory or not Config.FaceMemory.enabled then
        if Bridge.Notify then Bridge.Notify(src, 'Face memory feature is disabled', 'error') end
        return
    end
    
    -- Validate target
    local targetServerId = data and tonumber(data.targetServerId)
    if not targetServerId or targetServerId <= 0 then
        if Bridge.Notify then Bridge.Notify(src, 'Invalid target player', 'error') end
        return
    end
    
    -- Can't photo self
    if targetServerId == src then
        if Bridge.Notify then Bridge.Notify(src, 'You cannot update your own photo', 'error') end
        return
    end
    
    -- Resolve identifiers
    local identifier = Bridge.GetIdentifier(src)
    local targetIdentifier = Bridge.GetIdentifier(targetServerId)
    
    if not identifier or not targetIdentifier then
        if Bridge.Notify then Bridge.Notify(src, 'Could not resolve identifiers', 'error') end
        return
    end
    
    -- Check if relationship exists
    local existing = GetFaceMemoryByTarget(identifier, targetIdentifier)
    if not existing then
        if Bridge.Notify then Bridge.Notify(src, 'No face memory found for this player. Use /lpremember first.', 'warning') end
        return
    end
    
    -- Update headshot TXD
    local headshotTxd = data.headshotTxd
    if not headshotTxd or headshotTxd == '' then
        if Bridge.Notify then Bridge.Notify(src, 'Invalid photo data', 'error') end
        return
    end
    
    SafeQuery(function()
        MySQL.update.await([[
            UPDATE lifeprint_relationships
            SET headshot_txd = ?, last_interaction = ?
            WHERE id = ?
        ]], { headshotTxd, os.time(), existing.id })
    end)
    
    -- Update client cache
    local memories = GetFaceMemories(identifier)
    TriggerClientEvent('lifeprint:client:loadFaceMemories', src, memories)
    
    -- Notify
    local targetName = Bridge.GetCharacterName(targetServerId) or GetPlayerName(targetServerId) or 'Unknown'
    if Bridge.Notify then
        Bridge.Notify(src, 'Photo updated for ' .. targetName, 'success')
    end
    
    DebugLog(('Face photo updated: %s -> %s, headshot: %s'):format(identifier, targetIdentifier, headshotTxd))
end)

-- Server event: Check proximity for face memory reminder
RegisterNetEvent('lifeprint:server:checkFaceMemoryProximity', function(targetServerId, distance)
    local src = source
    if not ValidateSource(src) then return end
    
    -- Check if feature is enabled
    if not Config or not Config.FaceMemory or not Config.FaceMemory.enabled then return end
    
    -- Resolve identifiers
    local identifier = Bridge.GetIdentifier(src)
    local targetIdentifier = Bridge.GetIdentifier(targetServerId)
    
    if not identifier or not targetIdentifier then return end
    
    -- Check if target is in face memories
    local faceMemory = GetFaceMemoryByTarget(identifier, targetIdentifier)
    
    if not faceMemory then return end  -- Not a remembered face
    
    -- Check cooldown
    local currentTime = os.time()
    local cooldown = Config.FaceMemory.reminderCooldown or 900
    
    if FaceMemoryReminderCooldowns[identifier] and FaceMemoryReminderCooldowns[identifier][targetIdentifier] then
        local lastReminder = FaceMemoryReminderCooldowns[identifier][targetIdentifier]
        if (currentTime - lastReminder) < cooldown then
            return  -- Still on cooldown
        end
    end
    
    -- Initialize cooldown table if needed
    if not FaceMemoryReminderCooldowns[identifier] then
        FaceMemoryReminderCooldowns[identifier] = {}
    end
    
    -- Set cooldown
    FaceMemoryReminderCooldowns[identifier][targetIdentifier] = currentTime
    
    -- Send reminder to client
    local targetName = faceMemory.target_name or 'Unknown'
    local note = faceMemory.notes or ''
    
    TriggerClientEvent('lifeprint:client:faceMemoryReminder', src, targetIdentifier, targetName, note, distance)
    
    DebugLog(('Face memory reminder: %s recognized %s at %.1fm'):format(
        Bridge.GetCharacterName(src) or GetPlayerName(src) or 'Unknown',
        targetName,
        distance
    ))
end)

-- ============================================================================
-- Memory Brought Up Popup System
-- Shows cinematic popup when near someone with shared history
-- ============================================================================

-- Cooldown tracker for memory popups
local MemoryPopupCooldowns = {}

--- Get most recent memory involving a specific target
--- @param identifier string: Player identifier
--- @param targetIdentifier string: Target identifier
--- @return table|nil: Most recent memory or nil
local function GetMostRecentMemoryWithTarget(identifier, targetIdentifier)
    if not identifier or not targetIdentifier then return nil end
    
    local result = SafeQuery(function()
        return MySQL.query.await([[
            SELECT * FROM lifeprint_memories
            WHERE identifier = ? AND target_identifier = ?
            ORDER BY timestamp DESC
            LIMIT 1
        ]], { identifier, targetIdentifier })
    end)
    
    return result and #result > 0 and result[1] or nil
end

--- Get relationship with notes for popup
--- @param identifier string: Player identifier
--- @param targetIdentifier string: Target identifier
--- @return table|nil: Relationship or nil
local function GetRelationshipForPopup(identifier, targetIdentifier)
    if not identifier or not targetIdentifier then return nil end
    
    local result = SafeQuery(function()
        return MySQL.query.await([[
            SELECT * FROM lifeprint_relationships
            WHERE identifier = ? AND target_identifier = ?
            LIMIT 1
        ]], { identifier, targetIdentifier })
    end)
    
    return result and #result > 0 and result[1] or nil
end

-- Server event: Get memory pulse popup data for nearby player with history
RegisterNetEvent('lifeprint:server:getMemoryPopup', function(targetServerId)
    local src = source
    if not ValidateSource(src) then return end
    
    -- Check if feature is enabled (support both MemoryPulse and legacy MemoryPopup)
    local pulseConfig = Config.MemoryPulse or Config.MemoryPopup
    if not Config or not pulseConfig or not pulseConfig.enabled then return end
    
    -- Resolve identifiers server-side (never trust client)
    local identifier = Bridge.GetIdentifier(src)
    local targetIdentifier = Bridge.GetIdentifier(targetServerId)
    
    if not identifier or not targetIdentifier then return end
    if identifier == targetIdentifier then return end  -- Can't have history with self
    
    -- Check if player has memory popups enabled
    if not IsSettingEnabled(identifier, 'memory_popups') then
        DebugLog(('Memory popup skipped for %s - setting disabled'):format(identifier))
        return
    end
    
    -- Check cooldown
    local currentTime = os.time()
    local cooldown = pulseConfig.cooldown or 900
    
    if MemoryPopupCooldowns[identifier] and MemoryPopupCooldowns[identifier][targetIdentifier] then
        local lastPopup = MemoryPopupCooldowns[identifier][targetIdentifier]
        if (currentTime - lastPopup) < cooldown then
            return  -- Still on cooldown
        end
    end
    
    -- Get relationship
    local relationship = GetRelationshipForPopup(identifier, targetIdentifier)
    
    if not relationship then
        -- No relationship exists, don't show popup
        return
    end
    
    -- Get most recent memory with this target
    local recentMemory = GetMostRecentMemoryWithTarget(identifier, targetIdentifier)
    
    -- Set cooldown
    if not MemoryPopupCooldowns[identifier] then
        MemoryPopupCooldowns[identifier] = {}
    end
    MemoryPopupCooldowns[identifier][targetIdentifier] = currentTime
    
    -- Get target name
    local targetName = relationship.target_name or Bridge.GetCharacterName(targetServerId) or GetPlayerName(targetServerId) or 'Unknown'
    
    -- Get memory strength (default 1 if column doesn't exist yet)
    local memoryStrength = tonumber(relationship.memory_strength) or 1
    memoryStrength = math.min(10, math.max(1, memoryStrength))  -- Clamp 1-10
    
    -- Build popup data
    local popupData = {
        targetName = targetName,
        memoryTitle = recentMemory and (recentMemory.title or recentMemory.description) or nil,
        note = relationship.notes or '',
        relationshipType = relationship.relationship_type or 'stranger',
        relationshipValue = relationship.relationship_value or 0,
        memoryStrength = memoryStrength
    }
    
    -- Send popup to client
    TriggerClientEvent('lifeprint:client:showMemoryPopup', src, popupData)
    
    DebugLog(('Memory pulse: %s encountered %s with history (strength: %d)'):format(
        Bridge.GetCharacterName(src) or GetPlayerName(src) or 'Unknown',
        targetName,
        memoryStrength
    ))
end)

-- ============================================================================
-- Recent Faces System
-- Temporary proximity tracking for saving face memories later
-- ============================================================================

-- Server event: Get player info for recent faces list
RegisterNetEvent('lifeprint:server:getRecentFaceInfo', function(targetServerId, location)
    local src = source
    if not ValidateSource(src) then return end
    
    -- Check if feature is enabled
    if not Config or not Config.RecentFaces or not Config.RecentFaces.enabled then return end
    
    -- Validate target server ID
    targetServerId = tonumber(targetServerId)
    if not targetServerId or targetServerId <= 0 then return end
    
    -- Can't track self
    if targetServerId == src then return end
    
    -- Get target name (server-side only)
    local targetName = Bridge.GetCharacterName(targetServerId) or GetPlayerName(targetServerId) or 'Unknown'
    
    -- Send back to client
    TriggerClientEvent('lifeprint:client:addRecentFace', src, targetServerId, targetName, location)
    
    DebugLog(('Recent face info: %s (ID: %d)'):format(targetName, targetServerId))
end)

-- Server event: Remember a face from recent faces list
RegisterNetEvent('lifeprint:server:rememberRecentFace', function(targetServerId)
    local src = source
    if not ValidateSource(src) then return end
    
    -- Check if feature is enabled
    if not Config or not Config.FaceMemory or not Config.FaceMemory.enabled then
        TriggerClientEvent('lifeprint:client:rememberFaceResult', src, false, 'Face memory feature is disabled', targetServerId)
        return
    end
    
    -- Validate target server ID
    targetServerId = tonumber(targetServerId)
    if not targetServerId or targetServerId <= 0 then
        TriggerClientEvent('lifeprint:client:rememberFaceResult', src, false, 'Invalid server ID', targetServerId)
        return
    end
    
    -- Can't remember self
    if targetServerId == src then
        TriggerClientEvent('lifeprint:client:rememberFaceResult', src, false, 'Cannot remember yourself', targetServerId)
        return
    end
    
    -- Check if target still exists (is online)
    local targetIdentifier = Bridge.GetIdentifier(targetServerId)
    
    if not targetIdentifier then
        -- Target has disconnected
        TriggerClientEvent('lifeprint:client:rememberFaceResult', src, false, 'Player has disconnected', targetServerId)
        DebugLog(('Remember recent face failed: target %d disconnected'):format(targetServerId))
        return
    end
    
    -- Get player identifiers
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then
        TriggerClientEvent('lifeprint:client:rememberFaceResult', src, false, 'Could not resolve your identifier', targetServerId)
        return
    end
    
    -- Get names
    local playerName = Bridge.GetCharacterName(src) or GetPlayerName(src) or 'Unknown'
    local targetName = Bridge.GetCharacterName(targetServerId) or GetPlayerName(targetServerId) or 'Unknown'
    
    -- Save face memory (using existing SaveFaceMemory function)
    local location = 'Unknown Location'  -- Will be updated with actual location if available
    local success, result = SaveFaceMemory(identifier, targetIdentifier, targetName, '', location)
    
    if success then
        -- Add timeline memory
        local memoryDesc = 'You remembered ' .. targetName .. '.'
        
        SafeQuery(function()
            MySQL.insert.await([[
                INSERT INTO lifeprint_memories
                (identifier, target_identifier, memory_type, description, location, timestamp, visibility, is_demo)
                VALUES (?, ?, 'encounter', ?, ?, ?, 'private', 0)
            ]], { identifier, targetIdentifier, memoryDesc, location, os.time() })
        end)
        
        -- Update client cache
        local memories = GetFaceMemories(identifier)
        TriggerClientEvent('lifeprint:client:loadFaceMemories', src, memories)
        
        -- Notify success
        if Bridge.Notify then
            Bridge.Notify(src, 'Face remembered: ' .. targetName, 'success')
        end
        
        TriggerClientEvent('lifeprint:client:rememberFaceResult', src, true, 'Face remembered successfully', targetServerId)
        
        DebugLog(('Recent face remembered: %s -> %s'):format(playerName, targetName))
    else
        TriggerClientEvent('lifeprint:client:rememberFaceResult', src, false, 'Failed to save face memory', targetServerId)
    end
end)

--- AddMemory: Create a memory for a player
--- @param source number: Player server ID (required)
--- @param memoryType string: Type of memory (optional, defaults to 'other')
--- @param title string: Title/short description (optional)
--- @param description string: Full description (optional, uses title if nil)
--- @param location string: Location name (optional)
--- @param relatedIdentifier string: Identifier of related person (optional)
--- @param relatedName string: Display name of related person (optional)
--- @param visibility string: 'private', 'public', or 'admin' (optional, defaults to 'private')
--- @return boolean, string|number: success, error message or memory ID
local function Export_AddMemory(source, memoryType, title, description, location, relatedIdentifier, relatedName, visibility)
    -- Validate source
    if not source or type(source) ~= 'number' or source <= 0 then
        return false, 'Invalid source: must be a valid player server ID'
    end
    
    -- Resolve identifier via Bridge (never trust external identifiers)
    local identifier = Bridge and Bridge.GetIdentifier and Bridge.GetIdentifier(source)
    if not identifier then
        return false, 'Could not resolve identifier for source'
    end
    
    -- Validate inputs with safe defaults
    memoryType = memoryType or 'other'
    description = description or title or 'No description'
    location = location or nil
    visibility = visibility or 'private'
    
    -- Validate visibility
    if not IsValidVisibility(visibility) then
        visibility = 'private'
    end
    
    -- Validate memory type against config
    local validType = false
    if Config and Config.MemoryTypes then
        for _, mt in ipairs(Config.MemoryTypes) do
            if mt.id == memoryType then
                validType = true
                break
            end
        end
    end
    if not validType then
        memoryType = 'other'
    end
    
    DebugLog(('Export_AddMemory: source=%d, type=%s, visibility=%s'):format(source, memoryType, visibility))
    
    -- Insert memory
    local result = SafeQuery(function()
        return MySQL.insert.await([[
            INSERT INTO lifeprint_memories 
            (identifier, target_identifier, memory_type, description, location, timestamp, visibility, is_demo)
            VALUES (?, ?, ?, ?, ?, ?, ?, 0)
        ]], {
            identifier,
            relatedIdentifier or nil,
            memoryType,
            description,
            location,
            os.time(),
            visibility
        })
    end)
    
    if result then
        DebugLog(('Export_AddMemory: success, id=%d'):format(result))
        return true, result
    end
    
    return false, 'Database insert failed'
end

--- AddRelationship: Create or update a relationship between two players
--- @param source number: Player server ID (required)
--- @param targetSource number: Target player server ID (required)
--- @param relationshipType string: Type of relationship (optional, defaults to 'stranger')
--- @param scoreChange number: Change in relationship value, -100 to 100 (optional, defaults to 0)
--- @param note string: Private note for the relationship (optional)
--- @return boolean, string|number: success, error message or relationship ID
local function Export_AddRelationship(source, targetSource, relationshipType, scoreChange, note)
    -- Validate source
    if not source or type(source) ~= 'number' or source <= 0 then
        return false, 'Invalid source: must be a valid player server ID'
    end
    
    -- Validate target source
    if not targetSource or type(targetSource) ~= 'number' or targetSource <= 0 then
        return false, 'Invalid targetSource: must be a valid player server ID'
    end
    
    -- Don't allow self-relationships
    if source == targetSource then
        return false, 'Cannot create relationship with self'
    end
    
    -- Resolve identifiers via Bridge
    local identifier = Bridge and Bridge.GetIdentifier and Bridge.GetIdentifier(source)
    local targetIdentifier = Bridge and Bridge.GetIdentifier and Bridge.GetIdentifier(targetSource)
    
    if not identifier then
        return false, 'Could not resolve identifier for source'
    end
    if not targetIdentifier then
        return false, 'Could not resolve identifier for targetSource'
    end
    
    -- Validate/sanitize inputs
    relationshipType = relationshipType or 'stranger'
    scoreChange = tonumber(scoreChange) or 0
    scoreChange = math.max(-100, math.min(100, scoreChange))
    
    -- Validate relationship type against config
    local validType = false
    if Config and Config.RelationshipTypes then
        for _, rt in ipairs(Config.RelationshipTypes) do
            if rt.id == relationshipType then
                validType = true
                break
            end
        end
    end
    if not validType then
        relationshipType = 'stranger'
    end
    
    -- Get target name
    local targetName = Bridge.GetCharacterName and Bridge.GetCharacterName(targetSource) or GetPlayerName(targetSource) or 'Unknown'
    
    DebugLog(('Export_AddRelationship: source=%d, target=%d, type=%s, change=%d'):format(source, targetSource, relationshipType, scoreChange))
    
    -- Check for existing relationship
    local existing = SafeQuery(function()
        return MySQL.query.await([[
            SELECT id, relationship_value FROM lifeprint_relationships
            WHERE identifier = ? AND target_identifier = ?
        ]], { identifier, targetIdentifier })
    end)
    
    if existing and #existing > 0 then
        -- Update existing
        local newValue = math.max(-100, math.min(100, (existing[1].relationship_value or 0) + scoreChange))
        SafeQuery(function()
            return MySQL.update.await([[
                UPDATE lifeprint_relationships
                SET relationship_value = ?, relationship_type = ?, last_interaction = ?, interaction_count = interaction_count + 1, notes = COALESCE(?, notes)
                WHERE id = ?
            ]], { newValue, relationshipType, os.time(), note and string.sub(note, 1, 200) or nil, existing[1].id })
        end)
        DebugLog(('Export_AddRelationship: updated existing, new value=%d'):format(newValue))
        return true, existing[1].id
    end
    
    -- Create new relationship
    local result = SafeQuery(function()
        return MySQL.insert.await([[
            INSERT INTO lifeprint_relationships
            (identifier, target_identifier, target_name, relationship_value, relationship_type, first_met, last_interaction, notes, is_demo)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)
        ]], {
            identifier,
            targetIdentifier,
            targetName,
            scoreChange,
            relationshipType,
            os.time(),
            os.time(),
            note and string.sub(note, 1, 200) or nil
        })
    end)
    
    if result then
        DebugLog(('Export_AddRelationship: created new, id=%d'):format(result))
        return true, result
    end
    
    return false, 'Database insert failed'
end

--- AddReputation: Add reputation points for a player
--- @param source number: Player server ID (required)
--- @param reputationType string: Reputation category (optional, defaults to 'general')
--- @param amount number: Amount to add (can be negative, optional, defaults to 0)
--- @return boolean, string|number: success, error message or reputation ID
local function Export_AddReputation(source, reputationType, amount)
    -- Validate source
    if not source or type(source) ~= 'number' or source <= 0 then
        return false, 'Invalid source: must be a valid player server ID'
    end
    
    -- Resolve identifier
    local identifier = Bridge and Bridge.GetIdentifier and Bridge.GetIdentifier(source)
    if not identifier then
        return false, 'Could not resolve identifier for source'
    end
    
    -- Validate/sanitize inputs
    reputationType = reputationType or 'general'
    amount = tonumber(amount) or 0
    amount = math.max(-100, math.min(100, amount))
    
    DebugLog(('Export_AddReputation: source=%d, type=%s, amount=%d'):format(source, reputationType, amount))
    
    -- Check for existing reputation entry
    local existing = SafeQuery(function()
        return MySQL.query.await([[
            SELECT id, reputation_value FROM lifeprint_reputation
            WHERE identifier = ? AND category = ?
        ]], { identifier, reputationType })
    end)
    
    if existing and #existing > 0 then
        -- Update existing
        local newValue = math.max(-100, math.min(100, (existing[1].reputation_value or 0) + amount))
        SafeQuery(function()
            return MySQL.update.await([[
                UPDATE lifeprint_reputation
                SET reputation_value = ?, last_updated = ?
                WHERE id = ?
            ]], { newValue, os.time(), existing[1].id })
        end)
        DebugLog(('Export_AddReputation: updated existing, new value=%d'):format(newValue))
        return true, existing[1].id
    end
    
    -- Create new reputation entry
    local result = SafeQuery(function()
        return MySQL.insert.await([[
            INSERT INTO lifeprint_reputation
            (identifier, category, reputation_value, last_updated, is_demo)
            VALUES (?, ?, ?, ?, 0)
        ]], { identifier, reputationType, amount, os.time() })
    end)
    
    if result then
        DebugLog(('Export_AddReputation: created new, id=%d'):format(result))
        return true, result
    end
    
    return false, 'Database insert failed'
end

--- AddRumor: Create a rumor for a player
--- @param source number: Player server ID (required)
--- @param category string: Rumor category (optional, defaults to 'hearsay')
--- @param rumorText string: The rumor content (required)
--- @return boolean, string|number: success, error message or rumor ID
local function Export_AddRumor(source, category, rumorText)
    -- Validate source
    if not source or type(source) ~= 'number' or source <= 0 then
        return false, 'Invalid source: must be a valid player server ID'
    end
    
    -- Validate rumor text (required)
    if not rumorText or type(rumorText) ~= 'string' or #rumorText < 5 then
        return false, 'Invalid rumorText: must be a string with at least 5 characters'
    end
    
    -- Resolve identifier
    local identifier = Bridge and Bridge.GetIdentifier and Bridge.GetIdentifier(source)
    if not identifier then
        return false, 'Could not resolve identifier for source'
    end
    
    -- Validate/sanitize category
    category = category or 'hearsay'
    
    -- Validate rumor type against config
    local validType = false
    if Config and Config.RumorTypes then
        for _, rt in ipairs(Config.RumorTypes) do
            if rt.id == category then
                validType = true
                break
            end
        end
    end
    if not validType then
        category = 'hearsay'
    end
    
    -- Calculate expiration
    local expiresAt = nil
    if Config and Config.RumorExpirationDays and Config.RumorExpirationDays > 0 then
        expiresAt = os.time() + (Config.RumorExpirationDays * 86400)
    end
    
    DebugLog(('Export_AddRumor: source=%d, category=%s'):format(source, category))
    
    -- Insert rumor
    local result = SafeQuery(function()
        return MySQL.insert.await([[
            INSERT INTO lifeprint_rumors
            (identifier, source_identifier, rumor_type, content, expires_at, created_at, is_demo)
            VALUES (?, ?, ?, ?, ?, ?, 0)
        ]], {
            identifier,
            identifier,
            category,
            rumorText,
            expiresAt,
            os.time()
        })
    end)
    
    if result then
        DebugLog(('Export_AddRumor: success, id=%d'):format(result))
        return true, result
    end
    
    return false, 'Database insert failed'
end

--- GetLifeprint: Get all Lifeprint data for a player
--- @param source number: Player server ID (required)
--- @return table|nil: { memories, relationships, reputation, rumors } or nil on error
local function Export_GetLifeprint(source)
    -- Validate source
    if not source or type(source) ~= 'number' or source <= 0 then
        DebugLog('Export_GetLifeprint: Invalid source')
        return nil
    end
    
    -- Resolve identifier
    local identifier = Bridge and Bridge.GetIdentifier and Bridge.GetIdentifier(source)
    if not identifier then
        DebugLog('Export_GetLifeprint: Could not resolve identifier')
        return nil
    end
    
    DebugLog(('Export_GetLifeprint: source=%d, identifier=%s'):format(source, identifier))
    
    return {
        memories = GetPlayerMemories(identifier) or {},
        relationships = GetPlayerRelationships(identifier) or {},
        reputation = GetPlayerReputation(identifier) or {},
        rumors = GetPlayerRumors(identifier) or {}
    }
end

--- GetReputation: Get reputation data for a player
--- @param source number: Player server ID (required)
--- @return table: Array of reputation entries (empty table on error)
local function Export_GetReputation(source)
    -- Validate source
    if not source or type(source) ~= 'number' or source <= 0 then
        DebugLog('Export_GetReputation: Invalid source')
        return {}
    end
    
    -- Resolve identifier
    local identifier = Bridge and Bridge.GetIdentifier and Bridge.GetIdentifier(source)
    if not identifier then
        DebugLog('Export_GetReputation: Could not resolve identifier')
        return {}
    end
    
    DebugLog(('Export_GetReputation: source=%d'):format(source))
    return GetPlayerReputation(identifier) or {}
end

--- GetRelationships: Get relationships for a player
--- @param source number: Player server ID (required)
--- @return table: Array of relationships (empty table on error)
local function Export_GetRelationships(source)
    -- Validate source
    if not source or type(source) ~= 'number' or source <= 0 then
        DebugLog('Export_GetRelationships: Invalid source')
        return {}
    end
    
    -- Resolve identifier
    local identifier = Bridge and Bridge.GetIdentifier and Bridge.GetIdentifier(source)
    if not identifier then
        DebugLog('Export_GetRelationships: Could not resolve identifier')
        return {}
    end
    
    DebugLog(('Export_GetRelationships: source=%d'):format(source))
    return GetPlayerRelationships(identifier) or {}
end

--- GetMemories: Get memories for a player with optional limit
--- @param source number: Player server ID (required)
--- @param limit number: Maximum memories to return (optional, defaults to config max)
--- @return table: Array of memories (empty table on error)
local function Export_GetMemories(source, limit)
    -- Validate source
    if not source or type(source) ~= 'number' or source <= 0 then
        DebugLog('Export_GetMemories: Invalid source')
        return {}
    end
    
    -- Resolve identifier
    local identifier = Bridge and Bridge.GetIdentifier and Bridge.GetIdentifier(source)
    if not identifier then
        DebugLog('Export_GetMemories: Could not resolve identifier')
        return {}
    end
    
    -- Validate limit
    limit = tonumber(limit) or (Config and Config.MaxMemoriesPerCharacter) or 100
    limit = math.max(1, math.min(500, limit))
    
    DebugLog(('Export_GetMemories: source=%d, limit=%d'):format(source, limit))
    
    local result = SafeQuery(function()
        return MySQL.query.await([[
            SELECT * FROM lifeprint_memories
            WHERE identifier = ? AND (visibility = 'private' OR visibility = 'public' OR visibility IS NULL)
            ORDER BY timestamp DESC
            LIMIT ?
        ]], { identifier, limit })
    end)
    
    return result or {}
end

-- ============================================================================
-- Debug Mode System
-- Admin-only diagnostic information
-- ============================================================================

-- Track last server callback status
local LastCallbackStatus = {
    callback = nil,
    success = false,
    timestamp = 0,
    error = nil
}

-- Track last error message
local LastError = {
    message = nil,
    timestamp = 0,
    context = nil
}

-- Update callback status (call this from key functions)
local function UpdateCallbackStatus(callbackName, success, errorMsg)
    LastCallbackStatus.callback = callbackName or 'unknown'
    LastCallbackStatus.success = success or false
    LastCallbackStatus.timestamp = os.time()
    LastCallbackStatus.error = errorMsg or nil
    
    if errorMsg then
        LastError.message = errorMsg
        LastError.timestamp = os.time()
        LastError.context = callbackName
    end
end

-- Get oxmysql status safely
local function GetOxmysqlStatus()
    local status = {
        available = false,
        version = nil,
        connection = false
    }
    
    local ok, _ = pcall(function()
        if not MySQL or not MySQL.query then
            return
        end
        status.available = true
        
        -- Try a simple query to test connection
        local result = MySQL.query.await('SELECT 1 as test')
        if result and result[1] and result[1].test == 1 then
            status.connection = true
        end
    end)
    
    return status
end

-- Gather all debug information
local function GatherDebugInfo(src)
    local debugInfo = {
        -- Basic info
        timestamp = os.date('%Y-%m-%d %H:%M:%S'),
        serverId = src,
        
        -- Framework info
        framework = {
            detected = 'standalone',
            available = false,
            coreResource = nil
        },
        
        -- Player info
        player = {
            identifier = nil,
            name = nil,
            permissionCheck = false
        },
        
        -- Database status
        database = {
            available = false,
            connected = false
        },
        
        -- Data counts
        counts = {
            memories = 0,
            relationships = 0,
            rumors = 0,
            reputationRow = false
        },
        
        -- NUI state (client will update this)
        nui = {
            isOpen = false
        },
        
        -- Callback status
        lastCallback = {
            callback = LastCallbackStatus.callback,
            success = LastCallbackStatus.success,
            timestamp = LastCallbackStatus.timestamp,
            error = LastCallbackStatus.error
        },
        
        -- Last error
        lastError = {
            message = LastError.message,
            timestamp = LastError.timestamp,
            context = LastError.context
        }
    }
    
    -- Get framework info safely
    local ok, frameworkName = pcall(function()
        if Bridge and Bridge.GetFramework then
            return Bridge.GetFramework()
        end
        return 'standalone'
    end)
    if ok then
        debugInfo.framework.detected = frameworkName or 'standalone'
        debugInfo.framework.available = true
    end
    
    -- Check framework core resources
    if GetResourceState('qbx_core') == 'started' then
        debugInfo.framework.coreResource = 'qbx_core'
        debugInfo.framework.detected = 'qbox'
    elseif GetResourceState('qb-core') == 'started' then
        debugInfo.framework.coreResource = 'qb-core'
        debugInfo.framework.detected = 'qbcore'
    elseif GetResourceState('es_extended') == 'started' then
        debugInfo.framework.coreResource = 'es_extended'
        debugInfo.framework.detected = 'esx'
    end
    
    -- Get player info safely
    local ok, identifier = pcall(function()
        if Bridge and Bridge.GetIdentifier then
            return Bridge.GetIdentifier(src)
        end
        return nil
    end)
    if ok and identifier then
        debugInfo.player.identifier = identifier
    end
    
    local ok, name = pcall(function()
        if Bridge and Bridge.GetCharacterName then
            return Bridge.GetCharacterName(src)
        end
        return GetPlayerName(src)
    end)
    if ok then
        debugInfo.player.name = name or 'Unknown'
    end
    
    -- Check permission safely
    local ok, hasPerm = pcall(function()
        if Bridge and Bridge.HasPermission then
            return Bridge.HasPermission(src, 'lifeprint.admin')
        end
        return false
    end)
    if ok then
        debugInfo.player.permissionCheck = hasPerm or false
    end
    
    -- Get database status
    debugInfo.database = GetOxmysqlStatus()
    
    -- Get data counts if identifier exists
    if debugInfo.player.identifier then
        local id = debugInfo.player.identifier
        
        -- Memory count
        SafeQuery(function()
            local result = MySQL.query.await('SELECT COUNT(*) as count FROM lifeprint_memories WHERE identifier = ?', { id })
            if result and result[1] then
                debugInfo.counts.memories = result[1].count or 0
            end
        end)
        
        -- Relationship count
        SafeQuery(function()
            local result = MySQL.query.await('SELECT COUNT(*) as count FROM lifeprint_relationships WHERE identifier = ?', { id })
            if result and result[1] then
                debugInfo.counts.relationships = result[1].count or 0
            end
        end)
        
        -- Rumor count
        SafeQuery(function()
            local result = MySQL.query.await('SELECT COUNT(*) as count FROM lifeprint_rumors WHERE identifier = ?', { id })
            if result and result[1] then
                debugInfo.counts.rumors = result[1].count or 0
            end
        end)
        
        -- Reputation row exists
        SafeQuery(function()
            local result = MySQL.query.await('SELECT 1 as exists FROM lifeprint_reputation WHERE identifier = ? LIMIT 1', { id })
            debugInfo.counts.reputationRow = result and #result > 0
        end)
    end
    
    return debugInfo
end

-- Admin Command: /lpdebug (Debug Information Report)
RegisterNetEvent('lifeprint:server:adminDebug', function()
    local src = source
    if not ValidateSource(src) then return end
    
    -- Check if debug commands are enabled
    if not (Config and Config.DebugCommands) then
        if Bridge and Bridge.Notify then Bridge.Notify(src, 'Debug commands are disabled', 'error') end
        return
    end
    
    -- Check permission
    local hasPermission = false
    local ok, result = pcall(function()
        if Bridge and Bridge.HasPermission then
            return Bridge.HasPermission(src, 'lifeprint.admin')
        end
        return false
    end)
    if ok then hasPermission = result end
    
    if not hasPermission then
        if Bridge and Bridge.Notify then Bridge.Notify(src, 'You do not have permission', 'error') end
        return
    end
    
    -- Gather debug info
    local debugInfo = GatherDebugInfo(src)
    
    -- Log to server console if debug mode is enabled
    if Config and Config.Debug then
        print('^3[Lifeprint Debug]^7 ===== DEBUG REPORT =====')
        print(('  Framework: %s'):format(debugInfo.framework.detected))
        print(('  Core Resource: %s'):format(debugInfo.framework.coreResource or 'none'))
        print(('  Player ID: %s'):format(debugInfo.serverId))
        print(('  Identifier: %s'):format(debugInfo.player.identifier or 'N/A'))
        print(('  Character Name: %s'):format(debugInfo.player.name or 'Unknown'))
        print(('  Admin Permission: %s'):format(debugInfo.player.permissionCheck and 'YES' or 'NO'))
        print(('  oxmysql Available: %s'):format(debugInfo.database.available and 'YES' or 'NO'))
        print(('  Database Connected: %s'):format(debugInfo.database.connected and 'YES' or 'NO'))
        print(('  Memory Count: %d'):format(debugInfo.counts.memories))
        print(('  Relationship Count: %d'):format(debugInfo.counts.relationships))
        print(('  Rumor Count: %d'):format(debugInfo.counts.rumors))
        print(('  Reputation Row: %s'):format(debugInfo.counts.reputationRow and 'EXISTS' or 'NOT FOUND'))
        print(('  Last Callback: %s (%s)'):format(debugInfo.lastCallback.callback or 'none', debugInfo.lastCallback.success and 'SUCCESS' or 'FAILED'))
        if debugInfo.lastError.message then
            print(('  Last Error: %s [%s]'):format(debugInfo.lastError.message, debugInfo.lastError.context or 'unknown'))
        end
        print('^3[Lifeprint Debug]^7 ========================')
    end
    
    -- Send debug info to client for NUI display
    TriggerClientEvent('lifeprint:client:showDebugPanel', src, debugInfo)
    
    UpdateCallbackStatus('adminDebug', true)
end)

-- Export for external debug access
exports('GetDebugInfo', function(src)
    return GatherDebugInfo(src)
end)

-- Export to update callback status (for internal use)
exports('UpdateCallbackStatus', UpdateCallbackStatus)

-- ============================================================================
-- Export Registrations
-- ============================================================================

-- Primary exports (new signature with source instead of identifier)
exports('AddMemory', Export_AddMemory)
exports('AddRelationship', Export_AddRelationship)
exports('AddReputation', Export_AddReputation)
exports('AddRumor', Export_AddRumor)
exports('GetLifeprint', Export_GetLifeprint)
exports('GetReputation', Export_GetReputation)
exports('GetRelationships', Export_GetRelationships)
exports('GetMemories', Export_GetMemories)

-- Legacy exports (identifier-based, for backwards compatibility)
exports('AddMemoryByIdentifier', AddMemory)
exports('AddRelationshipByIdentifier', AddRelationship)
exports('AddReputationByIdentifier', AddReputation)
exports('AddRumorByIdentifier', AddRumor)

-- Data retrieval exports (identifier-based)
exports('GetLifeprintByIdentifier', GetPlayerLifeprint)
exports('GetMemoriesByIdentifier', GetPlayerMemories)
exports('GetPublicMemories', GetPublicMemories)
exports('GetAllMemoriesAdmin', GetAllMemoriesAdmin)
exports('GetRelationshipsByIdentifier', GetPlayerRelationships)
exports('GetReputationByIdentifier', GetPlayerReputation)
exports('GetRumorsByIdentifier', GetPlayerRumors)

-- Counter/Tag exports
exports('GetCounters', GetPlayerCounters)
exports('GetCountersBySource', function(src)
    local id = Bridge and Bridge.GetIdentifier and Bridge.GetIdentifier(src)
    return id and GetPlayerCounters(id) or nil
end)
exports('IncrementCounter', IncrementCounter)
exports('IncrementCounterBySource', function(src, counterType, amount)
    local id = Bridge and Bridge.GetIdentifier and Bridge.GetIdentifier(src)
    return id and IncrementCounter(id, counterType, amount) or false
end)
exports('SetCounter', SetCounter)
exports('SetCounterBySource', function(src, counterType, value)
    local id = Bridge and Bridge.GetIdentifier and Bridge.GetIdentifier(src)
    return id and SetCounter(id, counterType, value) or false
end)
exports('GetTags', function(id) return GenerateTagsFromCounters(GetPlayerCounters(id)) end)
exports('GetTagsBySource', function(src)
    local id = Bridge and Bridge.GetIdentifier and Bridge.GetIdentifier(src)
    return id and GenerateTagsFromCounters(GetPlayerCounters(id)) or {}
end)
exports('GetCharacterRead', function(id)
    local c = GetPlayerCounters(id)
    return GenerateCharacterRead(GenerateTagsFromCounters(c), c)
end)
exports('GetCharacterReadBySource', function(src)
    local id = Bridge and Bridge.GetIdentifier and Bridge.GetIdentifier(src)
    if not id then return '' end
    local c = GetPlayerCounters(id)
    return GenerateCharacterRead(GenerateTagsFromCounters(c), c)
end)

-- ============================================================================
-- NPC Witness System
-- Handle witnessed events from clients, create memories, reputation, rumors
-- ============================================================================

-- Get NPC Witness config safely
local function GetNPCWitnessConfig(key, default)
    if Config and Config.NPCWitness and Config.NPCWitness[key] ~= nil then
        return Config.NPCWitness[key]
    end
    return default
end

-- Get NPC Violence config safely
local function GetNPCViolenceConfig(key, default)
    if Config and Config.NPCViolence and Config.NPCViolence[key] ~= nil then
        return Config.NPCViolence[key]
    end
    return default
end

-- Counter mapping for event types
local NPCWitnessCounters = {
    npc_vehicle_theft = 'npc_vehicle_thefts',
    npc_assault = 'npc_assaults',
    npc_kill = 'npc_kills',
    gunshots = 'gunshots_reported',
    reckless_driving = 'gunshots_reported',  -- Reckless driving doesn't have its own counter
    drug_deal = 'drug_deals'
}

-- Main NPC Witness Event Handler
RegisterNetEvent('lifeprint:npcWitness:report', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    local eventType = data and data.eventType
    if not eventType then
        DebugLog('NPC Witness: Missing event type')
        return
    end
    
    -- Check NPCViolence config for violence-related events
    local violenceEvents = { npc_assault = true, npc_kill = true, gunshots = true }
    if violenceEvents[eventType] then
        if not GetNPCViolenceConfig('enabled', true) then
            DebugLog(('NPC Violence: %s disabled'):format(eventType))
            return
        end
        
        -- Check specific event toggles
        if eventType == 'npc_assault' and not GetNPCViolenceConfig('trackAssault', true) then return end
        if eventType == 'npc_kill' and not GetNPCViolenceConfig('trackKills', true) then return end
        if eventType == 'gunshots' and not GetNPCViolenceConfig('trackGunshots', true) then return end
    else
        -- Check general NPCWitness config for other events
        if not GetNPCWitnessConfig('enabled', true) then
            DebugLog('NPC Witness: System disabled')
            return
        end
    end
    
    -- Check cooldown
    local cooldown = violenceEvents[eventType] 
        and GetNPCViolenceConfig('cooldown', 300)
        or GetNPCWitnessConfig('cooldown', 300)
    if not CheckCooldown('npcwitness_' .. eventType, identifier, cooldown) then
        DebugLog(('NPC Witness: %s on cooldown for %s'):format(eventType, identifier))
        return
    end
    
    DebugLog(('NPC Witness: Processing %s for %s'):format(eventType, identifier))
    
    local playerName = Bridge.GetCharacterName(src) or GetPlayerName(src) or 'Unknown'
    local coords = data.coords
    local location = data.location or 'Unknown Location'
    local witnessCount = data.witnessCount or 1
    local metadata = data.metadata or {}
    
    -- Build memory title and description
    local memoryTitle, description
    
    -- Use NPCViolence config for violence events
    if violenceEvents[eventType] then
        local memories = GetNPCViolenceConfig('memories', {})
        local eventMemory = memories[eventType] or {}
        
        memoryTitle = eventMemory.title or 'Witnessed Event'
        description = eventMemory.description or 'Suspicious activity.'
        description = description:gsub('{location}', location)
    else
        -- Use NPCWitness config for other events
        local memoryTitles = GetNPCWitnessConfig('memoryTitles', {})
        memoryTitle = memoryTitles[eventType] or 'Witnessed Event'
        
        -- Build description based on event type
        if eventType == 'npc_vehicle_theft' then
            local vehicleModel = metadata.vehicleModel or 'vehicle'
            description = ('You were seen taking a vehicle that was not yours near %s.'):format(location)
        elseif eventType == 'reckless_driving' then
            local speed = metadata.speed and math.floor(metadata.speed * 3.6) or 'high'
            description = ('Drove recklessly (%s km/h) through %s. Pedestrians were alarmed.'):format(tostring(speed), location)
        elseif eventType == 'drug_deal' then
            description = ('A suspicious exchange occurred near %s. Something was seen.'):format(location)
        else
            description = ('Suspicious activity near %s. Witnesses were present.'):format(location)
        end
    end
    
    -- Create memory with coordinates
    AddMemory(identifier, {
        memoryType = eventType,
        title = memoryTitle,
        description = description,
        location = location,
        x = coords and coords.x,
        y = coords and coords.y,
        z = coords and coords.z,
        visibility = 'private',
        metadata = metadata
    })
    
    -- Update reputation counter(s)
    if violenceEvents[eventType] then
        -- Use NPCViolence counter increments
        local counterIncrements = GetNPCViolenceConfig('counterIncrements', {})
        local increments = counterIncrements[eventType] or {}
        for counterType, amount in pairs(increments) do
            IncrementCounter(identifier, counterType, amount)
        end
    else
        -- Use single counter for other events
        local counterKey = NPCWitnessCounters[eventType]
        if counterKey then
            IncrementCounter(identifier, counterKey, 1)
        end
    end
    
    -- Update reputation value
    local repChange
    if violenceEvents[eventType] then
        local repChanges = GetNPCViolenceConfig('reputationChanges', {})
        repChange = repChanges[eventType] or -5
    else
        local reputationChanges = GetNPCWitnessConfig('reputationChanges', {})
        repChange = reputationChanges[eventType:gsub('npc_', '')] or -5
    end
    
    if repChange and repChange ~= 0 then
        AddReputation(identifier, { category = 'criminal', change = repChange, reason = 'NPC witnessed: ' .. eventType })
        AddReputation(identifier, { category = 'general', change = repChange, reason = 'NPC witnessed: ' .. eventType })
    end
    
    -- Create rumor if enabled
    local shouldCreateRumor = violenceEvents[eventType]
        and GetNPCViolenceConfig('createRumors', true)
        or GetNPCWitnessConfig('createRumors', true)
    
    if shouldCreateRumor then
        local templates
        if violenceEvents[eventType] then
            local rumorTemplates = GetNPCViolenceConfig('rumorTemplates', {})
            templates = rumorTemplates[eventType]
        else
            local rumorTemplates = GetNPCWitnessConfig('rumorTemplates', {})
            templates = rumorTemplates[eventType]
        end
        
        if templates and #templates > 0 then
            -- Pick random template
            local template = templates[math.random(1, #templates)]
            
            -- Replace placeholders
            local rumorText = template
                :gsub('{name}', playerName)
                :gsub('{location}', location)
            
            AddRumor(identifier, {
                content = rumorText,
                rumorType = 'criminal',
                sourceIdentifier = nil,  -- Anonymous city witness
                targetIdentifier = identifier,
                targetName = playerName
            })
            
            DebugLog(('NPC Witness: Created rumor for %s'):format(eventType))
        end
    end
    
    -- Send notification to player
    TriggerClientEvent('lifeprint:client:journalNotification', src, {
        type = 'memory',
        title = memoryTitle,
        message = description,
        flavorType = 'witnessed'
    })
    
    DebugLog(('NPC Witness: Completed %s for %s at %s'):format(eventType, identifier, location))
end)

-- Integration event for drug deals (called by external scripts)
RegisterNetEvent('lifeprint:integration:drugDeal', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    -- Forward to NPC witness system
    TriggerEvent('lifeprint:npcWitness:report', {
        eventType = 'drug_deal',
        coords = data and data.coords,
        location = data and data.location,
        witnessCount = data and data.witnessCount or 1,
        metadata = data and data.metadata or {}
    })
end)

-- ============================================================================
-- Vehicle Theft Ownership Check
-- Validates if a vehicle is owned by the player before creating theft memory
-- ============================================================================

local function GetVehicleTheftConfig(key, default)
    if Config and Config.NPCVehicleTheft and Config.NPCVehicleTheft[key] ~= nil then
        return Config.NPCVehicleTheft[key]
    end
    return default
end

-- Check if vehicle is owned by the player (framework-specific)
local function IsVehicleOwnedByPlayer(src, plate)
    if not plate or plate == '' then return false end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return false end
    
    local framework = Bridge.GetFramework()
    
    -- QBCore: Check player_vehicles table
    if framework == 'qbcore' or framework == 'qbox' then
        local result = SafeQuery(function()
            return MySQL.query.await([[
                SELECT 1 FROM player_vehicles 
                WHERE plate = ? AND citizenid = ?
                LIMIT 1
            ]], { plate, identifier })
        end)
        return result and #result > 0
    end
    
    -- ESX: Check owned_vehicles table
    if framework == 'esx' then
        local result = SafeQuery(function()
            return MySQL.query.await([[
                SELECT 1 FROM owned_vehicles 
                WHERE plate = ? AND owner = ?
                LIMIT 1
            ]], { plate, identifier })
        end)
        return result and #result > 0
    end
    
    -- Standalone: No vehicle ownership database, assume NPC vehicle
    -- Server owners can customize this to check their own vehicle tables
    return false
end

-- Vehicle Theft Event Handler
RegisterNetEvent('lifeprint:vehicleTheft:checkOwnership', function(data)
    local src = source
    if not ValidateSource(src) then return end
    
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    
    -- Check if system is enabled
    if not GetVehicleTheftConfig('enabled', true) then
        DebugLog('Vehicle Theft: System disabled')
        return
    end
    
    local plate = data and data.plate
    local model = data and data.model or 'Unknown Vehicle'
    local coords = data and data.coords
    local location = data and data.location or 'Unknown Location'
    local witnessCount = data and data.witnessCount or 1
    
    -- Check cooldown
    local cooldown = GetVehicleTheftConfig('cooldown', 600)
    if not CheckCooldown('vehicle_theft', identifier, cooldown) then
        DebugLog(('Vehicle Theft: On cooldown for %s'):format(identifier))
        return
    end
    
    -- Check if player owns this vehicle
    if IsVehicleOwnedByPlayer(src, plate) then
        DebugLog(('Vehicle Theft: Player owns vehicle %s'):format(plate))
        return
    end
    
    -- Also check QBCore/Qbox garage system for vehicle state
    -- This prevents triggering for vehicles that were just spawned from garage
    local framework = Bridge.GetFramework()
    if framework == 'qbcore' or framework == 'qbox' then
        local garageResult = SafeQuery(function()
            return MySQL.query.await([[
                SELECT state FROM player_vehicles 
                WHERE plate = ?
                LIMIT 1
            ]], { plate })
        end)
        
        -- If vehicle is in garage state (0), it's an NPC vehicle
        -- If state is 1 (out), it might be player's vehicle
        if garageResult and #garageResult > 0 then
            local state = garageResult[1].state
            if state == 1 then
                -- Vehicle is out, check if it belongs to someone else
                -- This is still theft if player doesn't own it
                DebugLog(('Vehicle Theft: Vehicle %s is out of garage, checking ownership'):format(plate))
            end
        end
    end
    
    local playerName = Bridge.GetCharacterName(src) or GetPlayerName(src) or 'Unknown'
    
    DebugLog(('Vehicle Theft: Confirmed for %s - %s at %s'):format(identifier, model, location))
    
    -- Create memory
    local memoryDescription = ('You were seen taking a vehicle that was not yours near %s.'):format(location)
    
    AddMemory(identifier, {
        memoryType = GetVehicleTheftConfig('memoryType', 'npc_vehicle_theft'),
        description = memoryDescription,
        location = location,
        x = coords and coords.x,
        y = coords and coords.y,
        z = coords and coords.z,
        visibility = 'private',
        metadata = {
            vehicleModel = model,
            vehiclePlate = plate,
            witnessCount = witnessCount,
            timeDriven = data and data.timeDriven,
            distanceDriven = data and data.distanceDriven
        }
    })
    
    -- Update counters
    IncrementCounter(identifier, GetVehicleTheftConfig('counterType', 'npc_vehicle_thefts'), 1)
    local secondaryCounter = GetVehicleTheftConfig('secondaryCounterType', 'suspicious_actions')
    if secondaryCounter then
        IncrementCounter(identifier, secondaryCounter, 1)
    end
    
    -- Update reputation
    local repChange = GetVehicleTheftConfig('reputationChange', -10)
    if repChange ~= 0 then
        AddReputation(identifier, { category = 'criminal', change = repChange, reason = 'Vehicle theft witnessed' })
        AddReputation(identifier, { category = 'general', change = repChange, reason = 'Vehicle theft witnessed' })
    end
    
    -- Create rumor if enabled
    if GetVehicleTheftConfig('createRumor', true) then
        local rumorTemplate = GetVehicleTheftConfig('rumorTemplate', 
            'Locals say someone matching {name}\'s description stole a vehicle near {location}.')
        
        local rumorText = rumorTemplate
            :gsub('{name}', playerName)
            :gsub('{location}', location)
        
        AddRumor(identifier, {
            content = rumorText,
            rumorType = 'crime',
            sourceIdentifier = nil,  -- Anonymous city witness
            targetIdentifier = identifier,
            targetName = playerName
        })
        
        DebugLog(('Vehicle Theft: Created rumor for %s'):format(identifier))
    end
    
    -- Send notification to player
    TriggerClientEvent('lifeprint:client:journalNotification', src, {
        type = 'memory',
        title = GetVehicleTheftConfig('memoryTitle', 'Vehicle Theft'),
        message = memoryDescription,
        flavorType = 'criminal'
    })
    
    DebugLog(('Vehicle Theft: Completed for %s at %s'):format(identifier, location))
end)

-- Delete exports
exports('DeleteMemory', DeleteMemory)
exports('DeleteRumor', DeleteRumor)

-- Rumor Template System
exports('GenerateRumor', GenerateRumor)
exports('ClearRecentRumorCache', ClearRecentRumorCache)
