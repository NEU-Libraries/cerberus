# frozen_string_literal: true

require 'rails_helper'

describe SearchState do
  let(:search_state) do
    described_class.new(ActionController::Parameters.new, CatalogController.blacklight_config)
  end

  describe '#url_for_document' do
    it 'routes through the model-specific path helper when doc.klass is set' do
      doc = double('SolrDocument', klass: Community, to_param: 'abc123')

      expect(search_state.url_for_document(doc)).to eq('/communities/abc123')
    end
  end
end
