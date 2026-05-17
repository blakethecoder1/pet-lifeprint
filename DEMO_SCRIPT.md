# Lifeprint Demo Script

<div align="center">

**The City Remembers**

*2-Minute Contest Demo Walkthrough*

</div>

---

## Overview

This guide walks through a complete Lifeprint demonstration in under 2 minutes. Perfect for contest submissions, server showcases, or quick testing.

---

## Prerequisites

Before starting:

- [ ] Lifeprint resource is running
- [ ] You have admin permissions (`lifeprint.admin`)
- [ ] Database tables are imported

---

## Demo Walkthrough

### Step 1: Start Resource (10 seconds)

Verify Lifeprint is running:

```
/lifeprint
```

The NUI opens showing a loading state, then empty tabs. Close it:

```
ESC
```

---

### Step 2: Generate Demo Data (15 seconds)

Run the demo command:

```
/lpdemo
```

You'll see:

```
[Lifeprint] Contest demo data created! Opening Lifeprint...
```

The NUI auto-opens with populated data.

---

### Step 3: Explore Timeline (30 seconds)

The **Timeline** tab shows 8 memories telling a mini-story:

| Memory | Type | Story Beat |
|--------|------|------------|
| "Met a woman named Mara Voss..." | Encounter | Mysterious meeting at Legion Square |
| "Lost control of a Sultan RS..." | Crime | High-speed crash on Vespucci coast |
| "Dr. Bishop at Pillbox patched me up..." | Rescue | Medical treatment after crash |
| "Officer Hill arrested me..." | Conflict | Night in holding, no charges |
| "Released from Mission Row..." | Encounter | Warning from the officer |
| "Helped Lena Cross change a tire..." | Friendship | Good deed in Mirror Park |
| "Dex Carter caught me staring..." | Encounter | Suspicious encounter at the docks |
| "Starting to recognize faces..." | Business | Becoming known in the city |

**Demo the filters:**
1. Click the "Crime" filter pill
2. See only crime-related memories
3. Click "All" to reset

---

### Step 4: Explore People (25 seconds)

The **People** tab shows 5 relationship cards:

| Person | Score | Type | Story Context |
|--------|-------|------|---------------|
| **Lena Cross** | +55 | Friend | Helped with flat tire, owes you a drink |
| **Dr. Bishop** | +30 | Acquaintance | Treated injuries after crash |
| **Mara Voss** | +25 | Acquaintance | Nervous meeting at Legion Square |
| **Dex Carter** | +5 | Stranger | Saw you at the docks, knows something |
| **Officer Hill** | -15 | Adversary | Arrested then released, professional |

**Demo the search:**
1. Type "Lena" in the search box
2. See Lena Cross's card appear
3. Clear the search to see all relationships

---

### Step 5: Explore Reputation (25 seconds)

The **Reputation** tab shows:

**Stat Cards:**
- General: +20 (Known)
- Criminal: -10 (Dubious)
- Medical: +5 (Known)
- Police: -5 (Dubious)
- Community: +15 (Known)

**Reputation Tags (Premium Chips):**
- 🟢 **Well Connected** — Met 5+ people
- 🟡 **Has a Record** — 1+ arrest

**Character Read:**
> "Your Lifeprint suggests a well connected but has a record character with both redeeming qualities and concerning patterns. The city's opinion of you remains divided."

---

### Step 6: Explore Rumors (20 seconds)

The **Rumors** tab shows 5 city whispers:

| Rumor | Type | Content |
|-------|------|---------|
| Crime | Crime | "People say [Name] was rushed into Pillbox after a violent night..." |
| Conflict | Conflict | "Word around the block is [Name] has history with Officer Hill." |
| Hearsay | Hearsay | "Someone matching [Name]'s description was seen leaving a damaged Sultan..." |
| Achievement | Achievement | "Locals say [Name] helped someone stranded near Mirror Park." |
| Secret | Secret | "Some people think [Name] is becoming hard to ignore." |

These are anonymous city whispers that follow your character.

---

### Step 7: Demo Interactivity (20 seconds)

**Add a Memory:**
1. Click "Add Memory" button
2. Select "Friendship" type
3. Type a description
4. Click "Save Memory"
5. See the toast notification
6. Memory appears in Timeline

**Delete a Memory:**
1. Click the trash icon on any memory
2. See "Memory forgotten" toast
3. Memory disappears

---

## The Story Behind the Demo

The demo data tells a cohesive mini-narrative:

```
Day 1: You arrive in Los Santos, meet mysterious Mara Voss at Legion Square.

Day 2: You crash a Sultan on the coastal road. Dr. Bishop patches you up.

Day 3: Officer Hill arrests you on suspicion, releases you next morning.

Day 5: You help Lena Cross with a flat tire in Mirror Park.

Day 7: Dex Carter catches you looking at something suspicious at the docks.

Now: Word is spreading. People know your name.
```

This demonstrates how Lifeprint creates a **persistent memory layer** for characters.

---

## What Contest Judges See

When you run `/lpdemo` in a contest:

1. **Immediate Visual Impact** — Premium glassmorphism UI opens automatically
2. **Data Depth** — Timeline, relationships, reputation, rumors all populated
3. **Narrative Cohesion** — The mini-story shows purposeful design
4. **Feature Showcase** — Filters, search, chips, Character Read all working
5. **UX Polish** — Animations, toasts, empty states, loading states

---

## Technical Highlights to Mention

- **Standalone-First**: Works with no framework, auto-detects QBCore/Qbox/ESX
- **Vanilla Frontend**: No React, Vue, Tailwind, or npm packages
- **Inline SVGs**: Zero external dependencies for icons
- **Server-Side Security**: Never trusts client identifiers
- **Automatic Tracking**: Proximity, crash, injury detection built-in
- **Counter/Tag System**: Numerical counters generate reputation tags
- **Character Read**: Dynamic paragraph generation from data
- **8 Integration Events**: Drop-in connections for common systems

---

## Demo Script Summary

| Time | Action | Tab |
|------|--------|-----|
| 0:00 | `/lifeprint` → ESC | Verify working |
| 0:10 | `/lpdemo` | Generate data |
| 0:25 | Timeline tab | Show memories + filters |
| 0:55 | People tab | Show relationships + search |
| 1:20 | Reputation tab | Show stats + tags + Character Read |
| 1:45 | Rumors tab | Show city whispers |
| 2:00 | Done | Complete demo |

---

## Commands Reference

| Command | Permission | Description |
|---------|------------|-------------|
| `/lifeprint` | Everyone | Open the NUI |
| `/lpdemo` | Admin | Generate demo data + auto-open |
| `/lpwipe` | Admin | Clear all your Lifeprint data |
| `/lpaddmemory` | Admin | Add a test memory |

---

## Post-Demo Actions

### Wipe Demo Data

```
/lpwipe
```

### Add Custom Data

Use the "Add Memory" and "Add Rumor" buttons in the UI.

### Test Integrations

Trigger integration events from your other resources:

```lua
TriggerEvent('lifeprint:integration:policeArrest', source, nil, 'Test Location', 'Testing')
```

---

## Troubleshooting

### "You do not have permission"

Add to server.cfg:
```
add_ace identifier.steam:YOUR_HEX lifeprint.admin allow
```

### NUI Doesn't Open

1. Check resource is running: `/restart lifeprint`
2. Try `/lifeprint` again
3. Check F8 console for errors

### Demo Data Not Created

1. Enable debug: `Config.Debug = true`
2. Run `/lpdemo`
3. Check server console for SQL errors
4. Verify database tables exist

---

<div align="center">

**The City Remembers**

*Every interaction. Every relationship. Every reputation.*

</div>
