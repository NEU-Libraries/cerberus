# frozen_string_literal: true

require 'rails_helper'

# Below the operator tiers, Atlas refuses every read of a tombstoned resource but
# its `find`, which answers with a stub. Authorizable#render_withheld turns the
# refusal into the Removed page. See docs/authorization.md.
RSpec.describe 'A tombstone withholds the record', type: :request do
  include Devise::Test::IntegrationHelpers

  def tombstoned(type, id)
    AtlasRb::TombstonedError.new({ 'error' => 'tombstoned', 'tombstoned_resource_type' => type,
                                   'tombstoned_resource_id' => id })
  end

  def stub_record(id, title)
    AtlasRb::Mash.new('id' => id, 'title' => title, 'tombstoned' => true,
                      'tombstone_reason' => 'Removed from view by legal order')
  end

  before do
    sign_in User.new(email: 'e@x.edu', password: 'password', nuid: '000000005', groups: ['editors'])
  end

  {
    'Collection' => [AtlasRb::Collection, :edit_collection_path],
    'Community'  => [AtlasRb::Community, :edit_community_path],
    'Work'       => [AtlasRb::Work, :edit_work_path]
  }.each do |type, (klass, edit_path)|
    it "answers a tombstoned #{type}'s edit form with the Removed page" do
      allow(AtlasRb::Resource).to receive(:permissions).with('t1').and_raise(tombstoned(type, 't1'))
      allow(klass).to receive(:find).with('t1').and_return(stub_record('t1', "Withheld #{type}"))

      get public_send(edit_path, 't1')

      expect(response).to have_http_status(:gone)
      expect(response).to render_template('errors/gone')
      expect(response.body).to include("Withheld #{type}")
    end
  end

  it 'answers a refusal naming a FileSet with the not-found page' do
    allow(AtlasRb::Resource).to receive(:permissions).with('t1').and_raise(tombstoned('FileSet', 'fs1'))

    get edit_work_path('t1')

    expect(response).to have_http_status(:not_found)
  end
end
