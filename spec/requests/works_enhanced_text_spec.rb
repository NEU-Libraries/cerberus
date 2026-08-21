# frozen_string_literal: true

require 'rails_helper'

# End-to-end over the real test Atlas + Solr, on the v1 title this feature
# exists for: MODS escapes the subscript tags into the title's text node, so a
# reader has to get the formula and not the tags.
#
# The value reaches three kinds of place on one page, and each needs a different
# answer — element content renders the markup, an attribute and the page <title>
# cannot, and the search index holds the string as written. Proving all three
# from one fetch is the point: a helper spec cannot show that the right one was
# picked at each site.
RSpec.describe 'Work enhanced text', type: :request do
  include Devise::Test::IntegrationHelpers

  FORMULA_MARKUP = 'Bi<sub>2</sub>Sr<sub>2</sub>CaCu<sub>2</sub>O<sub>8</sub>'
  FORMULA_TEXT   = 'Bi2Sr2CaCu2O8'

  let!(:community)  { public_container(AtlasRb::Community, nil) }
  let!(:collection) { public_container(AtlasRb::Collection, community.id) }
  let!(:work)       { public_work(collection.id) }

  before { get work_path(work.id) }

  it 'renders the subscripts in the show heading' do
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<h3>Origin of the high-energy kink')
      .and include(FORMULA_MARKUP)
  end

  # The one place the tags still show, and the reason for the Atlas gap report:
  # the MODS metadata block is HTML that Atlas builds and Cerberus injects whole
  # (works/show.html.haml, `@mods.html_safe`). Atlas escapes the title into it,
  # so the markup cannot be recovered on this side without picking entities back
  # out of finished HTML. Pinned so the day Atlas stops escaping it, this fails
  # and the expectation flips rather than the behaviour changing unnoticed.
  it 'still shows the escaped tags inside the Atlas-rendered MODS block' do
    mods_block = response.body[%r{<dt>Title</dt>\s*<dd>(.*?)</dd>}m, 1]

    expect(mods_block).to include('&lt;sub&gt;')
  end

  it 'strips the markup from the citation_title tag, where it could only be characters' do
    plain = 'Origin of the high-energy kink in the photoemission spectrum of ' \
            "the high-temperature superconductor #{FORMULA_TEXT}"

    expect(response.body).to include('name="citation_title"').and include(%(content="#{plain}"))
  end

  it 'strips the markup from the page title' do
    title = response.body[%r{<title>(.*?)</title>}m, 1]

    expect(title).to include(FORMULA_TEXT)
    expect(title).not_to include('sub>')
  end

  it 'strips the markup from the thumbnail alt text' do
    alt = response.body[/alt="Preview of ([^"]*)"/, 1]

    expect(alt).to include(FORMULA_TEXT) if alt
  end

  # --- helpers -------------------------------------------------------------

  def mods(kind) = Rails.root.join('spec/fixtures/files', "#{kind}-mods.xml").to_s
  def read_public = { 'permissions' => { 'read' => ['public'] } }

  def public_container(klass, parent_id)
    kind = klass.name.demodulize.downcase
    container = klass.create(parent_id, mods(kind), nuid: '000000004')
    klass.metadata(container.id, read_public, nuid: '000000004')
    container
  end

  def public_work(parent_id)
    created = AtlasRb::Work.create(parent_id, mods('work-enhanced-text'), nuid: '000000004')
    AtlasRb::Work.complete(created.id, nuid: '000000004')
    AtlasRb::Work.metadata(created.id, read_public, nuid: '000000004')
    created
  end
end
