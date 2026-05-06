#!/usr/bin/env ruby
# Batch encode ISOs to H.265 MKV using MakeMKV extract + HandBrake encode.
# MakeMKV handles all disc types including encrypted DVDs.
# Picks English audio (including commentary), synthesizes stereo fallback.
# Keeps English subs. Drops foreign language tracks.
#
#   ruby encode_batch.rb                # encode all non-animated
#   ruby encode_batch.rb --animated     # only animated
#   ruby encode_batch.rb --all          # both animated and non-animated
#   ruby encode_batch.rb --dry-run      # show what would be done

require "fileutils"
require "open3"
require "json"

ISO_ROOT   = "/Volumes/BigBadWolf/Video_ISO"
OUTPUT     = File.expand_path("~/Movies/encoded")
TMP_DIR    = File.expand_path("~/Movies/mkv_temp")
LOG_FILE   = File.join(OUTPUT, "encode_log.txt")
FAIL_FILE  = File.join(OUTPUT, "encode_failures.txt")
MAKEMKV    = "/Applications/MakeMKV.app/Contents/MacOS/makemkvcon"

ANIMATED_DIRS = %w[animated redo/animated].freeze
NON_ANIMATED_DIRS = %w[adults kids misc redo/adults redo/kids redo/misc].freeze

dry_run       = ARGV.delete("--dry-run")
animated_only = ARGV.delete("--animated")
all_dirs      = ARGV.delete("--all")

dirs = if all_dirs
         ANIMATED_DIRS + NON_ANIMATED_DIRS
       elsif animated_only
         ANIMATED_DIRS
       else
         NON_ANIMATED_DIRS
       end

def log(msg)
  line = "[#{Time.now.strftime("%H:%M:%S")}] #{msg}"
  puts line
  File.open(LOG_FILE, "a") { |f| f.puts line }
end

# Extract the longest title from an ISO using MakeMKV.
# Returns path to extracted MKV, or nil on failure.
def extract(iso_path, tmp)
  FileUtils.rm_rf(tmp)
  FileUtils.mkdir_p(tmp)
  out, status = Open3.capture2(
    MAKEMKV, "mkv", "iso:#{iso_path}", "0", "#{tmp}/",
    err: [:child, :out]
  )
  out = out.encode("UTF-8", invalid: :replace, undef: :replace)

  mkv = Dir.glob("#{tmp}/*.mkv").max_by { |f| File.size(f) }
  return mkv if mkv && File.size(mkv) > 1_000_000

  log "  MakeMKV output: #{out.lines.last(3).join("  ")}" unless status.success?
  nil
end

# Probe an MKV for audio and subtitle streams using ffprobe.
def probe_tracks(mkv_path)
  json, status = Open3.capture2(
    "ffprobe", "-v", "quiet", "-print_format", "json", "-show_streams", mkv_path
  )
  return nil unless status.success?

  data = JSON.parse(json)
  audio_indices = []
  audio_langs = []
  sub_indices = []
  audio_idx = 0
  sub_idx = 0

  # Keep ALL audio tracks. Foreign-language defaults caused the original bug
  # where some movies ended up with only French/Spanish audio. Track the
  # language list so caller can warn when no English is present.
  data["streams"].each do |s|
    case s["codec_type"]
    when "audio"
      audio_idx += 1
      audio_indices << audio_idx
      audio_langs << (s.dig("tags", "language") || "und")
    when "subtitle"
      sub_idx += 1
      lang = s.dig("tags", "language") || "und"
      sub_indices << sub_idx if lang == "eng" || lang == "und"
    end
  end

  # Reorder so English (or undefined) comes first — that becomes the default track
  english_first = audio_indices.zip(audio_langs).sort_by { |_, l| l == "eng" ? 0 : (l == "und" ? 1 : 2) }
  audio_indices = english_first.map(&:first)
  audio_langs = english_first.map(&:last)

  audio_indices = [1] if audio_indices.empty?
  { audio: audio_indices, subs: sub_indices, langs: audio_langs }
rescue JSON::ParserError
  nil
end

def build_command(mkv_path, out_file, tracks, animated:)
  audio_spec = tracks[:audio].dup
  encoders = audio_spec.map { "copy" }
  mixdowns = audio_spec.map { "none" }
  drcs = audio_spec.map { "0" }

  # Always synth stereo from first English track for surround-incapable devices
  audio_spec << audio_spec.first
  encoders << "av_aac"
  mixdowns << "stereo"
  drcs << "2.0"

  args = [
    "HandBrakeCLI",
    "--input", mkv_path,
    "--output", out_file,
    "--format", "av_mkv",
    "--encoder", "x265_10bit",
    "--encoder-preset", "slow",
    "--quality", "20",
    "--audio", audio_spec.join(","),
    "--aencoder", encoders.join(","),
    "--mixdown", mixdowns.join(","),
    "--drc", drcs.join(","),
    "--markers",
  ]

  if tracks[:subs].any?
    args += ["--subtitle", tracks[:subs].join(",")]
  end

  if animated
    args += ["--encoder-tune", "animation"]
  else
    args += ["--encopts", "strong-intra-smoothing=0:psy-rd=2.0"]
  end

  args
end

# Collect ISOs
isos = []
dirs.each do |dir|
  path = File.join(ISO_ROOT, dir)
  next unless File.directory?(path)
  Dir.glob(File.join(path, "*.iso")).sort.each do |iso|
    isos << { path: iso, category: dir, animated: ANIMATED_DIRS.include?(dir) }
  end
end

FileUtils.mkdir_p(OUTPUT)
FileUtils.mkdir_p(TMP_DIR)
log "Found #{isos.size} ISOs to process"
log "Mode: #{dry_run ? 'DRY RUN' : 'ENCODE'}"

encoded = 0
skipped = 0
failed = []

isos.each_with_index do |iso, i|
  name = File.basename(iso[:path], ".iso")
  out_dir = File.join(OUTPUT, iso[:category])
  out_file = File.join(out_dir, "#{name}.mkv")
  label = "#{iso[:category]}/#{name}"

  if File.exist?(out_file) && File.size(out_file) > 1_000_000
    log "[#{i + 1}/#{isos.size}] SKIP: #{label}"
    skipped += 1
    next
  end

  tmp = File.join(TMP_DIR, name.gsub(/\s+/, "_"))

  log "[#{i + 1}/#{isos.size}] Extracting: #{label}"

  if dry_run
    log "  Would extract with MakeMKV then encode"
    next
  end

  mkv = extract(iso[:path], tmp)
  unless mkv
    log "  FAILED to extract"
    failed << label
    FileUtils.rm_rf(tmp)
    next
  end
  log "  Extracted: #{(File.size(mkv) / 1024.0 / 1024).round(0)} MB"

  tracks = probe_tracks(mkv)
  unless tracks
    log "  FAILED to probe tracks"
    failed << label
    FileUtils.rm_rf(tmp)
    next
  end
  log "  Audio: #{tracks[:audio].zip(tracks[:langs]).map { |i, l| "#{i}(#{l})" }.join(",")} +synth stereo"
  unless tracks[:langs].include?("eng")
    log "  WARN: no English audio detected (langs: #{tracks[:langs].uniq.join(",")})"
    File.open(File.join(OUTPUT, "no_english_audio.txt"), "a") { |f| f.puts label }
  end
  log "  Subs: #{tracks[:subs].any? ? tracks[:subs].join(",") : "none"}"

  args = build_command(mkv, out_file, tracks, animated: iso[:animated])

  FileUtils.mkdir_p(out_dir)
  start = Time.now
  success = system(*args)
  elapsed = ((Time.now - start) / 60).round(1)

  if success && File.exist?(out_file) && File.size(out_file) > 1_000_000
    log "  Done (#{elapsed} min, #{(File.size(out_file) / 1024.0 / 1024).round(1)} MB)"
    encoded += 1
  else
    log "  FAILED (#{elapsed} min)"
    File.delete(out_file) if File.exist?(out_file)
    failed << label
  end

  FileUtils.rm_rf(tmp)
end

log ""
log "=" * 50
log "Results: #{encoded} encoded, #{skipped} skipped, #{failed.size} failed"
if failed.any?
  log "Failed:"
  failed.each { |f| log "  #{f}" }
  File.open(FAIL_FILE, "w") { |f| failed.each { |name| f.puts name } }
end
