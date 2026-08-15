# frozen_string_literal: true

# The Streaming Only toggle: whether the page offers it, what it currently says,
# and how a submit persists it. Read and write sit together because they share
# one subtlety — the tier's audience is computed from the Work's read ACL, so
# each has to run on a different side of the metadata save.
module WorkStreamingOnly
  extend ActiveSupport::Concern

  private

    # State for the Streaming Only toggle. `offered` differs by page because the
    # evidence does — see the two call sites. The audience is computed from
    # @read_groups rather than @permissions: form_preparation has already
    # replaced the latter with the form's row objects by the time this runs.
    def load_streaming_only!(offered:)
      @streaming_only_offered = offered
      return unless offered

      @streaming_only = StreamingOnly.on?(StreamingOnly.stored_policy(params[:id]), read: @read_groups)
    end

    # Persist the toggle, if this form carried it. The Metadata and Advanced tabs
    # PATCH the same action without the field, and an absent field must mean
    # "leave it alone" rather than "turn it off" — hence the nil check, and the
    # unchecked hidden input in the partial.
    #
    # Runs AFTER handle_metadata_update, because the same submit can widen the
    # Work from private to public, and the tier audience is computed against the
    # Work's read ACL. Reading it before the save would size the tier against the
    # visibility the reader was replacing.
    def apply_streaming_only!
      requested = params.dig(:work, :streaming_only)
      return if requested.nil?

      StreamingOnly.apply!(params[:id],
                           enabled: ActiveModel::Type::Boolean.new.cast(requested).present?,
                           read:    Array(AtlasRb::Resource.permissions(params[:id])&.read))
    rescue AtlasRb::DerivativePermissionsError => e
      flash[:alert] = "Streaming Only wasn't changed — Atlas refused it: #{e.message}"
    end
end
