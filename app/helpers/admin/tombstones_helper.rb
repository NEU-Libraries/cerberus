# frozen_string_literal: true

module Admin
  # View helpers for the tombstone registry.
  module TombstonesHelper
    # The types Atlas refuses to purge while they still hold a member.
    CONTAINER_TYPES = %w[Collection Community].freeze

    PURGE_CONSEQUENCE = 'This removes the item and every preserved copy of its files, earlier ' \
                        'versions included. It cannot be undone; only the audit record of the ' \
                        'deletion survives.'

    PURGE_CONTAINER_CAVEAT = 'Atlas refuses this while the container still holds a member, and ' \
                             'tombstoned members count.'

    # The confirmation an admin reads before a purge. The shared turbo-confirm
    # modal splits on a blank line and renders the first block as the prompt and
    # the rest as muted detail, so the consequence sits under the question
    # instead of crowding it.
    #
    # The container caveat is not decoration. Atlas counts tombstoned members
    # when it refuses a container purge, where the tombstone refusal counts only
    # live ones — so a Collection whose children are all withdrawn looks empty to
    # the admin and is not. Saying it up front saves a round trip through a flash.
    def tombstone_purge_confirm(doc)
      blocks = ["Permanently delete “#{finder_doc_title(doc)}”?", PURGE_CONSEQUENCE]
      blocks << PURGE_CONTAINER_CAVEAT if CONTAINER_TYPES.include?(doc.klass_type.to_s)
      blocks.join("\n\n")
    end
  end
end
