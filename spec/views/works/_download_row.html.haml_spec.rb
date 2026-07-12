# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'works/_download_row', type: :view do
  it 'routes an S/M/L delegate through the derivative controller, not the raw gated URI' do
    file = AtlasRb::Mash.new(use: 'large_image', mime_type: 'image/jpeg', label: 'Large',
                             uri: 'https://gated.example/iiif/3/x.jp2/full/pct:75/0/default.jpg')

    render partial: 'works/download_row', locals: { file: file, work_noid: 'w-1' }

    expect(rendered).to include(derivative_download_path('w-1', 'large_image'))
    expect(rendered).not_to include('gated.example')
  end

  it 'offers an Add-to-queue control on a derivative row, keyed on work + slugged use' do
    file = AtlasRb::Mash.new(use: 'large_image', label: 'Large',
                             uri: 'https://gated.example/iiif/3/x.jp2/full/pct:75/0/default.jpg')

    render partial: 'works/download_row', locals: { file: file, work_noid: 'w-1' }

    expect(rendered).to include('Add to queue')
    expect(rendered).to include('queue-control-w-1-large_image')
  end
end
