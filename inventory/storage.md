# Storage

NAS + external drives + backup decisions. Where data lives, what's planned,
what's being phased out.

## NAS — Synology DS418play

Treated as **dumb storage**. Slated for retirement. Don't host services on it.

### Hardware

- Synology DiskStation DS418play, 10GB RAM.
- 2x WD Red (CMR, not Pro) ~3.6TB in RAID-1 via mdadm (not SHR). 3.5TB usable.
- 2 empty bays (4-bay chassis).
- Used: 682GB. Drives are old, SMART clean.
- DSM. User hacked the upgrade path once. Updates enabled.

### Mount (from mac-media)

- SMB. `movies` guest user — read-only.
- Mounts: `/mnt/nas/video`, `/mnt/nas/music` (see `server/nas-mounts/`).
- Jellyfin metadata cache lives on mac-media local disk (`~/srv/jellyfin/cache/`),
  not next to media on NAS, because guest user is read-only.

### Mac access — known pain

- **macOS Finder doesn't detect the drive reliably over SMB.** WS-Discovery
  is enabled but discovery is flaky.
- **AFP worked much better** for Mac discovery before phase-out.
- Workaround: Cmd+K → `smb://diskstation`.
- AFP phase-out (per `media-migration.md`) is pending — leave AFP enabled
  for now since SMB-only hurts daily Mac use.

### Backup status

**None.** No cloud backup. Concerned about cost (~$4/mo at B2 for 682GB
feels expensive given "ton of crap" stored).

Recommendation when ready: **Backblaze B2** (~$4/mo). Hyper Backup built into DSM.

Future: Time Machine to NAS via SMB, 1TB quota.

### Retirement plan

User is phasing out the NAS. Possibly building custom NAS, possibly
non-network-attached storage. Likes the low wattage of current unit.
Punting on spending money short-term.

### Rules

- **Don't suggest services on the NAS** (Container Manager, Docker, Web Station, etc.).
- Mount via SMB only.
- For new services that need write access to NAS: requires a write-enabled
  mount with a non-guest user. Not set up.

## External drives

| Drive             | Capacity | Type        | Status                         |
|-------------------|----------|-------------|--------------------------------|
| LaCie             | 2.7TB    | USB HDD     | In basement closet, unplugged. Cold archive |
| BigBadWolf (Sabrent) | 2TB   | USB HDD     | 13yo, unplugged. Source video ISOs |
| WD MyBook World   | unknown  | Network drive (white, capacity-gauge LED) | ~2009. Embedded Linux NAS, firmware long abandoned. 17yo drive. Plug in, pull data, recycle |

### BigBadWolf (Sabrent 2TB)

Cold archive of source video ISOs. Plug in only when a movie needs
re-encoding. 13yo drive — assume it can fail.

- `Video_ISO/` — source ISOs for every encoded movie
- `itunes_kb/` — tutorial screencasts (Peepcode, RailsCasts, OmniGraffle,
  etc.). Not movies. Pending copy to NAS.

ISO names will be re-aligned to match the Jellyfin-friendly NAS naming
(`Movie Name (Year)`) as part of the encoding cleanup.

### LaCie — synced to NAS (don't need LaCie copy anymore)

| LaCie path | NAS destination | Status |
|------------|-----------------|--------|
| `Music/iTunes` | `/Volumes/Music/Music/` | Verified by music_diff.rb. 1 Unicode false positive |
| `dad_rh/Pictures/Photos Library-rh.photoslibrary` | `/Volumes/Music/Pictures/` | rsync 2026-05-03 |
| `DVDs to be made` | `/Volumes/Video/home_videos/DVDs to be made/` | Already in sync |

### LaCie — stays on LaCie only (intentional)

| LaCie path | Why kept |
|------------|----------|
| `Video_ISO/` | Source ISOs (863G). Plug in only if a movie needs re-encoding |
| `dad_rh/Pictures/Merged.photolibrary` | Broken (0 Masters). Not worth syncing |
| `Pictures/photos-1` | Empty stub |
| `copy_music.rb`, `copy_photos.rb` | Old migration scripts. Historical |

LaCie role going forward: **cold archive of source ISOs**. Plug in only when
a movie needs re-encoding. Drive is 13yo, not NAS-grade — assume it can
fail at any time. The NAS holds everything that matters.

### Pulled to Mac, awaiting sort

In `~/Downloads/sort_through_these/dad_rh/`:
- `src/` (11G), `bin/`, `dotfiles/` — sort and place when ready
