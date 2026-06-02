# frozen_string_literal: true

module Admin
  # Linked members surface. Entry point for surfacing a single Work in
  # additional Collections without duplicating it (the leaves-only DAG
  # overlay). The Atlas linked-member endpoints + atlas_rb bindings
  # already exist (v1.2.0); the add/remove/provenance UI lands here in
  # follow-up work.
  class LinkedMembersController < BaseController
    def index; end
  end
end
