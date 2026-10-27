# frozen_string_literal: true

# The body of the Work edit page's Health tab, loaded into its lazy Turbo Frame.
# See docs/work-health.md.
class WorkHealthController < ApplicationController
  before_action :authenticate_user!
  before_action { authorize! :read, :work_health }

  # Atlas is called as the real operator, not the view-as target: the target may
  # sit below the tier Atlas allows, and Atlas would refuse.
  def show
    @work_id = params[:id]
    @check = WorkHealthCheck.call(@work_id, nuid: current_user.nuid)
  end
end
