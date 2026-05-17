# Lifeprint Installation Guide

<div align="center">

**The City Remembers**

*Complete setup instructions for Lifeprint*

</div>

---

## Requirements

### Required

| Requirement | Version | Notes |
|-------------|---------|-------|
| FiveM Server | 5181+ | Artifacts build |
| MySQL/MariaDB | 5.7+ / 10.3+ | Any compatible database |
| oxmysql | Latest | Required for database operations |

### Optional

| Requirement | Purpose |
|-------------|---------|
| ox_lib | Enhanced notifications with better UX |

---

## Step 1: Download and Place Resource

### Option A: Manual Download

1. Download the `lifeprint` resource folder
2. Place in your server's resources directory:

```
resources/
├── [local]/
│   └── lifeprint/
│       ├── fxmanifest.lua
│       ├── config.lua
│       ├── shared/
│       │   └── bridge.lua
│       ├── client/
│       │   └── main.lua
│       ├── server/
│       │   └── main.lua
│       ├── html/
│       │   ├── index.html
│       │   ├── style.css
│       │   └── app.js
│       └── sql/
│           └── lifeprint.sql
```

### Option B: Git Clone

```bash
cd resources/[local]
git clone https://github.com/your-repo/lifeprint.git
```

---

## Step 2: Import Database Schema

### Using Command Line

```bash
mysql -u username -p database_name < resources/[local]/lifeprint/sql/lifeprint.sql
```

### Using phpMyAdmin

1. Select your database
2. Click "Import" tab
3. Choose file: `sql/lifeprint.sql`
4. Click "Go"

### Using HeidiSQL

1. Connect to your database
2. File → Run SQL File
3. Select `sql/lifeprint.sql`
4. Execute

### Tables Created

| Table | Rows |
|-------|------|
| `lifeprint_memories` | Character timeline entries |
| `lifeprint_relationships` | Player relationships |
| `lifeprint_reputation` | Reputation by category |
| `lifeprint_reputation_log` | Reputation change history |
| `lifeprint_reputation_counters` | Counter tracking for tags |
| `lifeprint_rumors` | Rumors and whispers |

---

## Step 3: Configure server.cfg

Add these lines to your `server.cfg`:

```cfg
# Dependencies (ensure oxmysql starts first)
ensure oxmysql

# Lifeprint resource
ensure lifeprint
```

**Important:** oxmysql must start before lifeprint.

### Recommended Load Order

```cfg
ensure oxmysql
ensure ox_lib          # Optional
ensure lifeprint
```

---

## Step 4: Configure Framework

Open `config.lua` and verify framework settings:

### Auto-Detection (Recommended)

```lua
Config.Framework = "auto"
```

Lifeprint will automatically detect:
1. qbx_core → Qbox
2. qb-core → QBCore
3. es_extended → ESX
4. None of the above → Standalone

### Manual Configuration

```lua
-- Force a specific framework
Config.Framework = "qbcore"     -- QBCore
Config.Framework = "qbox"      -- Qbox
Config.Framework = "esx"       -- ESX Legacy
Config.Framework = "standalone" -- No framework
```

---

## Step 5: Configure Permissions

### Option A: ACE Permissions (Recommended for Standalone)

```cfg
# Grant to admin group
add_ace group.admin lifeprint.admin allow

# Grant to specific player
add_ace identifier.steam:YOUR_STEAM_HEX lifeprint.admin allow
add_ace identifier.discord:YOUR_DISCORD_ID lifeprint.admin allow
```

### Option B: Framework Permissions

```lua
-- config.lua
Config.PermissionMethod = "framework"

-- QBCore: players with "admin" or "god" permission
-- ESX: players with "superadmin" or "admin" group
-- Qbox: uses qbx_core:HasPermission
```

### Option C: Both Methods

```lua
-- config.lua
Config.PermissionMethod = "both"  -- Check ACE AND framework
```

---

## Step 6: Test Installation

### 1. Verify Resource Started

Check server console for:

```
[Lifeprint] Initialized with framework: standalone
```

Or for frameworks:

```
[Lifeprint] Framework loaded: QBCore
```

### 2. Test Basic Command

Join your server and type:

```
/lifeprint
```

The NUI should open with a loading state, then show empty tabs.

### 3. Test Demo Data

Type (requires admin permission):

```
/lpdemo
```

You should see:

```
Contest demo data created! Opening Lifeprint...
```

The NUI will auto-open with populated data:
- 8 timeline memories
- 5 relationship cards
- Reputation across categories
- 5 city rumors

### 4. Test All Tabs

Navigate through:
- **Timeline** — Filter by memory type
- **People** — Search relationships
- **Reputation** — View scores and "Character Read"
- **Rumors** — Browse city whispers

---

## Framework-Specific Notes

### QBCore

```lua
-- Ensure qb-core is in server.cfg before lifeprint
ensure qb-core
ensure lifeprint
```

- Uses `citizenid` as identifier
- Permission check: `PlayerData.permission == "admin" or "god"`
- Character name from `PlayerData.charinfo`

### Qbox

```lua
-- Ensure qbx_core is in server.cfg before lifeprint
ensure qbx_core
ensure lifeprint
```

- Uses `citizenid` as identifier
- Permission check via `exports.qbx_core:HasPermission`
- Character name from `PlayerData.charinfo`

### ESX Legacy

```lua
-- Ensure es_extended is in server.cfg before lifeprint
ensure es_extended
ensure lifeprint
```

- Uses `identifier` column as identifier
- Permission check: `xPlayer.getGroup() == "superadmin" or "admin"`
- Character name from `xPlayer.name`

### Standalone

No additional configuration needed.

- Uses `license:` identifier
- Permission check: ACE only
- Character name from `GetPlayerName()`

---

## Troubleshooting

### "oxmysql not found"

```
[Lifeprint] Error: oxmysql is required but not found
```

**Solution:** Ensure oxmysql is in server.cfg and starts before lifeprint.

### "Failed to get memories"

```
[Lifeprint] [ERROR] Failed to get memories: ...
```

**Solutions:**
1. Verify SQL tables were created
2. Check database connection
3. Review oxmysql configuration

### NUI Doesn't Open

**Check:**
1. F8 console for JavaScript errors
2. Resource is running: `/restart lifeprint`
3. `fxmanifest.lua` paths are correct

### "No identifier found for source"

**Solutions:**
1. Check framework is running
2. Verify player is connected properly
3. Set framework manually in config.lua

### Permission Denied for Admin Commands

**Check:**
1. ACE permissions are set correctly
2. `Config.PermissionMethod` matches your setup
3. Try `Config.PermissionMethod = "ace"` for testing

---

## Post-Installation Checklist

- [ ] Resource starts without errors
- [ ] `/lifeprint` opens the NUI
- [ ] `/lpdemo` adds test data (admin)
- [ ] All four tabs display correctly
- [ ] Player search works in modals
- [ ] ESC closes the NUI
- [ ] Framework is correctly detected
- [ ] Admin permissions work as expected

---

## Next Steps

1. **Configure Settings** — See [CONFIG_GUIDE.md](CONFIG_GUIDE.md)
2. **Add Integrations** — See [INTEGRATIONS.md](INTEGRATIONS.md)
3. **Run Contest Demo** — See [DEMO_SCRIPT.md](DEMO_SCRIPT.md)

---

## Support

For issues:
1. Enable debug mode: `Config.Debug = true`
2. Check server console for errors
3. Verify all requirements are met

---

<div align="center">

*The City Remembers*

</div>
