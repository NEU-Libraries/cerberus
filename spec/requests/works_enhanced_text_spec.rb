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
  let(:work) { public_work(collection.id, 'work-enhanced-text') }

  before { get work_path(work.id) }

  it 'renders the subscripts in the show heading' do
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<h3>Origin of the high-energy kink')
      .and include(FORMULA_MARKUP)
  end

  # The MODS metadata block is HTML that Atlas builds and Cerberus injects whole
  # (works/show.html.haml, `@mods.html_safe`), so Cerberus cannot sanitize it on
  # this side — the markup either survives Atlas's decorator or it is gone.
  # Asserted here because the block sits directly under the heading, and the two
  # disagreeing is what a reader notices first.
  it 'renders the subscripts inside the Atlas-rendered MODS block' do
    mods_block = response.body[%r{<dt>Title</dt>\s*<dd>(.*?)</dd>}m, 1]

    expect(mods_block).to include(FORMULA_MARKUP)
    expect(mods_block).not_to include('&lt;sub&gt;')
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

  # Gap 2's fix spans three repos — Atlas writes title_plain_tsim, the
  # blacklight-solr image lists it in the request handler's qf, and Cerberus
  # sends the query. Only an end-to-end search proves all three are in place;
  # each half looks correct on its own while the reader still finds nothing.
  describe 'searching for the formula' do
    it 'finds the work by the plain text a reader types' do
      get search_catalog_path(q: FORMULA_TEXT, search_field: 'all_fields')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(work.id)
    end

    # Matching happens on the plain text, display happens on the marked-up
    # string, and one result row has to do both. Atlas keeps title_tsim marked
    # up precisely so the heading can render — asserting the pair together is
    # what catches a well-meant "just strip the index field" change.
    it 'renders the subscripts in the row it matched' do
      get search_catalog_path(q: FORMULA_TEXT, search_field: 'all_fields')

      expect(response.body).to include(FORMULA_MARKUP)
    end
  end

  # A title where "<" is a character in its own right, which is what MODS holding
  # `&lt;Tc` yields. Both halves of the page used to lose the span between the
  # bare "<" and the next ">" — Cerberus's heading and Atlas's MODS block
  # independently, since each parsed the value as HTML. Asserting them together
  # is the point: they are two codebases that have to agree on one string.
  describe 'a literal less-than in the title' do
    let(:work) { public_work(collection.id, 'work-literal-less-than') }

    let(:expected) { 'Resistivity at Ti &lt;Tc and Ti &lt; Tc in Bi<sub>2</sub>O' }

    it 'keeps the whole title in the heading Cerberus renders' do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<h3>#{expected}</h3>")
    end

    it 'keeps the whole title in the block Atlas renders' do
      mods_block = response.body[%r{<dt>Title</dt>\s*<dd>(.*?)</dd>}m, 1]

      expect(mods_block).to eq(expected)
    end

    it 'keeps the whole title in the page title, with the markup off' do
      title = response.body[%r{<title>(.*?)</title>}m, 1]

      expect(title.strip).to eq('Resistivity at Ti &lt;Tc and Ti &lt; Tc in Bi2O')
    end
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

  def public_work(parent_id, fixture)
    created = AtlasRb::Work.create(parent_id, mods(fixture), nuid: '000000004')
    AtlasRb::Work.complete(created.id, nuid: '000000004')
    AtlasRb::Work.metadata(created.id, read_public, nuid: '000000004')
    created
  end
end
