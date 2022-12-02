# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkCreator do
  describe '#call' do
    it 'creates a work' do
      community = CommunityCreator.call(mods_xml: File.read('/home/cerberus/web/spec/fixtures/files/community-mods.xml'))
      collection = CollectionCreator.call(parent_id: community.id, mods_xml: File.read('/home/cerberus/web/spec/fixtures/files/collection-mods.xml'))
      work = WorkCreator.call(parent_id: collection.id, mods_xml: File.read('/home/cerberus/web/spec/fixtures/files/work-mods.xml'))
      expect(work.decorate.plain_title).to eq("What's New - How We Respond to Disaster, Episode 1")
    end
  end
end
