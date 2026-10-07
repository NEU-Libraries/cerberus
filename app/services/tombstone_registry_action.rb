# frozen_string_literal: true

# The two ways out of a withdrawal — restore and permanent deletion — for one
# item, shared by the registry's row buttons and TombstoneBulkJob. See
# docs/admin.md.
module TombstoneRegistryAction
  # Atlas answers a lock conflict with a 409, and nothing has changed when it
  # does, so the call is simply made again.
  LOCK_ATTEMPTS = 3

  module_function

  # @return [:ok, :tombstoned_parent, :failed] :tombstoned_parent when the
  #   item's parent is still tombstoned and has to be restored first.
  def restore(noid)
    response = with_lock_retry { AtlasRb::Admin::Resource.restore(noid) }
    return :ok if success?(response)

    error_code(response) == 'tombstoned_parent' ? :tombstoned_parent : :failed
  rescue Faraday::Error => e
    Rails.logger.error("TombstoneRegistryAction.restore #{noid}: #{e.class} #{e.message}")
    :failed
  end

  # @return [:ok, :has_children, :failed] :has_children when a container still
  #   holds members, tombstoned ones included.
  def purge(noid)
    response = with_lock_retry { AtlasRb::Admin::Resource.destroy(noid, confirm: :i_understand) }
    return :ok if success?(response)

    error_code(response) == 'has_children' ? :has_children : :failed
  rescue Faraday::Error => e
    Rails.logger.error("TombstoneRegistryAction.purge #{noid}: #{e.class} #{e.message}")
    :failed
  end

  def with_lock_retry
    response = nil
    LOCK_ATTEMPTS.times do
      response = yield
      break unless response.respond_to?(:status) && response.status == 409
    end
    response
  end

  # Neither call is one of atlas_rb's typed-error paths, so a refusal comes back
  # as a plain Faraday::Response instead of raising. Without the success? check
  # a refused call reports as done.
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
