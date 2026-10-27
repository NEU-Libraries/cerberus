# frozen_string_literal: true

require 'rails_helper'

# The Sentinel forms show the group editor only under "replace", and the tier
# ladder only under "set". The reveal is browser-only, and the Collection tab
# holds a second radio group above the one that drives it, so a request spec
# cannot see whether the right choice opens the right section.
RSpec.describe 'Sentinel form sections', :browser, type: :system do
  before(:all) do
    Current.nuid = admin_nuid
    @collection = create_collection(create_community(public: true).id, public: true)
    @set = AtlasRb::Compilation.create('Reveal spec set', nuid: admin_nuid)
  end

  before { sign_in_as(admin_nuid) }

  it 'opens the group editor for loaded works when replacing, past the visibility choice above it' do
    visit "#{edit_collection_path(@collection.id)}#derivative-access"
    editor = find('[data-reveal-target="section"]', visible: :all)
    expect(editor).not_to be_visible

    find('#loaded-grants-replace').choose
    expect(editor).to be_visible

    find('#loaded-grants-keep').choose
    expect(editor).not_to be_visible
  end

  it 'opens each part of a set Sentinel on its own choice' do
    visit edit_set_path(@set['id'], tab: 'sentinel')
    groups, ladder = all('#sentinel [data-reveal-target="section"]', visible: :all).to_a
    expect([groups, ladder]).to all(satisfy { |section| !section.visible? })

    find('#work-grants-replace').choose
    expect(groups).to be_visible
    expect(ladder).not_to be_visible

    find('#derivatives-set').choose
    expect(ladder).to be_visible
  end
end
