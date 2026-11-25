# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TusStore do
  include_context 'with a scratch uploads root'

  let(:owner) { '000000002' }
  let(:record) { described_class.create(length: 10, filename: 'scan.tif', filetype: 'image/tiff', owner_id: owner) }

  describe '.create and .find' do
    it 'starts an empty upload that its owner can find' do
      found = described_class.find(record.id, owner_id: owner)

      expect(found).to have_attributes(length: 10, filename: 'scan.tif', filetype: 'image/tiff', offset: 0)
    end

    # The endpoint answers all three the same, so an id cannot be probed.
    it 'finds nothing for another user, an unknown id or a malformed one' do
      expect(described_class.find(record.id, owner_id: '000000005')).to be_nil
      expect(described_class.find(SecureRandom.hex(16), owner_id: owner)).to be_nil
      expect(described_class.find('../../etc/passwd', owner_id: owner)).to be_nil
    end

    it 'keeps only the basename of a client-sent filename' do
      sneaky = described_class.create(length: 1, filename: '..\\..\\evil.sh', filetype: '', owner_id: owner)

      expect(sneaky.filename).to eq('evil.sh')
    end
  end

  describe '#append' do
    it 'grows the upload and reports the new offset' do
      expect(record.append(StringIO.new('hello'), offset: 0)).to eq(5)
      expect(record.append(StringIO.new('world'), offset: 5)).to eq(10)
      expect(record).to be_complete
    end

    it 'refuses a chunk sent for an offset the upload is not at' do
      record.append(StringIO.new('hello'), offset: 0)

      expect { record.append(StringIO.new('again'), offset: 0) }.to raise_error(TusStore::OffsetMismatch)
    end

    it 'never writes past the declared length' do
      expect(record.append(StringIO.new('far too many bytes'), offset: 0)).to eq(10)
    end
  end

  describe '.claim' do
    it 'hands back nothing until every byte has landed' do
      record.append(StringIO.new('hello'), offset: 0)

      expect(described_class.claim(record.id, owner_id: owner)).to be_nil
    end

    it 'hands a finished upload over, and the upload leaves the store when it moves' do
      record.append(StringIO.new('helloworld'), offset: 0)
      upload = described_class.claim(record.id, owner_id: owner)
      dest = File.join(uploads_root, 'staged.tif')

      expect(upload).to have_attributes(original_filename: 'scan.tif', content_type: 'image/tiff', size: 10)
      upload.move_to(dest)

      expect(File.read(dest)).to eq('helloworld')
      expect(described_class.find(record.id, owner_id: owner)).to be_nil
    end

    it 'hands nothing to anyone but the owner' do
      record.append(StringIO.new('helloworld'), offset: 0)

      expect(described_class.claim(record.id, owner_id: '000000005')).to be_nil
      expect(described_class.claim(record.id, owner_id: nil)).to be_nil
    end
  end

  describe '.sweep' do
    it 'removes an upload idle past the expiry and keeps one still arriving' do
      stale = record
      fresh = described_class.create(length: 1, filename: 'b', filetype: '', owner_id: owner)
      old = 2.days.ago.to_time
      File.utime(old, old, stale.data_path)
      File.utime(old, old, stale.info_path)

      expect(described_class.sweep).to eq(1)
      expect(described_class.find(stale.id, owner_id: owner)).to be_nil
      expect(described_class.find(fresh.id, owner_id: owner)).to be_present
    end
  end

  describe '.parse_metadata' do
    it 'decodes base64 values and allows a key with no value' do
      header = "filename #{Base64.strict_encode64('café.tif')},is_confidential"

      expect(described_class.parse_metadata(header)).to eq('filename' => 'café.tif', 'is_confidential' => '')
    end

    it 'rejects a value that is not base64' do
      expect(described_class.parse_metadata('filename not-base64!')).to be_nil
    end
  end
end
