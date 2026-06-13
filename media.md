# Media

Pipeline: ISO → MakeMKV → HandBrake → NAS (Jellyfin/Navidrome read-only mount).

## Tools (in `tools/`)
- `encode_batch.rb` — inputs: `.iso`, `.src.mkv` (skip MakeMKV), or `--source-paths "/abs/p1|/abs/p2"`. Filters per category: animated/live → `--detelecine --comb-detect --decomb`; home_videos → `--comb-detect --decomb`. Encoder: x265 10-bit, preset `slow`, quality 20.

## Layout
- **BigBadWolf** `/Volumes/BigBadWolf/Videos/{animated,live,home_videos}/`: `.iso` (disc rip) + `.src.mkv` (MakeMKV intermediate, kept as insurance against losing MakeMKV access).
- **NAS** `/volume1/Video/{Movies,Christmas,Misc}/<Title (Year)>/<Title (Year)>.mkv`. Local SMB mount at `/Volumes/Video/`.

## Chapter titles
Chapter titles are embedded in the current MKVs on the NAS (the Jellyfin library). If a re-encode needs them: `ffprobe -show_chapters <nas-source.mkv>` to extract, `mkvpropedit --chapters chapters.xml <new.mkv>` to apply. Do this per-title only if/when it matters.

## Process
1. Rip ISO from disc → BigBadWolf (MakeMKV, user-driven).
2. `encode_batch.rb` → `~/Movies/encoded/<cat>/<title>/<title>.mkv`.
3. Apply chapter titles if available.
4. Verify: `ffprobe` framerate (`23.976`/`25` trust; `29.97` run `ffmpeg -vf idet`; Multi-frame Progressive > 950/1001 = clean).
5. `scp -Op` to NAS via `ssh diskstation` — gotcha: Synology has no sftp subsystem, so plain `scp` fails. When replacing, rename existing target to `<Title>.bak.mkv` first.

See `media-migration.md` for migration history and reference (chapter source origin, NAS auth, `iso_mapping.txt`).
