# Changelog

## 2026-07-21 — Commands column sortable / filterable

- Store browser Commands column is now clickable to sort by USE / EQUIP / WEAR flags.
- Added a Commands filter (USE, EQUIP, WEAR, Any command, No commands) alongside category and mod filters.

## 2026-07-21 — CAP ChatInteractive data refresh

- Synced live CAP ChatInteractive export into the repo (ActiveMods, CommandSettings, Incidents, RaceSettings, StoreItems, Traits, Weather).
- Regenerated GitHub Pages store browser (`docs/data.js`) and `StoreItems_List.md` from the new `StoreItems.json`.
- Store catalog grew from **1,795** to **3,704** items across **65** categories (**3,703** purchasable).
- Left `viewers.json` and `Backups/` out of git (local-only / sensitive).
