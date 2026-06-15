# frozen_string_literal: true

require 'rails_helper'

describe SolrDocument do
  let(:no_noid_doc) { SolrDocument.new(id: '1', human_readable_type_ssim: ['Project']) }

  describe "has default to_param value when alternate_ids aren't set" do
    subject { no_noid_doc.to_param }
    it { is_expected.to eq no_noid_doc.id }
  end
end
