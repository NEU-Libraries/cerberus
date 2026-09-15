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

  # Read -> merge -> write, the spine every MODS form save shares. A nil field
  # means "leave it untouched", so a caller passes only what its own form owns
  # and one call can carry two forms' worth of fields.
  #
  # The read sits INSIDE with_stale_retry deliberately: a retry needs the
  # current MODS and its lock token, not a memo from the first attempt.
  #
  # The unchanged? guard is what keeps a no-op submit from minting an OCFL MODS
  # version and an audit row. Do not hoist it: `update` writes unconditionally.
  def merge_mods!(klass, id, origin:, **fields)
    with_stale_retry do
      xml = AtlasRb.const_get(klass).mods(id, 'xml')
      merged = Metadata::MODSMerge.call(xml: xml, **fields)
      break if Metadata::MODSMerge.unchanged?(xml, merged)

      AtlasRb.const_get(klass).update(id, write_tmp_xml(merged), origin: origin)
    end
  end

  def write_tmp_xml(xml)
    path = Rails.root.join('tmp', "#{SecureRandom.uuid}.xml").to_s
    File.write(path, xml)
    path
  end
end
