# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'works/_captions', type: :view do
  def render_section(captions: [], removed: [], removable: false)
    render partial: 'works/captions', locals: { captions: captions, removed: removed, removable: removable }
  end

  def caption(noid, language: nil, label: nil)
    AtlasRb::Mash.new(noid: noid, mime_type: 'text/vtt', language: language, track_label: label)
  end

  it 'offers a file input the browser filters to WebVTT' do
    render_section
    expect(rendered).to have_css('input#caption[type="file"][name="caption"][accept=".vtt"]', visible: :all)
  end

  it 'labels the input' do
    render_section
    expect(rendered).to have_css('label[for="caption"]', text: 'Caption file')
  end

  describe 'the language select' do
    before { render_section }

    it 'offers every listed language by tag, English first, then Other' do
      values = Capybara.string(rendered).all('select#caption_language option').map(&:value)
      expect(values).to eq(CaptionTrack::LANGUAGES.map(&:first) + [CaptionTrack::OTHER])
    end

    it 'names a language in English and in its own name' do
      expect(rendered).to have_css('option[value="es"]', text: 'Spanish — Español')
    end

    # Hidden until Other is chosen, but present, so the fields submit when used.
    it 'carries the Other tag and label fields, hidden until Other is chosen' do
      expect(rendered).to have_css('[hidden] input#caption_language_tag[name="caption_language_tag"]', visible: :all)
      expect(rendered).to have_css("input#caption_language_label[maxlength=\"#{CaptionTrack::LABEL_LIMIT}\"]",
                                   visible: :all)
    end
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

    it 'lists no current files' do
      expect(rendered).to have_no_css('.caption-tracks')
      expect(rendered).to have_no_link
    end
  end

  context 'when the work has captions in two languages' do
    let(:captions) { [caption('c-1'), caption('c-2', language: 'es', label: 'Español')] }

    before { render_section(captions: captions) }

    # The media route, not the download one: a reader who can play the video can
    # read its captions, whatever the download gate says.
    it 'lists each language with a link to its file' do
      expect(rendered).to have_link('View', href: '/media/c-1')
      expect(rendered).to have_link('View', href: '/media/c-2')
      expect(rendered).to have_css('.caption-tracks__label[lang="es"]', text: 'Español')
    end

    it 'shows each language tag as an identifier' do
      expect(Capybara.string(rendered).all('.caption-tracks__tag').map(&:text)).to eq(%w[en es])
    end

    it 'says a same-language upload replaces that file and keeps the old one' do
      expect(rendered).to have_text("replaces that language's file, and the earlier one is kept in its version history")
    end

    it 'offers no Remove unless the caller allows it' do
      expect(rendered).to have_no_button('Remove')
    end
  end

  context 'when Remove is allowed' do
    before { render_section(captions: [caption('c-2', language: 'es', label: 'Español')], removable: true) }

    it 'submits the remove form with that caption\'s id, after a named confirmation' do
      expect(rendered).to have_css('button[form="remove-caption"][name="caption_id"][value="c-2"]' \
                                   '[data-turbo-confirm^="Remove the Español caption file?"]')
    end

    # Removal withdraws the file rather than deleting it, and says so.
    it 'says a removed file can be restored' do
      expect(rendered).to have_css('[data-turbo-confirm*="can be restored from this page"]')
    end
  end

  context 'when the work has removed captions' do
    let(:removed) do
      [AtlasRb::Mash.new(noid: 'c-9', file_set: 'fs-9', mime_type: 'text/vtt', language: 'fr', track_label: 'Français',
                         tombstoned_at: '2026-09-30T14:00:00Z', tombstoned_by: '000000002')]
    end

    it 'lists each with who removed it and when, and a Restore for its file set' do
      render_section(removed: removed, removable: true)

      expect(rendered).to have_css('.caption-tracks--removed .caption-tracks__label[lang="fr"]', text: 'Français')
      expect(rendered).to have_css('.caption-tracks__meta', text: /Removed 2026-09-30 \d{2}:\d{2} \w+ by 000000002/)
      expect(rendered).to have_css('button[form="restore-caption"][name="file_set_id"][value="fs-9"]', text: 'Restore')
    end

    it 'hides them from a viewer who may not restore them' do
      render_section(removed: removed, removable: false)
      expect(rendered).to have_no_css('.caption-tracks--removed')
      expect(rendered).to have_no_text('Removed caption files')
    end
  end
end
