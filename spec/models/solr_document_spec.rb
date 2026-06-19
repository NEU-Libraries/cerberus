# frozen_string_literal: true

require 'rails_helper'

describe SolrDocument do
  let(:no_noid_doc) { SolrDocument.new(id: '1', human_readable_type_ssim: ['Project']) }

  describe "has default to_param value when alternate_ids aren't set" do
    subject { no_noid_doc.to_param }
    it { is_expected.to eq no_noid_doc.id }
  end

  describe '#klass' do
    # internal_resource_tesim drives klass; Person must resolve to the Person
    # model so a Person result row doesn't NameError in _document_list.
    it 'resolves a Person doc to the Person model' do
      doc = SolrDocument.new(id: '1', internal_resource_tesim: ['Person'])
      expect(doc.klass).to eq(Person)
    end
  end

  describe '#nav_url' do
    # Carries a synthetic navigation row's destination (e.g. a community's
    # "Faculty & Staff" entry); url_for_document honours it.
    it 'reads the nav_url_ssi field' do
      doc = SolrDocument.new(id: '1', nav_url_ssi: '/communities/jm640df/people')
      expect(doc.nav_url).to eq('/communities/jm640df/people')
    end
  end

  describe '#featured?' do
    # Atlas projects a showcase Collection's flag onto featured_bsi; drives the
    # "Featured" thumbnail pill. Solr returns a JSON boolean, but coerce
    # defensively for string-typed responses too.
    it 'is true for a JSON-boolean featured_bsi' do
      expect(SolrDocument.new(id: '1', featured_bsi: true).featured?).to be(true)
    end

    it 'is true for a string "true"' do
      expect(SolrDocument.new(id: '1', featured_bsi: 'true').featured?).to be(true)
    end

    it 'is false when absent or falsey' do
      expect(SolrDocument.new(id: '1').featured?).to be(false)
      expect(SolrDocument.new(id: '1', featured_bsi: false).featured?).to be(false)
    end
  end
end
