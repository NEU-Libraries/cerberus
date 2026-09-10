# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::LedgerHelper do
  # An activity row needs neither an actor nor a subject, so each example gives
  # only the fields the branch under test reads.
  def notice(kind, noid: nil, **payload)
    AdminNotice.new(kind: kind, subject: 'x', occurred_on: Date.current,
                    subject_noid: noid, payload: payload.stringify_keys)
  end

  describe '#ledger_notice_link' do
    it 'builds a load report path from the payload’s parts' do
      row = notice('load_report', loader_slug: 'iptc', load_report_id: 42)

      expect(helper.ledger_notice_link(row)).to eq('/loaders/iptc/loads/42')
    end

    # A row written before the payload carried both parts, or by a caller that
    # omitted one, has to render as plain text rather than a broken link.
    it 'is nil when the payload is missing either part of that path' do
      expect(helper.ledger_notice_link(notice('load_report', loader_slug: 'iptc'))).to be_nil
      expect(helper.ledger_notice_link(notice('load_report', load_report_id: 42))).to be_nil
      expect(helper.ledger_notice_link(notice('load_report'))).to be_nil
    end

    it 'points a cascade at the collection it ran on' do
      expect(helper.ledger_notice_link(notice('visibility_cascade', noid: 'abc123')))
        .to eq(helper.collection_path('abc123'))
    end

    it 'points each Set sweep at the set' do
      %w[set_reindex set_privatize set_sentinel_apply].each do |kind|
        expect(helper.ledger_notice_link(notice(kind, noid: 'set999')))
          .to eq(helper.set_path('set999'))
      end
    end

    it 'points a mismatch and a promotion at the work' do
      %w[work_completion_mismatch showcase_promotion].each do |kind|
        expect(helper.ledger_notice_link(notice(kind, noid: 'wk777')))
          .to eq(helper.work_path('wk777'))
      end
    end

    it 'is nil for a row that carries no noid to build a path from' do
      expect(helper.ledger_notice_link(notice('visibility_cascade'))).to be_nil
      expect(helper.ledger_notice_link(notice('set_reindex'))).to be_nil
    end

    it 'is nil for a request kind, which is linked through its subject instead' do
      expect(helper.ledger_notice_link(notice('request_withdraw', noid: 'wk777'))).to be_nil
    end
  end
end
