# frozen_string_literal: true

module Admin
  # One request on the ledger: read it, claim it, resolve it.
  #
  # The remedy is deliberately absent. Withdrawing a Work is the show-page
  # tombstone, moving one is the re-parent finder, restricting a container is
  # its own edit page — each already exists and is gated where it lives. Staff
  # go there, come back, and mark the request resolved, so this surface never
  # becomes a second place to perform a repository write.
  #
  # A restrict can only be fulfilled by :admin, because only :admin may run a
  # visibility cascade. The devolved-admin tier sees such a row and is told an
  # administrator has to act — the gate is enforced here, not only in the view.
  class StaffRequestsController < BaseController
    skip_before_action :require_admin
    before_action :require_admin_or_delegate
    before_action :set_request
    before_action :require_fulfiller, only: %i[claim unclaim resolve]

    breadcrumb_for 'Requests & activity', :admin_ledger_path

    def show
      breadcrumb request_breadcrumb, admin_staff_request_path(@request)
      NuidResolver.names_for([@request.requester_nuid, @request.claimed_by_nuid, @request.resolved_by_nuid].compact)
    end

    def claim
      @request.claim!(acting_nuid)
      redirect_to admin_staff_request_path(@request), notice: 'Claimed.'
    end

    def unclaim
      @request.unclaim!
      redirect_to admin_staff_request_path(@request), notice: 'Returned to the queue.'
    end

    def resolve
      resolution = params[:resolution].to_s
      return redirect_with_problem unless StaffRequest::RESOLUTIONS.include?(resolution)

      note = params[:resolution_note].to_s.strip
      @request.resolve!(nuid: acting_nuid, resolution: resolution, note: note)
      notify_requester(resolution, note)
      redirect_to admin_ledger_path, notice: 'Resolved.'
    end

    private

      def set_request
        @request = StaffRequest.find_by(id: params[:id])
        render template: 'errors/not_found', status: :not_found, layout: 'application' if @request.nil?
      end

      # An admin-only kind stays readable to the delegate tier — seeing the
      # queue is the point — but its actions are refused.
      def require_fulfiller
        return unless @request&.admin_only?
        return if current_user&.admin?

        render template: 'errors/forbidden', status: :forbidden, layout: 'application'
      end

      def redirect_with_problem
        redirect_to admin_staff_request_path(@request), alert: 'Choose whether the request was done or declined.'
      end

      def acting_nuid
        current_user&.nuid
      end

      # The reply the requester was promised when they asked. This is what the
      # inbox is good at — one person, one outcome, dismissable — and it is why
      # moving the request itself off the inbox costs the depositor nothing.
      def notify_requester(resolution, note)
        SystemMessage.deliver(
          to_nuid: @request.requester_nuid,
          subject: %(Your request to #{@request.kind} “#{@request.subject_title}” was #{resolution}),
          body:    [resolution_sentence(resolution), note.presence].compact.join("\n\n")
        )
      end

      def resolution_sentence(resolution)
        return 'DRS staff have carried out your request.' if resolution == 'done'

        'DRS staff did not carry out your request.'
      end

      def request_breadcrumb
        "#{@request.kind.capitalize} — #{@request.subject_title.presence || @request.subject_noid}"
      end
  end
end
