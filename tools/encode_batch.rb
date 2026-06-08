#!/usr/bin/env ruby
# Encode DVD ISOs to H.265 MKV using MakeMKV extract + HandBrake encode.
# Walks Videos/<category>/*.iso, writes encoded/<category>/<name>/<name>.mkv.
# Uses HandBrake's animation tune for ISOs under animated/.
# Keeps all audio tracks (English first), synthesizes a stereo fallback.
# Keeps English subtitles. Skips already-encoded files so it's safe to restart.
#
#   ruby encode_batch.rb                    # encode all categories
#   ruby encode_batch.rb --only animated    # one category
#   ruby encode_batch.rb --isos "name1|name2"  # only these ISO basenames (pipe-separated; titles can contain commas)
#   ruby encode_batch.rb --source-paths "/abs/path1|/abs/path2"  # encode these files directly (bypasses BigBadWolf scan)
#   ruby encode_batch.rb --dry-run          # show what would be done

require "fileutils"
require "open3"
require "json"

VIDEOS    = "/Volumes/BigBadWolf/Videos"
OUTPUT    = File.expand_path("~/Movies/encoded")
TMP_DIR   = File.expand_path("~/Movies/mkv_temp")
LOG_FILE  = File.join(OUTPUT, "encode_log.txt")
FAIL_FILE = File.join(OUTPUT, "encode_failures.txt")
MAKEMKV   = "/Applications/MakeMKV.app/Contents/MacOS/makemkvcon"

CATEGORIES  = %w[animated home_videos live].freeze
ANIMATED    = "animated"
HOME_VIDEOS = "home_videos"

dry_run = ARGV.delete("--dry-run")
only_idx = ARGV.index("--only")
only = only_idx && ARGV[only_idx + 1]
ARGV.slice!(only_idx, 2) if only_idx

isos_idx = ARGV.index("--isos")
only_isos = isos_idx && ARGV[isos_idx + 1].split("|")
ARGV.slice!(isos_idx, 2) if isos_idx

sources_idx = ARGV.index("--source-paths")
source_paths = sources_idx ? ARGV[sources_idx + 1].split("|") : []
ARGV.slice!(sources_idx, 2) if sources_idx

categories = only ? [only] : CATEGORIES

def log(msg)
  line = "[#{Time.now.strftime("%H:%M:%S")}] #{msg}"
  puts line
  File.open(LOG_FILE, "a") { |f| f.puts line }
end

def extract(iso_path, tmp)
  FileUtils.rm_rf(tmp)
  FileUtils.mkdir_p(tmp)
  out, status = Open3.capture2(MAKEMKV, "mkv", "iso:#{iso_path}", "0", "#{tmp}/", err: [:child, :out])
  out = out.encode("UTF-8", invalid: :replace, undef: :replace)
  mkv = Dir.glob("#{tmp}/*.mkv").max_by { |f| File.size(f) }
  return mkv if mkv && File.size(mkv) > 1_000_000

  log "  MakeMKV output: #{out.lines.last(3).join("  ")}" unless status.success?
  nil
end

def probe_tracks(mkv_path)
  json, status = Open3.capture2("ffprobe", "-v", "quiet", "-print_format", "json", "-show_streams", mkv_path)
  return nil unless status.success?

  data = JSON.parse(json)
  audio_indices = []
  audio_langs = []
  sub_indices = []
  audio_idx = 0
  sub_idx = 0

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

  paired = audio_indices.zip(audio_langs).sort_by { |_, l| l == "eng" ? 0 : (l == "und" ? 1 : 2) }
  audio_indices = paired.map(&:first)
  audio_langs = paired.map(&:last)

  audio_indices = [1] if audio_indices.empty?
  { audio: audio_indices, subs: sub_indices, langs: audio_langs }
rescue JSON::ParserError
  nil
end

def build_command(mkv, out_file, tracks, animated:, home_videos:)
  audio_spec = tracks[:audio].dup
  encoders = audio_spec.map { "copy" }
  mixdowns = audio_spec.map { "none" }
  drcs = audio_spec.map { "0" }

  audio_spec << audio_spec.first
  encoders << "av_aac"
  mixdowns << "stereo"
  drcs << "2.0"

  args = [
    "HandBrakeCLI", "--input", mkv, "--output", out_file,
    "--format", "av_mkv", "--encoder", "x265_10bit",
    "--encoder-preset", "slow", "--quality", "20",
    "--audio", audio_spec.join(","),
    "--aencoder", encoders.join(","),
    "--mixdown", mixdowns.join(","),
    "--drc", drcs.join(","),
    "--markers",
  ]
  args += ["--subtitle", tracks[:subs].join(",")] if tracks[:subs].any?
  args += animated ? ["--encoder-tune", "animation"] : ["--encopts", "strong-intra-smoothing=0:psy-rd=2.0"]
  # Film sources (animated/live) carry 3:2 telecine on NTSC DVD; camera-shot home_videos are truly interlaced.
  # Detelecine + comb-detect/decomb together: detelecine restores clean 3:2 cadence, decomb cleans up residual combing the IVTC missed (mixed-cadence sources).
  args += home_videos ? ["--comb-detect", "--decomb"] : ["--detelecine", "--comb-detect", "--decomb"]
  args
end

isos = []
categories.each do |cat|
  path = File.join(VIDEOS, cat)
  next unless File.directory?(path)
  Dir.glob(File.join(path, "*.iso")).sort.each do |iso|
    isos << { path: iso, category: cat, animated: cat == ANIMATED, home_videos: cat == HOME_VIDEOS, pre_extracted: false }
  end
  # Pre-extracted MakeMKV intermediates: <name>.src.mkv next to ISOs, skip MakeMKV step.
  Dir.glob(File.join(path, "*.src.mkv")).sort.each do |mkv|
    isos << { path: mkv, category: cat, animated: cat == ANIMATED, home_videos: cat == HOME_VIDEOS, pre_extracted: true }
  end
end

def basename_of(iso)
  base = File.basename(iso[:path])
  if iso[:pre_extracted]
    base.sub(/\.src\.mkv\z/, "").sub(/\.mkv\z/, "")
  else
    base.sub(/\.iso\z/i, "")
  end
end

isos.select! { |iso| only_isos.include?(basename_of(iso)) } if only_isos

# --source-paths: explicit absolute paths; category from parent dir name or default to live; not filtered by --isos.
source_paths.each do |path|
  cat = CATEGORIES.find { |c| File.dirname(path).end_with?("/#{c}") } || "live"
  isos << {
    path: path,
    category: cat,
    animated: cat == ANIMATED,
    home_videos: cat == HOME_VIDEOS,
    pre_extracted: !path.downcase.end_with?(".iso"),
  }
end

FileUtils.mkdir_p(OUTPUT)
FileUtils.mkdir_p(TMP_DIR)
log "Found #{isos.size} ISOs (#{categories.join(", ")})"
log "Mode: #{dry_run ? 'DRY RUN' : 'ENCODE'}"

encoded = 0
skipped = 0
failed = []

isos.each_with_index do |iso, i|
  name = basename_of(iso)
  out_dir = File.join(OUTPUT, iso[:category], name)
  out_file = File.join(out_dir, "#{name}.mkv")
  label = "#{iso[:category]}/#{name}"

  if File.exist?(out_file) && File.size(out_file) > 1_000_000
    log "[#{i + 1}/#{isos.size}] SKIP: #{label}"
    skipped += 1
    next
  end

  log "[#{i + 1}/#{isos.size}] #{iso[:pre_extracted] ? 'Using pre-extracted' : 'Extracting'}: #{label}"

  if dry_run
    log "  Would #{iso[:pre_extracted] ? 'encode directly' : 'extract with MakeMKV then encode'}"
    next
  end

  if iso[:pre_extracted]
    mkv = iso[:path]
    tmp = nil
  else
    tmp = File.join(TMP_DIR, name.gsub(/\s+/, "_"))
    mkv = extract(iso[:path], tmp)
    unless mkv
      log "  FAILED to extract"
      failed << label
      FileUtils.rm_rf(tmp)
      next
    end
    log "  Extracted: #{(File.size(mkv) / 1024.0 / 1024).round(0)} MB"
  end

  tracks = probe_tracks(mkv)
  unless tracks
    log "  FAILED to probe tracks"
    failed << label
    FileUtils.rm_rf(tmp)
    next
  end
  log "  Audio: #{tracks[:audio].zip(tracks[:langs]).map { |n, l| "#{n}(#{l})" }.join(",")} +synth stereo"
  unless tracks[:langs].include?("eng")
    log "  WARN: no English audio detected (langs: #{tracks[:langs].uniq.join(",")})"
    File.open(File.join(OUTPUT, "no_english_audio.txt"), "a") { |f| f.puts label }
  end
  log "  Subs: #{tracks[:subs].any? ? tracks[:subs].join(",") : "none"}"

  args = build_command(mkv, out_file, tracks, animated: iso[:animated], home_videos: iso[:home_videos])

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

  FileUtils.rm_rf(tmp) if tmp
end

log ""
log "=" * 50
log "Results: #{encoded} encoded, #{skipped} skipped, #{failed.size} failed"
if encoded > 0
  log ""
  log "run tool to apply chapter names"
end
if failed.any?
  log "Failed:"
  failed.each { |f| log "  #{f}" }
  File.open(FAIL_FILE, "w") { |f| failed.each { |name| f.puts name } }
end
