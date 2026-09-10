# frozen_string_literal: true

# The two things an Atlas write needs that the caller should not have to think
# about: surviving a lost optimistic-lock race, and handing raw MODS over as a
# file path rather than a string. Shared by the controller concerns and by the
# services that write MODS, so neither carries its own copy.
module AtlasWrite
  # Atlas enforces optimistic locking server-side and raises
  # AtlasRb::StaleResourceError (HTTP 409) only once its own retry budget is
  # exhausted. During a deposit the async ingest/derivative jobs are still
  # finalizing the Work (Work.complete, Delegate PATCHes), so an interactive
  # metadata/permissions save can lose the race. Re-run the block so each attempt
  # re-reads the current state and token, backing off briefly between tries.
  # atlas_rb blesses this pattern via retry_on for jobs; the interactive path
  # needs its own bounded loop.
  def with_stale_retry(attempts: 5)
    tries = 0
    begin
      yield
    rescue AtlasRb::StaleResourceError
      tries += 1
      raise if tries >= attempts

      sleep(0.2 * tries)
      retry
    end
  end

  def write_tmp_xml(xml)
    path = Rails.root.join('tmp', "#{SecureRandom.uuid}.xml").to_s
    File.write(path, xml)
    path
  end
end
