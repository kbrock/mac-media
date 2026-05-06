#!/usr/bin/env ruby
# Batch encode DVD ISOs to H.265 MKV using HandBrakeCLI.
# Picks the longest title from each ISO (the movie, not extras).
# Skips already-encoded files so it's safe to restart.
#
#   ruby encode_isos.rb                # encode all ISOs
#   ruby encode_isos.rb --dry-run      # just show what would be done
#   ruby encode_isos.rb --scan-only    # scan titles, don't encode

ISO_ROOT = "/Volumes/BigBadWolf/Video_ISO"
OUTPUT   = File.expand_path("~/Movies/encoded")

# H.265 VideoToolbox (hardware encoder on M4 Pro), AAC audio, DVD resolution
HANDBRAKE_OPTS = %w[
  --encoder vt_h265
  --quality 22
  --aencoder ca_aac
  --ab 160
  --mixdown stereo
  --format av_mkv
].freeze

dry_run   = ARGV.delete("--dry-run")
scan_only = ARGV.delete("--scan-only")

require "fileutils"
require "open3"
require "json"

abort "ISO_ROOT not found: #{ISO_ROOT}" unless File.directory?(ISO_ROOT)
FileUtils.mkdir_p(OUTPUT) unless dry_run

# Find the longest title in an ISO
def scan_titles(iso_path)
  out, status = Open3.capture2("HandBrakeCLI", "--input", iso_path, "--title", "0", "--scan", "--json")
  return nil unless status.success?

  # Extract "JSON Title Set: {...}" block and parse
  out = out.encode("UTF-8", invalid: :replace, undef: :replace)
  json_str = out.sub(/\A.*^JSON Title Set: /m, "")
  data = JSON.parse(json_str)

  titles = data["TitleList"].map do |t|
    d = t["Duration"]
    duration = d["Hours"] * 3600 + d["Minutes"] * 60 + d["Seconds"]
    { index: t["Index"], duration: duration, display: "#{d["Hours"]}h#{d["Minutes"]}m#{d["Seconds"]}s" }
  end

  titles.max_by { |t| t[:duration] }
rescue JSON::ParserError
  nil
end

# Find all ISOs
isos = Dir.glob("#{ISO_ROOT}/**/*.iso").sort
puts "Found #{isos.size} ISOs in #{ISO_ROOT}"
puts "Output: #{OUTPUT}"
puts "Mode: #{dry_run ? 'DRY RUN' : scan_only ? 'SCAN ONLY' : 'ENCODE'}"
puts

encoded = 0
skipped = 0
failed = []

isos.each_with_index do |iso, i|
  rel = iso.delete_prefix("#{ISO_ROOT}/")
  name = File.basename(rel, ".iso")
  category = File.dirname(rel)
  out_dir = File.join(OUTPUT, category)
  out_file = File.join(out_dir, "#{name}.mkv")

  if File.exist?(out_file) && File.size(out_file) > 1_000_000
    puts "[#{i + 1}/#{isos.size}] SKIP (exists): #{rel}"
    skipped += 1
    next
  end

  puts "[#{i + 1}/#{isos.size}] Scanning: #{rel}"
  title = scan_titles(iso)

  unless title
    puts "  FAILED to scan, skipping"
    failed << rel
    next
  end

  puts "  Main title: ##{title[:index]} (#{title[:display]})"

  if scan_only
    next
  end

  if dry_run
    puts "  Would encode to: #{out_file}"
    next
  end

  FileUtils.mkdir_p(out_dir)
  puts "  Encoding to: #{out_file}"
  start = Time.now

  success = system(
    "HandBrakeCLI",
    "--input", iso,
    "--output", out_file,
    "--title", title[:index].to_s,
    *HANDBRAKE_OPTS
  )

  elapsed = ((Time.now - start) / 60).round(1)

  if success && File.exist?(out_file) && File.size(out_file) > 1_000_000
    puts "  Done (#{elapsed} min)"
    encoded += 1
  else
    puts "  FAILED (#{elapsed} min)"
    File.delete(out_file) if File.exist?(out_file)
    failed << rel
  end
end

puts
puts "=" * 50
puts "Results: #{encoded} encoded, #{skipped} skipped, #{failed.size} failed"
if failed.any?
  puts
  puts "Failed ISOs:"
  failed.each { |f| puts "  #{f}" }
end
