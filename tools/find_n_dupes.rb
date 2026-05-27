#!/usr/bin/env ruby
# Find MP3 pairs like "Track.mp3" + "Track 1.mp3" in the same folder.
# Usage: ruby find_n_dupes.rb /mnt/nas/music > pairs.txt
#
# Output columns: size_base  size_N  delta%  n_path
# Review pairs.txt, delete rows you want to handle manually, then:
#   awk -F'\t' '{print $4}' pairs.txt | tr '\n' '\0' | xargs -0 rm -v

require 'find'

root = ARGV[0] or abort "usage: #{$0} <root>"

by_dir = Hash.new { |h, k| h[k] = [] }
Find.find(root) do |path|
  next unless path.end_with?('.mp3')
  by_dir[File.dirname(path)] << File.basename(path)
end

puts ["size_base", "size_N", "delta%", "n_path"].join("\t")

by_dir.keys.sort.each do |dir|
  names = by_dir[dir]
  lookup = names.to_set rescue names.each_with_object({}) { |n, h| h[n] = true }
  names.sort.each do |name|
    m = name.match(/\A(.+) (\d+)\.mp3\z/)
    next unless m
    base = "#{m[1]}.mp3"
    next unless lookup.include?(base)

    base_path = File.join(dir, base)
    n_path    = File.join(dir, name)
    base_size = File.size(base_path)
    n_size    = File.size(n_path)
    delta     = base_size.zero? ? 0.0 : ((n_size - base_size).abs.to_f / base_size * 100)

    puts [base_size, n_size, format("%.2f", delta), n_path].join("\t")
  end
end
