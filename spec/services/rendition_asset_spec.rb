# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RenditionAsset do
  def asset(noid, name, mime, role: 'original_file')
    AtlasRb::Mash.new('role' => role, 'noid' => noid, 'original_filename' => name, 'mime_type' => mime)
  end

  def file_sets(*assets)
    assets.map { |a| AtlasRb::Mash.new('assets' => [a]) }
  end

  let(:mov) { asset('b-mov', 'talk.mov', 'video/quicktime') }

  def mp4_rendition(sets) = described_class.for(sets, mime_types: described_class::MP4)

  it 'finds the MP4 remuxed from the original' do
    mp4 = asset('b-mp4', 'talk.mp4', 'video/mp4')

    expect(mp4_rendition(file_sets(mov, mp4))['noid']).to eq('b-mp4')
  end

  # An original that is already an MP4 is never remuxed, so it has no rendition,
  # and must not be mistaken for one and overwritten.
  it 'never treats an MP4 original as its own rendition' do
    expect(mp4_rendition(file_sets(asset('b-mp4', 'talk.mp4', 'video/mp4')))).to be_nil
  end

  it 'does not look for a PDF when asked for an MP4' do
    pdf = asset('b-pdf', 'talk.pdf', 'application/pdf')

    expect(mp4_rendition(file_sets(mov, pdf))).to be_nil
  end

  # A file the depositor attached under another name is theirs, not a rendition.
  it 'ignores an MP4 with a different name' do
    expect(mp4_rendition(file_sets(mov, asset('b-mp4', 'outtakes.mp4', 'video/mp4')))).to be_nil
  end

  it 'ignores assets that are not an original_file' do
    thumb = asset('b-thumb', 'talk.mp4', 'video/mp4', role: 'thumbnail_image')

    expect(mp4_rendition(file_sets(mov, thumb))).to be_nil
  end

  it 'picks the same MP4 every time when duplicates already exist' do
    later = asset('b-zz', 'talk.mp4', 'video/mp4')
    earlier = asset('b-aa', 'talk.mp4', 'video/mp4')

    expect(mp4_rendition(file_sets(mov, later, earlier))['noid']).to eq('b-aa')
    expect(mp4_rendition(file_sets(earlier, mov, later))['noid']).to eq('b-aa')
  end

  it 'answers nil for a Work with no file sets' do
    expect(mp4_rendition(nil)).to be_nil
  end
end
