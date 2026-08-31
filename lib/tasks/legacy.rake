# frozen_string_literal: true

# Loads the v1 pid → v2 NOID mapping that LegacyController serves redirects
# from, and that the impressions historical import joins ten years of v1 rows
# through.
#
# The mapping is produced by the v1→v2 migration, which runs outside this app.
# This task is the contract between the two: hand it a CSV of
# `pid,noid,object_type` and the table is populated. That keeps the runtime app
# read-only — nothing in a request path writes here — while giving the migration
# an obvious shape to emit and this app a way to be exercised end to end before
# the migration exists.
#
# Idempotent on pid, so a corrected export can be re-run over an earlier one.
namespace :legacy do
  desc 'Load the v1 pid → v2 NOID map from CSV. Usage: rake legacy:load[path/to/map.csv]'
  task :load, [:path] => :environment do |_task, args|
    require 'csv'

    path = args[:path].presence || abort('Usage: rake legacy:load[path/to/map.csv]')
    abort("No such file: #{path}") unless File.exist?(path)

    written = 0
    skipped = []

    CSV.foreach(path, headers: true).with_index(2) do |row, line|
      record = LegacyIdentifier.find_or_initialize_by(pid: row['pid'].to_s.strip)
      record.noid = row['noid'].to_s.strip
      record.object_type = row['object_type'].to_s.strip

      if record.save
        written += 1
      else
        # Named rather than counted, and the load continues. A partial map still
        # redirects most links, and a run that aborted on row 900,000 of a
        # million would leave the table in a state nobody could reason about.
        skipped << "line #{line} (#{record.pid.presence || 'blank pid'}): " \
                   "#{record.errors.full_messages.join(', ')}"
      end
    end

    puts "Wrote #{written} mapping#{'s' unless written == 1}."
    return if skipped.empty?

    puts "Skipped #{skipped.size}:"
    skipped.first(20).each { |line| puts "  #{line}" }
    puts "  … and #{skipped.size - 20} more." if skipped.size > 20
  end

  desc 'Report what the v1 pid → v2 NOID map currently holds.'
  task stats: :environment do
    total = LegacyIdentifier.count
    puts "#{total} mapping#{'s' unless total == 1}."
    LegacyIdentifier.group(:object_type).count.sort.each do |type, count|
      puts format('  %<type>-11s %<count>d', type: type, count: count)
    end
  end
end
