# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'reset:clean' do
  let(:uploads) { Dir.mktmpdir('reset-uploads') }
  let(:images) { Dir.mktmpdir('reset-images') }
  let(:solr) { instance_double(RSolr::Client, delete_by_query: nil, commit: nil) }

  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == 'reset:clean' }
  end

  before do
    @orig = Rails.application.config.x.cerberus.uploads_root
    @orig_images = Rails.application.config.x.cerberus.derivatives_root
    Rails.application.config.x.cerberus.uploads_root = uploads
    Rails.application.config.x.cerberus.derivatives_root = images
    allow(Rails.env).to receive(:development?).and_return(true)
    allow(Blacklight.default_index).to receive(:connection).and_return(solr)
    allow(AtlasRb::Reset).to receive(:clean)
    Rake::Task['reset:clean'].reenable
  end

  after do
    Rails.application.config.x.cerberus.uploads_root = @orig
    Rails.application.config.x.cerberus.derivatives_root = @orig_images
    FileUtils.rm_rf([uploads, images])
  end

  it 'empties the upload staging area but keeps the directory' do
    FileUtils.mkdir_p(File.join(uploads, 'abc1234'))
    File.write(File.join(uploads, 'abc1234', 'old.jpg'), 'stale')

    Rake::Task['reset:clean'].invoke

    expect(Dir.exist?(uploads)).to be(true)
    expect(Dir.children(uploads)).to be_empty
  end

  it 'empties the JP2 derivatives, which nothing references after a reset' do
    File.write(File.join(images, 'open-1234.jp2'), 'orphan')

    Rake::Task['reset:clean'].invoke

    expect(Dir.exist?(images)).to be(true)
    expect(Dir.children(images)).to be_empty
  end
end
