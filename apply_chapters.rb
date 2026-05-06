#!/usr/bin/env ruby
# Apply chapter names from NAS-extracted JSON files to local MKVs.
# Uses mkvpropedit to write chapter data.
#
#   ruby apply_chapters.rb              # apply to all matching MKVs
#   ruby apply_chapters.rb --dry-run    # show what would be done

require "json"
require "open3"
require "tempfile"

CHAPTER_DIR = File.expand_path("~/Movies/encoded/chapter_data")
ENCODED_DIR = File.expand_path("~/Movies/encoded")
MAPPING_FILE = File.join(File.dirname(__FILE__), "iso_mapping.txt")

dry_run = ARGV.delete("--dry-run")

# Build NAS name -> local path mapping from iso_mapping.txt
nas_to_local = {}
File.readlines(MAPPING_FILE).each do |line|
  line = line.strip
  next if line.empty? || line.start_with?("#")
  parts = line.split("|").map(&:strip)
  next unless parts.size >= 3
  status, iso_path, nas_name = parts[0], parts[1], parts[2]
  next unless %w[match new v2 home].include?(status)
  next if nas_name.nil? || nas_name.empty?

  # Clean up NAS name for matching against chapter JSON filenames
  # (JSON files use NAS directory names with : replaced by _)
  iso_basename = File.basename(iso_path)
  category = File.dirname(iso_path)
  mkv_path = File.join(ENCODED_DIR, category, "#{iso_basename}.mkv")

  # Also check redo/ path
  unless File.exist?(mkv_path)
    mkv_path = File.join(ENCODED_DIR, "redo", category, "#{iso_basename}.mkv")
  end

  nas_to_local[nas_name] = mkv_path if File.exist?(mkv_path)
end

# Convert ffprobe chapter JSON to mkvpropedit XML format
def chapters_to_xml(chapters)
  xml = %(<?xml version="1.0" encoding="UTF-8"?>\n)
  xml << %(<Chapters>\n  <EditionEntry>\n)

  chapters.each do |ch|
    start_ns = (ch["start_time"].to_f * 1_000_000_000).to_i
    end_ns = (ch["end_time"].to_f * 1_000_000_000).to_i
    title = ch.dig("tags", "title") || "Chapter"

    # Skip chapters with negative or zero timestamps
    next if start_ns < 0

    xml << %(    <ChapterAtom>\n)
    xml << %(      <ChapterTimeStart>#{format_time(start_ns)}</ChapterTimeStart>\n)
    # Omit end time if negative (last chapter - mkvpropedit infers from file duration)
    xml << %(      <ChapterTimeEnd>#{format_time(end_ns)}</ChapterTimeEnd>\n) if end_ns > 0
    xml << %(      <ChapterDisplay>\n)
    xml << %(        <ChapterString>#{escape_xml(title)}</ChapterString>\n)
    xml << %(        <ChapterLanguage>eng</ChapterLanguage>\n)
    xml << %(      </ChapterDisplay>\n)
    xml << %(    </ChapterAtom>\n)
  end

  xml << %(  </EditionEntry>\n</Chapters>\n)
  xml
end

def format_time(ns)
  total_s = ns / 1_000_000_000
  h = total_s / 3600
  m = (total_s % 3600) / 60
  s = total_s % 60
  frac = ns % 1_000_000_000
  sprintf("%02d:%02d:%02d.%09d", h, m, s, frac)
end

def escape_xml(str)
  str.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
end

applied = 0
skipped = 0
failed = 0

Dir.glob("#{CHAPTER_DIR}/*.json").sort.each do |json_file|
  nas_name = File.basename(json_file, ".json").gsub("_", ":")
  # Also try with underscores left as-is (some names use _ literally)
  nas_name_raw = File.basename(json_file, ".json")

  mkv_path = nas_to_local[nas_name] || nas_to_local[nas_name_raw]

  unless mkv_path
    # Try fuzzy match - NAS names have colons replaced with _
    match = nas_to_local.find { |k, _| k.gsub(":", "_").gsub("/", "_") == nas_name_raw }
    mkv_path = match&.last
  end

  unless mkv_path && File.exist?(mkv_path)
    skipped += 1
    next
  end

  data = JSON.parse(File.read(json_file))
  chapters = data["chapters"] || []
  next if chapters.empty?

  # Skip if all chapters are generic
  named_count = chapters.count { |c| c.dig("tags", "title") && c.dig("tags", "title") !~ /^Chapter \d+$/ }
  if named_count == 0
    puts "SKIP (generic): #{nas_name_raw}"
    skipped += 1
    next
  end

  xml = chapters_to_xml(chapters)

  if dry_run
    puts "WOULD APPLY: #{nas_name_raw} -> #{File.basename(mkv_path)} (#{chapters.size} chapters, #{named_count} named)"
    applied += 1
    next
  end

  Tempfile.create(["chapters", ".xml"]) do |tmp|
    tmp.write(xml)
    tmp.flush

    out, status = Open3.capture2e("mkvpropedit", mkv_path, "--chapters", tmp.path)
    if status.success?
      puts "OK: #{File.basename(mkv_path)} (#{chapters.size} chapters)"
      applied += 1
    else
      puts "FAIL: #{File.basename(mkv_path)}: #{out.strip}"
      failed += 1
    end
  end
end

puts ""
puts "Results: #{applied} applied, #{skipped} skipped, #{failed} failed"
