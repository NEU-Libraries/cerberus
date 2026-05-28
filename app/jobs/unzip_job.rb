# frozen_string_literal: true

require 'zip'

# Opens the staged archive (zip or tar) for a LoadReport, walks the
# entries in a single forward pass, and for each JPEG: creates one
# IptcIngest row + extracts the entry to disk + enqueues one
# IptcIngestJob.
#
# Strictly streaming — entry data is copied chunk-by-chunk to disk
# via Zip::Entry#extract or IO.copy_stream (tar). The whole-entry
# read APIs (entry.get_input_stream.read for zip, entry.read for tar)
# are NEVER used here; they slurp the JPEG into a Ruby string and
# the worker takes the high-water-mark hit for the rest of its life.
class UnzipJob < ApplicationJob
  queue_as :default

  JPEG_EXT = %w[.jpg .jpeg .JPG .JPEG].freeze

  # rubocop:disable Metrics/MethodLength
  # Linear shape mirrors the audit-trail it produces (start → extract →
  # enqueue → rescue) so splitting it isn't a readability win.
  def perform(load_report_id)
    load_report = LoadReport.find(load_report_id)
    return unless load_report.pending?

    load_report.start_load

    extracted_dir = extracted_dir_for(load_report)
    FileUtils.mkdir_p(extracted_dir)

    archive_path = archive_path_for(load_report)
    extract_each(archive_path, extracted_dir) do |basename|
      ingest = load_report.iptc_ingests.create!(
        source_filename: basename,
        idempotency_key: SecureRandom.uuid
      )
      IptcIngestJob.perform_later(ingest.id)
    end
  rescue StandardError => e
    Rails.logger.error("UnzipJob failed for LoadReport #{load_report_id}: #{e.class} #{e.message}")
    LoadReport.find_by(id: load_report_id)&.fail_load
  end
  # rubocop:enable Metrics/MethodLength

  private

    def extract_each(archive_path, dest_dir, &block)
      if archive_path.end_with?('.zip')
        extract_zip(archive_path, dest_dir, &block)
      else
        extract_tar(archive_path, dest_dir, &block)
      end
    end

    def extract_zip(path, dest_dir)
      seen = Set.new
      Zip::File.open(path) do |zip|
        zip.each do |entry|
          basename = File.basename(entry.name)
          next unless relevant_jpeg?(entry.name) && seen.add?(basename)

          dest = File.join(dest_dir, basename)
          # Streaming extract. Never entry.get_input_stream.read.
          entry.extract(dest) unless File.exist?(dest)
          yield(basename)
        end
      end
    end

    def extract_tar(path, dest_dir)
      seen = Set.new
      File.open(path, 'rb') do |file|
        Gem::Package::TarReader.new(file) do |tar|
          tar.each do |entry|
            next unless entry.file?

            basename = File.basename(entry.full_name)
            next unless relevant_jpeg?(entry.full_name) && seen.add?(basename)

            dest = File.join(dest_dir, basename)
            # Streaming copy. Never entry.read with no argument.
            File.open(dest, 'wb') { |out| IO.copy_stream(entry, out) } unless File.exist?(dest)
            yield(basename)
          end
        end
      end
    end

    def relevant_jpeg?(name)
      return false if name.start_with?('__MACOSX/') || File.basename(name).start_with?('._')

      JPEG_EXT.include?(File.extname(name))
    end

    def archive_path_for(load_report)
      File.join(uploads_root, 'load_reports', load_report.id.to_s, load_report.source_filename)
    end

    def extracted_dir_for(load_report)
      File.join(uploads_root, 'load_reports', load_report.id.to_s, 'extracted')
    end

    def uploads_root
      Rails.application.config.x.cerberus.uploads_root
    end
end
