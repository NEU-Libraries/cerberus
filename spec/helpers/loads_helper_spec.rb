# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LoadsHelper do
  describe '#report_ingest_order' do
    let(:load_report) { LoadReport.create!(source_filename: 'pages.zip') }

    def page(item, sequence)
      MultipageIngest.create!(load_report: load_report, item_index: item, sequence: sequence,
                              source_filename: "#{item}-#{sequence}.tif", idempotency_key: SecureRandom.uuid)
    end

    # Pages of each Work stay together, and a structural-failure row (no item,
    # no page) leads rather than sinking to the bottom.
    it 'orders multipage rows by item, then page, with the unplaced row first' do
      [[1, 1], [0, 2], [0, 1], [1, 2]].each { |item, sequence| page(item, sequence) }
      failure = MultipageIngest.create!(load_report: load_report, source_filename: 'manifest.xlsx',
                                        status: :failed, idempotency_key: SecureRandom.uuid)

      ordered = load_report.multipage_ingests.order(*helper.report_ingest_order(Loader.new(kind: :multipage)))

      expect(ordered.map { |row| [row.item_index, row.sequence] })
        .to eq([[nil, nil], [0, 1], [0, 2], [1, 1], [1, 2]])
      expect(ordered.first).to eq(failure)
    end
  end

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
