# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UploadStaging do
  let(:stager) { Class.new { include UploadStaging }.new }
  let(:file) do
    instance_double(ActionDispatch::Http::UploadedFile,
                    original_filename: 'scan.tif', tempfile: instance_double(Tempfile, path: '/tmp/x'))
  end

  # A full, missing or read-only uploads volume must read as an outage, so the
  # depositor is told to try again rather than shown the generic error page.
  it 'reports a volume that will not take the file as a storage outage' do
    allow(FileUtils).to receive(:mkdir_p).and_raise(Errno::ENOSPC)

    expect { stager.send(:stage_upload, file, 'abc123') }.to raise_error(Outage::StorageUnavailable)
  end
end
