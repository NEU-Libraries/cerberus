# frozen_string_literal: true

# Serializes rspec runs against the one shared resource a run destroys on
# startup: the atlas-test instance. rails_helper's `before(:suite)` calls
# AtlasRb::Reset.clean, and Atlas's `GET /reset` wipes its database, deletes the
# blacklight-test Solr core by query, and purges the OCFL storage root.
#
# So two overlapping runs corrupt each other: the second one's reset deletes
# records the first is mid-example on. The damage lands in whatever file happened
# to be executing, as a cluster of failures that pass when that file is re-run
# alone — which reads like a bug in that file rather than a collision, and costs
# a long time to attribute. Failing fast is much cheaper than debugging it.
#
# flock is used rather than a pidfile because the kernel releases it when the
# process dies, so a killed run leaves nothing stale to clear by hand.
module ExclusiveRunLock
  # Deliberately outside the checkout: worktrees each have their own tmp/, but
  # they all reach the same atlas-test service, and the service is what needs
  # serializing. Overridable so a genuinely separate Atlas (a second container,
  # CI with one instance per job) can run concurrently without a false conflict.
  #
  # One lock per worker, because the thing being serialized is the Atlas
  # instance and each worker owns its own. A single shared path would make the
  # workers refuse each other, which is the opposite of the point — while still
  # leaving two concurrent *suites* correctly blocked, since worker N of one run
  # and worker N of the other contend for the same file.
  PATH = ENV.fetch('CERBERUS_RSPEC_LOCK_PATH') do
    worker = ENV['TEST_ENV_NUMBER'].to_s
    suffix = worker.empty? ? '' : "-#{worker}"
    "/tmp/cerberus-rspec-run#{suffix}.lock"
  end

  class << self
    # Take the lock for the lifetime of the process, or abort. Matches
    # rails_helper's existing `abort` on a pending migration: a precondition the
    # run cannot proceed without, reported as a plain message rather than a
    # backtrace through RSpec's hook machinery.
    def acquire!
      # Style/FileOpen wants the block form, but the descriptor staying open IS
      # the lock: flock is released the moment the file object closes, so a block
      # would drop the lock before the first example ran.
      handle = File.open(PATH, File::RDWR | File::CREAT, 0o644) # rubocop:disable Style/FileOpen
      abort(conflict_message) unless handle.flock(File::LOCK_EX | File::LOCK_NB)

      # Retained on the module for the same reason: a local would be eligible for
      # garbage collection mid-run, silently dropping the lock partway through.
      @handle = handle
    end

    private

      def conflict_message
        <<~MSG
          Another rspec run already holds #{PATH}.

          A run resets the shared atlas-test instance at startup (database, the
          blacklight-test Solr core, and OCFL storage), so two overlapping runs
          delete each other's fixtures and fail in unrelated-looking places.

          Wait for the other run to finish. If this run targets a different
          Atlas, point CERBERUS_RSPEC_LOCK_PATH at its own lock file.
        MSG
      end
  end
end
