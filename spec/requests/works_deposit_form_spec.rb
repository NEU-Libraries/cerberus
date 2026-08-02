# frozen_string_literal: true

require 'rails_helper'

# The deposit form's POST target. Worth its own spec because the surface that
# broke is not the one the other deposit specs exercise: they POST to the create
# route directly, so they stay green while the rendered form points somewhere
# else entirely. Only rendering `new` and reading the form's action catches that.
RSpec.describe 'Works deposit form', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:fixtures)   { '/home/cerberus/web/spec/fixtures/files' }
  let(:community)  { AtlasRb::Community.create(nil, "#{fixtures}/community-mods.xml", nuid: '000000004') }
  let(:collection) { AtlasRb::Collection.create(community.id, "#{fixtures}/collection-mods.xml", nuid: '000000004') }

  let(:editor) do
    User.new(email: 'editor@example.com', password: 'password', nuid: '000000002',
             name: 'Ed, Itor', role: 'privileged', groups: [Permissions::STAFF_EDIT_GROUP])
  end

  before { sign_in editor }

  it 'posts to the collection create route, not back to itself' do
    get new_collection_work_path(collection.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(action="#{collection_works_path(collection.id)}"))
    expect(response.body).not_to include(%(action="#{new_collection_work_path(collection.id)}"))
  end

  # The action has to be a route that accepts POST — the failure mode here was a
  # form pointing at a GET-only path, which only shows up on submit.
  it 'names a path that routes to works#create' do
    expect(Rails.application.routes.recognize_path(collection_works_path(collection.id), method: :post))
      .to include(controller: 'works', action: 'create')
  end
end
