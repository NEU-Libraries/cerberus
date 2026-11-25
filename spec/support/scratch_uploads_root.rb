# frozen_string_literal: true

# Points the uploads root at a throwaway directory for the example, so specs
# that stage or resume real files never touch the container's shared volume.
RSpec.shared_context 'with a scratch uploads root' do
  let(:uploads_root) { Dir.mktmpdir('uploads') }

  around do |example|
    config = Rails.application.config.x.cerberus
    original = config.uploads_root
    config.uploads_root = uploads_root
    example.run
  ensure
    config.uploads_root = original
    FileUtils.rm_rf(uploads_root)
  end

  # A finished resumable upload, as the browser leaves it before the form posts.
  def finished_tus_upload(owner:, filename: 'image.png', source: Rails.root.join('spec/fixtures/files/image.png'))
    bytes = File.binread(source)
    record = TusStore.create(length: bytes.bytesize, filename: filename, filetype: 'image/png', owner_id: owner)
    record.append(StringIO.new(bytes), offset: 0)
    record
  end
end
