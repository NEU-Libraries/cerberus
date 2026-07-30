# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FacetedWorkNoids do
  def work_doc(noid)
    doc = instance_double(SolrDocument)
    allow(doc).to receive(:[]).with('alternate_ids_ssim').and_return(["id-#{noid}"])
    doc
  end

  describe 'type: content' do
    it 'returns Work noids matching the classification value' do
      allow(Blacklight.default_index).to receive(:search)
        .with(hash_including(fq: array_including('internal_resource_tesim:Work', 'classification_ssim:"Image"')))
        .and_return(instance_double(Blacklight::Solr::Response, documents: [work_doc('w1')]))

      expect(described_class.call(type: 'content', value: 'Image')).to eq(['w1'])
    end

    it 'returns an empty array for a blank value' do
      expect(Blacklight.default_index).not_to receive(:search)
      expect(described_class.call(type: 'content', value: '')).to eq([])
    end
  end

  describe 'type: featured' do
    it 'resolves showcases titled after the genre, then the works linked into them' do
      showcase_doc = instance_double(SolrDocument, id: 'uuid-showcase')
      allow(showcase_doc).to receive(:[]).with('title_tsim').and_return(['Datasets'])

      allow(Blacklight.default_index).to receive(:search)
        .with(hash_including(fq: array_including('internal_resource_tesim:Collection', 'featured_bsi:true')))
        .and_return(instance_double(Blacklight::Solr::Response, documents: [showcase_doc]))
      allow(Blacklight.default_index).to receive(:search)
        .with(hash_including(fq: array_including('internal_resource_tesim:Work')))
        .and_return(instance_double(Blacklight::Solr::Response, documents: [work_doc('w2')]))

      expect(described_class.call(type: 'featured', value: 'Datasets')).to eq(['w2'])
    end

    it 'returns an empty array when no showcase matches the genre exactly' do
      near_match = instance_double(SolrDocument, id: 'uuid-x')
      allow(near_match).to receive(:[]).with('title_tsim').and_return(['Datasets Annual']) # tokenized over-match guard

      allow(Blacklight.default_index).to receive(:search)
        .and_return(instance_double(Blacklight::Solr::Response, documents: [near_match]))

      expect(described_class.call(type: 'featured', value: 'Datasets')).to eq([])
    end
  end

  it 'returns an empty array for an unrecognized type' do
    expect(described_class.call(type: 'nonsense', value: 'x')).to eq([])
  end
end
