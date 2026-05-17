# Lifeprint Integration Guide

<div align="center">

**The City Remembers**

*Connect your server systems to Lifeprint*

</div>

---

## Overview

Lifeprint provides two integration methods:

| Method | Difficulty | Use Case |
|--------|------------|----------|
| **Integration Events** | Easy | Drop-in triggers for common systems |
| **Direct Exports** | Advanced | Full control over data creation |

Both methods are **server-side only** for security.

---

## Quick Integration Events

The easiest way to connect your resources. Just trigger an event and Lifeprint handles the rest.

### Police Arrest

```lua
-- When a player is arrested
TriggerEvent('lifeprint:integration:policeArrest',
    playerSource,    -- The arrested player
    officerSource,   -- The officer (or nil)
    'Vespucci Blvd', -- Location
    'Suspected GTA'  -- Charges
)
```

**What it creates:**
- Crime memory with officer name and charges
- Adversary relationship with officer (-10)
- Law reputation hit (-5)
- Arrests counter increment
- Crime rumor from template

**Example Integration:**

```lua
-- In your police resource
RegisterNetEvent('police:server:arrestPlayer', function(targetSource, charges)
    local officerSource = source
    
    -- Your existing arrest logic...
    
    -- Add to Lifeprint
    TriggerEvent('lifeprint:integration:policeArrest',
        targetSource,
        officerSource,
        'Arrest Location',
        charges
    )
end)
```

---

### EMS Treatment

```lua
-- When a player receives medical treatment
TriggerEvent('lifeprint:integration:emsTreatment',
    patientSource,     -- The treated player
    medicSource,       -- The medic (or nil)
    'Pillbox Medical', -- Location
    'Gunshot wounds'   -- Treatment type
)
```

**What it creates:**
- Rescue memory with medic name
- Friend relationship with medic (+10)
- Medical reputation boost (+1)
- EMS visits counter increment

**Example Integration:**

```lua
-- In your EMS resource
RegisterNetEvent('ems:server:revivePlayer', function(targetSource, injuries)
    local medicSource = source
    
    -- Your existing revive logic...
    
    TriggerEvent('lifeprint:integration:emsTreatment',
        targetSource,
        medicSource,
        'Pillbox Hill Medical Center',
        injuries
    )
end)
```

---

### Jail Sentence

```lua
-- When a player is sent to jail
TriggerEvent('lifeprint:integration:jail',
    playerSource,   -- The jailed player
    15,             -- Duration (months)
    'Grand Theft Auto' -- Charges
)
```

**What it creates:**
- Crime memory with sentence details
- Criminal reputation hit (-10)
- Arrests counter increment
- Crime rumor about jail time

**Example Integration:**

```lua
-- In your judicial/jail resource
RegisterNetEvent('court:server:sentence', function(targetSource, months, crime)
    TriggerEvent('lifeprint:integration:jail',
        targetSource,
        months,
        crime
    )
end)
```

---

### Billing

```lua
-- When a player receives or pays a bill
TriggerEvent('lifeprint:integration:bill',
    playerSource,   -- The billed player
    5000,           -- Amount
    'Medical Services', -- Reason
    isPaid          -- true if paid, false if unpaid
)
```

**What it creates:**
- Business memory for transaction
- Business reputation change (+2 paid, -2 unpaid)

**Example Integration:**

```lua
-- When a bill is paid
RegisterNetEvent('billing:server:payBill', function(billId)
    -- Your existing payment logic...
    
    TriggerEvent('lifeprint:integration:bill',
        source,
        bill.amount,
        bill.reason,
        true  -- Paid
    )
end)
```

---

### Gang Interaction

```lua
-- For gang-related activities
TriggerEvent('lifeprint:integration:gangInteraction',
    playerSource,    -- The player
    targetSource,    -- Related player (or nil)
    'The Lost MC',   -- Gang name
    'join'           -- Interaction type
)
```

**Interaction Types:** `join`, `leave`, `conflict`, `ally`

**What it creates:**
- Encounter memory with gang name
- Relationship with involved player
- Underground reputation change
- Meetings counter increment
- Secret rumor about connections

**Example Integration:**

```lua
-- Gang recruitment
RegisterNetEvent('gang:server:recruitMember', function(newMemberSource, gangName)
    TriggerEvent('lifeprint:integration:gangInteraction',
        newMemberSource,
        source,  -- Recruiter
        gangName,
        'join'
    )
end)
```

---

### Business Interaction

```lua
-- For business transactions
TriggerEvent('lifeprint:integration:businessInteraction',
    playerSource,       -- The player
    businessOwnerSource, -- Owner (or nil)
    'Gemini Motel',     -- Business name
    'purchase'          -- Interaction type
)
```

**Interaction Types:** `purchase`, `sale`, `contract`, `hire`, `fire`

**What it creates:**
- Business memory
- Acquaintance relationship with owner
- Business reputation boost (+3)
- Meetings counter increment

**Example Integration:**

```lua
-- Property purchase
RegisterNetEvent('realestate:server:purchaseProperty', function(propertyId, ownerSource)
    TriggerEvent('lifeprint:integration:businessInteraction',
        source,
        ownerSource,
        propertyId.name,
        'purchase'
    )
end)
```

---

### Trucking Event

```lua
-- For trucking job events
TriggerEvent('lifeprint:integration:truckingEvent',
    playerSource,        -- The trucker
    'delivery_success',  -- Event type
    'Port of Los Santos', -- Location
    'Luxury Electronics'  -- Details
)
```

**Event Types:** `delivery_success`, `delivery_fail`, `crash`, `job_complete`

**What it creates:**
- Business memory for the job
- Business reputation change (+2 success, -3 crash)
- Appropriate counter increment

**Example Integration:**

```lua
-- Successful delivery
RegisterNetEvent('trucking:server:completeDelivery', function(cargo, location)
    TriggerEvent('lifeprint:integration:truckingEvent',
        source,
        'delivery_success',
        location,
        cargo
    )
end)

-- Truck crash
RegisterNetEvent('trucking:server:crash', function(location, details)
    TriggerEvent('lifeprint:integration:truckingEvent',
        source,
        'crash',
        location,
        details
    )
end)
```

---

### DOT Inspection

```lua
-- For Department of Transportation interactions
TriggerEvent('lifeprint:integration:dotInteraction',
    playerSource,    -- The inspected player
    officerSource,   -- DOT officer
    'inspection',    -- Inspection type
    true             -- Passed (true/false)
)
```

**Inspection Types:** `inspection`, `citation`, `warning`, `clear`

**What it creates:**
- Encounter memory with officer
- Relationship with officer (-5)
- General reputation change (+2 clean, -2 failed)
- Appropriate counter increment

**Example Integration:**

```lua
-- DOT inspection complete
RegisterNetEvent('dot:server:inspectionComplete', function(driverSource, passed)
    TriggerEvent('lifeprint:integration:dotInteraction',
        driverSource,
        source,
        'inspection',
        passed
    )
end)
```

---

## Direct Exports

For full control over data creation. All exports accept **player source** (server ID) and resolve identifiers internally via Bridge for security.

### AddMemory

Creates a memory for a player.

```lua
local success, result = exports.lifeprint:AddMemory(
    source,              -- Player server ID (required)
    "encounter",         -- Memory type (optional, defaults to 'other')
    "Met at Fleeca",     -- Title (optional)
    "Had a brief conversation at the bank ATM", -- Description (optional, uses title if nil)
    "Fleeca Bank",       -- Location (optional)
    nil,                 -- Related identifier (optional)
    nil,                 -- Related name (optional)
    "private"            -- Visibility: 'private', 'public', or 'admin' (optional)
)

if success then
    print("Memory created with ID:", result)
else
    print("Error:", result)
end
```

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| source | number | Yes | - | Player server ID |
| memoryType | string | No | 'other' | Memory category |
| title | string | No | - | Short title |
| description | string | No | title | Full description |
| location | string | No | nil | Location name |
| relatedIdentifier | string | No | nil | Identifier of related person |
| relatedName | string | No | nil | Display name of related person |
| visibility | string | No | 'private' | 'private', 'public', or 'admin' |

**Returns:** `success (boolean), id (number) or errorMessage (string)`

---

### AddRelationship

Creates or updates a relationship between two players.

```lua
local success, result = exports.lifeprint:AddRelationship(
    source,           -- Player server ID (required)
    targetSource,     -- Target player server ID (required)
    "friend",         -- Relationship type (optional, defaults to 'stranger')
    15,               -- Score change: -100 to 100 (optional, defaults to 0)
    "Helped me with a flat tire"  -- Private note (optional)
)

if success then
    print("Relationship updated, ID:", result)
else
    print("Error:", result)
end
```

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| source | number | Yes | - | Player server ID |
| targetSource | number | Yes | - | Target player server ID |
| relationshipType | string | No | 'stranger' | Type of relationship |
| scoreChange | number | No | 0 | Change amount (-100 to 100) |
| note | string | No | nil | Private note (max 200 chars) |

**Returns:** `success (boolean), id (number) or errorMessage (string)`

**Notes:**
- Automatically resolves identifiers via Bridge
- Updates existing relationship if one exists
- Clamps values to -100 to 100 range

---

### AddReputation

Adds reputation points for a player.

```lua
local success, result = exports.lifeprint:AddReputation(
    source,       -- Player server ID (required)
    "criminal",    -- Reputation category (optional, defaults to 'general')
    -10            -- Amount to add (optional, defaults to 0, can be negative)
)

if success then
    print("Reputation updated, ID:", result)
else
    print("Error:", result)
end
```

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| source | number | Yes | - | Player server ID |
| reputationType | string | No | 'general' | Reputation category |
| amount | number | No | 0 | Points to add (can be negative) |

**Returns:** `success (boolean), id (number) or errorMessage (string)`

---

### AddRumor

Creates a rumor for a player.

```lua
local success, result = exports.lifeprint:AddRumor(
    source,                                  -- Player server ID (required)
    "hearsay",                               -- Rumor category (optional)
    "Word on the street is they've been meeting with some shady characters downtown"
)

if success then
    print("Rumor created with ID:", result)
else
    print("Error:", result)
end
```

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| source | number | Yes | - | Player server ID |
| category | string | No | 'hearsay' | Rumor category |
| rumorText | string | Yes | - | Rumor content (min 5 chars) |

**Returns:** `success (boolean), id (number) or errorMessage (string)`

---

### GetLifeprint

Retrieves all Lifeprint data for a player.

```lua
local data = exports.lifeprint:GetLifeprint(source)

if data then
    print("Memories:", #data.memories)
    print("Relationships:", #data.relationships)
    print("Reputation entries:", #data.reputation)
    print("Rumors:", #data.rumors)
else
    print("Could not retrieve data")
end
```

**Returns:** `table` with `{ memories, relationships, reputation, rumors }` or `nil` on error

---

### GetReputation

Retrieves reputation entries for a player.

```lua
local reputation = exports.lifeprint:GetReputation(source)

for _, entry in ipairs(reputation) do
    print(entry.category, entry.reputation_value)
end
```

**Returns:** `table` (array of reputation entries, empty table on error)

---

### GetRelationships

Retrieves relationships for a player.

```lua
local relationships = exports.lifeprint:GetRelationships(source)

for _, rel in ipairs(relationships) do
    print(rel.target_name, rel.relationship_value, rel.relationship_type)
end
```

**Returns:** `table` (array of relationships, empty table on error)

---

### GetMemories

Retrieves memories for a player with optional limit.

```lua
local memories = exports.lifeprint:GetMemories(source, 20)  -- Get last 20 memories

for _, mem in ipairs(memories) do
    print(mem.description, mem.location, os.date('%Y-%m-%d', mem.timestamp))
end
```

**Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| source | number | Yes | - | Player server ID |
| limit | number | No | 100 | Max memories to return (1-500) |

**Returns:** `table` (array of memories, empty table on error)

---

## Counter & Tag Exports

Work with the reputation counter system.

### GetCountersBySource

```lua
local counters = exports.lifeprint:GetCountersBySource(source)

if counters then
    print("Arrests:", counters.arrests)
    print("EMS Visits:", counters.ems_visits)
    print("Crashes:", counters.crashes)
    print("Meetings:", counters.meetings)
end
```

---

### IncrementCounterBySource

```lua
-- Increment meetings counter by 1
exports.lifeprint:IncrementCounterBySource(source, 'meetings', 1)

-- Increment arrests counter by 1
exports.lifeprint:IncrementCounterBySource(source, 'arrests', 1)
```

---

### SetCounterBySource

```lua
-- Set arrests counter to specific value
exports.lifeprint:SetCounterBySource(source, 'arrests', 5)
```

---

### GetTagsBySource

```lua
local tags = exports.lifeprint:GetTagsBySource(source)

for _, tag in ipairs(tags) do
    print(tag.label, tag.style, tag.priority)
    -- Example: "Has a Record", "danger", 10
end
```

---

### GetCharacterReadBySource

```lua
local readText = exports.lifeprint:GetCharacterReadBySource(source)
-- Returns: "Your Lifeprint suggests a well-connected individual with a record..."
print(readText)
```

---

## Legacy Exports (Identifier-Based)

For backwards compatibility with existing integrations that already have player identifiers.

### AddMemoryByIdentifier

```lua
exports.lifeprint:AddMemoryByIdentifier(identifier, {
    targetIdentifier = "target_citizenid",  -- Optional
    memoryType = "encounter",
    description = "Met at the bank",
    location = "Fleeca Bank",
    visibility = "private"
})
```

---

### AddRelationshipByIdentifier

```lua
exports.lifeprint:AddRelationshipByIdentifier(identifier, {
    targetIdentifier = "target_citizenid",
    value = 50,           -- Absolute value (-100 to 100)
    -- OR
    change = 10,          -- Relative change to existing
    relationshipType = "friend",
    notes = "Private note"
})
```

---

### AddReputationByIdentifier

```lua
exports.lifeprint:AddReputationByIdentifier(identifier, {
    category = "criminal",
    change = -15,
    reason = "Armed robbery conviction",
    source = "judicial"
})
```

---

### AddRumorByIdentifier

```lua
exports.lifeprint:AddRumorByIdentifier(identifier, {
    targetIdentifier = "target_citizenid",  -- Optional
    rumorType = "secret",
    content = "Rumor has it they work for the cartel"
})
```

---

### Data Retrieval by Identifier

```lua
local memories = exports.lifeprint:GetMemoriesByIdentifier(identifier)
local relationships = exports.lifeprint:GetRelationshipsByIdentifier(identifier)
local reputation = exports.lifeprint:GetReputationByIdentifier(identifier)
local rumors = exports.lifeprint:GetRumorsByIdentifier(identifier)
local counters = exports.lifeprint:GetCounters(identifier)
```

---

## Bridge Exports

Framework-agnostic utilities.

```lua
-- Get current framework
local framework = exports.lifeprint:GetFramework()
-- Returns: "standalone", "qbcore", "qbox", or "esx"

-- Get player identifier
local identifier = exports.lifeprint:GetIdentifier(source)

-- Get character name
local name = exports.lifeprint:GetCharacterName(source)

-- Check admin permission
local isAdmin = exports.lifeprint:HasPermission(source, "lifeprint.admin")
```

---

## Automatic Tracking

Lifeprint can passively track player interactions without manual integration.

### Available Tracking

| Type | Trigger | Cooldown |
|------|---------|----------|
| **Proximity** | Players within 3m for 20 seconds | 24 hours per pair |
| **Vehicle Crash** | Vehicle damage >30% while moving | 10 minutes |
| **Injury** | Health drops below 60% | 10 minutes |

### Configuration

```lua
Config.AutoTracking = {
    proximity = true,
    vehicleCrash = true,
    injury = true,
    
    proximityDistance = 3.0,    -- Meters
    proximityTime = 20,         -- Seconds required
    proximityCooldown = 86400,  -- 24 hours
    
    crashCooldown = 600,        -- 10 minutes
    injuryCooldown = 600        -- 10 minutes
}
```

### How Proximity Works

1. Client checks nearby players every 2 seconds
2. If player within 3m for 20 seconds → triggers server
3. Server validates both players, checks cooldown
4. Creates bidirectional "acquaintance" relationship
5. Adds encounter memory for both players
6. Increments meetings counter for both

### Disable Tracking

```lua
Config.AutoTracking.proximity = false
Config.AutoTracking.vehicleCrash = false
Config.AutoTracking.injury = false
```

---

## Best Practices

### Security

```lua
-- ALWAYS use source from server events, Lifeprint resolves identifiers internally
RegisterNetEvent('myresource:server:action', function()
    local src = source  -- Always use this, never trust client-sent identifiers
    
    -- Safe to call Lifeprint exports with source
    local success, err = exports.lifeprint:AddMemory(
        src,            -- Lifeprint resolves identifier via Bridge
        "encounter",
        "Bank meeting",
        "Had a meeting at the bank",
        "Fleeca Bank"
    )
    
    if not success then
        print("Failed to add memory:", err)
    end
end)
```

### Performance

- Don't create memories for every minor interaction
- Use cooldowns (built into integration events)
- Batch reputation changes when possible
- Set appropriate rumor expiration times

### Data Quality

```lua
-- Good: Descriptive and contextual
exports.lifeprint:AddMemory(
    source,
    "crime",
    "Arrested at Fleeca",
    "Arrested by Officer Johnson for armed robbery at Fleeca Bank",
    "Fleeca Bank, Legion Square",
    nil, nil, "private"
)

-- Avoid: Vague and unhelpful
exports.lifeprint:AddMemory(
    source,
    "other",
    "Did something",
    "Did a thing",
    "Somewhere"
)
```

### Error Handling

```lua
-- Always check return values
local success, result = exports.lifeprint:AddRelationship(source, targetSource, "friend", 10)

if success then
    print("Relationship ID:", result)
else
    print("Error:", result)  -- result contains error message
end

-- For data retrieval, check for nil or empty tables
local data = exports.lifeprint:GetLifeprint(source)
if data and #data.memories > 0 then
    -- Process memories
end
```

---

## Framework Compatibility

All integration methods work across all frameworks:

| Framework | Identifier | Tested |
|-----------|------------|--------|
| Standalone | License | ✅ |
| QBCore | CitizenID | ✅ |
| Qbox | CitizenID | ✅ |
| ESX Legacy | Identifier | ✅ |

No framework-specific code required in your integrations.

---

<div align="center">

*The City Remembers*

</div>
