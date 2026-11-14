# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'works/_associations' do
  def doc(id, abstract: nil, **thumbnails)
    fields = { 'id' => "uuid-#{id}", 'alternate_ids_ssim' => ["id-#{id}"], 'title_tsim' => ["Title #{id}"] }
    fields['description_tsim'] = [abstract] if abstract
    SolrDocument.new(fields.merge(thumbnails.transform_keys(&:to_s)))
  end

  def render_with(*docs)
    result = WorkAssociations::Result.new({ 'is_supplemental_material_for' => docs }, {})
    render partial: 'works/associations', locals: { associations: result }
  end

  it 'shows a trimmed abstract in place of the PID' do
    render_with(doc('abc1234', abstract: "#{'word ' * 60}end"))

    expect(rendered).to have_css('.work-association__abstract', text: /\Aword word/)
    expect(rendered).not_to have_css('.work-association__id')
    expect(rendered.scan('word').size).to be < 60
  end

  it 'falls back to the PID for a work with no abstract' do
    render_with(doc('abc1234'))

    expect(rendered).to have_css('.work-association__id', text: 'abc1234')
  end

  # The 50 px tile is 100 device pixels on a HiDPI screen, more than the 85 px copy holds.
  it "offers a HiDPI screen the thumbnail's 2x copy" do
    render_with(doc('abc1234', thumbnail_ssi: 'https://iiif/t.jpg', thumbnail_2x_ssi: 'https://iiif/t2.jpg'))

    expect(rendered).to have_css('.work-association__thumb img[src="https://iiif/t.jpg"]' \
                                 '[srcset="https://iiif/t.jpg 1x, https://iiif/t2.jpg 2x"]')
  end
end
