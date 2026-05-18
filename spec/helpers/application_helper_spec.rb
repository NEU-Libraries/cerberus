# frozen_string_literal: true

require 'rails_helper'

describe ApplicationHelper do
  describe '#application_version' do
    it 'returns the VERSION constant' do
      stub_const('VERSION', '1.0.0')
      expect(helper.application_version).to eq('1.0.0')
    end
  end

  describe '#document_type_icon' do
    it 'maps Community to fa-users' do
      expect(helper.document_type_icon('Community')).to eq('fa-users')
    end

    it 'maps Collection to fa-folder-open' do
      expect(helper.document_type_icon('Collection')).to eq('fa-folder-open')
    end

    it 'falls back to fa-file for anything else' do
      expect(helper.document_type_icon('CoreFile')).to eq('fa-file')
    end
  end

  describe '#file_type_icon' do
    it 'matches image/* mimes' do
      expect(helper.file_type_icon('image/png')).to eq('fa-file-image')
    end

    it 'matches application/pdf exactly' do
      expect(helper.file_type_icon('application/pdf')).to eq('fa-file-pdf')
    end

    it 'matches Word/officedocument mimes' do
      expect(helper.file_type_icon('application/vnd.openxmlformats-officedocument.wordprocessingml.document'))
        .to eq('fa-file-word')
    end

    it 'falls back to fa-file for unknown mimes' do
      expect(helper.file_type_icon('application/x-made-up')).to eq('fa-file')
    end

    it 'tolerates nil input' do
      expect(helper.file_type_icon(nil)).to eq('fa-file')
    end
  end

  describe '#javascript_inline_importmap_tag' do
    it 'renders an inline importmap script tag' do
      html = helper.javascript_inline_importmap_tag('{"imports":{}}')
      expect(html).to include('<script')
      expect(html).to include('type="importmap"')
      expect(html).to include('{"imports":{}}')
    end
  end

  describe '#report_a_problem_url' do
    it 'builds a libanswers URL containing the document URL' do
      document = instance_double('Document')
      allow(helper).to receive(:document_url).with(document).and_return('https://example.test/communities/abc')

      url = helper.report_a_problem_url(document)

      expect(url).to start_with('https://northeastern.libanswers.com/form?')
      expect(url).to include('queue_id=5581')
      expect(url).to include('resource=https%3A%2F%2Fexample.test%2Fcommunities%2Fabc')
    end
  end

  describe '#document_url' do
    it 'uses the typed url helper when document.klass is a model class' do
      document = double('Document', klass: Community)
      allow(helper).to receive(:community_url).with(document).and_return('/communities/x')

      expect(helper.document_url(document)).to eq('/communities/x')
    end

    it 'falls back to polymorphic_url when document does not respond to klass' do
      document = double('Document')
      allow(helper).to receive(:polymorphic_url).with(document).and_return('/something/y')

      expect(helper.document_url(document)).to eq('/something/y')
    end

    it 'falls back to polymorphic_url when klass is nil' do
      document = double('Document', klass: nil)
      allow(helper).to receive(:polymorphic_url).with(document).and_return('/something/z')

      expect(helper.document_url(document)).to eq('/something/z')
    end
  end
end
