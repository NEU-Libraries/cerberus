# frozen_string_literal: true

require 'zip'

module XmlLoader
  # Reads a loader archive (.zip / .tar).
  #
  # `read` pulls a single small entry (the manifest, one MODS XML) fully into
  # memory — fine for KB-scale text and what the preview pass needs. `extract_all`
  # streams every file entry to disk chunk-by-chunk (Zip::Entry#extract /
  # IO.copy_stream), so large content files in create-mode never land in a Ruby
  # string — the batch-job memory budget rule. Entries are flattened to their
  # basename and macOS resource-fork cruft (__MACOSX/, ._*) is skipped, matching
  # UnzipJob's discipline.
  class Archive
    def initialize(path)
      @path = path
    end

    def zip?
      @path.end_with?('.zip')
    end

    # Bytes of the first entry whose basename matches (case-insensitively),
    # or nil if absent.
    def read(basename)
      target = basename.downcase
      zip? ? read_zip(target) : read_tar(target)
    end

    # Streams every relevant file entry into dest_dir, yielding each basename
    # written. Duplicate basenames after the first are skipped.
    def extract_all(dest_dir, &)
      zip? ? extract_zip(dest_dir, &) : extract_tar(dest_dir, &)
    end

    private

      def read_zip(target)
        Zip::File.open(@path) do |zip|
          entry = zip.find { |e| match?(e.name, target) }
          return entry&.get_input_stream&.read
        end
      end

      def read_tar(target)
        File.open(@path, 'rb') do |file|
          Gem::Package::TarReader.new(file) do |tar|
            tar.each { |e| return e.read if e.file? && match?(e.full_name, target) }
          end
        end
        nil
      end

      def extract_zip(dest_dir)
        seen = Set.new
        Zip::File.open(@path) do |zip|
          zip.each do |entry|
            base = File.basename(entry.name)
            next unless relevant?(entry.name) && seen.add?(base)

            dest = File.join(dest_dir, base)
            entry.extract(dest) unless File.exist?(dest)
            yield(base) if block_given?
          end
        end
      end

      def extract_tar(dest_dir)
        seen = Set.new
        File.open(@path, 'rb') do |file|
          Gem::Package::TarReader.new(file) do |tar|
            tar.each do |entry|
              next unless entry.file?

              base = File.basename(entry.full_name)
              next unless relevant?(entry.full_name) && seen.add?(base)

              dest = File.join(dest_dir, base)
              File.open(dest, 'wb') { |out| IO.copy_stream(entry, out) } unless File.exist?(dest)
              yield(base) if block_given?
            end
          end
        end
      end

      def match?(name, target)
        relevant?(name) && File.basename(name).downcase == target
      end

      def relevant?(name)
        !name.start_with?('__MACOSX/') && !File.basename(name).start_with?('._')
      end
  end
end
