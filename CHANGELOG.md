# Changelog

## 2026-08-03 — Trait descriptions & effects on Traits page

- Traits browser now shows each trait's RimWorld description and stat effects (when present).
- Search matches name, defName, description, and effects text.
- Regenerated `docs/traits-data.js` to include description alongside stats.

## 2026-08-03 — Read-only Backstories browser

- Added `docs/backstories.html` (search / slot / source filters) for childhood and adulthood backstories.
- Added `scripts/export-backstories.ps1` to scrape RimWorld `BackstoryDef` XML into `Backstories.json`.
- Extended `scripts/generate-docs-data.ps1` to emit `docs/backstories-data.js`.
- Nav link on Store, Traits, Events, and Backstories pages.
- Catalog is reference-only; chat still uses `!shufflechildhood` / `!shuffleadulthood`.

## 2026-07-21 — Fix sticky table header gap

- Column headers no longer float mid-list with rows sitting between the filter bar and the header.
- Sticky `thead` offset is measured from the live top bar / controls height (handles wrapped filters).
- Switched tables to `border-collapse: separate` and dropped `.table-shell` overflow clipping so sticky headers pin correctly in Chromium.

## 2026-07-21 — Traits, Xenotypes, Events & Weather browsers

- Added `docs/traits.html` (Traits / Xenotypes tabs) and `docs/events.html` (Incidents / Weather tabs) with search, sort, and filters.
- Generated data JS from live config: 137 traits, 294 xenotype prices, 226 incidents, 22 weather types.
- Extended `scripts/generate-docs-data.ps1` to regenerate all docs data files after CAP exports.
- Site nav across Store, Traits & Xenotypes, and Events & Weather.
- Per-section command hints (`!buy`, `!trait` / `!addtrait`, `!xenotypes`, `!event`, `!weather`, `!lookup`, etc.).
- Redesigned docs UI (`docs/site.css`): sticky brand + Store / Traits / Events nav, shared ledger look, clearer command strips.
- Dark mode is the default; Light/Dark toggle in the top bar (persists via `localStorage`).

## 2026-07-21 — Commands column sortable / filterable

- Store browser Commands column is now clickable to sort by USE / EQUIP / WEAR flags.
- Added a Commands filter (USE, EQUIP, WEAR, Any command, No commands) alongside category and mod filters.

## 2026-07-21 — CAP ChatInteractive data refresh

- Synced live CAP ChatInteractive export into the repo (ActiveMods, CommandSettings, Incidents, RaceSettings, StoreItems, Traits, Weather).
- Regenerated GitHub Pages store browser (`docs/data.js`) and `StoreItems_List.md` from the new `StoreItems.json`.
- Store catalog grew from **1,795** to **3,704** items across **65** categories (**3,703** purchasable).
- Left `viewers.json` and `Backups/` out of git (local-only / sensitive).
