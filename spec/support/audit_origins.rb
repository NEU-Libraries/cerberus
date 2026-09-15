# frozen_string_literal: true

# Reads back the edit-origin tags Atlas recorded on a resource's MODS-upload
# audit events. Each Cerberus editing surface asserts its own tag on the write,
# and the tag is only worth anything once it has survived the multipart upload —
# so the specs covering those surfaces read the recorded event rather than
# asserting on the atlas_rb call.
module AuditOrigins
  # In event order, so a surface's tag can be asserted against a resource whose
  # earlier MODS writes carry no origin (a fixture created with a MODS file, or
  # any programmatic write).
  def mods_edit_origins(id, nuid: '000000004')
    events = AtlasRb::Resource.history(id, nuid: nuid)
    Array(events && events['events'])
      .select { |event| event['action'] == 'update' && event['payload'].to_h['source'] == 'mods' }
      .map { |event| event['payload'].to_h['origin'] }
  end
end

RSpec.configure do |config|
  config.include AuditOrigins
end
