# frozen_string_literal: true

require 'rails_helper'

# Atlas answers a purged Work, Collection or Community with 410 and an id-only
# stub, and an id that never existed with 404. require_resource! tells the two
# apart. See docs/authorization.md.
RSpec.describe 'The Removed page for a purged id', type: :request do
  include AtlasFixtures

  def purged_stub(id)
    AtlasRb::Mash.new('id' => id, 'purged' => true, 'purged_at' => '2026-11-06T18:30:00Z')
  end

  describe 'against Atlas' do
    let(:collection) { create_collection(create_community.id) }

    it 'answers a purged Work with the Removed page and its purge date' do
      work = create_work(collection.id)
      AtlasRb::Admin::Resource.destroy(work.id, confirm: :i_understand, nuid: admin_nuid)
      purged_on = Time.zone.today.strftime('%B %-d, %Y')

      get work_path(work.id)

      expect(response).to have_http_status(:gone)
      expect(response).to render_template('errors/gone')
      expect(response.body).to include("This item was removed on #{purged_on}.", work.id)
    end

    it 'still answers an id that never existed with 404' do
      get work_path('neverexisted')

      expect(response).to have_http_status(:not_found)
    end
  end

  {
    'Collection' => [AtlasRb::Collection, :collection_path],
    'Community'  => [AtlasRb::Community, :community_path]
  }.each do |type, (klass, path)|
    it "answers a purged #{type} with the Removed page" do
      allow(klass).to receive(:find).with('p1').and_return(purged_stub('p1'))

      get public_send(path, 'p1')

      expect(response).to have_http_status(:gone)
      expect(response.body).to include('This item was removed on November 6, 2026.', 'p1')
    end
  end
end
