# frozen_string_literal: true

module Admin
  # Re-parent / Move surface. Entry point for moving a Collection or
  # Community to a new structural parent. The Atlas re-parent endpoints
  # + atlas_rb bindings already exist (v1.2.0); the move workflow UI
  # lands here in follow-up work.
  class ReparentController < BaseController
    def index; end
  end
end
