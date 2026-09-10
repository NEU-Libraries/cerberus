# frozen_string_literal: true

module Admin
  # The human door onto the read-only maintenance window. Atlas holds the flag;
  # this is one of three things that writes it, alongside the `maintenance` rake
  # task and the deploy orchestrator.
  #
  # Full admin only — inherited from BaseController, deliberately not broadened
  # to the devolved tier. Opening a window is an operator action on the same
  # footing as a permanent delete.
  #
  # Gating the window is not a hole in "nobody writes during a window". That
  # rule is about repository objects; the flag is an operational control.
  class MaintenanceController < BaseController
    breadcrumb_for 'Maintenance', :admin_maintenance_path

    # The load-bearing line in this file. If the write gate ever covered this
    # controller, an open window could not be closed from the browser — and
    # because MaintenanceMode fails closed when Atlas cannot be read, a flaky
    # read would hold the app in maintenance mode with only shell access left.
    # Opening a window from here is convenience; closing one is the escape
    # hatch, so the exemption sits next to the code it protects rather than in
    # MaintenanceGate's allowlist.
    skip_before_action :block_writes_in_maintenance!

    def show
      @window = MaintenanceMode.window
    end

    def open_window
      @window = MaintenanceMode.open!(
        message:     params[:message].presence,
        retry_after: params[:retry_after].presence&.to_i
      )
      redirect_to admin_maintenance_path, notice: 'The repository is now read-only.'
    end

    def close_window
      @window = MaintenanceMode.close!
      redirect_to admin_maintenance_path, notice: 'The repository is accepting writes again.'
    end
  end
end
