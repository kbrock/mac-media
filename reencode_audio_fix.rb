#!/usr/bin/env ruby
# Re-encode movies with broken audio (foreign-only or no audio at all).
# Uses the new keep-all-audio logic from encode_batch.rb.
# Outputs directly into the renamed Movies/ structure.

require "fileutils"
require "open3"
require "json"

ISO_ROOT = "/Volumes/BigBadWolf/Video_ISO"
MOVIES   = File.expand_path("~/Movies/encoded/Movies")
TMP_DIR  = File.expand_path("~/Movies/mkv_temp")
LOG_FILE = File.expand_path("~/Movies/encoded/reencode_audio_fix.log")
MAKEMKV  = "/Applications/MakeMKV.app/Contents/MacOS/makemkvcon"

# (display_name, animated?)
MOVIES_TO_FIX = [
  ["101 Dalmatians II - Patch's London Adventure (2003)", true],
  ["Balto III - Wings of Change (2004)", true],
  ["Benny & Joon (1993)", false],
  ["Bolt (2008)", true],
  ["Buzz Lightyear of Star Command - The Adventure Begins (2000)", true],
  ["Fearless (2006)", false],
  ["How the Grinch Stole Christmas! (1966)", true],
  ["Jimmy Neutron - Attack of the Twonkies (2004)", true],
  ["Legally Blonde 2 - Red, White & Blonde (2003)", false],
  ["Lilo & Stitch (2002)", true],
  ["Mulan II (2004)", true],
  ["Robin Hood (1973)", true],
  ["Rumble in the Bronx (1995)", false],
  ["The Aristocats (1970)", true],
  ["The Road to El Dorado (2000)", true],
  ["The Sword in the Stone (1963)", true],
  ["Treasure Planet (2002)", true],
]

dry_run = ARGV.delete("--dry-run")

def log(msg)
  line = "[#{Time.now.strftime("%H:%M:%S")}] #{msg}"
  puts line
  File.open(LOG_FILE, "a") { |f| f.puts line }
end

def find_iso(name)
  Dir.glob(File.join(ISO_ROOT, "**", "#{name}.iso")).first
end

def extract(iso_path, tmp)
  FileUtils.rm_rf(tmp)
  FileUtils.mkdir_p(tmp)
  Open3.capture2(MAKEMKV, "mkv", "iso:#{iso_path}", "0", "#{tmp}/", err: [:child, :out])
  Dir.glob("#{tmp}/*.mkv").max_by { |f| File.size(f) }
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

  # Reorder so English comes first (becomes default)
  paired = audio_indices.zip(audio_langs).sort_by { |_, l| l == "eng" ? 0 : (l == "und" ? 1 : 2) }
  audio_indices = paired.map(&:first)
  audio_langs = paired.map(&:last)

  audio_indices = [1] if audio_indices.empty?
  { audio: audio_indices, subs: sub_indices, langs: audio_langs }
end

def build_command(mkv, out_file, tracks, animated:)
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
  args
end

failed = []
encoded = 0

MOVIES_TO_FIX.each_with_index do |(name, animated), i|
  iso = find_iso(name)
  unless iso
    log "[#{i+1}/#{MOVIES_TO_FIX.size}] MISS: #{name} (no ISO)"
    failed << name
    next
  end

  out_dir = File.join(MOVIES, name)
  out_file = File.join(out_dir, "#{name}.mkv")
  tmp = File.join(TMP_DIR, name.gsub(/\W+/, "_"))

  log "[#{i+1}/#{MOVIES_TO_FIX.size}] Extracting: #{name}"

  if dry_run
    log "  Would extract from #{iso}"
    next
  end

  mkv = extract(iso, tmp)
  unless mkv
    log "  FAILED extract"
    failed << name
    FileUtils.rm_rf(tmp)
    next
  end
  log "  Extracted: #{(File.size(mkv)/1024.0/1024).round(0)} MB"

  tracks = probe_tracks(mkv)
  unless tracks
    log "  FAILED probe"
    failed << name
    FileUtils.rm_rf(tmp)
    next
  end

  log "  Audio: #{tracks[:audio].zip(tracks[:langs]).map { |x, l| "#{x}(#{l})" }.join(",")}"
  unless tracks[:langs].include?("eng")
    log "  WARN: still no English audio detected (langs: #{tracks[:langs].uniq.join(",")})"
  end

  FileUtils.mkdir_p(out_dir)
  args = build_command(mkv, out_file, tracks, animated: animated)
  start = Time.now
  success = system(*args)
  elapsed = ((Time.now - start)/60).round(1)

  if success && File.exist?(out_file) && File.size(out_file) > 100_000_000
    log "  Done (#{elapsed} min, #{(File.size(out_file)/1024.0/1024).round(0)} MB)"
    encoded += 1
  else
    log "  FAILED encode"
    File.delete(out_file) if File.exist?(out_file)
    failed << name
  end

  FileUtils.rm_rf(tmp)
end

log ""
log "=" * 50
log "Done: #{encoded}/#{MOVIES_TO_FIX.size}, failed: #{failed.size}"
failed.each { |n| log "  FAIL: #{n}" }
