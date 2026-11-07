# frozen_string_literal: true

require 'rails_helper'

# A community page with no keyword, facet or picked sort lists its own
# showcases first, in FeaturedContent::GENRES order, then Faculty & Staff, then
# everything else by title, as v1 floated its genre rows. Over the real test
# Atlas; signed in as an admin, who sees the empty showcases too.
RSpec.describe 'Community showcase order', type: :request do
  include Devise::Test::IntegrationHelpers

  def nuid = '000000004'
  def mods(kind) = Rails.root.join("spec/fixtures/files/#{kind}-mods.xml").to_s

  # By title alone "Test Collection" sorts between Technical Reports and
  # Theses & Dissertations, so only the floated order puts it last.
  before(:context) do
    @community = AtlasRb::Community.create(nil, mods('community'), nuid: nuid)
    Current.set(nuid: nuid) { ShowcaseProvisioner.call(community_id: @community.id) }
    @collection = AtlasRb::Collection.create(@community.id, mods('collection'), nuid: nuid)
  end

  let(:admin) do
    User.new(email: 'admin@example.com', password: 'password', nuid: nuid,
             name: 'Ad, Min', role: 'admin', groups: [Permissions::STAFF_EDIT_GROUP])
  end

  before do
    sign_in admin
    # The Faculty & Staff row needs affiliated people; its placement is the point.
    allow_any_instance_of(CommunitiesController).to receive(:affiliated_people_count).and_return(1)
  end

  def titles
    response.parsed_body.css('#documents article .index_title a').map { |a| a.text.strip }
  end

  def selected_sort
    response.parsed_body.at_css('#sort-dropdown .dropdown-item.active')&.text&.strip
  end

  let(:floated) { [*FeaturedContent.genre_labels, 'Faculty & Staff', 'Test Collection'] }

  it 'floats the showcases on a plain browse, with title still the selected sort' do
    get community_path(@community.id)

    expect(titles).to eq(floated)
    expect(selected_sort).to eq('title')
  end

  it 'floats them on an empty search too' do
    get community_path(@community.id, q: '')

    expect(titles.first(FeaturedContent::GENRES.size + 1)).to eq(floated.first(FeaturedContent::GENRES.size + 1))
  end

  it 'sorts by title alone when the visitor picks the sort' do
    get community_path(@community.id, sort: 'title')

    expect(titles).to eq(['Faculty & Staff', *(FeaturedContent.genre_labels + ['Test Collection']).sort])
  end

  it 'does not float under a facet' do
    get community_path(@community.id, f: { type_ssim: ['Collection'] })

    expect(titles).to eq((FeaturedContent.genre_labels + ['Test Collection']).sort)
  end
end
