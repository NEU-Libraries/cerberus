# frozen_string_literal: true

# The two ways out of a tombstone — restore and permanent deletion — for one
# item, shared by the registry's row buttons and TombstoneBulkJob. See
# docs/admin.md.
module TombstoneRegistryAction
  extend AtlasWrite

  # Atlas does not retry a restore or a destroy, so a lock conflict raises
  # AtlasRb::StaleResourceError. Nothing has changed when it does, so the call
  # is simply made again.
  LOCK_ATTEMPTS = 3

  module_function

  # @return [:ok, :tombstoned_parent, :failed] :tombstoned_parent when the
  #   item's parent is still tombstoned and has to be restored first.
  def restore(noid)
    response = with_stale_retry(attempts: LOCK_ATTEMPTS) { AtlasRb::Admin::Resource.restore(noid) }
    return :ok if success?(response)

    error_code(response) == 'tombstoned_parent' ? :tombstoned_parent : :failed
  rescue AtlasRb::StaleResourceError, Faraday::Error => e
    Rails.logger.error("TombstoneRegistryAction.restore #{noid}: #{e.class} #{e.message}")
    :failed
  end

  # @return [:ok, :has_children, :failed] :has_children when a container still
  #   holds members, tombstoned ones included.
  def purge(noid)
    response = with_stale_retry(attempts: LOCK_ATTEMPTS) do
      AtlasRb::Admin::Resource.destroy(noid, confirm: :i_understand)
    end
    return :ok if success?(response)

    error_code(response) == 'has_children' ? :has_children : :failed
  rescue AtlasRb::StaleResourceError, Faraday::Error => e
    Rails.logger.error("TombstoneRegistryAction.purge #{noid}: #{e.class} #{e.message}")
    :failed
  end

  # A refusal such as a 422 or 403 is not one of atlas_rb's typed-error paths,
  # so it comes back as a plain Faraday::Response instead of raising. Without
  # the success? check a refused call reports as done.
  def success?(response)
    !response.respond_to?(:success?) || response.success?
  end

  # Atlas's refusal envelope carries the machine token on `code`.
  def error_code(response)
    body = JSON.parse(response.body.to_s)
    body['code'] if body.is_a?(Hash)
  rescue JSON::ParserError
    nil
  end
end
