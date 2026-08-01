# frozen_string_literal: true

# "Ask DRS staff to restrict this" on a Collection or Community edit page.
#
# Following WorkChangeRequest's model rather than inventing approval machinery:
# a request is a Message, which the recipient fulfils with the ordinary tools.
# Kept as a sibling of that concern instead of generalising it — the two differ
# in resource, verb, recipient and remedy, so folding them together would
# parameterise more than it shares.
#
# Addressed to Permissions::ADMIN_GROUP rather than the staff group. Only the
# :admin role may run a cascade, and a staff-group editor is precisely who this
# affordance exists for, so sending it to their own inbox would be a loop.
module ContainerRestrictionRequest
  extend ActiveSupport::Concern

  # Narrowing a Community does not cascade, and the form offers it to nobody —
  # so the fulfiller needs telling how to do it, or the request is unanswerable.
  # Restricting each Collection inside cascades (and confirms) on its own, which
  # is why that is the route rather than a Community-wide sweep.
  COMMUNITY_REMEDY = 'Restricting a community does not reach what is inside it. Restrict each collection ' \
                     'within it first — each of those cascades to its own contents — then the community.'

  def request_restriction
    note = params[:request_note].to_s.strip
    return redirect_to(container_edit_path, alert: 'Say who this should still be able to see.') if note.blank?

    deliver_restriction_request(note)
    redirect_to container_show_path,
                notice: 'Your request has been sent to DRS administrators — they will follow up in your inbox.'
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

    # A user-sent message, so the recipient can see who asked and reply.
    def deliver_restriction_request(note)
      container = AtlasRb.const_get(container_klass).find(params[:id])
      requester = current_user.try(:name).presence || current_user&.nuid
      Message.create!(
        sender_nuid:     attributed_nuid,
        recipient_group: Permissions::ADMIN_GROUP,
        subject:         %(Request to restrict “#{container.title}”),
        body:            request_body(container, requester, note)
      )
    end

    def request_body(container, requester, note)
      lines = ["#{requester} has asked for this #{container_klass.downcase} to be restricted.",
               '', %(#{container_klass}: “#{container.title}”),
               public_send("#{controller_name.singularize}_url", params[:id]),
               '', "Should still be able to see it: #{note}"]
      lines += ['', COMMUNITY_REMEDY] if container_klass == 'Community'
      lines.join("\n")
    end
end
