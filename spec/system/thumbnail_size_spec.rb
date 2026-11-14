# frozen_string_literal: true

require 'rails_helper'

# A thumbnail drawn a few pixels off its stored IIIF size is resampled, and the
# small step blurs it. These measure the space each box gives the picture, so
# they hold whether or not the image server answers. See docs/derivatives.md.
RSpec.describe 'Thumbnail boxes', :browser, type: :system do
  before(:all) do
    Current.nuid = AtlasFixtures::ADMIN_NUID
    community = create_community(public: true)
    @collection = create_collection(community.id, public: true)
    @work = create_work(@collection.id, public: true)
    AtlasRb::Resource.set_thumbnails(@collection.id, thumbnail: 'http://127.0.0.1:9/iiif/c.jpg',
                                                     thumbnail_2x: 'http://127.0.0.1:9/iiif/c2.jpg', nuid: admin_nuid)
    AtlasRb::Resource.set_thumbnails(@work.id, thumbnail: 'http://127.0.0.1:9/iiif/t.jpg',
                                               thumbnail_2x: 'http://127.0.0.1:9/iiif/t2.jpg', nuid: admin_nuid)
  end

  before { sign_in_as(admin_nuid) }

  # The box's inner width less the img's own padding: the largest the picture can draw.
  def picture_areas(boxes)
    expect(page).to have_css("#{boxes} img", visible: :all)
    page.evaluate_script(<<~JS).uniq
      Array.from(document.querySelectorAll('#{boxes}')).map(function (box) {
        var s = getComputedStyle(box.querySelector('img'));
        return box.clientWidth - parseFloat(s.paddingLeft) - parseFloat(s.paddingRight);
      })
    JS
  end

  it "gives a Collection's header the 85 px picture" do
    visit "/collections/#{@collection.id}"

    expect(picture_areas('.col-md-auto > .document-thumbnail')).to eq([85])
  end

  it 'gives a list row the 85 px picture' do
    visit "/catalog?q=#{@work.id}&view=list"

    expect(picture_areas('#documents .document-thumbnail')).to eq([85])
  end

  it 'gives a gallery card the 170 px picture' do
    visit "/catalog?q=#{@work.id}&view=gallery"

    expect(picture_areas('.documents-gallery .document-thumbnail')).to eq([170])
  end
end
