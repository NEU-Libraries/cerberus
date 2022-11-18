# frozen_string_literal: true

# Generated with `rails generate valkyrie:model FileSet`
require 'rails_helper'
require 'valkyrie/specs/shared_specs'

RSpec.describe Work do
  let(:resource_klass) { described_class }
  let(:work) { FactoryBot.create_for_repository(:work) }
  it_behaves_like 'a Valkyrie::Resource'

  it 'has default XML' do
    expect(work.mods_xml).not_to be(nil)
  end
end
