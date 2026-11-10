# frozen_string_literal: true

require 'rails_helper'

describe AtlasWrite do
  let(:host) { Class.new { include AtlasWrite }.new }

  describe '#with_tmp_xml' do
    it 'hands the block a path holding the XML' do
      host.with_tmp_xml('<mods/>') { |path| expect(File.read(path)).to eq('<mods/>') }
    end

    it 'removes the file once the block returns' do
      path = host.with_tmp_xml('<mods/>') { |p| p }
      expect(File).not_to exist(path)
    end

    it 'removes the file when the block raises' do
      path = nil
      upload = lambda do |p|
        path = p
        raise Faraday::ConnectionFailed, 'down'
      end
      expect { host.with_tmp_xml('<mods/>', &upload) }.to raise_error(Faraday::ConnectionFailed)
      expect(File).not_to exist(path)
    end

    it 'gives each write a file of its own' do
      paths = Array.new(2) { host.with_tmp_xml('<mods/>') { |p| p } }
      expect(paths.uniq.size).to eq(2)
    end
  end

  describe '#merge_mods!' do
    it 'uploads the merged MODS and leaves no file behind' do
      allow(AtlasRb::Resource).to receive(:mods).and_return('<mods/>')
      allow(Metadata::MODSMerge).to receive_messages(call: '<mods>merged</mods>', unchanged?: false)
      uploaded = nil
      allow(AtlasRb::Resource).to receive(:put_mods) { |_id, path, **| uploaded = [path, File.read(path)] }

      host.merge_mods!('w-1', origin: 'spec', title: 'T')

      expect(uploaded.last).to eq('<mods>merged</mods>')
      expect(File).not_to exist(uploaded.first)
    end
  end
end
