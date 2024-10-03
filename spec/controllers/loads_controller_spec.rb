# frozen_string_literal: true

require 'rails_helper'

describe LoadsController do
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml') }
  let(:collection) { AtlasRb::Collection.create(community['id'], '/home/cerberus/web/spec/fixtures/files/collection-mods.xml') }
  let(:work) { AtlasRb::Work.create(collection['id'], '/home/cerberus/web/spec/fixtures/files/work-mods.xml') }
  let(:zip) { fixture_file_upload('/home/cerberus/web/spec/fixtures/files/metadata_existing_files.zip', 'application/zip') }

  describe 'noid test' do
    it 'lets spec set the noid' do
      AtlasRb::Community.metadata(work['id'], { 'noid' => '123' })
      expect(AtlasRb::Work.find('123')).to be_present
    end
  end

  describe 'create popups' do
    it 'processes the zip file successfully' do
      post :create, params: { file: zip }
      expect(response).to redirect_to(loads_path)
      # expect(flash[:notice]).to eq("ZIP file processed successfully.")
      expect(flash[:alert]).to be_nil
    end
  end
end
