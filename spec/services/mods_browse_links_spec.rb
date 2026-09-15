# frozen_string_literal: true

require 'rails_helper'

# Two halves. The predicate examples build the marker markup directly, because
# the decision being tested is Cerberus's alone. The contract example runs
# Atlas's real display through the service instead: the attribute names, the
# axis vocabulary and the exact indexed value are all Atlas's to emit, and a
# hand-written fragment would keep passing after Atlas changed any of them.
RSpec.describe MODSBrowseLinks do
  let(:configured) { CatalogController.blacklight_config.facet_fields.keys }

  def marked(axis:, value:, authority: 'lcsh', text: nil)
    authority_attr = authority ? %( data-browse-authority="#{authority}") : ''
    %(<dl><dd><p><span data-browse-axis="#{axis}" ) +
      %(data-browse-value="#{value}"#{authority_attr}>#{text || value}</span></p></dd></dl>)
  end

  def call(html) = described_class.call(html: html, facet_fields: configured)

  describe 'the three predicates' do
    it 'links a value whose axis maps to a configured facet and carries an authority' do
      html = call(marked(axis: 'topic', value: 'Civil society'))

      expect(html).to include('<a href="/catalog?f%5Bsubject_ssim%5D%5B%5D=Civil+society">')
      expect(html).to include('>Civil society</a>')
    end

    it 'leaves a value with no authority as plain text' do
      html = call(marked(axis: 'topic', value: 'coastal resilience', authority: nil))

      expect(html).not_to include('<a ')
      expect(html).to include('coastal resilience')
    end

    # Atlas marks these, and MODS permits an authority on both. The allowlist is
    # the only thing keeping them out, so this is the example that fails if
    # someone "completes" AXES. See docs/discovery.md.
    it 'leaves an axis the allowlist omits as plain text, authority notwithstanding' do
      expect(call(marked(axis: 'publisher', value: 'Northeastern University Press'))).not_to include('<a ')
      expect(call(marked(axis: 'place_of_publication', value: 'Boston'))).not_to include('<a ')
    end

    it 'withholds the link when the facet is no longer configured' do
      html = described_class.call(html:         marked(axis: 'topic', value: 'Civil society'),
                                  facet_fields: configured - ['subject_ssim'])

      expect(html).not_to include('<a ')
    end
  end

  describe 'what it does not touch' do
    it 'passes a nil fragment through, since a resource may have no MODS' do
      expect(described_class.call(html: nil, facet_fields: configured)).to be_nil
    end

    it 'passes an unmarked fragment through unchanged' do
      html = '<dl><dt>Title</dt><dd>A work with no marked values</dd></dl>'
      expect(call(html)).to include('A work with no marked values')
      expect(call(html)).not_to include('<a ')
    end

    # Atlas owns how a value reads. A superscript in a subject heading has to
    # survive, so the anchor wraps the value's markup rather than its text.
    it 'keeps the markup inside a value' do
      html = call(marked(axis: 'topic', value: 'H2O', text: 'H<sub>2</sub>O'))

      expect(html).to include('<a href="/catalog?f%5Bsubject_ssim%5D%5B%5D=H2O">H<sub>2</sub>O</a>')
    end

    # The link has to carry the INDEXED value, which Atlas normalises away in
    # the text it renders. Matching on the rendered string is what this whole
    # contract exists to avoid.
    it 'links the indexed value, not the displayed one' do
      html = call(marked(axis: 'topic', value: 'salt marshes', text: 'Salt marshes'))

      expect(html).to include('f%5Bsubject_ssim%5D%5B%5D=salt+marshes')
      expect(html).to include('>Salt marshes</a>')
    end
  end

  # AtlasFixtures is included for system specs alone, since its helpers mint real
  # resources in the test Atlas. Pulled in here rather than widened in
  # spec/support, because the reason to keep it off every spec still holds.
  describe "against Atlas's real display" do
    include AtlasFixtures

    before(:all) do
      Current.nuid = admin_nuid
      work = create_work(create_collection(create_community(public: true).id, public: true).id, public: true)
      @html = described_class.call(html:         AtlasRb::Work.mods(work.id, 'html'),
                                   facet_fields: CatalogController.blacklight_config.facet_fields.keys)
      @links = Nokogiri::HTML5.fragment(@html).css('a[href*="/catalog"]')
    end

    it 'links the authority-controlled values the fixture carries' do
      expect(@links).not_to be_empty
      expect(@links.map(&:text)).to include('Civil society', 'podcasts', 'English', 'Flynn, Stephen E.')
    end

    # The fixture's <subject> holds two <topic> children under one valueURI, and
    # Atlas indexes and displays that as ONE heading. Linking the parts instead
    # would point at values Solr no longer holds.
    it 'links a subdivided heading as one whole heading' do
      heading = @links.find { |a| a.text.include?('Emergency management') }

      expect(heading.text).to eq('Emergency management -- Planning')
      expect(heading['href']).to include('Emergency+management+--+Planning')
    end

    it 'routes each axis to its own facet field' do
      targets = @links.to_h { |a| [a.text, a['href'][/f%5B([a-z_]+)%5D/, 1]] }

      expect(targets).to include('Civil society'     => 'subject_ssim',
                                 'podcasts'          => 'genre_ssim',
                                 'English'           => 'language_ssim',
                                 'Flynn, Stephen E.' => 'contributor_ssim')
    end

    # Every rendered link must land somewhere. Asserted on the links the service
    # produced rather than on Atlas's markers: a marker with no facet target is
    # correct behaviour and must stay plain text, so a spec over markers would
    # fail on the right answer.
    it 'renders no link that cannot resolve to a facet field' do
      fields = @links.map { |a| a['href'][/f%5B([a-z_]+)%5D/, 1] }

      expect(fields).to all(be_in(CatalogController.blacklight_config.facet_fields.keys))
    end

    it 'leaves a value Atlas marks but Cerberus does not browse as plain text' do
      plain = Nokogiri::HTML5.fragment(@html).css('[data-browse-axis="photo_category"], ' \
                                                  '[data-browse-axis="publisher"]')

      expect(plain.css('a')).to be_empty
    end
  end
end
