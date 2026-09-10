# frozen_string_literal: true

require 'rails_helper'

# The row this partial draws sat on the Work page for a long time fed by a MODS
# field nothing ever wrote, so every Work carried a labelled link to nowhere.
# Now it is fed by the handle Atlas mints, and the absent case is the one that
# has to stay right: minting is best-effort, so "no handle" is an ordinary state
# and must render nothing at all.
RSpec.describe 'works/_permanent_url', type: :view do
  def render_row(url)
    render partial: 'works/permanent_url', locals: { url: url }
  end

  context 'with a minted handle' do
    before { render_row('https://hdl.handle.net/2047/gq67jr519') }

    it 'links the resolved handle under the Permanent URL label' do
      expect(rendered).to have_link('https://hdl.handle.net/2047/gq67jr519',
                                    href: 'https://hdl.handle.net/2047/gq67jr519')
      expect(rendered).to include('Permanent URL:')
    end
  end

  context 'without a handle' do
    before { render_row(nil) }

    it 'renders neither the label nor a link' do
      expect(rendered).to have_no_link
      expect(rendered).not_to include('Permanent URL')
    end

    it 'still emits the span, so the Downloads link keeps the right edge of the row' do
      expect(rendered).to have_css('span', count: 1)
      expect(rendered.gsub(/\s+/, '')).to eq('<span></span>')
    end
  end
end
