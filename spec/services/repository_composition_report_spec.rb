# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepositoryCompositionReport do
  subject(:report) { described_class.new }

  describe '#entity_counts' do
    it 'maps the internal_resource_tesim facet onto the tracked entity types, defaulting missing ones to 0' do
      allow(SolrFacetValues).to receive(:call).with(field: 'internal_resource_tesim')
                                              .and_return([['Work', 500], ['Collection', 40], ['FileSet', 2000]])

      expect(report.entity_counts).to eq('Community' => 0, 'Collection' => 40, 'Work' => 500, 'Person' => 0)
    end

    it 'memoizes — only queries Solr once even if called twice' do
      expect(SolrFacetValues).to receive(:call).once.and_return([])

      report.entity_counts
      report.entity_counts
    end
  end

  describe '#work_visibility' do
    before do
      allow(SolrFacetValues).to receive(:call).with(field: 'internal_resource_tesim')
                                              .and_return([['Work', 100]])
    end

    it 'derives private as the remainder after a public-only count query' do
      expect(Blacklight.default_index).to receive(:search)
        .with(hash_including(fq: ['internal_resource_tesim:Work', 'read_access_group_ssim:public']))
        .and_return(instance_double(Blacklight::Solr::Response, total: 60))

      expect(report.work_visibility).to eq(public: 60, private: 40)
    end

    it 'memoizes — only queries Solr once even if called twice' do
      expect(Blacklight.default_index).to receive(:search).once
                                                          .and_return(instance_double(Blacklight::Solr::Response, total: 60))

      report.work_visibility
      report.work_visibility
    end
  end

  describe '#classification_counts' do
    it 'delegates to SolrFacetValues scoped to Works' do
      expect(SolrFacetValues).to receive(:call)
        .with(field: 'classification_ssim', extra_fq: ['internal_resource_tesim:Work'])
        .and_return([['Image', 12], ['Text', 3]])

      expect(report.classification_counts).to eq([['Image', 12], ['Text', 3]])
    end
  end
end
