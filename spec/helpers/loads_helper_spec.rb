# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LoadsHelper do
  describe '#loader_intake_description' do
    it 'describes an archive of tagged images for an IPTC loader' do
      expect(helper.loader_intake_description(Loader.new(kind: :iptc)))
        .to eq('an archive of IPTC-tagged JPEGs')
    end

    it 'describes a manifest with one MODS file per row for an XML loader' do
      expect(helper.loader_intake_description(Loader.new(kind: :xml)))
        .to eq('a manifest spreadsheet with a MODS file per row')
    end

    it 'describes ordered page images for a multipage loader' do
      expect(helper.loader_intake_description(Loader.new(kind: :multipage)))
        .to eq('a manifest spreadsheet with a MODS file and ordered page images per item')
    end
  end
end
