# Photo Library Inventory

## Sources — NAS `/volume1/Photos/Pictures/`

| Library                          | Type             | Masters | Total files | Size  | Modified         |
|----------------------------------|------------------|---------|-------------|-------|------------------|
| iPhoto Library.photolibrary      | iPhoto bundle    | 2,318   | 22,817      | 8.6G  | 2018-04-21       |
| Merged.photolibrary              | iPhoto bundle    | 11,050  | 67,085      | 21G   | 2024-02-09       |
| Photos Library-rh.photoslibrary  | Photos bundle    | 2,168   | 24,050      | 8.7G  | 2018-04-21       |
| photos/                          | exploded iPhoto  | 12,689  | 107,165     | 33G   | 2018-04-21       |
| photos-1/                        | exploded iPhoto  | 12,251  | 95,413      | 31G   | 2018-07-11       |
| nanny_photos/                    | flat folder      | 259     | 259         | 78M   | 2018-04-21       |
| pics/                            | flat folder      | 44      | 48          | 257M  | 2023-04-05       |
| Summer2014/                      | flat folder      | 18      | 18          | 38M   | 2018-04-21       |
| Photos Library (from-mac zip)    | Photos bundle    | ~53k    | ~53k        | 46G   | up to 2022-11    |

`photos/` and `photos-1/` are exploded iPhoto libraries — have `AlbumData.xml`, `Database/`, `Attachments/` but no `.photolibrary` wrapper. Originals under `Masters/YYYY/MM/DD/UUID/`.

`Photos Library (from-mac zip)` came from a different laptop. Unzipped to NAS July 2026. Also contains loose JPGs (2019-2022) and a Photo Booth Library.

## BigBadWolf

Already unplugged. No photo libraries inventoried.

## Mac Studio

Only 123 iCloud photos locally. Not a meaningful source.

## Diagnosis

`Merged.photolibrary` (Feb 2024) is the most recent and likely a prior consolidation attempt — 11,050 masters absorbed from multiple sources.

`photos/` and `photos-1/` hold the bulk of historical data (24,940 masters combined). Likely where content from older libraries ended up when libraries were exploded.

`Photos Library-rh.photoslibrary` and `iPhoto Library.photolibrary` appear related (same ancestor). NAS version has 150 more masters — more complete.

Libraries were seeded from each other over the years (laptop-to-laptop copies), so UUID overlap across libraries is expected to be high.

Many photos — especially 1970s family photos — have manually corrected dates in iPhoto/Photos. These corrections live only in the SQLite databases, not in the files' EXIF.

## Plan

**Assumptions:** image edits (crops, adjustments) not worth preserving. Originals only. No Photos.app export needed — extract directly from bundles.

### 1 — Strip thumbnails and caches

Library bundles carry significant non-photo bulk. Safe to delete per bundle before any other work:
- `Thumbnails/`
- `resources/derivatives/`
- `scopes/`
- `resources/caches/`

Keep: `Originals/` or `Masters/`, `database/` (needed for step 2).

### 2 — UUID dedup

UUID comparison across all libraries identifies duplicates without touching files — same UUID = same photo, keep one copy. Ruby script walks all libraries, builds UUID set, copies unique originals to a staging folder.

- Photos bundles: `originals/X/UUID.ext`
- iPhoto bundles and exploded: `Masters/YYYY/MM/DD/UUID/filename.jpg`

Must run before step 3 — baking dates changes file hashes, so dedup must happen first.

### 3 — Bake date corrections from SQLite

Script reads each library DB, builds `UUID -> corrected_date` map, exports CSV.
Second script on Mac reads CSV and writes corrected dates into EXIF via `exiftool`.

- iPhoto: `Library.apdb` -> `RKVersion.imageDate` keyed by `masterUuid`
- Photos: `Photos.sqlite` -> `ZASSET.ZDATECREATED` (Core Data timestamp: seconds since 2001-01-01)

Run against the deduped staging folder only, not the originals.
`exiftool` not available on Synology — must run on Mac with Photos share mounted.

Unblocked by: Photos share mounted on mac-media.

### 4 — Immich import

Import staging folder into Immich. UUID dedup in step 2 already handled duplicates — hash dedup not relied on.

mac-media has no GPU. Immich ML features (face recognition, CLIP search) need to reach out to Mac Studio over the local network for inference.

### Hold

Don't delete original libraries until Immich import is verified complete.
