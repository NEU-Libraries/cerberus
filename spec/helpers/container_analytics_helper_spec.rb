# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContainerAnalyticsHelper do
  let(:base_item) { { noid: 'c1', uuid: 'uuid-c1', klass: 'Collection', title: 'Test Collection' } }
  let(:work_item) { { noid: 'w1', uuid: 'uuid-w1', klass: 'Work', title: 'Sample Office Document' } }

  def report(scope)
    instance_double(ImpressionsReport, scope: scope)
  end

  def scope(facet: nil)
    ImpressionScope.new(item: base_item, facet:)
  end

  describe '#container_analytics_drilled?' do
    it 'is false when the effective item is the base container itself' do
      expect(helper).not_to be_container_analytics_drilled(base_item, base_item)
    end

    it 'is true when a descendant item is the effective scope' do
      expect(helper).to be_container_analytics_drilled(base_item, work_item)
    end
  end

  describe '#container_analytics_scope_blurb' do
    it 'describes the whole subtree when neither a drill-down nor a facet is active' do
      blurb = helper.container_analytics_scope_blurb(report(scope), base_item, base_item)

      expect(blurb).to eq('An overview of the contents and usage of Test Collection, including counts of its ' \
                          'communities, collections, and works, along with usage statistics recorded by human ' \
                          'visitors.')
    end

    # The figures below this sentence are for the one item, so claiming the
    # whole subtree here would contradict them.
    it 'names the drilled-into item instead of the subtree' do
      blurb = helper.container_analytics_scope_blurb(report(scope), base_item, work_item)

      expect(blurb).to include('for Sample Office Document — one work within this collection')
      expect(blurb).not_to include('An overview of the contents')
    end

    it 'says the figures are facet-narrowed rather than claiming everything' do
      faceted = scope(facet: { type: 'content', value: 'Text' })
      blurb = helper.container_analytics_scope_blurb(report(faceted), base_item, base_item)

      expect(blurb).to include('the works under this collection that match the filter below')
      expect(blurb).not_to include('An overview of the contents')
    end

    it 'prefers the drill-down wording when a facet is also active' do
      faceted = scope(facet: { type: 'content', value: 'Text' })
      blurb = helper.container_analytics_scope_blurb(report(faceted), base_item, work_item)

      expect(blurb).to include('one work within this collection')
    end

    it 'reads naturally for a Community too' do
      community = { noid: 'm1', uuid: 'uuid-m1', klass: 'Community', title: 'A Community' }
      blurb = helper.container_analytics_scope_blurb(report(scope), community, community)

      expect(blurb).to include('An overview of the contents and usage of A Community')
    end
  end
end
