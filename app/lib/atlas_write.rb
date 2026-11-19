# frozen_string_literal: true

# The two things an Atlas write needs that the caller should not have to think
# about: surviving a lost optimistic-lock race, and handing raw MODS over as a
# file path rather than a string. Shared by the controller concerns and by the
# services that write MODS, so neither carries its own copy.
# See docs/deposit.md.
module AtlasWrite
  # Atlas answers a lost optimistic-lock race with AtlasRb::StaleResourceError
  # (HTTP 409). It never retries a permissions or metadata update itself, and a
  # deposit's jobs are still writing the same Work while its form is saved. Re-run
  # the block so each attempt re-reads the current state, backing off briefly;
  # jobs get the same from retry_on.
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
  # The read sits INSIDE with_stale_retry deliberately: a retry has to merge into
  # the MODS as stored now, not a memo from the first attempt.
  #
  # The unchanged? guard is what keeps a no-op submit from minting an OCFL MODS
  # version and an audit row. Do not hoist it: `update` writes unconditionally.
  #
  # Type-agnostic, so anything may call it — a controller, or a service with no
  # resource declaration at all. Atlas reads and writes MODS on
  # /resources/:id/mods whatever the resource turns out to be.
  def merge_mods!(id, origin:, **fields)
    with_stale_retry do
      xml = AtlasRb::Resource.mods(id, 'xml')
      merged = Metadata::MODSMerge.call(xml: xml, **fields)
      break if Metadata::MODSMerge.unchanged?(xml, merged)

      with_tmp_xml(merged) { |path| AtlasRb::Resource.put_mods(id, path, origin: origin) }
    end
  end

  def with_tmp_xml(xml)
    Tempfile.create(['mods', '.xml']) do |file|
      file.write(xml)
      file.close
      yield file.path
    end
  end
end
