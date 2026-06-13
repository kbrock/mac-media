# Media

Movies, TV, music, photos — hardware, services, scripts, decisions.
For NAS/drive specs see [storage.md](storage.md). For network DNS plan see
[network.md](network.md). Active migration tasks live in
[../media-migration.md](../media-migration.md) and will fold into here as
they finish.

## Hardware

| Device               | Spec                                       | Role        |
|----------------------|--------------------------------------------|-------------|
| Roku Ultra e93       | model 4670                                 | Primary streamer |
| Samsung UN55JU7100   | 55" 4K 2015, HDMI 2.0a, HDCP 2.2           | TV (rarely used) |
| Samsung H550 soundbar | 2015, PowerLink + Anynet+ (HDMI-CEC)       | TV audio    |

Samsung TV is **no longer connected to the internet** — its built-in apps
phone home aggressively (used to show email on every power-on). All
streaming goes via Roku.

## Roku apps

- **Jellyfin** — primary use, streams from mac-media `movies.home.thebrocks.net`
- **Luna** (sideloaded) — Amazon cloud gaming
- Other streaming apps (Netflix, etc.) — installed normally

## Services on mac-media

| Service   | Subdomain (planned)              | Port | Source             |
|-----------|----------------------------------|------|--------------------|
| Jellyfin  | `movies.home.thebrocks.net`      | 8096 | NAS `/mnt/nas/video` |
| Navidrome | `music.home.thebrocks.net`       | 4533 | NAS `/mnt/nas/music` |
| Immich    | `photos.home.thebrocks.net` (planned) | 2283 | NAS, Postgres + Redis quadlets needed |

Jellyfin's metadata cache lives on mac-media local disk (`~/srv/jellyfin/cache/`)
because the NAS `movies` guest user is read-only.

## Storage map for media

- **Movies (encoded H.265 MKV)**: NAS `/Volumes/Video/Movies/`
- **Movies (source ISOs)**: BigBadWolf `/Volumes/BigBadWolf/Video_ISO/`. Plug
  in only when re-encoding needed.
- **Music**: NAS `/Volumes/Music/Music/`
- **Photos**: NAS `/Volumes/Music/Pictures/` (multiple libraries — Immich
  will dedupe on import)
- **NAS-only movies (no ISO source)**: boundaries, StarshipGroove, The
  American Dollar, SR movie, 7 Christmas specials

## Encoding pipeline

Scripts live in `tools/`. Documentation lives here.

- `encode_batch.rb` — MakeMKV extract + HandBrake encode → H.265 MKV.
  Result is ~160MB from ~4GB ISO, ~2:20 per movie on M4 Max.
- `apply_chapters.rb` — applies named chapters to MKVs via `mkvpropedit`,
  reading `~/Movies/encoded/chapter_data/*.json` (ffprobe output).
- `music_diff.rb` — diffs music between sources to find missing.
- `find_n_dupes.rb`, `resolve_n_dupes.rb` — finds `Track.mp3` +
  `Track 1.mp3` duplicate pairs.

### Decisions

- **Codec**: H.265 MKV. Picked for size at acceptable quality.
- **Container**: MKV (not MP4) — better chapter support.
- **Chapters**: named via `mkvpropedit` from `chapter_data/*.json` extracted
  with ffprobe.
- **Naming**: `Movie Name (Year)` per Jellyfin/TMDb conventions.
- **Audio**: original tracks preserved.
- **Subtitles**: included if present in source.
- **Library structure**: `Movies/` flat (one folder per movie), `Christmas/`
  separate, `Misc/` for series/home video/non-movie files.
- **Pipeline consolidation**: `encode_batch.rb` superseded `encode_redo.rb`,
  `encode_animated.rb`, `encode_isos.rb`. Always uses MakeMKV extract +
  HandBrake encode.
- **MKV input escape hatch (pending)**: when `rip.sh` fails (damaged or
  copy-protected disc), MakeMKV-UI produces MKV directly. Pipeline should
  detect `.mkv` input and skip the MakeMKV extract step.
- **Animated edge case**: ISOs with multiple titles (Despicable Me, Lion
  King, Madagascar, Shark Tale) — MakeMKV pulled short featurettes by
  default. Required manual title selection via `makemkvcon info iso:<path>`.

## Phone apps

- Amperfy → Navidrome (planned, pin offline albums for car).
- Immich iOS app → Immich (planned, once server is up; family auto-upload).

## Migration vs steady state

`media-migration.md` is the **task list** for getting the libraries cleaned
up and into the services. When that work completes, the task list goes away
but decisions and current-state notes from it should land in this file.
