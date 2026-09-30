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

  # Staff depositing into someone else's personal root: the form names the owner,
  # and the publish block waits under Ownership for a proxy deposit.
  context 'in someone else\'s workspace' do
    before do
      # Made first: the stub below reads collection.id, and a lazy create inside
      # it would call the wrapped find again.
      target_id = collection.id
      allow(AtlasRb::Collection).to receive(:find).and_wrap_original do |original, id, *rest, **kw|
        found = original.call(id, *rest, **kw)
        id.to_s == target_id.to_s ? found.merge('personal_root' => true, 'depositor' => '000000006') : found
      end
      allow(AtlasRb::Person).to receive(:resolve) do |nuids|
        root = nuids.first == '000000006' ? target_id : 'elsewhere'
        [AtlasRb::Mash.new('nuid' => nuids.first, 'display_name' => 'Jane Doe', 'personal_root_id' => root,
                           'affiliated_community_ids' => ['comm1'])]
      end
      allow(AtlasRb::Community).to receive(:find).and_call_original
      allow(AtlasRb::Community).to receive(:find).with('comm1').and_return(AtlasRb::Mash.new('title' => 'A Community'))
      allow(ShowcaseFinder).to receive(:call).and_return('Datasets' => 'ds1')
      get new_collection_work_path(collection.id)
    end

    let(:html) { response.parsed_body }

    it 'names whose workspace it is' do
      expect(html.at_css('.deposit-form__body .well .deposit-form__radio-title').text.strip).to eq('Jane Doe’s workspace')
    end

    it 'puts the publish block after Ownership, hidden until Proxy is chosen' do
      form = html.at_css('form.deposit-form')
      expect(form['data-deposit-promotion-requires-proxy-value']).to eq('true')

      promote = html.at_css('fieldset.deposit-form__promote[data-deposit-promotion-target="promote"]')
      expect(promote['class']).to include('d-none')
      expect(promote.text).to include('Also promote to Jane Doe’s community showcase')

      fields = html.css('.deposit-form__body > fieldset.deposit-form__field, .deposit-form__body > .deposit-form__field')
      legends = fields.map { |f| f.at_css('legend')&.text&.strip }
      expect(fields.index(promote)).to be > legends.index('Ownership')
    end

    it 'wires the ownership radios to the promotion controller' do
      expect(html.css('input[name="upload_as"][data-action="deposit-promotion#proxyChanged"]').size).to eq(2)
    end
  end
end
