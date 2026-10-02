# frozen_string_literal: true

require 'rails_helper'

# The Work show page's Analytics tab, against the live Atlas test backend: a real
# public Work that the staff group may edit, so the :edit gate is the real one.
RSpec.describe 'Work show page Analytics tab', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:fixtures)   { '/home/cerberus/web/spec/fixtures/files' }
  let(:community)  { AtlasRb::Community.create(nil, "#{fixtures}/community-mods.xml", nuid: '000000004') }
  let(:collection) { AtlasRb::Collection.create(community.id, "#{fixtures}/collection-mods.xml", nuid: '000000004') }
  let(:work)       { AtlasRb::Work.create(collection.id, "#{fixtures}/work-mods.xml", nuid: '000000004') }

  let(:editor) do
    User.new(email: 'editor@example.com', password: 'password', nuid: '000000002',
             name: 'Ed, Itor', role: 'privileged', groups: [Permissions::STAFF_EDIT_GROUP])
  end
  let(:admin) do
    User.new(email: 'admin@example.com', password: 'password', nuid: '000000004', role: 'admin', groups: [])
  end

  before do
    publicize_ancestry!(community: community, collection: collection)
    AtlasRb::Resource.set_permissions(work.id, { 'read' => ['public'], 'edit' => [Permissions::STAFF_EDIT_GROUP] },
                                      nuid: '000000004')
    AtlasRb::Work.complete(work.id, nuid: '000000004')
    ImpressionDailyCount.create!(noid: work.id, action: 'view', day: Date.current, count: 1234)
    ImpressionDailyCount.create!(noid: work.id, action: 'download', day: Date.current, count: 56)
    ImpressionDailyCount.create!(noid: 'someone-else', action: 'view', day: Date.current, count: 999)
  end

  it "shows an editor this Work's own totals under an Analytics tab" do
    sign_in editor
    get work_path(work.id)

    expect(response.body).to include('data-bs-target="#analytics"', 'data-bs-target="#metadata"')
    ledger = response.parsed_body.css('#analytics .usage-ledger__item').map { |item| item.text.squish }
    expect(ledger).to eq(['Views 1,234', 'Downloads 56'])
  end

  it 'draws each action on its own chart' do
    sign_in editor
    get work_path(work.id)

    titles = response.parsed_body.css('#analytics .usage-chart-block__title').map(&:text)
    expect(titles).to eq(['Views in the last 90 days', 'Downloads in the last 90 days'])
    expect(response.parsed_body.css('#analytics [data-usage-chart-stacked-value]')).to be_empty
  end

  # Streams are counted only for a Work that plays in the browser.
  it 'leaves streams out for a Work with no player' do
    sign_in editor
    get work_path(work.id)

    expect(response.body).not_to include('usage-ledger__item--stream')
  end

  it 'shows a public reader the page without tabs' do
    get work_path(work.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('data-bs-target="#analytics"', 'usage-ledger')
  end

  # The dashboard is admin-only, so the link would 403 for a group editor.
  it 'links an admin, and only an admin, to the Usage analytics dashboard' do
    sign_in admin
    get work_path(work.id)
    expect(response.body).to include('See other date ranges in Usage analytics')

    sign_out admin
    sign_in editor
    get work_path(work.id)
    expect(response.body).not_to include('See other date ranges in Usage analytics')
  end
end
