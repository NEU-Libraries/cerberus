# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'

# Live network smoke for Darwin Core validation, opt-in like the LoC smoke.
#
# TDWG's published Simple Darwin Core schemas import their siblings by relative
# path, import each other in a cycle, and do not compile as published. This
# runs a real record through the project's mirror list, so it fails if Kataba
# regresses on either import shape, or if a corrected copy under
# vendor/schemas/tdwg stops compiling against the Dublin Core and W3C files
# still fetched live.
#
# Run on demand:
#   RUN_LOC_SMOKE=1 bundle exec rspec spec/integration/kataba_tdwg_regression_spec.rb
describe 'Kataba TDWG regression', :loc_smoke do
  before do
    skip 'Set RUN_LOC_SMOKE=1 to run live TDWG smoke (network)' unless ENV['RUN_LOC_SMOKE']
  end

  # An ephemeral cache, so every fetch exercises the network and the mirrors.
  around do |example|
    Dir.mktmpdir do |dir|
      original_storage = Kataba.configuration.offline_storage
      Kataba.configuration.offline_storage = dir
      begin
        example.run
      ensure
        Kataba.configuration.offline_storage = original_storage
      end
    end
  end

  let(:record) { file_fixture('dwc-record.xml').read }

  %w[
    http://rs.tdwg.org/dwc/xsd/tdwg_dwc_simple.xsd
    https://dwc.tdwg.org/xml/tdwg_dwc_simple.xsd
  ].each do |uri|
    it "validates the TDWG example against #{uri}" do
      xml = record.sub('http://rs.tdwg.org/dwc/xsd/tdwg_dwc_simple.xsd', uri)

      expect(DarwinCoreRecordValidator.call(xml:)).to eq([])
    end
  end

  it 'refuses a term the standard does not define' do
    xml = record.sub('<dwc:sex>male</dwc:sex>', '<dwc:notATerm>male</dwc:notATerm>')

    expect(DarwinCoreRecordValidator.call(xml:).map(&:to_s)).to include(a_string_matching(/notATerm/))
  end
end
