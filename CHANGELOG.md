# Changelog

All notable changes to Lifeprint are documented in this file.

## v1.1.0 - 2026-06-09

### Added
- Privacy Controls 2.0 in player settings:
  - Allow Public Memories toggle
  - Allow Rumor Sharing toggle
  - Allow Proximity Tracking toggle
  - Per-category memory visibility controls
- Rumor creation UI option to mark rumors public when sharing is enabled.
- New settings persistence fields for privacy controls and category map.

### Changed
- Server-side enforcement now validates privacy preferences when saving memories and rumors.
- Public memory saves are automatically downgraded to private if global or category rules disallow public visibility.
- Proximity tracking now respects both proximity memory preference and explicit allow proximity tracking preference.
- Settings load/save normalization improved for compatibility with existing rows.

### Database
- Added new columns in lifeprint_settings:
  - allow_public_memories
  - allow_rumor_sharing
  - allow_proximity_tracking
  - public_memory_categories (JSON)
- Expanded safe migration routine for lifeprint_settings to backfill these fields on existing installs.

### UI
- Added new settings controls and category checklist.
- Added styling for stacked settings rows and category grid states.
- Improved settings panel handling for missing payloads.

### Notes
- Existing client-side Lua diagnostics for global symbols (Config and Bridge) are unchanged and pre-existing.
