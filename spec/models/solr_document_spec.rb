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
end
