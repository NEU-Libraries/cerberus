# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'works/_download_row', type: :view do
  it 'routes an S/M/L delegate through the derivative controller, not the raw gated URI' do
    file = AtlasRb::Mash.new(use: 'Large Image', role: 'large_image', mime_type: 'image/jpeg', label: 'Large',
                             uri: 'https://gated.example/iiif/3/x.tif/full/pct:75/0/default.jpg')

    render partial: 'works/download_row', locals: { file: file, work_noid: 'w-1' }

    expect(rendered).to include(derivative_download_path('w-1', 'large_image'))
    expect(rendered).not_to include('gated.example')
  end

  describe 'a rendition row' do
    let(:file) do
      AtlasRb::Mash.new(use: 'Small Image', role: 'small_image', label: 'Small Image',
                        uri: 'https://gated.example/iiif/3/x.tif/full/pct:33/0/default.jpg')
    end

    it 'names the file it will save as' do
      render partial: 'works/download_row', locals: { file: file, work_noid: 'w-1' }

      expect(rendered).to include('small_image_w-1.jpg')
    end

    # The tilde is hidden from screen readers, which hear "about 59 KB".
    it 'marks its size as an estimate' do
      allow(DerivativeSizeEstimate).to receive(:call).and_return(60_000)

      render partial: 'works/download_row', locals: { file: file, work_noid: 'w-1' }

      size = Nokogiri::HTML.fragment(rendered).at_css('small[title="Estimated size"]')
      expect(size.text.strip).to eq('~about 59 KB')
      expect(size.at_css('[aria-hidden="true"]').text).to eq('~')
      expect(size.at_css('.visually-hidden').text).to eq('about ')
    end

    it 'shows no size when none can be estimated' do
      allow(DerivativeSizeEstimate).to receive(:call).and_return(nil)

      render partial: 'works/download_row', locals: { file: file, work_noid: 'w-1' }

      expect(rendered).not_to include('Estimated size')
    end
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

  it 'offers an Add-to-queue control on a derivative row, keyed on work + role' do
    file = AtlasRb::Mash.new(use: 'Large Image', role: 'large_image', label: 'Large',
                             uri: 'https://gated.example/iiif/3/x.tif/full/pct:75/0/default.jpg')

    render partial: 'works/download_row', locals: { file: file, work_noid: 'w-1' }

    expect(rendered).to include('Add to queue')
    expect(rendered).to include('queue-control-w-1-large_image')
  end
end
