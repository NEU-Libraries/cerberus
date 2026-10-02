# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StagedMediaProbe do
  let(:tmp_uploads) { Dir.mktmpdir('staged-media-probe') }
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

  def stage(fixture)
    FileUtils.mkdir_p(work_dir)
    FileUtils.cp(Rails.root.join('spec/fixtures/files', fixture), File.join(work_dir, fixture))
  end

  it 'names the audio tier for a staged recording' do
    stage('sample-audio.mp3')

    expect(described_class.call(work_id: work_id)).to eq(%w[audio])
  end

  it 'names the video tier for a staged video' do
    stage('sample-video.mp4')

    expect(described_class.call(work_id: work_id)).to eq(%w[video])
  end

  it 'names no tier for a staged document' do
    stage('example.pdf')

    expect(described_class.call(work_id: work_id)).to eq([])
  end

  # The staging directory can be reaped; the deposit page must still render.
  it 'names no tier when nothing is staged' do
    expect(described_class.call(work_id: work_id)).to eq([])
  end
end
