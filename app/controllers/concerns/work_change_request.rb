# frozen_string_literal: true

# The editor-facing "Request withdraw / move" action on the Work edit page.
#
# Cerberus has no approval model and no request lifecycle: a request is one
# write-once row on the admin ledger, which staff read and then fulfil with the
# tools that already exist — the show-page tombstone, or the admin re-parent
# finder. They coordinate with each other, and reply to the depositor, off-site.
# Mixed into WorksController, where request_change is an edit-gated action (see
# authorize_resource_writes!).
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
                notice: 'Your request has been sent to the DRS staff — they will be in touch.'
  end

  private

    # nil when the request is well-formed, else the user-facing reason it isn't.
    def change_request_problem(action, note)
      return 'Choose whether to request a withdrawal or a move.' unless REQUEST_ACTIONS.include?(action)

      'Tell the staff where this work should move to.' if action == 'move' && note.blank?
    end

    # The requester is attribution-aware (attributed_nuid), like the deposit and
    # set-sharing paths, so an impersonated request names the person acted for.
    # The title is snapshotted because the ledger lists many rows at once and
    # must not cost one Atlas call each; the row links by noid, so a later
    # rename leaves the link correct.
    def deliver_change_request(action, note)
      work = AtlasRb::Work.find(params[:id])
      AdminNotice.create!(
        kind:         "request_#{action}",
        subject:      %(Request to #{action} “#{work.title}”),
        actor_nuid:   attributed_nuid,
        subject_noid: params[:id],
        payload:      { subject_type: 'Work', subject_title: work.title, note: note.presence }
      )
    end
end
