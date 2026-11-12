# frozen_string_literal: true

require 'rails_helper'

# End-to-end over the real test Atlas: a public Work's show page is fetched and
# the <head> inspected. The gating and field mapping are unit-specced
# (google_scholar_metadata_spec); this proves the show page's citation read and
# the content_for(:head) partial emit the tags, and that the CSL type gate holds.
RSpec.describe 'Work Google Scholar metadata', type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:community)  { public_container(AtlasRb::Community, nil) }
  let!(:collection) { public_container(AtlasRb::Collection, community.id) }

  it 'emits citation_* tags in the <head> of a public, scholarly-genre work' do
    work = public_work(collection.id, 'work-thesis')

    get work_path(work.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('name="citation_title"')
      .and include('name="citation_author"')
      .and include('name="citation_publication_date"')
      .and include('content="2017"')
      .and match(/name="keywords" content="[^"]*Civil society/)
  end

  it 'emits no citation_* tags for a non-scholarly genre' do
    work = public_work(collection.id, 'work') # "podcasts", a sound recording: CSL type song

    get work_path(work.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('citation_title')
  end

  # --- helpers -------------------------------------------------------------

  def mods(kind) = Rails.root.join('spec/fixtures/files', "#{kind}-mods.xml").to_s
  def read_public = { 'read' => ['public'] }

  def public_container(klass, parent_id)
    kind = klass.name.demodulize.downcase
    container = klass.create(parent_id, mods(kind), nuid: '000000004')
    AtlasRb::Resource.set_permissions(container.id, read_public, nuid: '000000004')
    container
  end

  def public_work(parent_id, fixture)
    work = AtlasRb::Work.create(parent_id, mods(fixture), nuid: '000000004')
    AtlasRb::Work.complete(work.id, nuid: '000000004')
    AtlasRb::Resource.set_permissions(work.id, read_public, nuid: '000000004')
    work
  end
end
