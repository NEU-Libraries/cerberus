# frozen_string_literal: true

# The editor-facing "Request withdraw / move" action on the Work edit page.
#
# Cerberus has no approval model: a request is a StaffRequest row on the admin
# ledger, which staff fulfill with the tools that already exist — the show-page
# tombstone, or the admin re-parent finder — and then resolve. Mixed into
# WorksController, where request_change is an edit-gated action (see
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
                notice: 'Your request has been sent to the DRS staff — they will follow up in your inbox.'
  end

  private

    # nil when the request is well-formed, else the user-facing reason it isn't.
    def change_request_problem(action, note)
      return 'Choose whether to request a withdrawal or a move.' unless REQUEST_ACTIONS.include?(action)

      'Tell the staff where this work should move to.' if action == 'move' && note.blank?
    end

    # The requester is attribution-aware (attributed_nuid), like the deposit and
    # set-sharing paths, so an impersonated request names the person acted for.
    # The title is snapshotted because the queue lists many rows at once and
    # must not cost one Atlas call each; the row links by noid, so a later
    # rename leaves the link correct.
    def deliver_change_request(action, note)
      work = AtlasRb::Work.find(params[:id])
      StaffRequest.create!(
        kind:           action,
        subject_type:   'Work',
        subject_noid:   params[:id],
        subject_title:  work.title,
        requester_nuid: attributed_nuid,
        note:           note
      )
    end
end
