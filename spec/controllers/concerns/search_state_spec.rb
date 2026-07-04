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

    it "returns a synthetic doc's nav_url verbatim, bypassing the model path" do
      doc = double('SolrDocument', nav_url: '/communities/jm640df/people', klass: Person, to_param: 'x')

      expect(search_state.url_for_document(doc)).to eq('/communities/jm640df/people')
    end
  end
end
