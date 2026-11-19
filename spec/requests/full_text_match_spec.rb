# frozen_string_literal: true

require 'rails_helper'

# The "Full Text Match" snippet over the real test Atlas and Solr. A stubbed
# response cannot catch the catalog highlighting a field Atlas never writes, so
# this seeds body text through Atlas and searches for a word only it contains.
RSpec.describe 'Full Text Match snippet', type: :request do
  def nuid = '000000004'
  def mods(kind) = Rails.root.join("spec/fixtures/files/#{kind}-mods.xml").to_s
  def read_public = { 'read' => ['public'] }

  def public_container(klass, parent_id)
    container = klass.create(parent_id, mods(klass.name.demodulize.downcase), nuid: nuid)
    AtlasRb::Resource.set_permissions(container.id, read_public, nuid: nuid)
    container
  end

  # Letters only, so the English analyzer leaves the token whole.
  let(:token) { @token }

  before(:context) do
    @token = "quillmark#{SecureRandom.alphanumeric(8).downcase.tr('0-9', 'a-j')}"
    community = public_container(AtlasRb::Community, nil)
    collection = public_container(AtlasRb::Collection, community.id)
    work = AtlasRb::Work.create(collection.id, mods('work'), nuid: nuid)
    AtlasRb::Work.complete(work.id, nuid: nuid)
    AtlasRb::Resource.set_permissions(work.id, read_public, nuid: nuid)
    AtlasRb::Work.set_full_text(work.id, text: "The surveyor's notebook mentions #{@token} twice.", nuid: nuid)
  end

  it 'highlights the matched word from the Work body' do
    get search_catalog_path(q: token)

    snippet = response.parsed_body.at_css('.full-text-match__snippet')
    expect(snippet).to be_present
    expect(snippet.css('em').map(&:text)).to include(token)
  end
end
