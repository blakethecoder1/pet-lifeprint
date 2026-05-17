# Lifeprint Changelog

<div align="center">

**The City Remembers**

*Version history and release notes*

</div>

---

## [1.0.0] - Initial Release

### Core Features

#### Timeline System
- Character memory recording with timestamps
- 9 memory types: encounter, conflict, friendship, business, romantic, betrayal, rescue, crime, other
- Location tagging for all memories
- Target player linking
- Timeline filtering by memory type
- Maximum memories per character (configurable)

#### People System
- Bidirectional relationship tracking
- Relationship score range: -100 to +100
- 8 relationship types: family, close friend, friend, acquaintance, stranger, disliked, rival, enemy
- Automatic relationship updates on repeated interactions
- Last interaction timestamp
- Interaction count tracking
- Search functionality

#### Reputation System
- 6 reputation categories: general, criminal, business, law, medical, underground
- Score range: -100 to +100
- 9 reputation tiers: Infamous, Notorious, Disreputable, Dubious, Unknown, Known, Respected, Honored, Legendary
- Reputation change logging with reasons
- **Counter System**: 6 counters track numerical events
- **Tag Generation**: Automatic reputation tags from counter thresholds
- **Character Read**: Dynamic paragraph summarizing reputation

#### Rumors System
- City whisper recording
- 8 rumor types: crime, secret, personal, business, conflict, achievement, scandal, hearsay
- Configurable expiration
- Source tracking
- Target linking

---

### Framework Support

| Framework | Identifier | Status |
|-----------|------------|--------|
| Standalone | License | ✅ Full Support |
| QBCore | CitizenID | ✅ Full Support |
| Qbox | CitizenID | ✅ Full Support |
| ESX Legacy | Identifier | ✅ Full Support |

**Auto-Detection**: Automatically detects running framework

---

### Commands

| Command | Permission | Description |
|---------|------------|-------------|
| `/lifeprint` | Everyone | Open the Lifeprint NUI |
| `/lpdemo` | Admin | Generate contest-ready demo data with mini-story |
| `/lpwipe` | Admin | Wipe all player's Lifeprint data |
| `/lpaddmemory` | Admin | Add a test memory instantly |

---

### User Interface

**Design:**
- Dark glassmorphism aesthetic
- Phone/dossier style interface
- Four navigation tabs
- Premium rounded cards
- Soft shadows and subtle glow

**Components:**
- Timeline with vertical connectors
- Filter pills for memory types
- Relationship cards with progress bars
- Reputation stat cards
- Reputation tag chips
- Character Read paragraph
- Rumor cards with type badges
- Modal forms for adding entries
- Player search with live results
- Toast notifications

**Animations:**
- Staggered card reveals
- Smooth tab transitions
- Loading bar animation
- Toast slide-in

**UX:**
- ESC key to close
- Click outside to close modals
- Empty state screens
- Loading state screens
- Debug mode for browser preview

**Technical:**
- Vanilla HTML/CSS/JS only
- Inline SVG icons (zero external dependencies)
- No React, Vue, Tailwind, Bootstrap, jQuery
- No npm packages required

---

### Database

**Tables:**
| Table | Purpose |
|-------|---------|
| `lifeprint_memories` | Character timeline entries |
| `lifeprint_relationships` | Player-to-player relationships |
| `lifeprint_reputation` | Reputation scores by category |
| `lifeprint_reputation_log` | Reputation change history |
| `lifeprint_reputation_counters` | Numerical counter tracking |
| `lifeprint_rumors` | City whispers and secrets |

**Features:**
- `is_demo` column for demo data identification
- `target_name` column for cached names
- JSON metadata column
- Expiration timestamp for rumors

---

### Server Exports

**Core Exports:**
```lua
exports.lifeprint:AddMemory(identifier, data)
exports.lifeprint:AddRelationship(identifier, data)
exports.lifeprint:AddReputation(identifier, data)
exports.lifeprint:AddRumor(identifier, data)
exports.lifeprint:DeleteMemory(identifier, memoryId)
exports.lifeprint:DeleteRumor(identifier, rumorId)
```

**Data Retrieval:**
```lua
exports.lifeprint:GetLifeprint(identifier)
exports.lifeprint:GetMemories(identifier)
exports.lifeprint:GetRelationships(identifier)
exports.lifeprint:GetReputation(identifier)
exports.lifeprint:GetRumors(identifier)
```

**Counter System:**
```lua
exports.lifeprint:GetCounters(identifier)
exports.lifeprint:IncrementCounter(identifier, counterType, amount)
exports.lifeprint:SetCounter(identifier, counterType, value)
exports.lifeprint:GetTags(identifier)
exports.lifeprint:GetCharacterRead(identifier)
```

**Helper Exports:**
```lua
exports.lifeprint:AddPlayerMemory(source, targetSource, type, desc, location)
exports.lifeprint:ModifyPlayerReputation(source, category, change, reason, sourceName)
exports.lifeprint:ModifyPlayerRelationship(source, targetSource, change, reason)
exports.lifeprint:CreateRumor(source, targetSource, type, content)
```

**Tracking Exports:**
```lua
exports.lifeprint:ClearTrackingCooldown(cooldownType, key)
exports.lifeprint:GetTrackingCooldown(cooldownType, key)
```

---

### Bridge System

**Framework-Agnostic Functions:**
```lua
Bridge.Initialize()
Bridge.GetFramework()
Bridge.IsLoaded()
Bridge.GetPlayer(source)
Bridge.GetPlayerByIdentifier(identifier)
Bridge.GetIdentifier(source)
Bridge.GetAllIdentifiers(source)
Bridge.GetCharacterName(source)
Bridge.GetCharacterNameByIdentifier(identifier)
Bridge.HasPermission(source, permission)
Bridge.Notify(source, message, type)
Bridge.NotifyClient(message, type)
```

**Bridge Exports:**
```lua
exports.lifeprint:GetFramework()
exports.lifeprint:GetPlayer(source)
exports.lifeprint:GetIdentifier(source)
exports.lifeprint:GetCharacterName(source)
exports.lifeprint:HasPermission(source, permission)
exports.lifeprint:Notify(source, message, type)
```

---

### Integration Events

8 pre-built integration events:

| Event | System | Description |
|-------|--------|-------------|
| `lifeprint:integration:policeArrest` | Police | Arrest tracking with officer relationship |
| `lifeprint:integration:emsTreatment` | EMS | Medical treatment with medic relationship |
| `lifeprint:integration:jail` | Judicial | Jail sentence recording |
| `lifeprint:integration:bill` | Billing | Payment/debt tracking |
| `lifeprint:integration:gangInteraction` | Gangs | Gang activity tracking |
| `lifeprint:integration:businessInteraction` | Business | Transaction recording |
| `lifeprint:integration:truckingEvent` | Trucking | Delivery and crash tracking |
| `lifeprint:integration:dotInteraction` | DOT | Inspection tracking |

Each event handles memory creation, relationship updates, reputation changes, counter increments, and optional rumor generation automatically.

---

### Automatic Tracking

**Proximity Tracking:**
- Detects players within 3.0 meters for 20 seconds
- Creates bidirectional "acquaintance" relationship
- Adds encounter memory for both players
- 24-hour cooldown per player pair
- 2-second check interval (performance optimized)

**Vehicle Crash Tracking:**
- Monitors vehicle body health every 1 second
- Detects significant damage (>30% or 200+)
- Verifies vehicle was moving at impact
- Creates "Vehicle Incident" memory
- Increments crashes counter
- 10-minute cooldown

**Injury Tracking:**
- Monitors player health every 2 seconds
- Triggers when health drops below 60%
- Creates injury memory with severity level
- 10-minute cooldown

---

### Security

- **Server-side validation**: All data validated server-side
- **No client trust**: Never trusts client-provided identifiers
- **ACE permission support**: Built-in ACE admin checking
- **Framework permission integration**: QBCore/ESX permission support
- **Configurable permission methods**: ACE, framework, or both
- **Source validation**: All server events validate source

---

### Configuration

**Framework Settings:**
- Auto/manual framework selection
- Permission method selection
- Debug mode

**Notification Settings:**
- ox_lib notification support
- Native GTA notification fallback

**Memory Settings:**
- Maximum memories per character
- Customizable memory types

**Relationship Settings:**
- Customizable relationship types
- Relationship point change values

**Reputation Settings:**
- Customizable categories
- Customizable reputation tiers
- Tag threshold configuration
- Character Read templates

**Rumor Settings:**
- Maximum rumors per character
- Configurable expiration
- Customizable rumor types

**Tracking Settings:**
- Master toggles for each tracking type
- Distance, time, and threshold configuration
- Cooldown configuration

**Integration Settings:**
- Per-integration enable/disable
- Customizable reputation changes
- Customizable rumor templates

---

### Dependencies

| Dependency | Required | Purpose |
|------------|----------|---------|
| oxmysql | ✅ Yes | Database operations |
| ox_lib | ⚪ Optional | Enhanced notifications |

**Server Requirements:**
- FiveM Server (build 5181+)
- MySQL/MariaDB database

---

### Technical Details

**Architecture:**
- Standalone-first design
- Multi-framework bridge system
- Server-client event communication
- NUI callback system

**File Structure:**
```
lifeprint/
├── fxmanifest.lua
├── config.lua
├── shared/
│   └── bridge.lua
├── client/
│   └── main.lua
├── server/
│   └── main.lua
├── html/
│   ├── index.html
│   ├── style.css
│   └── app.js
└── sql/
    └── lifeprint.sql
```

**Load Order:**
1. config.lua
2. shared/bridge.lua
3. @oxmysql/lib/MySQL.lua
4. server/main.lua
5. client/main.lua
6. html/index.html

---

### Documentation

| File | Purpose |
|------|---------|
| README.md | Project overview and quick start |
| INSTALL.md | Step-by-step installation guide |
| CONFIG_GUIDE.md | Configuration reference |
| INTEGRATIONS.md | Integration examples and exports |
| DEMO_SCRIPT.md | 2-minute contest demo walkthrough |
| CHANGELOG.md | This file |

---

## Future Roadmap

### Planned Features
- [ ] Rumor spread system (whispers propagate to connected players)
- [ ] Shared memories between players
- [ ] Public rumor board
- [ ] Faction/gang reputation category
- [ ] NPC relationship tracking
- [ ] Memory sharing with trusted friends
- [ ] Export data to JSON
- [ ] Import data from backup
- [ ] Admin panel for viewing other players' data

### Under Consideration
- [ ] Memory fading over time
- [ ] Relationship decay without interaction
- [ ] Reputation recovery actions
- [ ] Rumor verification system
- [ ] Character death and memory inheritance

---

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 1.0.0 | 2024 | Initial release |

---

<div align="center">

**The City Remembers**

</div>
