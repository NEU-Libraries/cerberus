# frozen_string_literal: true

# The files behind the resumable-upload endpoint (TusUploadsController). Each
# upload is a data file that grows chunk by chunk, beside a JSON record of its
# declared length, its filename and the user who started it. The data file's
# size is the upload's offset, so a chunk that half-lands still leaves the two
# in agreement. See docs/uploads.md.
class TusStore
  ID_FORMAT = /\A\h{32}\z/
  # An upload untouched for this long is abandoned, and TusSweepJob removes it.
  EXPIRY = 24.hours

  class OffsetMismatch < StandardError; end

  # A finished upload, handed to the action that consumes it. It answers the
  # parts of ActionDispatch::Http::UploadedFile that the staging code reads, so
  # a controller can take either without branching.
  class Upload
    attr_reader :original_filename, :content_type, :path

    def initialize(record)
      @record            = record
      @original_filename = record.filename
      @content_type      = record.filetype
      @path              = record.data_path
    end

    def tempfile = self

    def size = File.size(path)

    # A rename, not a copy: the upload already sits on the staging volume, and
    # copying a multi-gigabyte file a second time is what TUS is here to avoid.
    def move_to(dest)
      FileUtils.mv(path, dest)
      @record.destroy
      dest
    end
  end

  class Record
    attr_reader :id, :length, :filename, :filetype, :owner_id

    def initialize(id:, length:, filename:, filetype:, owner_id:)
      @id       = id
      @length   = length
      @filename = filename
      @filetype = filetype
      @owner_id = owner_id
    end

    def data_path = File.join(TusStore.root, id)
    def info_path = "#{data_path}.json"

    def offset = File.size?(data_path).to_i

    def complete? = offset == length

    # Appends at most the bytes still owed, so a client that sends past the
    # declared length cannot grow the file beyond it. The lock keeps two
    # concurrent chunks for one upload from interleaving.
    #
    # @return [Integer] the new offset.
    def append(io, offset:)
      File.open(data_path, 'ab') do |file|
        file.flock(File::LOCK_EX)
        raise OffsetMismatch unless file.size == offset

        IO.copy_stream(io, file, length - offset)
        file.flush
        file.size
      end
    end

    def destroy
      FileUtils.rm_f([data_path, info_path])
    end

    def to_h = { length: length, filename: filename, filetype: filetype, owner_id: owner_id }
  end

  class << self
    def root = File.join(Rails.application.config.x.cerberus.uploads_root, 'tus')

    def create(length:, filename:, filetype:, owner_id:)
      record = Record.new(id: SecureRandom.hex(16), length: length, filename: safe_filename(filename),
                          filetype: filetype.to_s, owner_id: owner_id)
      Outage.guard_storage do
        FileUtils.mkdir_p(root)
        FileUtils.touch(record.data_path)
        File.write(record.info_path, JSON.generate(record.to_h))
      end
      record
    end

    # Nil for an id that is malformed, unknown or another user's: the endpoint
    # answers all three with the same 404, so an id cannot be probed.
    def find(id, owner_id:)
      return nil unless ID_FORMAT.match?(id.to_s)

      info = JSON.parse(File.read(File.join(root, "#{id}.json")))
      return nil unless info['owner_id'] == owner_id

      Record.new(id: id, length: info['length'], filename: info['filename'],
                 filetype: info['filetype'], owner_id: owner_id)
    rescue Errno::ENOENT, JSON::ParserError
      nil
    end

    # The finished upload a form names by id, or nil when there is none to take.
    def claim(id, owner_id:)
      return nil if id.blank? || owner_id.blank?

      record = find(id, owner_id: owner_id)
      Upload.new(record) if record&.complete?
    end

    # Activity is the data file's mtime, which every chunk moves forward, so a
    # slow upload that is still arriving is never swept from under itself.
    def sweep(before: EXPIRY.ago)
      Dir.glob(File.join(root, '*.json')).count do |info_path|
        data_path = info_path.delete_suffix('.json')
        touched = [File.mtime(info_path), File.exist?(data_path) ? File.mtime(data_path) : Time.zone.at(0)].max
        next false if touched >= before

        FileUtils.rm_f([data_path, info_path])
        true
      end
    end

    # `Upload-Metadata` is comma-separated `key base64value` pairs, the value
    # optional. Nil for a malformed header, which the endpoint answers with 400.
    def parse_metadata(header)
      header.to_s.split(',').each_with_object({}) do |pair, metadata|
        key, value = pair.strip.split(' ', 2)
        metadata[key] = value ? Base64.strict_decode64(value).force_encoding(Encoding::UTF_8) : ''
        return nil unless metadata[key].valid_encoding?
      end
    rescue ArgumentError
      nil
    end

    # The basename only, as Rack does for a multipart filename: it becomes a
    # path under the staging root, so a client-sent `../` must not climb out.
    def safe_filename(name)
      base = File.basename(name.to_s.tr('\\', '/')).delete("\u0000").strip
      %w[. ..].include?(base) ? '' : base
    end
  end
end
