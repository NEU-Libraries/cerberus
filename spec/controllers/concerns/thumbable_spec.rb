# frozen_string_literal: true

require 'rails_helper'

describe Thumbable do
  let(:mock_thumbable_class) do
    Class.new do
      include Thumbable
      attr_accessor :params

      def initialize(params)
        @params = params
      end
    end
  end

  let(:file) { double('UploadedFile', tempfile: double('Tempfile', path: '/temp/path')) }
  let(:params_without_file) { { thumbnail: nil } }
  let(:params_with_file) { { thumbnail: file } }
  let(:permitted_params) { {} }

  describe 'add_thumbnail' do
    it 'returns nil when file is blank' do
      mock_thumbable = mock_thumbable_class.new(params_without_file)
      expect(mock_thumbable.add_thumbnail(permitted_params)).to be_nil
      expect(permitted_params).to be_empty
    end

    it 'calls ThumbnailCreator' do
      mock_thumbable = mock_thumbable_class.new(params_with_file)
      allow(ThumbnailCreator).to receive(:call).with(path: '/temp/path').and_return('123456789')
      mock_thumbable.add_thumbnail(permitted_params)
      expect(permitted_params[:thumbnail]).to eq('123456789')
    end
  end
end
