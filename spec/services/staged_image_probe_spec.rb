# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StagedImageProbe do
  let(:tmp_uploads) { Dir.mktmpdir('staged-probe') }
  let(:work_id) { 'w-probe' }
  let(:work_dir) { File.join(tmp_uploads, work_id) }

  before do
    @orig = Rails.application.config.x.cerberus.uploads_root
    Rails.application.config.x.cerberus.uploads_root = tmp_uploads
  end

  after do
    Rails.application.config.x.cerberus.uploads_root = @orig
    FileUtils.rm_rf(tmp_uploads)
  end

  def stage(fixture, as: nil)
    FileUtils.mkdir_p(work_dir)
    FileUtils.cp(Rails.root.join('spec/fixtures/files', fixture), File.join(work_dir, as || fixture))
  end

  it 'reads the staged image dimensions via a vips header read' do
    stage('image.png')
    result = described_class.call(work_id: work_id)

    expect(result.width).to eq(441)
    expect(result.height).to eq(588)
    expect(result.longest_edge).to eq(588)
    expect(result.path).to eq(File.join(work_dir, 'image.png'))
  end

  it 'returns nil when no staging directory exists' do
    expect(described_class.call(work_id: work_id)).to be_nil
  end

  it 'returns nil when the directory holds no files' do
    FileUtils.mkdir_p(work_dir)
    expect(described_class.call(work_id: work_id)).to be_nil
  end

  it 'returns nil for a non-image deposit' do
    stage('plain.txt')
    expect(described_class.call(work_id: work_id)).to be_nil
  end

  it 'returns nil (not an error) for a corrupt image file' do
    FileUtils.mkdir_p(work_dir)
    # PNG magic bytes so Marcel calls it an image, followed by garbage.
    File.binwrite(File.join(work_dir, 'bad.png'), "\x89PNG\r\n\x1a\ngarbage")
    expect(described_class.call(work_id: work_id)).to be_nil
  end
end
