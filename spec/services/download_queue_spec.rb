# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DownloadQueue do
  let(:session) { {} }
  let(:queue) { described_class.new(session) }

  it 'adds an item and reports membership + count' do
    expect(queue.add('w1', 'b1')).to eq(:ok)
    expect(queue.count).to eq(1)
    expect(queue.include?('w1', 'b1')).to be(true)
  end

  it 'is a no-op on a duplicate add' do
    queue.add('w1', 'b1')
    expect(queue.add('w1', 'b1')).to eq(:already)
    expect(queue.count).to eq(1)
  end

  it 'removes an item' do
    queue.add('w1', 'b1')
    queue.remove('w1', 'b1')
    expect(queue.include?('w1', 'b1')).to be(false)
    expect(queue).to be_empty
  end

  it 'clears the queue' do
    queue.add('w1', 'b1')
    queue.add('w1', 'b2')
    queue.clear
    expect(queue).to be_empty
  end

  it 'refuses to grow past the cap' do
    stub_const('DownloadQueue::MAX', 2)
    queue.add('w1', 'b1')
    queue.add('w1', 'b2')
    expect(queue.add('w1', 'b3')).to eq(:full)
    expect(queue.count).to eq(2)
  end

  it 'stores minimal string-keyed pairs (stable across session serialization)' do
    queue.add('w1', 'b1')
    expect(session[:download_queue]).to eq([{ 'w' => 'w1', 'b' => 'b1' }])
  end

  it 'adds a derivative rendition, tracked independently of blobs' do
    expect(queue.add_derivative('w1', 'Large Image')).to eq(:ok)
    expect(queue.include_derivative?('w1', 'Large Image')).to be(true)
    expect(queue.include?('w1', 'Large Image')).to be(false) # a blob with that noid is a different entry
  end

  it 'stores a derivative as a distinct { w, d } pair' do
    queue.add_derivative('w1', 'Large Image')
    expect(session[:download_queue]).to eq([{ 'w' => 'w1', 'd' => 'Large Image' }])
  end

  it 'removes a derivative' do
    queue.add_derivative('w1', 'Large Image')
    queue.remove_derivative('w1', 'Large Image')
    expect(queue.include_derivative?('w1', 'Large Image')).to be(false)
  end

  it 'counts blob and derivative entries together toward the cap' do
    queue.add('w1', 'b1')
    queue.add_derivative('w1', 'Large Image')
    expect(queue.count).to eq(2)
  end
end
