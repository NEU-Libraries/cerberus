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

  def request_restriction
    note = params[:request_note].to_s.strip
    return redirect_to(container_edit_path, alert: 'Say who this should still be able to see.') if note.blank?

    deliver_restriction_request(note)
    redirect_to container_show_path,
                notice: 'Your request has been sent to DRS administrators — they will be in touch.'
  end

  private

    # 'Collection' / 'Community', from whichever controller mixed this in.
    def container_klass
      controller_name.classify
    end

    def container_edit_path
      public_send("edit_#{controller_name.singularize}_path", params[:id])
    end

    def container_show_path
      public_send("#{controller_name.singularize}_path", params[:id])
    end

    # The requester is attribution-aware (attributed_nuid), so an impersonated
    # request names the person acted for. The note carries who must still be
    # able to see the container, which is the one fact the fulfiller cannot
    # work out for themselves.
    def deliver_restriction_request(note)
      container = AtlasRb.const_get(container_klass).find(params[:id])
      AdminNotice.create!(
        kind:         'request_restrict',
        subject:      %(Request to restrict “#{container.title}”),
        actor_nuid:   attributed_nuid,
        subject_noid: params[:id],
        payload:      { subject_type: container_klass, subject_title: container.title, note: note }
      )
    end
end
