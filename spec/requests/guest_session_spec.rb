# frozen_string_literal: true

require 'rails_helper'

# A guest who only reads pages must not cost a sessions row: most crawlers never
# send the cookie back, so every write would insert a new one. The test
# environment turns forgery protection off, which would hide the CSRF token
# write, so these examples turn it back on. See docs/identity.md.
RSpec.describe 'Guest sessions', type: :request do
  include Devise::Test::IntegrationHelpers

  around do |example|
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  let!(:community)  { public_container(AtlasRb::Community, nil) }
  let!(:collection) { public_container(AtlasRb::Collection, community.id) }
  let!(:work)       { public_work(collection.id) }

  def session_rows = ActiveRecord::SessionStore::Session.count

  describe 'a guest who only reads' do
    {
      'the home page'                            => -> { root_path },
      'a collection page, which lists its works' => -> { collection_path(collection.id) },
      'a work page'                              => -> { work_path(work.id) }
    }.each do |page, path|
      it "stores no session on #{page}" do
        expect { get instance_exec(&path) }.not_to(change { session_rows })

        expect(response).to have_http_status(:ok)
        expect(response.headers['Set-Cookie'].to_s).not_to include('_cerberus_session')
        expect(response.parsed_body.at_css('meta[name="csrf-token"]')).to be_nil
      end
    end

    it 'renders the collection page with a link to the work it lists' do
      get collection_path(collection.id)

      expect(response.parsed_body.at_css(%(a[href="#{work_path(work.id)}"]))).to be_present
    end
  end

  it 'still gives a signed-in user the CSRF meta tag, which sign-out needs' do
    sign_in User.new(email: 'staff@example.com', nuid: '000000006', groups: [Permissions::STAFF_EDIT_GROUP])

    get work_path(work.id)

    expect(response.parsed_body.at_css('meta[name="csrf-token"]')).to be_present
  end

  describe "a guest's own form" do
    def remove_form
      get download_queue_path
      response.parsed_body.at_css(%(form[action^="#{download_queue_item_path}"]))
    end

    before do
      ActionController::Base.allow_forgery_protection = false
      post download_queue_items_path, params: { work_noid: work.id, blob_noid: 'blob1' }
      ActionController::Base.allow_forgery_protection = true
    end

    it 'submits with the hidden token it carries' do
      form = remove_form
      token = form.at_css('input[name="authenticity_token"]')['value']

      delete form['action'], params: { authenticity_token: token, work_noid: work.id, blob_noid: 'blob1' }

      expect(response).to have_http_status(:redirect)
    end

    it 'is refused without the token, so the check is really on' do
      form = remove_form

      delete form['action'], params: { work_noid: work.id, blob_noid: 'blob1' }

      expect(response).to have_http_status(:unprocessable_content)
    end
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

  def public_work(parent_id)
    work = AtlasRb::Work.create(parent_id, mods('work'), nuid: '000000004')
    AtlasRb::Work.complete(work.id, nuid: '000000004')
    AtlasRb::Resource.set_permissions(work.id, read_public, nuid: '000000004')
    work
  end
end
