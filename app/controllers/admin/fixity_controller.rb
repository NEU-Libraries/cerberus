# frozen_string_literal: true

module Admin
  # The fixity report: the Works whose stored bytes failed a check, are not
  # fully verified within a year, or were never checked. See docs/fixity.md.
  #
  # :admin only. The list reads Solr, and gated discovery would show the
  # devolved-admin tier only what its groups can see, so a short list would
  # read as a healthy repository.
  class FixityController < BaseController
    breadcrumb_for 'Fixity', :admin_fixity_path

    include Blacklight::Configurable

    copy_blacklight_config_from(CatalogController)

    TABS = {
      'failed'  => 'Failed',
      'overdue' => 'Not fully verified in 12 months',
      'never'   => 'Never verified'
    }.freeze

    def index
      @state = TABS.key?(params[:state]) ? params[:state] : 'failed'
      @response = FixityReport.call(scope: self, state: @state.to_sym, page: params[:page])
      @counts = TABS.keys.index_with { |state| state == @state ? @response.total : count_for(state) }
    end

    private

      def count_for(state)
        FixityReport.call(scope: self, state: state.to_sym, page: 1).total
      end
  end
end
