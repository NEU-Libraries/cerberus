# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImpressionScope do
  describe 'unscoped' do
    subject(:scope) { described_class.new }

    it 'is inactive with nil noid sets and no labels' do
      expect(scope.active?).to be false
      expect(scope.overview_noids).to be_nil
      expect(scope.top_works_noids).to be_nil
      expect(scope.top_containers_noids).to be_nil
      expect(scope.show_collections_tab?).to be true
      expect(scope.item_label).to be_nil
      expect(scope.facet_label).to be_nil
    end
  end

  describe 'item scope: a Work' do
    subject(:scope) { described_class.new(item: { noid: 'w1', uuid: 'uuid-w1', klass: 'Work', title: 'A Work' }) }

    it 'is a single-noid scope with no container concept' do
      expect(scope.active?).to be true
      expect(scope.item_container?).to be false
      expect(scope.overview_noids).to eq(['w1'])
      expect(scope.top_works_noids).to eq(['w1'])
      expect(scope.top_containers_noids).to be_nil
      expect(scope.show_collections_tab?).to be false
      expect(scope.item_label).to eq('Work: A Work')
    end
  end

  describe 'item scope: a Collection' do
    subject(:scope) { described_class.new(item: { noid: 'c1', uuid: 'uuid-c1', klass: 'Collection', title: 'A Collection' }) }

    before do
      allow(ContainerDescendantsQuery).to receive(:new).with(noid: 'c1', uuid: 'uuid-c1')
                                                       .and_return(instance_double(ContainerDescendantsQuery,
                                                                                   noids:           %w[c1 sub w1 w2],
                                                                                   work_noids:      %w[w1 w2],
                                                                                   container_noids: %w[c1 sub]))
    end

    it 'includes containers+works in the overview but only works for the ranking noid set' do
      expect(scope.item_container?).to be true
      expect(scope.overview_noids).to eq(%w[c1 sub w1 w2])
      expect(scope.top_works_noids).to eq(%w[w1 w2])
      expect(scope.top_containers_noids).to eq(%w[c1 sub])
      expect(scope.show_collections_tab?).to be true
      expect(scope.item_label).to eq('Collection: A Collection')
    end
  end

  describe 'facet only' do
    subject(:scope) { described_class.new(facet: { type: 'content', value: 'Image' }) }

    before do
      allow(FacetedWorkNoids).to receive(:call).with(type: 'content', value: 'Image').and_return(%w[w1 w3])
    end

    it 'narrows to the facet Work noids and hides the collections tab' do
      expect(scope.active?).to be true
      expect(scope.overview_noids).to eq(%w[w1 w3])
      expect(scope.top_works_noids).to eq(%w[w1 w3])
      expect(scope.top_containers_noids).to be_nil
      expect(scope.show_collections_tab?).to be false
      expect(scope.facet_label).to eq('Content: Image')
      expect(scope.facet_type).to eq('content')
      expect(scope.facet_value).to eq('Image')
    end

    it 'labels a featured facet distinctly' do
      featured_scope = described_class.new(facet: { type: 'featured', value: 'Datasets' })
      allow(FacetedWorkNoids).to receive(:call).with(type: 'featured', value: 'Datasets').and_return([])

      expect(featured_scope.facet_label).to eq('Featured Content: Datasets')
    end
  end

  describe 'combined item (Collection) + facet' do
    subject(:scope) do
      described_class.new(item:  { noid: 'c1', uuid: 'uuid-c1', klass: 'Collection', title: 'A Collection' },
                          facet: { type: 'content', value: 'Image' })
    end

    before do
      allow(ContainerDescendantsQuery).to receive(:new).with(noid: 'c1', uuid: 'uuid-c1')
                                                       .and_return(instance_double(ContainerDescendantsQuery,
                                                                                   noids:           %w[c1 sub w1 w2],
                                                                                   work_noids:      %w[w1 w2],
                                                                                   container_noids: %w[c1 sub]))
      allow(FacetedWorkNoids).to receive(:call).with(type: 'content', value: 'Image').and_return(%w[w2 w9])
    end

    it 'intersects the container work-set with the facet work-set, dropping container noids' do
      expect(scope.overview_noids).to eq(['w2']) # only overlap between {c1,sub,w1,w2} and {w2,w9}
      expect(scope.top_works_noids).to eq(['w2'])
      expect(scope.show_collections_tab?).to be false # a facet is active
    end
  end

  describe 'combined item (Work) + facet that does not match' do
    subject(:scope) do
      described_class.new(item:  { noid: 'w1', uuid: 'uuid-w1', klass: 'Work', title: 'A Work' },
                          facet: { type: 'content', value: 'Image' })
    end

    before do
      allow(FacetedWorkNoids).to receive(:call).with(type: 'content', value: 'Image').and_return(%w[w9])
    end

    it 'resolves to an empty noid set rather than raising' do
      expect(scope.overview_noids).to eq([])
      expect(scope.top_works_noids).to eq([])
    end
  end
end
