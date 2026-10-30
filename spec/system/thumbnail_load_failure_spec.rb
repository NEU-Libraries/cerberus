# frozen_string_literal: true

require 'rails_helper'

# The browser fetches thumbnails and previews from the image server directly,
# so when that server is down no Rails code sees the failure. The page itself
# has to catch the error and degrade to an icon rather than a broken image.
# A closed local port stands in for the server, so the request fails at once.
RSpec.describe 'Thumbnails when the image server is down', :browser, type: :system do
  before(:all) do
    Current.nuid = AtlasFixtures::ADMIN_NUID
    @community = create_community(public: true)
    @collection = create_collection(@community.id, public: true)
    @work = create_work(@collection.id, public: true)
    @related = create_work(@collection.id, public: true)
    unreachable = 'http://127.0.0.1:9/iiif'
    [@community, @collection].each do |container|
      AtlasRb::Resource.set_thumbnails(container.id, thumbnail: "#{unreachable}/c.jpg",
                                                     thumbnail_2x: "#{unreachable}/c2.jpg", nuid: admin_nuid)
    end
    AtlasRb::Resource.set_thumbnails(@work.id,
                                     thumbnail:      "#{unreachable}/t.jpg",
                                     thumbnail_2x:   "#{unreachable}/t2.jpg",
                                     preview:        "#{unreachable}/preview.jpg",
                                     preview_width:  500,
                                     preview_height: 375,
                                     nuid:           admin_nuid)
    AtlasRb::Work.associate(@related.id, @work.id, type: 'is_codebook_for', nuid: admin_nuid)
    @set = AtlasRb::Compilation.create('Unreachable Thumbnails', nuid: admin_nuid)
    AtlasRb::Compilation.add_included_work(@set['id'], @work.id, nuid: admin_nuid)
  end

  before { sign_in_as(admin_nuid) }

  it "keeps the Work preview's frame and shows the icon in it" do
    visit "/works/#{@work.id}"

    expect(page).to have_css('.preview-blur-up[data-blur-up="failed"]')
    expect(page).to have_css('.preview-blur-up__icon .fa-image', visible: :visible)
    box = page.evaluate_script(<<~JS)
      (function () {
        var img = document.querySelector('.preview-blur-up img');
        var r = img.getBoundingClientRect();
        return { loaded: img.naturalWidth > 0, ratio: r.width / r.height };
      })()
    JS
    expect(box['loaded']).to be(true)
    # The frame's 4 px padding and 1 px border sit outside the 4:3 content box.
    expect(box['ratio']).to be_within(0.02).of(4.0 / 3)
  end

  it "swaps a result's thumbnail for its type icon" do
    visit "/collections/#{@collection.id}"

    expect(page).to have_css('.document-thumbnail .thumbnail-fallback:not(.d-none)', visible: :visible)
    expect(page).to have_css('.document-thumbnail img.d-none', visible: :all)
  end

  it "swaps a Collection's and a Community's header thumbnail for its type icon" do
    visit "/collections/#{@collection.id}"
    expect(page).to have_css('.document-thumbnail .thumbnail-fallback:not(.d-none) .fa-folder-open', visible: :visible)

    visit "/communities/#{@community.id}"
    expect(page).to have_css('.document-thumbnail .thumbnail-fallback:not(.d-none) .fa-users', visible: :visible)
  end

  it "swaps an associated Work's thumbnail for the image icon" do
    visit "/works/#{@related.id}"

    expect(page).to have_css('.work-association__thumb span:not(.d-none) .fa-image', visible: :visible)
    expect(page).to have_css('.work-association__thumb img.d-none', visible: :all)
  end

  it "swaps a Set row's thumbnail for the image icon" do
    visit "/sets/#{@set['id']}"

    expect(page).to have_css('#set-results .thumb span:not(.d-none) .fa-image', visible: :visible)
    expect(page).to have_css('#set-results .thumb img.d-none', visible: :all)
  end
end
