# Photo Library Inventory

Snapshot taken 2026-05-03.

## NAS `/Volumes/Music/Pictures/`

| Library                          | Type        | Masters | Originals | Total files | Size | Modified            |
|----------------------------------|-------------|---------|-----------|-------------|------|---------------------|
| iPhoto Library.photolibrary      | iPhoto pkg  | 2,318   | 0         | 22,817      | 8.6G | 2018-04-21 14:40    |
| Merged.photolibrary              | iPhoto pkg  | 11,050  | 0         | 67,085      | 20G  | 2024-02-09 13:31    |

| Folder              | Image files | Masters subfolder | Total files | Size  | Modified            |
|---------------------|-------------|-------------------|-------------|-------|---------------------|
| nanny_photos/       | 259         | 0                 | 259         | 60M   | 2018-04-21 12:31    |
| photos/             | 49,453      | 12,689            | 107,165     | 33G   | 2018-04-21 18:00    |
| photos-1/           | 45,887      | 12,251            | 95,413      | 31G   | 2018-07-11 12:17    |
| pics/               | 44          | 0                 | 48          | 255M  | 2023-04-05 19:51    |
| Summer2014/         | 18          | 0                 | 18          | 38M   | 2018-04-21 12:34    |

`photos/` and `photos-1/` are exploded iPhoto libraries (have AlbumData.xml,
Database/, Attachments/ - just no .photolibrary wrapper).

## LaCie copy at `~/Downloads/sort_through_these/dad_rh/Pictures/`

| Library                            | Type        | Masters | Originals | Total files | Size  | Modified            |
|------------------------------------|-------------|---------|-----------|-------------|-------|---------------------|
| Merged.photolibrary                | iPhoto pkg  | **0**   | 0         | 44,964      | 11G   | 2018-04-21 20:46    |
| Photos Library-rh.photoslibrary    | iPhoto pkg  | 2,168   | 0         | 24,050      | 8.5G  | 2018-04-21 20:26    |

## BigBadWolf

Already unplugged. No photo libraries inventoried.

## Mac Studio (current)

Photos library on Mac Studio: not inventoried in this snapshot. User reports "only 123 iCloud photos locally."

## Diagnosis

**LaCie's `Merged.photolibrary` is broken.** 0 masters and 0 originals - only thumbnails and database. The photos that *should* be inside are stored elsewhere (referenced library, or were extracted into a non-library folder).

**LaCie's `Photos Library-rh.photoslibrary`** has 2,168 masters. NAS's `iPhoto Library.photolibrary` has 2,318 masters - 150 more. Could be related (same ancestor) but NAS version is more complete.

**NAS `Merged.photolibrary` (Feb 2024)** is much newer than the LaCie copies (April 2018). Likely a consolidation built from various sources after the LaCie copies were made. 11,050 masters suggests it absorbed content from multiple libraries.

**NAS `photos/` and `photos-1/` total 24,940 image files in Masters folders.** These exploded libraries hold most of the historical photo data. Likely where the LaCie's broken Merged photos ended up.

## Conservative recommendation

**Don't delete anything yet.** Don't copy LaCie to NAS yet. Verify first.

Verification options ranked by effort:

### Easy (10 minutes)
- `diff <(find LaCie/Merged.photolibrary -name "*.xml" -printf "%f\n" | sort) <(find NAS/Merged.photolibrary -name "*.xml" | sort)` — see if database structures match
- Check `AlbumData.xml` dates on each library to find the lineage
- Open NAS Merged in Photos.app on Mac (read-only mount), see if photo count matches expectation

### Medium (1 hour)
- For LaCie's Photos Library-rh, sample 10 random Master filenames, see if they exist in NAS iPhoto Library Masters
- If they do, LaCie is a subset/older version, safe to ignore
- If they don't, LaCie has unique content worth migrating

### Thorough (half day)
- Full hash comparison of all Master files across all NAS libraries vs LaCie libraries
- Output: definitive list of any photo on LaCie not present anywhere on NAS

### Best long-term path

Don't try to merge libraries manually. Instead:
1. Install Immich on mac-media (planned project)
2. Point Immich at all 4-5 photo locations as separate import jobs
3. Immich deduplicates by file hash automatically
4. End state: one Immich library, all unique photos preserved, original libraries can be archived/deleted

This avoids the manual merge work entirely. The original libraries remain on NAS as cold backup until Immich is proven working.
