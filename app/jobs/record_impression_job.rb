# frozen_string_literal: true

# Insert a usage impression off the request thread (Solid Queue, :background
# lane so analytics writes never compete with deposit/derivative work). The
# throttle's DB read happens here, not on the request. Current.nuid
# auto-propagates from the enqueuing request via ApplicationJob.
class RecordImpressionJob < ApplicationJob
  queue_as :background

  def perform(action:, noid: nil, blob_id: nil, request_meta: {})
    # Download path: resolve the containing Work from the blob alone.
    noid ||= AtlasRb::Blob.work(blob_id) if blob_id.present?
    return if noid.blank? # orphan / unresolvable blob — nothing to attribute

    meta = request_meta.symbolize_keys
    UserAgent.record(meta[:user_agent])

    # create (not create!): a throttle rejection is the expected, benign no-op.
    Impression.create(
      noid: noid, action: action,
      session_id: meta[:session_id], ip_address: meta[:ip_address],
      referrer: meta[:referrer], user_agent: meta[:user_agent]
    )
  end
end
