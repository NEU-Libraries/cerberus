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

  it 'names a caption file Captions, not Atlas\'s generic Text Document' do
    file = AtlasRb::Mash.new(noid: 'c-1', mime_type: 'text/vtt', label: 'Text Document',
                             filename: 'captions.vtt', size: 1200)

    render partial: 'works/download_row', locals: { file: file, work_noid: 'w-1' }

    expect(rendered).to include('English captions')
    expect(rendered).not_to include('Text Document')
  end

  it 'names a caption download by its language, so two captions can be told apart' do
    file = AtlasRb::Mash.new(noid: 'c-2', mime_type: 'text/vtt', label: 'Text Document',
                             filename: 'es.vtt', size: 900, language: 'es', track_label: 'Español')

    render partial: 'works/download_row', locals: { file: file, work_noid: 'w-1' }

    expect(rendered).to include('Español captions')
  end

  it 'offers an Add-to-queue control on a derivative row, keyed on work + slugged use' do
    file = AtlasRb::Mash.new(use: 'large_image', label: 'Large',
                             uri: 'https://gated.example/iiif/3/x.jp2/full/pct:75/0/default.jpg')

    render partial: 'works/download_row', locals: { file: file, work_noid: 'w-1' }

    expect(rendered).to include('Add to queue')
    expect(rendered).to include('queue-control-w-1-large_image')
  end
end
