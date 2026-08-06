# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminFinderHelper do
  describe '#deposit_last_change' do
    it 'renders the date, with the full timestamp in the title for the exact moment' do
      doc = SolrDocument.new(id: '1', updated_at_dtsi: '2026-08-01T09:30:00Z')

      html = helper.deposit_last_change(doc)

      expect(html).to include('2026-08-01')
      expect(html).to include('title="2026-08-01T09:30:00Z"')
    end

    # A resource with no timestamp is not an error worth a blank cell: the dash
    # says "no value" where an empty td reads as a rendering fault.
    it 'renders a dash when the resource carries no timestamp' do
      expect(helper.deposit_last_change(SolrDocument.new(id: '1'))).to include('—')
    end
  end

  describe '#finder_doc_title' do
    it 'falls back for an untitled resource so the row is still actionable' do
      expect(helper.finder_doc_title(SolrDocument.new(id: '1'))).to eq('(untitled)')
    end
  end
end
