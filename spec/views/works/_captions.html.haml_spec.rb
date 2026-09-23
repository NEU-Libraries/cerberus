# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'works/_captions', type: :view do
  def render_section(caption: nil)
    render partial: 'works/captions', locals: { caption: caption }
  end

  it 'offers a file input the browser filters to WebVTT' do
    render_section
    expect(rendered).to have_css('input#caption[type="file"][name="caption"][accept=".vtt"]', visible: :all)
  end

  it 'labels the input' do
    render_section
    expect(rendered).to have_css('label[for="caption"]', text: 'Captions file')
  end

  context 'when the work has no captions' do
    before { render_section }

    it 'says which format it takes and who can help convert one' do
      expect(rendered).to have_text('Caption files must be in WebVTT (.vtt) format.')
      expect(rendered).to have_text('Contact repository staff for help converting caption files to WebVTT.')
    end

    # HAML reads a line STARTING with ".srt" as a div.srt, which silently ate half
    # of that sentence. The text assertion above passes on the broken markup
    # (innerText still reads through), so the element check is the one that bites.
    it 'renders the format note as prose, not as a stray element' do
      expect(rendered).to have_no_css('.srt')
      expect(rendered).to have_no_css('.vtt')
    end

    it 'offers no link to a file that does not exist' do
      expect(rendered).to have_no_link
    end
  end

  context 'when the work already has captions' do
    before { render_section(caption: AtlasRb::Mash.new(noid: 'c-1', mime_type: 'text/vtt')) }

    # The media route, not the download one: a reader who can play the video can
    # read its captions, whatever the download gate says.
    it 'links the current file for review' do
      expect(rendered).to have_link('View the current caption file', href: '/media/c-1')
    end

    it 'says the file it replaces is kept' do
      expect(rendered).to have_text('Older caption files are retained in this work’s version history.')
    end

    it 'still states the format a replacement must be in' do
      expect(rendered).to have_text('Caption files must be in WebVTT (.vtt) format.')
    end
  end
end
