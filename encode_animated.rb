#!/usr/bin/env ruby
# Encode animated MKVs extracted by MakeMKV. Runs 2 at a time.
#
#   ruby encode_animated.rb             # encode all
#   ruby encode_animated.rb --dry-run   # show what would be done

require "fileutils"
require "open3"
require "json"

MKV_DIR  = File.expand_path("~/Movies/mkv_temp/animated")
OUTPUT   = File.expand_path("~/Movies/encoded/animated")
LOG_FILE = File.join(OUTPUT, "encode_animated_log.txt")
PARALLEL = 2

dry_run = ARGV.delete("--dry-run")

def log(msg)
  line = "[#{Time.now.strftime("%H:%M:%S")}] #{msg}"
  puts line
  File.open(LOG_FILE, "a") { |f| f.puts line }
end

def select_tracks(mkv)
  probe = JSON.parse(`ffprobe -v quiet -print_format json -show_streams "#{mkv}"`) rescue nil
  return nil unless probe

  eng_audio = []
  eng_subs = []
  probe["streams"].each_with_index do |s, i|
    lang = s.dig("tags", "language") || "und"
    if s["codec_type"] == "audio" && (lang == "eng" || lang == "und")
      eng_audio << (i + 1)
    elsif s["codec_type"] == "subtitle" && (lang == "eng" || lang == "und")
      eng_subs << (i + 1)
    end
  end
  eng_audio = [1] if eng_audio.empty?

  { audio: eng_audio, subs: eng_subs }
end

def encode(mkv, out_file, tracks)
  audio_spec = (tracks[:audio] + [tracks[:audio].first]).join(",")
  encoders = (tracks[:audio].map { "copy" } + ["av_aac"]).join(",")
  mixdowns = (tracks[:audio].map { "none" } + ["stereo"]).join(",")
  drcs = (tracks[:audio].map { "0" } + ["2.0"]).join(",")

  args = [
    "HandBrakeCLI",
    "--input", mkv,
    "--output", out_file,
    "--format", "av_mkv",
    "--encoder", "x265_10bit",
    "--encoder-preset", "slow",
    "--quality", "20",
    "--encoder-tune", "animation",
    "--audio", audio_spec,
    "--aencoder", encoders,
    "--mixdown", mixdowns,
    "--drc", drcs,
    "--markers",
  ]
  args += ["--subtitle", tracks[:subs].join(",")] if tracks[:subs].any?

  system(*args)
end

# Collect MKVs to encode
jobs = []
Dir.children(MKV_DIR).sort.each do |name|
  dir = File.join(MKV_DIR, name)
  next unless File.directory?(dir)
  mkv = Dir.glob("#{dir}/*.mkv").first
  next unless mkv

  out_file = File.join(OUTPUT, "#{name}.mkv")
  if File.exist?(out_file) && File.size(out_file) > 1_000_000
    log "SKIP: #{name}"
    next
  end

  jobs << { name: name, mkv: mkv, out: out_file }
end

FileUtils.mkdir_p(OUTPUT)
log "Found #{jobs.size} animated movies to encode (#{PARALLEL} parallel)"
log "Mode: #{dry_run ? 'DRY RUN' : 'ENCODE'}"

if dry_run
  jobs.each { |j| log "  #{j[:name]}" }
  exit
end

# Process in batches of PARALLEL
jobs.each_slice(PARALLEL) do |batch|
  pids = {}
  batch.each do |job|
    tracks = select_tracks(job[:mkv])
    unless tracks
      log "FAILED to probe: #{job[:name]}"
      next
    end
    log "Starting: #{job[:name]} (audio: #{tracks[:audio].join(",")}, subs: #{tracks[:subs].join(",")})"

    pid = fork do
      encode(job[:mkv], job[:out], tracks)
    end
    pids[pid] = job
  end

  # Wait for batch to finish
  pids.each do |pid, job|
    Process.wait(pid)
    if $?.success? && File.exist?(job[:out]) && File.size(job[:out]) > 1_000_000
      log "Done: #{job[:name]} (#{(File.size(job[:out]) / 1024.0 / 1024).round(1)} MB)"
    else
      log "FAILED: #{job[:name]}"
      File.delete(job[:out]) if File.exist?(job[:out])
    end
  end
end

log "Animated batch complete."
