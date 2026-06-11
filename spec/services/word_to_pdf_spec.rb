# frozen_string_literal: true

require 'rails_helper'

describe WordToPdf do
  describe 'call' do
    it 'drives libreconv with the timeout wrapper as the soffice command' do
      allow(Libreconv).to receive(:convert)

      result = described_class.call(source_path: '/staged/thesis.docx', target_path: '/staged/thesis.pdf')

      expect(result).to eq('/staged/thesis.pdf')
      expect(Libreconv).to have_received(:convert)
        .with('/staged/thesis.docx', '/staged/thesis.pdf', Rails.root.join('bin/soffice-timeout').to_s)
    end
  end

  describe 'real conversion' do
    # Free coverage once the image gains LibreOffice; harmless before.
    it 'converts the docx fixture to a real PDF' do
      skip 'soffice not installed in this image' unless described_class.available?

      Dir.mktmpdir do |tmp|
        target = File.join(tmp, 'example.pdf')
        described_class.call(source_path: Rails.root.join('spec/fixtures/files/example.docx').to_s,
                             target_path: target)
        expect(File.binread(target, 4)).to eq('%PDF')
      end
    end
  end

  describe 'available?' do
    before { allow(File).to receive(:exist?).and_call_original }

    it 'is true when the LibreOffice binary is installed' do
      allow(File).to receive(:exist?).with(described_class::SOFFICE_BIN).and_return(true)
      expect(described_class).to be_available
    end

    it 'is false when the image lacks LibreOffice' do
      allow(File).to receive(:exist?).with(described_class::SOFFICE_BIN).and_return(false)
      expect(described_class).not_to be_available
    end
  end
end
