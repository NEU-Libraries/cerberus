# frozen_string_literal: true

# "Ask DRS staff to restrict this" on a Collection or Community edit page.
#
# Following WorkChangeRequest's model rather than inventing approval machinery:
# a request is one write-once ledger row, which the fulfiller answers with the
# ordinary tools. Kept as a sibling of that concern instead of generalising it —
# the two differ in resource, verb, fulfiller and remedy, so folding them
# together would parameterise more than it shares.
#
# Only the :admin role may run a cascade, so the ledger marks this kind
# admin-only. A staff-group editor is precisely who the affordance exists for,
# which is why asking them to do it themselves would be a loop.
module ContainerRestrictionRequest
  extend ActiveSupport::Concern

  include AtlasResourceType

  def request_restriction
    note = params[:request_note].to_s.strip
    return redirect_to(edit_path(params[:id]), alert: 'Say who this should still be able to see.') if note.blank?

    deliver_restriction_request(note)
    redirect_to show_path(params[:id]),
                notice: 'Your request has been sent to DRS administrators — they will be in touch.'
  end

  private

    # The requester is attribution-aware (attributed_nuid), so an impersonated
    # request names the person acted for. The note carries who must still be
    # able to see the container, which is the one fact the fulfiller cannot
    # work out for themselves.
    def deliver_restriction_request(note)
      container = atlas_class.find(params[:id])
      AdminNotice.create!(
        kind:         'request_restrict',
        subject:      %(Request to restrict “#{container.title}”),
        actor_nuid:   attributed_nuid,
        subject_noid: params[:id],
        payload:      { subject_type: solr_type, subject_title: container.title, note: note }
      )
    end
end
