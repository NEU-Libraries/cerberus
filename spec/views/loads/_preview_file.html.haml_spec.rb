# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'loads/_preview_file', type: :view do
  def render_file(file, identifier: nil)
    render partial: 'loads/preview_file', locals: { file: file, identifier: identifier }
    Capybara.string(rendered)
  end

  it 'shows a create-mode image with its name, size and type' do
    page = render_file(XmlPreviewFile::Result.new(name: 'flower.jpg', byte_size: 104_297, mime_type: 'image/jpeg',
                                                  thumbnail_src: 'data:image/jpeg;base64,AAAA'))

    expect(page).to have_css('img.load-preview-file__image[alt="Preview of flower.jpg"][src^="data:image/jpeg"]')
    expect(page).to have_css('figcaption', text: 'flower.jpg · 102 KB · JPG', normalize_ws: true)
  end

  it 'shows the type icon, and says so, for a file with no picture' do
    page = render_file(XmlPreviewFile::Result.new(name: 'talk.mp3', byte_size: 5000, mime_type: 'audio/mpeg'))

    expect(page).to have_css('i.load-preview-file__icon.fa-file-audio')
    expect(page).to have_no_css('img')
    expect(page).to have_css('figcaption', text: 'No picture for this file type')
  end

  it 'names the Work in update mode, with or without a thumbnail' do
    expect(render_file(XmlPreviewFile::Result.new(thumbnail_src: 'https://iiif.example/p.jpg'), identifier: 'abc1234'))
      .to have_css('figcaption', text: 'Current thumbnail of abc1234')
    expect(render_file(XmlPreviewFile::Result.new, identifier: 'abc1234'))
      .to have_css('figcaption', text: 'abc1234 has no thumbnail yet')
  end

  it 'renders nothing when the row names no file the archive holds' do
    expect(render_file(nil)).to have_no_css('figure')
  end
end
