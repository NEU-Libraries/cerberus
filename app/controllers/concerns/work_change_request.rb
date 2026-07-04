# frozen_string_literal: true

# The editor-facing "Request withdraw / move" action on the Work edit page.
#
# Cerberus has no request/approval model: a request is a user-sent Message to
# the DRS staff group inbox (read-time group delivery, see Message.inbox_for),
# which staff fulfill with the existing tools — the show-page tombstone, or the
# admin re-parent finder. Mixed into WorksController, where request_change is an
# edit-gated action (see authorize_resource_writes!).
module WorkChangeRequest
  extend ActiveSupport::Concern

  # The actions an editor may *request* (not perform) on their own work.
  REQUEST_ACTIONS = %w[withdraw move].freeze

  def request_change
    action = params[:request_action].to_s
    note   = params[:request_note].to_s.strip

    if (problem = change_request_problem(action, note))
      return redirect_to(edit_work_path(params[:id]), alert: problem)
    end

    deliver_change_request(action, note)
    redirect_to work_path(params[:id]),
                notice: 'Your request has been sent to the DRS staff — they will follow up in your inbox.'
  end

  private

    # nil when the request is well-formed, else the user-facing reason it isn't.
    def change_request_problem(action, note)
      return 'Choose whether to request a withdrawal or a move.' unless REQUEST_ACTIONS.include?(action)

      'Tell the staff where this work should move to.' if action == 'move' && note.blank?
    end

    # Compose the staff-group inbox message. A user-sent message (sender = the
    # requester, attribution-aware like the deposit / set-sharing paths), so
    # staff see who asked and can reply.
    def deliver_change_request(action, note)
      work = AtlasRb::Work.find(params[:id])
      requester = current_user.try(:name).presence || current_user&.nuid
      verb = action == 'withdraw' ? 'withdrawn' : 'moved'
      lines = ["#{requester} has requested that this work be #{verb}.",
               '', %(Work: “#{work.title}”), work_url(params[:id])]
      lines += ['', "#{action == 'move' ? 'Requested destination' : 'Note'}: #{note}"] if note.present?

      Message.create(
        sender_nuid:     attributed_nuid,
        recipient_group: Permissions::STAFF_EDIT_GROUP,
        subject:         %(Request to #{action} “#{work.title}”),
        body:            lines.join("\n")
      )
    end
end
