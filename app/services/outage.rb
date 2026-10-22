# frozen_string_literal: true

# What a reader loses when a backing service stops answering, named the way a
# reader would name it. The service itself is named only in the log and on the
# admin health page. See docs/outages.md.
class Outage
  # Raised by Cerberus's own disk writes, so a full or missing volume reads as an
  # outage rather than as an Errno from somewhere in a controller.
  class StorageUnavailable < StandardError; end

  Capability = Data.define(:key, :title, :lede)

  CAPABILITIES = {
    repository: Capability.new(
      key:   :repository,
      title: 'The repository is temporarily unavailable.',
      lede:  'The DRS cannot open any page right now. Nothing you had saved before now has been lost. ' \
             'Please try again in a few minutes.'
    ),
    search:     Capability.new(
      key:   :search,
      title: 'Search is temporarily unavailable.',
      lede:  'The DRS cannot search or browse the repository right now. A record still opens from a direct ' \
             'link or a bookmark. Please try searching again in a few minutes.'
    ),
    records:    Capability.new(
      key:   :records,
      title: 'Records are temporarily unavailable.',
      lede:  'The DRS cannot open or save records right now. Nothing you had saved before now has been lost. ' \
             'Please try again in a few minutes.'
    ),
    uploads:    Capability.new(
      key:   :uploads,
      title: 'Uploads are temporarily unavailable.',
      lede:  'The DRS cannot store new files right now, so the file you sent was not saved. ' \
             'Please try again in a few minutes.'
    )
  }.freeze

  # A proxy in front of Atlas answers these while Atlas is down or restarting. A
  # bare 500 is left out: it is as likely to be a bug as an outage, and calling a
  # bug an outage tells the reader to wait for something that will not change.
  GATEWAY_STATUSES = [502, 503, 504].freeze

  RETRY_AFTER = 60

  # What a volume that is missing, full, read-only or failing raises. A missing
  # source file raises ENOENT too, which this reports as storage; that case
  # needs a vanished request tempfile, and the reader's answer is the same.
  STORAGE_ERRORS = [
    Errno::ENOENT, Errno::ENOTDIR, Errno::EACCES, Errno::EROFS, Errno::ENOSPC, Errno::EDQUOT, Errno::EIO
  ].freeze

  class << self
    def for(exception)
      key = capability_key(exception)
      key && CAPABILITIES.fetch(key)
    end

    def guard_storage
      yield
    rescue *STORAGE_ERRORS => e
      raise StorageUnavailable, e.message
    end

    def handled_errors
      [
        *repository_errors,
        *search_errors,
        *records_errors,
        StorageUnavailable
      ]
    end

    private

      # ConnectionNotEstablished is the connect that failed; ConnectionFailed is
      # a connection that dropped mid-query, as one does when Postgres restarts.
      def repository_errors = [ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionFailed]

      def search_errors
        [
          Blacklight::Exceptions::ECONNREFUSED, Blacklight::Exceptions::RepositoryTimeout,
          RSolr::Error::ConnectionRefused, RSolr::Error::Timeout
        ]
      end

      # The Cantaloupe clients rescue their own Faraday errors, so one that
      # escapes to a controller came from atlas_rb.
      def records_errors = [Faraday::ConnectionFailed, Faraday::TimeoutError]

      # is_a?, never case/when: SystemCallError's === matches on errno alone, so
      # `when Blacklight::Exceptions::ECONNREFUSED` would claim a refusal from
      # any socket as a search outage.
      def capability_key(exception)
        if kind?(exception, repository_errors) then :repository
        elsif kind?(exception, search_errors) then :search
        elsif kind?(exception, records_errors) then :records
        elsif exception.is_a?(AtlasRb::ResourceError) then atlas_status_key(exception)
        elsif exception.is_a?(StorageUnavailable) then :uploads
        end
      end

      def atlas_status_key(exception) = (:records if GATEWAY_STATUSES.include?(exception.status))

      def kind?(exception, classes) = classes.any? { |klass| exception.is_a?(klass) }
  end
end
