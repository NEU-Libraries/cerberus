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

    it 'maps Person to fa-user' do
      expect(helper.document_type_icon('Person')).to eq('fa-user')
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

  describe '#document_status_icons' do
    it 'renders a lock for a non-public document' do
      html = helper.document_status_icons('read_access_group_ssim' => ['northeastern:drs:repository:staff'])
      expect(html).to include('fa-lock').and include('Not public')
      expect(html).not_to include('fa-link')
    end

    it 'renders nothing for a public document outside any container' do
      expect(helper.document_status_icons('read_access_group_ssim' => ['public'])).to be_nil
    end

    it 'renders a link when the document is linked into the container being viewed' do
      assign(:collection, double(valkyrie_id: 'uuid-here'))
      html = helper.document_status_icons('read_access_group_ssim'  => ['public'],
                                          'a_linked_member_of_ssim' => ['id-uuid-here'])
      expect(html).to include('fa-link').and include('Linked here')
      expect(html).not_to include('fa-lock')
    end

    it 'does not render a link for a member of a different container' do
      assign(:collection, double(valkyrie_id: 'uuid-here'))
      expect(helper.document_status_icons('read_access_group_ssim'  => ['public'],
                                          'a_linked_member_of_ssim' => ['id-other'])).to be_nil
    end

    it 'does not render a link with no container context (catalog index)' do
      expect(helper.document_status_icons('read_access_group_ssim'  => ['public'],
                                          'a_linked_member_of_ssim' => ['id-uuid-here'])).to be_nil
    end
  end

  describe '#pill_label' do
    it 'labels an embargoed document "Embargoed" ahead of Featured/People/type' do
      doc = SolrDocument.new(id: '1', internal_resource_tesim: ['Work'], featured_bsi: true,
                             embargo_release_date_dtsi: (Date.current + 30).to_s)
      expect(helper.pill_label(doc)).to eq('Embargoed')
    end

    it 'labels a featured document "Featured" when not embargoed' do
      doc = SolrDocument.new(id: '1', internal_resource_tesim: ['Collection'], featured_bsi: true)
      expect(helper.pill_label(doc)).to eq('Featured')
    end

    it 'labels the synthetic Faculty & Staff row "People"' do
      doc = SolrDocument.new(id: '1', internal_resource_tesim: ['Community'], people_browse_bsi: true)
      expect(helper.pill_label(doc)).to eq('People')
    end

    it 'falls back to the resource type' do
      doc = SolrDocument.new(id: '1', internal_resource_tesim: ['Collection'])
      expect(helper.pill_label(doc)).to eq('Collection')
    end
  end

  describe '#embargo_notice' do
    it 'renders the release date for an embargoed document' do
      doc = SolrDocument.new(id: '1', embargo_release_date_dtsi: '2028-07-16')
      html = helper.embargo_notice(doc)
      expect(html).to include('Contents available July 16, 2028')
      expect(html).to include('text-danger')
    end

    it 'renders nothing for a non-embargoed document' do
      expect(helper.embargo_notice(SolrDocument.new(id: '1'))).to be_nil
    end

    it 'renders nothing once the embargo has lapsed' do
      doc = SolrDocument.new(id: '1', embargo_release_date_dtsi: (Date.current - 1).to_s)
      expect(helper.embargo_notice(doc)).to be_nil
    end
  end
end
