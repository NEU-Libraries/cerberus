# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LoadReportRows do
  let(:report) { LoadReport.create!(source_filename: 'batch.zip') }

  describe 'an IPTC or XML report' do
    before do
      create_list(:iptc_ingest, LoadReportRows::PER_PAGE + 3, load_report: report, status: :completed)
    end

    def page(number)
      described_class.call(relation: report.iptc_ingests.order(:id), multipage: false, page: number)
    end

    it 'shows PER_PAGE rows, then the rest on the next page' do
      expect(page(nil).rows.size).to eq(LoadReportRows::PER_PAGE)
      expect(page(2).rows.size).to eq(3)
      expect(page(nil).pager.total_pages).to eq(2)
    end

    it 'shows the last page for a page past the end' do
      expect(page(9).pager.current_page).to eq(2)
      expect(page(9).rows.size).to eq(3)
    end
  end

  describe 'a multipage report' do
    # Item sizes in pages; nil is a structural-failure row with no item.
    def seed(sizes)
      sizes.each do |item, count|
        count.times { |n| create(:multipage_ingest, load_report: report, item_index: item, sequence: n + 1) }
      end
    end

    def page(number)
      relation = report.multipage_ingests.order(MultipageIngest.arel_table[:item_index].asc.nulls_first, :sequence)
      described_class.call(relation: relation, multipage: true, page: number)
    end

    # 30 + 30 would pass PER_PAGE, so Work 1 starts page 2 rather than splitting.
    it 'never splits a Work across a page break' do
      seed({ 0 => 30, 1 => 30, 2 => 10 })

      expect(page(1).rows.map(&:item_index).uniq).to eq([0])
      expect(page(2).rows.map(&:item_index).uniq).to eq([1, 2])
      expect(page(1).pager.total_pages).to eq(2)
    end

    it 'gives a Work longer than a page a page of its own' do
      seed({ 0 => 5, 1 => LoadReportRows::PER_PAGE + 20, 2 => 5 })

      expect([1, 2, 3].map { |n| page(n).rows.map(&:item_index).uniq }).to eq([[0], [1], [2]])
    end

    it 'puts the structural-failure row first, as a Work of its own' do
      seed({ nil => 1, 0 => 3 })

      expect(page(1).rows.map(&:item_index)).to eq([nil, 0, 0, 0])
    end

    it 'shows the last page for a page past the end' do
      seed({ 0 => 30, 1 => 30 })

      expect(page(9).pager.current_page).to eq(2)
      expect(page(9).rows.map(&:item_index).uniq).to eq([1])
    end
  end
end
