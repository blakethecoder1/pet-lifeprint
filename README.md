# Lifeprint — The City Remembers

<div align="center">

**BLDR Contest Release**

*A FiveM roleplay memory system — characters, relationships, reputation, rumors, and the stories your city refuses to forget.*

[![FiveM](https://img.shields.io/badge/FiveM-Server-00b344?style=flat-square)](https://fivem.net)
[![Framework](https://img.shields.io/badge/Framework-Standalone%20|%20QBCore%20|%20Qbox%20|%20ESX-blue?style=flat-square)]()
[![Version](https://img.shields.io/badge/Version-1.0.0-orange?style=flat-square)]()
[![Built With](https://img.shields.io/badge/Built%20With-BLDR-purple?style=flat-square)]()

</div>

---

## About

I’m excited to finally submit **Lifeprint — The City Remembers** for the **BLDR contest**.

This script was **made and built by BLDR**, with the concept, ideas, design direction, and project shepherding by **PET Development**. I poured in credits, my own money, long hours, sweat, and time away from other things to get it pushed out in time. It’s not perfect, and there are still things I want to polish and expand on — but looking at what it became, every bit of it was worth it.

---

## The Idea

Lifeprint is a FiveM roleplay memory system built around one simple idea:

> **The city should remember what you do.**

Instead of player actions vanishing the moment they happen, Lifeprint creates a living record of your character’s story — memories, relationships, reputation, rumors, deaths, kills, injuries, witnessed actions, and NPC behavior — all tied to who you are in the world.

---

## The Memory Brain

One of the standout pieces of Lifeprint is the **Memory Brain** — a visual way to read your character’s story at a glance.

| Color | Meaning |
|-------|---------|
| 🟢 **Green** | Good memories |
| 🔴 **Red** | Bad memories |
| 🟣 **Purple** | Rumors |
| 🟡 **Yellow** | Everything else |

A single look tells you what kind of story you’re building. It helps you remember who you are, what you’ve done, and how the city sees you.

---

## What Lifeprint Includes

- 📖 **Character timeline** — every significant moment, preserved
- 👥 **People & relationship tracking** — who you’ve met and how they feel about you
- ⚖️ **Reputation system** — six categories: General, Criminal, Business, Law, Medical, Underground
- 🗣️ **City whispers & rumors** — the grapevine that follows your character
- 💀 **Death, kill, and injury memories** — the consequences stick
- 👁️ **NPC witnessed action tracking** — the world sees what you do
- 🔔 **Memory notifications** — real-time feedback as your story unfolds
- 🧠 **Memory Brain UI** — visual story-at-a-glance
- 🧬 **Face memory concept** — recognize the people you’ve crossed paths with
- 🧩 **Standalone-first** setup, no framework required
- 🔌 **QBCore, Qbox, and ESX** auto-detection and full support

---

## Honest Note

The one thing I wasn’t able to fully finish in time was the **image / photo system for faces**. The face memory concept is there, but working images and cleaner visuals are at the top of my post-contest list — that’s the first thing getting fixed in the next update.

Lifeprint isn’t meant to be just another menu. The goal was to add **long-term roleplay depth** and make the world feel alive — a place that actually remembers your character’s footprint.

I fully intend to keep updating Lifeprint over time with fixes, improvements, polish, and more immersive features based on community feedback.

---

## Demo Preview

<div align="center">

**2-Minute Contest Demo**

Type `/lpdemo` → Type `/lifeprint` → See your city story unfold.

</div>

---

## Framework Support

Lifeprint is **standalone-first** — no framework required.

| Framework | Status | Identifier | Notes |
|-----------|--------|------------|-------|
| **Standalone** | ✅ Full Support | License | Works out of the box |
| **QBCore** | ✅ Full Support | CitizenID | Auto-detects qb-core |
| **Qbox** | ✅ Full Support | CitizenID | Auto-detects qbx_core |
| **ESX Legacy** | ✅ Full Support | Identifier | Auto-detects es_extended |

**Auto-detection enabled** — set `Config.Framework = "auto"` and let Lifeprint handle the rest.

---

## Dependencies

| Dependency | Required | Purpose |
|------------|----------|---------|
| **oxmysql** | ✅ Yes | Database operations |
| **ox_lib** | ⚪ Optional | Enhanced notifications |

---

## Installation

### Quick Start

```bash
# 1. Place in resources folder
resources/[local]/lifeprint/

# 2. Import SQL
mysql -u root -p your_database < resources/lifeprint/sql/lifeprint.sql

# 3. Add to server.cfg
ensure oxmysql
ensure lifeprint

# 4. Configure (optional)
# Edit config.lua to set framework, permissions, etc.

# 5. Test
/lifeprint    # Open the NUI
/lpdemo       # Add demo data (admin only)
```

See [INSTALL.md](INSTALL.md) for detailed setup instructions.

---

## Commands

| Command | Permission | Description |
|---------|------------|-------------|
| `/lifeprint` | Everyone | Open the Lifeprint NUI |
| `/lpdemo` | Admin | Generate contest-ready demo data with mini-story |
| `/lpwipe` | Admin | Wipe all your Lifeprint data |
| `/lpaddmemory` | Admin | Add a test memory instantly |

### Admin Permissions

Add to `server.cfg`:

```cfg
# Group permission
add_ace group.admin lifeprint.admin allow

# Individual player
add_ace identifier.steam:YOUR_HEX lifeprint.admin allow
```

---

## Configuration

Lifeprint is highly configurable through `config.lua`. Key settings:

```lua
Config.Framework = "auto"           -- Auto-detect framework
Config.PermissionMethod = "both"    -- ACE + Framework perms
Config.UseOxLibNotify = true         -- Use ox_lib if available
Config.MaxMemoriesPerCharacter = 100
Config.RumorExpirationDays = 7      -- Rumors expire after 7 days
```

See [CONFIG_GUIDE.md](CONFIG_GUIDE.md) for complete documentation.

---

## Exports

### Server Exports

```lua
-- Add a memory
exports.lifeprint:AddMemory(identifier, {
    targetIdentifier = "target_citizenid",
    memoryType = "encounter",
    description = "Met at Legion Square",
    location = "Legion Square",
    timestamp = os.time()
})

-- Modify reputation
exports.lifeprint:AddReputation(identifier, {
    category = "criminal",
    change = -10,
    reason = "Caught stealing",
    source = "police"
})

-- Update relationship
exports.lifeprint:AddRelationship(identifier, {
    targetIdentifier = "target_citizenid",
    change = 5,
    relationshipType = "friend"
})

-- Create a rumor
exports.lifeprint:AddRumor(identifier, {
    targetIdentifier = "target_citizenid",
    rumorType = "secret",
    content = "They have connections in the underground"
})

-- Get all player data
local lifeprint = exports.lifeprint:GetLifeprint(identifier)
```

### Helper Exports (Simplified)

```lua
-- Memory by player source
exports.lifeprint:AddPlayerMemory(source, targetSource, "encounter", "Met at the bank", "Fleeca Bank")

-- Reputation by source
exports.lifeprint:ModifyPlayerReputation(source, "criminal", -10, "Armed robbery", "police")

-- Relationship by sources
exports.lifeprint:ModifyPlayerRelationship(source, targetSource, 15, "Saved from robbery")

-- Rumor by sources
exports.lifeprint:CreateRumor(source, targetSource, "secret", "Known associate of the Vagos")
```

### Bridge Exports

```lua
local framework = exports.lifeprint:GetFramework()
local identifier = exports.lifeprint:GetIdentifier(source)
local name = exports.lifeprint:GetCharacterName(source)
local hasPerms = exports.lifeprint:HasPermission(source, "lifeprint.admin")
```

---

## Integrations

Lifeprint ships with pre-built integration events for common server systems:

| System | Event | What It Tracks |
|--------|-------|----------------|
| **Police** | `lifeprint:integration:policeArrest` | Arrests, charges, officer relationships |
| **EMS** | `lifeprint:integration:emsTreatment` | Treatments, hospital visits |
| **Jail** | `lifeprint:integration:jail` | Sentences, time served |
| **Billing** | `lifeprint:integration:bill` | Payments, debts |
| **Gangs** | `lifeprint:integration:gangInteraction` | Joining, conflicts, alliances |
| **Business** | `lifeprint:integration:businessInteraction` | Transactions, partnerships |
| **Trucking** | `lifeprint:integration:truckingEvent` | Deliveries, crashes |
| **DOT** | `lifeprint:integration:dotInteraction` | Inspections, citations |

**Example:**

```lua
-- In your police resource
TriggerEvent('lifeprint:integration:policeArrest', 
    criminalSource,    -- Player being arrested
    officerSource,     -- Arresting officer
    'Vespucci Blvd',   -- Location
    'Suspected GTA'    -- Charges
)
```

See [INTEGRATIONS.md](INTEGRATIONS.md) for complete examples.

---

## Automatic Tracking

Lifeprint includes passive tracking that runs in the background:

| Feature | Trigger | Result |
|---------|---------|--------|
| **Proximity** | Within 3m for 20s | Creates "Known Contact" relationship |
| **Vehicle Crash** | Significant damage | Records incident, increments crash counter |
| **Injury** | Health drops below threshold | Records injury with severity |

All tracking includes cooldowns to prevent spam. Fully configurable in `config.lua`.

---

## Database Schema

| Table | Purpose |
|-------|---------|
| `lifeprint_memories` | Character memories/timeline |
| `lifeprint_relationships` | Player-to-player relationships |
| `lifeprint_reputation` | Reputation scores by category |
| `lifeprint_reputation_log` | History of reputation changes |
| `lifeprint_reputation_counters` | Numerical counters for tag generation |
| `lifeprint_rumors` | Rumors and whispers |

---

## UI Design

- **Dark glassmorphism** aesthetic
- **Phone/dossier style** interface
- **Four navigation tabs**: Timeline, People, Reputation, Rumors
- **Modal forms** for adding entries
- **Player search** with live results
- **Smooth CSS animations**
- **ESC key** and button close
- **Loading states** and empty states
- **Toast notifications**

Built with **vanilla HTML/CSS/JS** — no React, Vue, Tailwind, or external dependencies.

---

## Troubleshooting

### NUI Not Opening
1. Check F8 console for NUI errors
2. Verify `fxmanifest.lua` paths
3. Restart resource: `/restart lifeprint`

### Database Errors
1. Ensure oxmysql is running
2. Verify SQL tables were created
3. Check database credentials

### Framework Not Detected
1. Check `Config.Framework` setting
2. Verify framework resource is started
3. Set manually: `Config.Framework = "qbcore"`

### Permission Denied
1. Verify ACE permissions in server.cfg
2. Check `Config.PermissionMethod`
3. Test with: `Config.PermissionMethod = "ace"`

---

## Documentation

| File | Purpose |
|------|---------|
| [README.md](README.md) | This file |
| [INSTALL.md](INSTALL.md) | Step-by-step installation |
| [CONFIG_GUIDE.md](CONFIG_GUIDE.md) | Configuration reference |
| [INTEGRATIONS.md](INTEGRATIONS.md) | Integration examples |
| [DEMO_SCRIPT.md](DEMO_SCRIPT.md) | Contest demo walkthrough |
| [CHANGELOG.md](CHANGELOG.md) | Version history |

---

## Credits

- **Concept, ideas, and design direction:** [PET Development](#)
- **Built and developed with:** [BLDR](#)

Huge thanks to **BLDR** for running the contest and giving people a real reason to push themselves creatively — and for making a tool that helped bring this idea to life.

**Lifeprint — The City Remembers**
Concept and ideas by **PET Development** · Made and built by **BLDR**.

---

## License

Lifeprint is released under a **Custom Non-Commercial License**. See [LICENSE](LICENSE) for the full text.

**Short version:**

- ✅ Free to use on your FiveM server
- ✅ Free to modify for your own server
- ✅ Donations / community subs on your server are fine — the script itself just isn't the product being sold
- ❌ May NOT be resold, repackaged, sublicensed, or redistributed publicly
- ❌ May NOT be uploaded to Tebex, marketplaces, leak sites, or mirrors
- ❌ Credits to **PET Development** and **BLDR** may NOT be removed or obscured
- ℹ️ The general *concept* of a character memory system is not protected — only this code, UI, and assets are. Independent implementations are welcome; copies are not.

---

<div align="center">

**The City Remembers**

*Every interaction. Every relationship. Every reputation.*

> *The brain remembers, so you don’t have to.*

</div>
