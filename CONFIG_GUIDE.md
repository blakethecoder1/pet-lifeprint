# Lifeprint Configuration Guide

<div align="center">

**The City Remembers**

*Complete configuration reference*

</div>

---

## Core Settings

### Config.Framework

Controls which framework Lifeprint uses for player identification and data retrieval.

```lua
Config.Framework = "auto"        -- Auto-detect (recommended)
Config.Framework = "standalone"   -- No framework, uses license identifier
Config.Framework = "qbcore"       -- QBCore (citizenid)
Config.Framework = "qbox"         -- Qbox (citizenid)
Config.Framework = "esx"          -- ESX Legacy (identifier)
```

**Auto-Detection Priority:**
1. qbx_core running → Qbox
2. qb-core running → QBCore
3. es_extended running → ESX
4. None detected → Standalone

---

### Config.Debug

Enable detailed logging to server console.

```lua
Config.Debug = true   -- Show all debug messages
Config.Debug = false  -- Production mode
```

When enabled, you'll see:
- Data retrieval counts
- Event triggers
- SQL operation results
- Cooldown tracking

---

## Permission Settings

### Config.PermissionMethod

How admin permissions are checked for `/lpdemo`, `/lpwipe`, `/lpaddmemory`.

```lua
Config.PermissionMethod = "both"       -- Check ACE AND framework (recommended)
Config.PermissionMethod = "ace"        -- ACE permissions only
Config.PermissionMethod = "framework"  -- Framework permissions only
```

### ACE Permissions

```lua
Config.ACEAdminGroup = "lifeprint.admin"
```

Add to server.cfg:

```cfg
add_ace group.admin lifeprint.admin allow
add_ace identifier.steam:YOUR_HEX lifeprint.admin allow
```

### Framework Permissions

```lua
-- QBCore/Qbox
Config.QBCorePermission = "admin"  -- "admin" or "god"

-- ESX
Config.ESXPermission = "superadmin"  -- "superadmin" or "admin"

-- Standalone fallback
Config.StandaloneAdminACE = "lifeprint.admin"
```

---

## Command Settings

### Config.OpenCommand

Chat command to open the Lifeprint NUI.

```lua
Config.OpenCommand = "lifeprint"  -- /lifeprint
```

### Config.AdminCommands

Admin command names (customizable).

```lua
Config.AdminCommands = {
    demo = "lpdemo",        -- Generate demo data
    wipe = "lpwipe",        -- Clear all player data
    addmemory = "lpaddmemory" -- Add test memory
}
```

---

## Notification Settings

### Config.UseOxLibNotify

Use ox_lib notifications if the resource is running.

```lua
Config.UseOxLibNotify = true   -- Use ox_lib if available
Config.UseOxLibNotify = false  -- Always use native GTA notifications
```

When `true` and ox_lib is running:
- Styled toast notifications
- Better visibility
- Type indicators (success/error/warning)

When `false` or ox_lib not available:
- Native GTA notifications
- Works on all servers

---

## Memory Settings

### Config.MaxMemoriesPerCharacter

Maximum memories stored per character. Older memories still exist in database but won't display.

```lua
Config.MaxMemoriesPerCharacter = 100
```

### Config.MemoryTypes

Available memory types for timeline entries. Each has an ID, display label, and icon.

```lua
Config.MemoryTypes = {
    { id = "encounter", label = "Encounter", icon = "eye" },
    { id = "conflict", label = "Conflict", icon = "zap" },
    { id = "friendship", label = "Friendship", icon = "heart" },
    { id = "business", label = "Business", icon = "briefcase" },
    { id = "romantic", label = "Romantic", icon = "star" },
    { id = "betrayal", label = "Betrayal", icon = "skull" },
    { id = "rescue", label = "Rescue", icon = "shield" },
    { id = "crime", label = "Crime", icon = "lock" },
    { id = "other", label = "Other", icon = "file" }
}
```

**Adding Custom Types:**

```lua
Config.MemoryTypes = {
    -- Keep existing types...
    { id = "medical", label = "Medical", icon = "heart" },
    { id = "legal", label = "Legal", icon = "file" }
}
```

Icons use inline SVG — no external dependencies.

---

## Relationship Settings

### Config.RelationshipTypes

Relationship level definitions with value ranges (-100 to 100).

```lua
Config.RelationshipTypes = {
    -- Positive relationships
    family = { min = 81, max = 100, label = "Family", color = "#F59E0B" },
    close_friend = { min = 61, max = 80, label = "Close Friend", color = "#059669" },
    friend = { min = 31, max = 60, label = "Friend", color = "#10B981" },
    acquaintance = { min = 11, max = 30, label = "Acquaintance", color = "#9CA3AF" },
    stranger = { min = 0, max = 10, label = "Stranger", color = "#6B7280" },
    
    -- Negative relationships
    disliked = { min = -10, max = -1, label = "Disliked", color = "#FCA5A5" },
    rival = { min = -30, max = -11, label = "Rival", color = "#F87171" },
    enemy = { min = -100, max = -31, label = "Enemy", color = "#EF4444" }
}
```

### Config.RelationshipPointChanges

Recommended values for different interaction types (use in your integrations).

```lua
Config.RelationshipPointChanges = {
    positive_interaction = 5,
    negative_interaction = -5,
    major_positive = 15,
    major_negative = -15,
    betrayal = -30,
    rescue = 20
}
```

---

## Reputation Settings

### Config.ReputationCategories

Categories for tracking different aspects of reputation.

```lua
Config.ReputationCategories = {
    { id = "general", label = "General Reputation", color = "#8B5CF6" },
    { id = "criminal", label = "Criminal Standing", color = "#EF4444" },
    { id = "business", label = "Business Reputation", color = "#10B981" },
    { id = "law", label = "Law Enforcement", color = "#3B82F6" },
    { id = "medical", label = "Medical Community", color = "#EC4899" },
    { id = "underground", label = "Underground Scene", color = "#F59E0B" }
}
```

**Adding Custom Categories:**

```lua
Config.ReputationCategories = {
    -- Keep existing...
    { id = "political", label = "Political Standing", color = "#6366F1" }
}
```

### Config.ReputationRanges

Tiers for reputation display.

```lua
Config.ReputationRanges = {
    { min = -100, max = -75, label = "Infamous", tier = -4 },
    { min = -74, max = -50, label = "Notorious", tier = -3 },
    { min = -49, max = -25, label = "Disreputable", tier = -2 },
    { min = -24, max = -1, label = "Dubious", tier = -1 },
    { min = 0, max = 0, label = "Unknown", tier = 0 },
    { min = 1, max = 24, label = "Known", tier = 1 },
    { min = 25, max = 49, label = "Respected", tier = 2 },
    { min = 50, max = 74, label = "Honored", tier = 3 },
    { min = 75, max = 100, label = "Legendary", tier = 4 }
}
```

---

## Counter & Tag System

### Config.ReputationCounterTypes

Counters tracked for automatic tag generation.

```lua
Config.ReputationCounterTypes = {
    "arrests",
    "ems_visits",
    "crashes",
    "meetings",
    "helpful_actions",
    "suspicious_actions"
}
```

### Config.ReputationTagThresholds

Tags generated when counters reach thresholds.

```lua
Config.ReputationTagThresholds = {
    arrests = {
        { threshold = 1, label = "Has a Record", priority = 3, style = "warning" },
        { threshold = 3, label = "Known Offender", priority = 4, style = "danger" }
    },
    ems_visits = {
        { threshold = 3, label = "Frequent Patient", priority = 2, style = "info" }
    },
    crashes = {
        { threshold = 3, label = "Reckless Driver", priority = 2, style = "warning" }
    },
    meetings = {
        { threshold = 5, label = "Well Connected", priority = 4, style = "success" }
    },
    helpful_actions = {
        { threshold = 3, label = "Helpful Civilian", priority = 3, style = "success" }
    },
    suspicious_actions = {
        { threshold = 3, label = "Person of Interest", priority = 3, style = "danger" }
    }
}
```

**Tag Styles:**
- `success` — Green (positive traits)
- `warning` — Yellow (cautionary traits)
- `danger` — Red (negative traits)
- `info` — Blue (informational)

### Config.CharacterReadTemplates

Templates for the "Character Read" paragraph in the Reputation tab.

```lua
Config.CharacterReadTemplates = {
    positive_strong = "Your reputation speaks for itself. {positive_tags} — the city knows your name, and most speak it with respect.",
    negative_strong = "Your name carries weight in this city, but not the kind you want. {negative_tags}. People cross the street when they see you coming.",
    mixed = "Your Lifeprint suggests a {mixed_tags} character with both redeeming qualities and concerning patterns. The city's opinion of you remains divided.",
    record = "You've caught the attention of law enforcement. {record_tags}. Your file at Mission Row has grown thick.",
    connected = "Your web of contacts spreads across the city. {connected_tags}. Doors open for you — the question is which ones.",
    neutral = "Your Lifeprint is still being written. The city doesn't know what to make of you yet."
}
```

### Config.ReputationTagStyles

Color definitions for tag chips.

```lua
Config.ReputationTagStyles = {
    success = { bg = "rgba(52, 211, 153, 0.15)", color = "#34d399", border = "rgba(52, 211, 153, 0.3)" },
    warning = { bg = "rgba(251, 191, 36, 0.15)", color = "#fbbf24", border = "rgba(251, 191, 36, 0.3)" },
    danger = { bg = "rgba(248, 113, 113, 0.15)", color = "#f87171", border = "rgba(248, 113, 113, 0.3)" },
    info = { bg = "rgba(96, 165, 250, 0.15)", color = "#60a5fa", border = "rgba(96, 165, 250, 0.3)" }
}
```

---

## Rumor Settings

### Config.MaxRumorsPerCharacter

Maximum rumors displayed per character.

```lua
Config.MaxRumorsPerCharacter = 20
```

### Config.RumorExpirationDays

Days until rumors automatically expire (0 = never).

```lua
Config.RumorExpirationDays = 7  -- 1 week
```

### Config.RumorTypes

Available rumor types for city whispers.

```lua
Config.RumorTypes = {
    { id = "crime", label = "Crime", icon = "lock", color = "#EF4444" },
    { id = "secret", label = "Secret", icon = "eye-off", color = "#8B5CF6" },
    { id = "affair", label = "Personal", icon = "heart", color = "#EC4899" },
    { id = "business", label = "Business", icon = "briefcase", color = "#10B981" },
    { id = "conflict", label = "Conflict", icon = "zap", color = "#F59E0B" },
    { id = "achievement", label = "Achievement", icon = "trophy", color = "#3B82F6" },
    { id = "scandal", label = "Scandal", icon = "alert-triangle", color = "#EF4444" },
    { id = "hearsay", label = "Hearsay", icon = "message-circle", color = "#6B7280" }
}
```

---

## Automatic Tracking

### Config.AutoTracking

Settings for passive background tracking.

```lua
Config.AutoTracking = {
    -- Master toggles
    proximity = true,        -- Enable proximity relationship creation
    vehicleCrash = true,     -- Enable crash memory creation
    injury = true,           -- Enable injury memory creation
    
    -- Proximity settings
    proximityDistance = 3.0,       -- Meters apart to trigger
    proximityTime = 20,            -- Seconds of proximity required
    proximityCooldown = 86400,     -- 24 hours per pair
    proximityCheckInterval = 2000, -- Check every 2 seconds
    proximityRelationshipType = "acquaintance",
    proximityRelationshipValue = 10,
    
    -- Crash settings
    crashCooldown = 600,           -- 10 minutes
    crashCheckInterval = 1000,     -- Check every second
    crashHealthThreshold = 30,     -- 30% damage triggers
    crashVelocityThreshold = 20.0, -- Minimum speed
    crashMemoryType = "encounter",
    crashMemoryTitle = "Vehicle Incident",
    
    -- Injury settings
    injuryCooldown = 600,          -- 10 minutes
    injuryCheckInterval = 2000,    -- Check every 2 seconds
    injuryHealthThreshold = 120,   -- Below 60% health
    injuryMemoryType = "encounter",
    injuryMemoryTitle = "Injury"
}
```

### How Tracking Works

| Type | Trigger | Result | Cooldown |
|------|---------|--------|----------|
| **Proximity** | Within 3m for 20s | Bidirectional "acquaintance" relationship + encounter memory | 24h per pair |
| **Crash** | Vehicle damage >30% | "Vehicle Incident" memory + crash counter increment | 10 minutes |
| **Injury** | Health drops below 60% | "Injury" memory with severity level | 10 minutes |

---

## Integration Settings

### Config.Integrations

Pre-built integration modules for external resources.

```lua
Config.Integrations = {
    Police = {
        enabled = true,
        memoryType = "crime",
        reputationCategory = "law",
        reputationChange = -5,
        counterType = "arrests",
        relationshipChange = -10,
        relationshipType = "adversary",
        createRumor = true,
        rumorType = "crime",
        rumorTemplates = {
            "Word on the street is {name} had a run-in with the law.",
            "People say {name} was picked up by LSPD near {location}."
        }
    },
    EMS = {
        enabled = true,
        memoryType = "rescue",
        reputationCategory = "medical",
        reputationChange = 1,
        counterType = "ems_visits",
        relationshipChange = 10,
        relationshipType = "friend"
    },
    Jail = {
        enabled = true,
        memoryType = "crime",
        reputationCategory = "criminal",
        reputationChange = -10,
        counterType = "arrests",
        createRumor = true,
        rumorType = "crime",
        rumorTemplates = {
            "Rumor has it {name} is doing time at Bolingbroke."
        }
    },
    Billing = {
        enabled = true,
        memoryType = "business",
        reputationCategory = "business",
        reputationChange = -2,
        positiveReputationChange = 2
    },
    Gang = {
        enabled = true,
        memoryType = "encounter",
        reputationCategory = "underground",
        reputationChange = 0,
        counterType = "meetings",
        relationshipChange = 5,
        relationshipType = "acquaintance",
        createRumor = true,
        rumorType = "secret",
        rumorTemplates = {
            "Word is {name} has been seen with some dangerous company."
        }
    },
    Business = {
        enabled = true,
        memoryType = "business",
        reputationCategory = "business",
        reputationChange = 3,
        counterType = "meetings",
        relationshipChange = 5,
        relationshipType = "acquaintance"
    },
    Trucking = {
        enabled = true,
        memoryType = "business",
        reputationCategory = "business",
        reputationChange = 2,
        counterType = "helpful_actions",
        crashReputationChange = -3,
        crashCounterType = "crashes"
    },
    DOT = {
        enabled = true,
        memoryType = "encounter",
        reputationCategory = "general",
        reputationChange = -2,
        counterType = "suspicious_actions",
        cleanReputationChange = 2,
        cleanCounterType = "helpful_actions"
    }
}
```

Each integration can be disabled individually:

```lua
Config.Integrations.Police.enabled = false  -- Disable police integration
```

---

## Quick Configuration Presets

### Minimal Standalone

```lua
Config.Framework = "standalone"
Config.PermissionMethod = "ace"
Config.UseOxLibNotify = false
Config.Debug = false
Config.AutoTracking = {
    proximity = false,
    vehicleCrash = false,
    injury = false
}
```

### Full-Featured QBCore

```lua
Config.Framework = "auto"  -- or "qbcore"
Config.PermissionMethod = "both"
Config.UseOxLibNotify = true
Config.Debug = false
Config.AutoTracking = {
    proximity = true,
    vehicleCrash = true,
    injury = true
}
```

### Development Mode

```lua
Config.Framework = "auto"
Config.PermissionMethod = "ace"  -- Easier testing
Config.Debug = true
Config.UseOxLibNotify = true
```

---

<div align="center">

*The City Remembers*

</div>
