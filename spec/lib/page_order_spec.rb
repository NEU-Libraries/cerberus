# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PageOrder do
  def asset(noid) = AtlasRb::Mash.new('noid' => noid)
  def page(*noids) = { 'assets' => noids.map { |n| { 'noid' => n } } }

  it 'lists page files in page order, whatever order the assets came in' do
    files = [asset('p2-master'), asset('p1-master')]
    pages = [page('p1-master'), page('p2-master')]

    expect(described_class.sort(files, pages).pluck('noid')).to eq(%w[p1-master p2-master])
  end

  it 'keeps a page\'s own files in their order, and puts Work-level files last' do
    files = [asset('work-pdf'), asset('p2-b'), asset('p1-a'), asset('p2-a')]
    pages = [page('p1-a'), page('p2-b', 'p2-a')]

    expect(described_class.sort(files, pages).pluck('noid')).to eq(%w[p1-a p2-b p2-a work-pdf])
  end

  it 'leaves a single-page Work, and a nil listing, as they were' do
    files = [asset('b'), asset('a')]

    expect(described_class.sort(files, [])).to eq(files)
    expect(described_class.sort(nil, [page('a')])).to be_nil
  end
end
