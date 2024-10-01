# frozen_string_literal: true

require 'rails_helper'

describe LoadsController do
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml') }
  let(:collection) { AtlasRb::Collection.create(community['id'], '/home/cerberus/web/spec/fixtures/files/collection-mods.xml') }
  let(:work) { AtlasRb::Work.create(collection['id'], '/home/cerberus/web/spec/fixtures/files/work-mods.xml') }

  describe 'noid test' do
    it 'lets spec set the noid' do
      # not for keeping, just iterating - this lets us hard code pids in the xml zip fixture file
      # and patch them in to test objects for the xml update testing
      AtlasRb::Community.metadata(work['id'], { 'noid' => '123' })
      expect(AtlasRb::Work.find('123')).to be_present

      # PIDs in metadata_existing_files.zip

      # 8j2RtvbFW
      # 2fCuGC0E5
      # 4GaFRGnrr
      # hHtP31089
      # 089wXVbXf
    end
  end
end
