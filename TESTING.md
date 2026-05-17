# Lifeprint QA Checklist

Complete this checklist before contest submission. Mark each test with ✅ (pass) or ❌ (fail).

---

## 1. Framework Compatibility

Test on a clean server with each framework configuration.

### Standalone Mode
- [ ] Resource starts without errors
- [ ] `/lifeprint` command works
- [ ] Player identifier resolves correctly (license or first available)
- [ ] Character name shows as `GetPlayerName` result
- [ ] Admin ACE permission `lifeprint.admin` works

### QBCore
- [ ] Resource detects `qb-core` automatically
- [ ] `citizenid` is used as identifier
- [ ] Character name resolves from `PlayerData.charinfo`
- [ ] QBCore permission check works (`Player.PlayerData.job.grade` or ACE fallback)

### Qbox
- [ ] Resource detects `qbx_core` automatically
- [ ] `citizenid` is used as identifier
- [ ] Character name resolves from Qbox player data
- [ ] Permission check works via Qbox or ACE fallback

### ESX
- [ ] Resource detects `es_extended` automatically
- [ ] License identifier is used
- [ ] Character name resolves from `xPlayer.getName()`
- [ ] ESX permission check works (`xPlayer.getGroup()` or ACE fallback)

---

## 2. Database Setup

### SQL Import
- [ ] `sql/lifeprint.sql` imports without errors
- [ ] All 6 tables are created:
  - [ ] `lifeprint_memories`
  - [ ] `lifeprint_relationships`
  - [ ] `lifeprint_reputation`
  - [ ] `lifeprint_reputation_log`
  - [ ] `lifeprint_reputation_counters`
  - [ ] `lifeprint_rumors`
- [ ] Migration procedures run without errors
- [ ] Indexes are created on `identifier`, `target_identifier`, `created_at`

### Data Integrity
- [ ] `visibility` column exists on `lifeprint_memories` (default: 'private')
- [ ] `is_face_memory` column exists on `lifeprint_relationships`
- [ ] `notes` column exists on `lifeprint_relationships`
- [ ] `title` column exists on `lifeprint_memories`

---

## 3. UI Functionality

### Opening the UI
- [ ] `/lifeprint` command opens the NUI
- [ ] Loading screen shows for 6 seconds
- [ ] Loading screen transitions to main UI
- [ ] Player name displays correctly in header
- [ ] No JavaScript errors in browser console (F8 → NUI → Console)

### Closing the UI
- [ ] ESC key closes the NUI
- [ ] Close button (X) closes the NUI
- [ ] NUI focus is released (can move character)
- [ ] Cursor disappears after closing

### Tab Navigation
- [ ] Timeline tab loads and displays memories
- [ ] People tab loads and displays relationships
- [ ] Reputation tab loads with counters and tags
- [ ] Rumors tab loads and displays rumors

---

## 4. Commands

### /lifeprint
- [ ] Opens UI with player's data
- [ ] Shows empty state gracefully if no data exists
- [ ] Does not crash if player has no identifier

### /lpdemo (Admin Only)
- [ ] Creates 8 timeline memories
- [ ] Creates 5 relationships (Mara Voss, Officer Hill, Dex Carter, Lena Cross, Dr. Bishop)
- [ ] Creates reputation counters
- [ ] Creates 5 rumors
- [ ] Shows notification "Lifeprint demo profile generated."
- [ ] Auto-opens the UI after creation

### /lpdemo Duplicate Prevention
- [ ] Running `/lpdemo` twice does not create duplicate data
- [ ] Old demo data is cleared before new data is inserted
- [ ] Only `is_demo = 1` records are cleared (preserves real data)

### /lpwipe (Admin Only)
- [ ] Clears all player data
- [ ] Shows notification "Your Lifeprint data has been wiped"
- [ ] Opening `/lifeprint` after wipe shows empty state

### /lpaddmemory (Admin Only)
- [ ] Adds a test memory
- [ ] Shows notification with memory description

### /lpadmin (Admin Only)
- [ ] Opens admin panel
- [ ] Admin panel is centered and compact (max 540px wide)
- [ ] Player list populates with online players
- [ ] Search returns matching players
- [ ] Selecting a player shows their data
- [ ] Can add memory to selected player
- [ ] Can add rumor to selected player
- [ ] Can adjust reputation counters
- [ ] Can wipe player data

---

## 5. Permissions & Security

### Admin Permissions
- [ ] Admin commands work with `lifeprint.admin` ACE permission
- [ ] QBCore/Qbox job grades work for admin detection
- [ ] ESX groups work for admin detection

### Non-Admin Restriction
- [ ] Non-admin cannot use `/lpdemo` (shows "no permission")
- [ ] Non-admin cannot use `/lpwipe`
- [ ] Non-admin cannot use `/lpadmin`
- [ ] Non-admin cannot use `/lpaddmemory`

### Server-Side Validation
- [ ] All identifiers are resolved server-side
- [ ] Client-provided identifiers are ignored (security)
- [ ] Admin panel only returns data for valid player IDs

---

## 6. UI Content

### Timeline Tab
- [ ] Memories display with title
- [ ] Memory type icons/pills show correctly
- [ ] Location shows when available
- [ ] Timestamps are formatted correctly
- [ ] Visibility badge shows (Private/Public)
- [ ] Empty state shows when no memories

### People Tab
- [ ] Relationships display with target name
- [ ] Relationship value bar shows (-100 to 100)
- [ ] Relationship type badge shows
- [ ] Face memory badge shows when `is_face_memory = 1`
- [ ] Notes preview shows truncated text
- [ ] Can edit notes inline
- [ ] Save/cancel buttons work
- [ ] Empty state shows when no relationships

### Reputation Tab
- [ ] Counter stats display (arrests, EMS visits, etc.)
- [ ] Tags generate based on thresholds:
  - [ ] "Has a Record" (arrests >= 1)
  - [ ] "Known Offender" (arrests >= 3)
  - [ ] "Frequent Patient" (ems_visits >= 3)
  - [ ] "Reckless Driver" (crashes >= 3)
  - [ ] "Well Connected" (meetings >= 5)
  - [ ] "Helpful Civilian" (helpful_actions >= 3)
  - [ ] "Person of Interest" (suspicious_actions >= 3)
- [ ] Character Read paragraph generates
- [ ] Empty state shows gracefully

### Rumors Tab
- [ ] Rumors display with content
- [ ] Rumor type badges show
- [ ] Timestamp shows correctly
- [ ] Empty state shows when no rumors

---

## 7. Exports & Integrations

### Test Resource Setup
Create a test resource with this code:

```lua
-- Test resource: lifeprint_test
RegisterCommand('testexports', function()
    local success, result
    
    -- Test AddMemory
    success, result = exports.lifeprint:AddMemory(source, 'encounter', 'Test Memory', 'Created via export', 'Test Location')
    print('AddMemory:', success, result)
    
    -- Test GetLifeprint
    local data = exports.lifeprint:GetLifeprint(source)
    print('GetLifeprint:', json.encode(data))
    
    -- Test AddRelationship
    success, result = exports.lifeprint:AddRelationship(source, GetPlayerServerId(source) + 1, 'acquaintance', 10, 'Test note')
    print('AddRelationship:', success, result)
end)
```

### Export Tests
- [ ] `AddMemory(source, type, title, desc, location)` returns `true, id`
- [ ] `AddRelationship(source, targetSource, type, change, note)` returns `true, id`
- [ ] `AddReputation(source, category, amount)` returns `true, id`
- [ ] `AddRumor(source, content, type)` returns `true, id`
- [ ] `GetLifeprint(source)` returns full data table
- [ ] `GetReputation(source)` returns counters and tags
- [ ] `GetRelationships(source)` returns relationships array
- [ ] `GetMemories(source)` returns memories array

---

## 8. Auto-Tracking Performance

### Proximity Tracking
- [ ] Does not trigger on every frame (uses interval)
- [ ] Only triggers after 20+ seconds of proximity
- [ ] 24-hour cooldown prevents spam between same pair
- [ ] Creates "Known Contact" relationship bidirectionally
- [ ] Increments `meetings` counter for both players

### Vehicle Crash Tracking
- [ ] Triggers on significant health/velocity drop
- [ ] 10-minute cooldown prevents spam
- [ ] Creates "Vehicle Incident" memory
- [ ] Increments `crashes` counter

### Injury Tracking
- [ ] Triggers when health drops below threshold
- [ ] 10-minute cooldown prevents spam
- [ ] Creates injury memory

### Face Memory Proximity
- [ ] Walk-by reminder triggers when near remembered face
- [ ] 15-minute cooldown prevents notification spam
- [ ] Reminder shows target name and saved note

---

## 9. Stability

### F8 Console (Client)
- [ ] No script errors on resource start
- [ ] No errors when opening/closing UI
- [ ] No errors when running commands
- [ ] No NUI JavaScript errors

### Server Console
- [ ] No errors on resource start
- [ ] No SQL errors on data operations
- [ ] No framework detection errors
- [ ] Debug logs show correctly when `Config.Debug = true`

### Memory & Performance
- [ ] Resource does not cause FPS drops
- [ ] Client loops use reasonable intervals (not every frame)
- [ ] Server queries use LIMIT clauses
- [ ] Caches clear on player disconnect

---

## 10. Final Contest Demo Flow

Run this sequence for judges:

1. [ ] Clear old data: `/lpwipe`
2. [ ] Generate demo: `/lpdemo`
3. [ ] Open UI: `/lifeprint`
4. [ ] Show Timeline (8 story memories)
5. [ ] Show People (5 relationships)
6. [ ] Show Reputation (tags + character read)
7. [ ] Show Rumors (5 city whispers)
8. [ ] Close UI: ESC
9. [ ] Open admin panel: `/lpadmin`
10. [ ] Search for a player
11. [ ] Show admin features

---

## Test Results Summary

| Category | Pass | Fail | Notes |
|----------|------|------|-------|
| Framework Compatibility | /10 | | |
| Database Setup | /9 | | |
| UI Functionality | /10 | | |
| Commands | /15 | | |
| Permissions | /8 | | |
| UI Content | /20 | | |
| Exports | /8 | | |
| Auto-Tracking | /10 | | |
| Stability | /8 | | |

**Total: ___/98 tests passed**

---

## Known Issues

List any issues found during testing:

1. 
2. 
3. 

---

## Pre-Submission Checklist

- [ ] All critical tests pass
- [ ] `Config.Debug = false` for production
- [ ] `sql/lifeprint.sql` is complete
- [ ] `fxmanifest.lua` has correct dependencies
- [ ] `README.md` is up to date
- [ ] No hardcoded test data in production code
- [ ] Resource name in manifest matches folder name
