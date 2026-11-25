# frozen_string_literal: true

require 'rails_helper'

# Turbo caches a page as it leaves it, after Stimulus has disconnected its
# controllers, and Back paints that copy. Only a real Turbo visit fills the
# cache, so each example leaves through one. docs/design.md covers the rules.
RSpec.describe 'A page restored from the Turbo cache', :browser, type: :system do
  before(:all) do
    Current.nuid = AtlasFixtures::ADMIN_NUID
    @collection = create_collection(create_community(public: true).id, public: true)
    @recording = create_work(@collection.id, public: true)
    AtlasRb::Blob.create(@recording.id, Rails.root.join('spec/fixtures/files/sample-audio.mp3').to_s,
                         'sample-audio.mp3', nuid: AtlasFixtures::ADMIN_NUID)
  end

  before { sign_in_as(admin_nuid) }

  def leave_by_turbo_visit(path)
    page.execute_script('Turbo.visit(arguments[0])', path)
    expect(page).to have_current_path(path)
  end

  # dispose() deletes the <video> video.js mounted on, so the cached copy had
  # no player to mount, and the page came back with only its download line.
  it 'mounts the A/V player again' do
    visit "/works/#{@recording.id}"
    expect(page).to have_css('.av-player .vjs-control-bar', visible: :all)

    leave_by_turbo_visit("/collections/#{@collection.id}")
    page.go_back

    expect(page).to have_current_path("/works/#{@recording.id}")
    expect(page).to have_css('.av-player .vjs-control-bar', visible: :all)
    expect(page).to have_css('.av-player .video-js', count: 1, visible: :all)
  end

  # A restored menu has no Bootstrap instance, so an outside click and Esc
  # left it open.
  it 'brings the user menu back closed' do
    visit "/collections/#{@collection.id}"
    find('.user-menu-link[data-bs-toggle="dropdown"]').click
    expect(page).to have_css('.dropdown-menu.show')

    leave_by_turbo_visit("/works/#{@recording.id}")
    page.go_back

    expect(page).to have_current_path("/collections/#{@collection.id}")
    expect(page).to have_no_css('.dropdown-menu.show')
    expect(page).to have_css('.user-menu-link[aria-expanded="false"]')
  end
end
