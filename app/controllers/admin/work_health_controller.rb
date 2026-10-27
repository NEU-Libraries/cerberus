# frozen_string_literal: true

module Admin
  # The Work health check by NOID, for a Work too broken to open its edit page.
  # See docs/work-health.md.
  class WorkHealthController < BaseController
    skip_before_action :require_admin
    before_action :require_admin_or_delegate

    breadcrumb_for 'Work health', :admin_work_health_path

    # A NOID, not a title search: the title search reads Solr, and a Work with
    # no Solr document is one of the cases this page exists for.
    def show
      @noid = params[:noid].to_s.strip.presence
      @check = WorkHealthCheck.call(@noid, nuid: current_user.nuid) if @noid
    end
  end
end
