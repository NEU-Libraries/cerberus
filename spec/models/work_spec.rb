# frozen_string_literal: true

# Generated with `rails generate valkyrie:model FileSet`
require 'rails_helper'
require 'valkyrie/specs/shared_specs'

RSpec.describe Work do
  let(:resource_klass) { described_class }
  #   let(:file_set) { FactoryBot.create_for_repository(:file_set) }
  it_behaves_like 'a Valkyrie::Resource'
end
