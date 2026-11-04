# frozen_string_literal: true

require 'rails_helper'

# End-to-end over the real test Atlas, as a guest: the history reaches readers
# under the Work's own read gate, not only the admin tiers that can read the
# attributed Blob.versions.
RSpec.describe 'Work file history', type: :request do
  let(:fixtures) { Rails.root.join('spec/fixtures/files') }
  let!(:community)  { public_container(AtlasRb::Community, nil) }
  let!(:collection) { public_container(AtlasRb::Collection, community.id) }
  let!(:work)       { public_work(collection.id) }

  it 'renders no File history card for a Work whose file was never replaced' do
    get work_path(work.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="downloads"')
    expect(response.body).not_to include('id="file-history"')
  end

  context 'when a file was replaced' do
    let!(:blob_noid) do
      noid = AtlasRb::Work.assets(work.id, nuid: '000000004').first.noid
      AtlasRb::Blob.update(noid, fixtures.join('image.png').to_s, nuid: '000000004')
      noid
    end

    it 'lists each version newest first, with the file ID, to a guest' do
      get work_path(work.id)

      expect(response).to have_http_status(:ok)
      card = response.parsed_body.at_css('#file-history')
      expect(card).to be_present
      expect(card.text).to include('File ID', blob_noid)
      expect(card.css('tbody tr td:first-child .admin-registry-table__id').map(&:text)).to eq(%w[2 1])
      expect(card.css('tbody tr').first.text).to include('current')
    end

    # The read is supplementary: a failure drops the card, not the page.
    it 'still renders the page when the read fails' do
      allow(AtlasRb::Work).to receive(:file_revisions).and_raise(AtlasRb::ResourceError.new('boom'))

      get work_path(work.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="downloads"')
      expect(response.body).not_to include('id="file-history"')
    end
  end

  # --- helpers -------------------------------------------------------------

  def mods(kind) = fixtures.join("#{kind}-mods.xml").to_s
  def read_public = { 'read' => ['public'] }

  def public_container(klass, parent_id)
    kind = klass.name.demodulize.downcase
    container = klass.create(parent_id, mods(kind), nuid: '000000004')
    AtlasRb::Resource.set_permissions(container.id, read_public, nuid: '000000004')
    container
  end

  # Public before the Blob lands, so the Blob is minted readable by a guest.
  def public_work(parent_id)
    work = AtlasRb::Work.create(parent_id, mods('work'), nuid: '000000004')
    AtlasRb::Resource.set_permissions(work.id, read_public, nuid: '000000004')
    AtlasRb::Blob.create(work.id, fixtures.join('image.png').to_s, 'image.png', nuid: '000000004')
    AtlasRb::Work.complete(work.id, nuid: '000000004')
    work
  end
end
