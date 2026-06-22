# frozen_string_literal: true

require 'rails_helper'

RSpec::Matchers.define_negated_matcher :not_have_enqueued_job, :have_enqueued_job

describe WorksController do
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml', nuid: '000000004') }
  let(:collection) { AtlasRb::Collection.create(community.id, '/home/cerberus/web/spec/fixtures/files/collection-mods.xml', nuid: '000000004') }
  let(:work) do
    created = AtlasRb::Work.create(collection.id, '/home/cerberus/web/spec/fixtures/files/work-mods.xml', nuid: '000000004')
    AtlasRb::Work.complete(created.id, nuid: '000000004')
    AtlasRb::Work.find(created.id, nuid: '000000004')
  end

  def stub_work_in_progress(work)
    in_progress = AtlasRb::Work.find(work.id, nuid: '000000004')
    in_progress['in_progress'] = true
    allow(AtlasRb::Work).to receive(:find).with(work.id).and_return(in_progress)
  end

  describe 'show' do
    render_views

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
    end

    it 'renders the show partial' do
      expect(work.title).to eq("What's New - How We Respond to Disaster, Episode 1")

      get :show, params: { id: work.id }
      expect(response).to render_template('works/show')
      expect(CGI.unescapeHTML(response.body)).to include(work.title)
    end

    context 'when the work is still in_progress' do
      render_views

      before { stub_work_in_progress(work) }

      it 'flashes the in-progress notice and hides the Edit link' do
        get :show, params: { id: work.id }
        expect(flash.now[:alert]).to eq(WorksController::IN_PROGRESS_NOTICE)
        expect(response.body).not_to match(%r{>\s*Edit\s*</a>})
      end
    end
  end

  describe 'downloads' do
    render_views

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
    end

    it 'renders the downloads turbo-frame without the layout' do
      get :downloads, params: { id: work.id }
      expect(response).to render_template('works/downloads')
      expect(response).not_to render_template(layout: 'application')
      expect(response.body).to include('downloads-modal-frame')
    end
  end

  describe 'create' do
    include ActiveJob::TestHelper

    let(:uuid_re) { /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/ }
    let(:user) { User.new(email: 'depositor@example.com', nuid: '000000004', groups: ['editors']) }

    before { sign_in user }

    it 'enqueues both jobs and redirects to the metadata page' do
      expect do
        post :create, params: { binary:    fixture_file_upload('image.png', 'image/png'),
                                parent_id: collection.id }
      end.to have_enqueued_job(IiifAssetsJob)
        .and have_enqueued_job(ContentCreationJob)
        .with(anything, anything, 'image.png', a_string_matching(uuid_re))

      expect(subject).to redirect_to action: :metadata, id: assigns(:work).id
    end

    it 'does not enqueue any enrichment job for unenriched uploads' do
      expect do
        post :create, params: { binary:    fixture_file_upload('plain.txt', 'text/plain'),
                                parent_id: collection.id }
      end.to have_enqueued_job(ContentCreationJob)
        .with(anything, anything, 'plain.txt', a_string_matching(uuid_re))
        .and not_have_enqueued_job(IiifAssetsJob)
        .and not_have_enqueued_job(PdfRenditionJob)
    end

    it 'routes PDF uploads to IiifAssetsJob for first-page thumbnails' do
      expect do
        post :create, params: { binary:    fixture_file_upload('example.pdf', 'application/pdf'),
                                parent_id: collection.id }
      end.to have_enqueued_job(IiifAssetsJob)
        .and have_enqueued_job(ContentCreationJob)
        .and not_have_enqueued_job(PdfRenditionJob)
    end

    it 'routes Word uploads to PdfRenditionJob with a derived rendition key' do
      docx_mime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      expect do
        post :create, params: { binary:    fixture_file_upload('example.docx', docx_mime),
                                parent_id: collection.id }
      end.to have_enqueued_job(PdfRenditionJob)
        .with(anything, anything, a_string_matching(uuid_re))
        .and have_enqueued_job(ContentCreationJob)
        .and not_have_enqueued_job(IiifAssetsJob)
    end

    it 'seeds the work title from the uploaded filename via the structure-safe MODS path' do
      post :create, params: { binary:    fixture_file_upload('image.png', 'image/png'),
                              parent_id: collection.id }
      work_id = assigns(:work).id
      expect(AtlasRb::Work.find(work_id).title).to eq('image.png')
    ensure
      AtlasRb::Work.tombstone(work_id) if work_id
    end

    context 'depositor attribution' do
      it 'explicitly attributes to the acting user when upload_as is missing (default)' do
        allow(AtlasRb::Work).to receive(:create).and_call_original

        post :create, params: { binary:    fixture_file_upload('image.png', 'image/png'),
                                parent_id: collection.id }

        expect(AtlasRb::Work).to have_received(:create).with(collection.id, depositor: user.nuid)
      end

      it 'explicitly attributes to the acting user when upload_as is "myself"' do
        allow(AtlasRb::Work).to receive(:create).and_call_original

        post :create, params: { binary:    fixture_file_upload('image.png', 'image/png'),
                                parent_id: collection.id,
                                upload_as: 'myself' }

        expect(AtlasRb::Work).to have_received(:create).with(collection.id, depositor: user.nuid)
      end

      it 'forwards the parent collection depositor when upload_as is "proxy"' do
        allow(AtlasRb::Work).to receive(:create).and_call_original

        post :create, params: { binary:    fixture_file_upload('image.png', 'image/png'),
                                parent_id: collection.id,
                                upload_as: 'proxy' }

        expect(AtlasRb::Work).to have_received(:create)
          .with(collection.id, depositor: collection['depositor'])
      end

      it 'attributes wholly to the acting-as target during an impersonation session' do
        # Pure impersonation: even with the radio defaulting to "myself", an
        # active acting-as session overrides — depositor is the target, never
        # the operating admin. (proxy_uploader-empty is enforced Atlas-side.)
        allow(AtlasRb::Work).to receive(:create).and_call_original

        post :create, params:  { binary:    fixture_file_upload('image.png', 'image/png'),
                                 parent_id: collection.id,
                                 upload_as: 'myself' },
                      session: { acting_as_nuid: '000000002' }

        expect(AtlasRb::Work).to have_received(:create).with(collection.id, depositor: '000000002')
      end
    end

    context 'weighted deposit fork' do
      it 'workspace branch deposits into the picked collection' do
        allow(AtlasRb::Work).to receive(:create).and_call_original

        post :create, params: { binary: fixture_file_upload('image.png', 'image/png'),
                                deposit_to: 'workspace', workspace_collection_id: collection.id }

        expect(AtlasRb::Work).to have_received(:create).with(collection.id, depositor: user.nuid)
      ensure
        AtlasRb::Work.tombstone(assigns(:work).id) if assigns(:work)
      end

      it 'publish branch homes the work in the personal root and links it into the showcase' do
        person = AtlasRb::Mash.new('nuid' => user.nuid, 'personal_root_id' => collection.id,
                                   'affiliated_community_ids' => ['comm1'])
        allow(AtlasRb::Person).to receive(:resolve).and_return([person])
        allow(ShowcaseFinder).to receive(:call).and_return('showcasenoid')
        allow(AtlasRb::Work).to receive(:add_linked_member)
        allow(AtlasRb::Work).to receive(:create).and_call_original

        post :create, params: { binary: fixture_file_upload('image.png', 'image/png'),
                                deposit_to: 'publish', publish_community_id: 'comm1',
                                publish_genre: 'Datasets' }

        expect(AtlasRb::Work).to have_received(:create).with(collection.id, depositor: user.nuid)
        expect(AtlasRb::Work).to have_received(:add_linked_member).with(assigns(:work).id, 'showcasenoid')
        expect(response).to redirect_to(metadata_work_path(assigns(:work).id))
      ensure
        AtlasRb::Work.tombstone(assigns(:work).id) if assigns(:work)
      end

      it 'publish branch degrades to the form when no personal root is available (Atlas gap)' do
        allow(AtlasRb::Person).to receive(:resolve).and_return([]) # no Person → no root
        allow(AtlasRb::Work).to receive(:create).and_call_original

        post :create, params: { binary: fixture_file_upload('image.png', 'image/png'),
                                deposit_to: 'publish', publish_community_id: 'comm1',
                                publish_genre: 'Datasets' }

        expect(AtlasRb::Work).not_to have_received(:create)
        expect(response).to redirect_to(new_work_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'new' do
    it 'presents the interface to upload a file' do
      get :new
      expect(response).to render_template('works/new')
    end

    context 'with publish targets' do
      render_views

      let(:user) { User.new(email: 'dep@example.com', nuid: '000000004', role: 'standard', groups: []) }

      before { sign_in user }

      it 'renders the publish card with the community picker and its showcase genres' do
        person = AtlasRb::Mash.new('nuid' => '000000004', 'personal_root_id' => 'root1',
                                   'affiliated_community_ids' => %w[comm1 comm2])
        allow(AtlasRb::Person).to receive(:resolve).and_return([person])
        allow(ShowcaseFinder).to receive(:call).and_return('Datasets' => 'dsnoid')
        allow(AtlasRb::Community).to receive(:find).with('comm1')
                                                   .and_return(AtlasRb::Mash.new('title' => 'My Community'))
        allow(AtlasRb::Community).to receive(:find).with('comm2')
                                                   .and_return(AtlasRb::Mash.new('title' => 'Other Community'))

        get :new

        expect(response.body).to include('Publish to my community')
        expect(response.body).to include('My Community') # community picker (size > 1)
        expect(response.body).to include('Other Community')
        expect(response.body).to include('Datasets') # showcase genre option
      end
    end
  end

  describe 'edit' do
    render_views

    let(:user) { User.new(email: 'test@example.com', password: 'password', groups: ['editors']) }

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'edit' => ['editors'] } }, nuid: '000000004')
      sign_in user
    end

    it 'renders the edit partial' do
      get :edit, params: { id: work.id }
      expect(response).to render_template('works/edit')
      expect(CGI.unescapeHTML(response.body)).to include(work.title)
    end

    it 'renders the Advanced tab: title-part fields, creator widgets, and read-only preserved names' do
      get :edit, params: { id: work.id }
      body = CGI.unescapeHTML(response.body)
      expect(body).to match(/<button[^>]*id="advanced-tab"/)
      expect(body).to include('Title parts')
      expect(body).to include('Personal creators')
      expect(body).to include('Corporate creators')
      expect(body).to include('Press + to add a personal creator') # stacked-input entry row
      expect(body).to include('Other names')                       # preserved-names panel
      expect(body).to include('Cohen, Daniel J.')    # an authority name, read-only
      expect(body).to include('Contributor')         # a preserved non-Creator role
    end

    it 'renders the cosmetic group name in the permissions dropdown, not the raw identifier' do
      Group.create!(raw: 'editors', cosmetic: 'Course Editors')

      get :edit, params: { id: work.id }
      body = CGI.unescapeHTML(response.body)

      expect(body).to match(%r{<option[^>]*>\s*Course Editors\s*</option>})
      expect(body).not_to match(%r{<option[^>]*>\s*editors\s*</option>})
    end

    context 'when the work is still in_progress' do
      before { stub_work_in_progress(work) }

      it 'redirects to show with the in-progress alert' do
        get :edit, params: { id: work.id }
        expect(response).to redirect_to(work_path(work.id))
        expect(flash[:alert]).to eq(WorksController::IN_PROGRESS_NOTICE)
      end
    end

    context 'audit history tab' do
      let(:history_envelope) do
        AtlasRb::Mash.new('resource_id' => work.id, 'events' => [])
      end
      let(:admin_user) do
        User.new(email: 'admin@example.com', nuid: '000000004', groups: [], role: 'admin')
      end

      before do
        allow(AtlasRb::Resource).to receive(:history).and_return(history_envelope)
      end

      it 'renders the History tab for Atlas :admin users (no group stuffing required)' do
        sign_in admin_user
        get :edit, params: { id: work.id }
        expect(response.body).to match(/<button[^>]*id="history-tab"/)
        expect(response.body).to include('Audit log')
      end

      it 'does not render the History tab for non-admin editors' do
        get :edit, params: { id: work.id }
        expect(response.body).not_to match(/<button[^>]*id="history-tab"/)
        expect(response.body).not_to include('Audit log')
      end
    end
  end

  describe 'metadata' do
    render_views

    let(:user) { User.new(email: 'test@example.com', password: 'password', groups: ['editors']) }

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'edit' => ['editors'] } }, nuid: '000000004')
      sign_in user
    end

    it 'renders the metadata form prefilled with the title and the permissions section' do
      get :metadata, params: { id: work.id }
      expect(response).to render_template('works/metadata')
      body = CGI.unescapeHTML(response.body)
      expect(body).to include('Respond')
      expect(body).to include('Keywords')
      expect(body).to include('General Permissions')
      expect(body).to include('Group Permissions')
      expect(body).to include('Press + to add a group permission')
      expect(body).to include('group-permissions#add')
    end

    it 'renders the Image Derivatives section when a staged image is probed' do
      allow(StagedImageProbe).to receive(:call).with(work_id: work.id)
                                               .and_return(StagedImageProbe::Result.new(path: '/x', width: 441, height: 588))

      get :metadata, params: { id: work.id }

      body = CGI.unescapeHTML(response.body)
      expect(body).to include('Image Derivatives')
      expect(body).to include('longest edge is')
      expect(body).to include('588')
      expect(body).to include('derivative_widths[small]')
      expect(body).to include('derivative-sizes')
    end

    it 'omits the Image Derivatives section for non-image deposits' do
      allow(StagedImageProbe).to receive(:call).and_return(nil)

      get :metadata, params: { id: work.id }

      expect(CGI.unescapeHTML(response.body)).not_to include('Image Derivatives')
    end
  end

  describe 'update_metadata' do
    let(:user) { User.new(email: 'test@example.com', password: 'password', nuid: '000000004', groups: ['editors']) }

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'edit' => ['editors'] } }, nuid: '000000004')
      sign_in user
    end

    it 'edits the main title without flattening the structured title parts' do
      patch :update_metadata, params: { id: work.id, work: { title: 'NewTitle', description: 'NewAbstract', keywords: %w[alpha beta] } }

      updated = AtlasRb::Work.find(work.id, nuid: '000000004')
      expect(updated.title).to start_with('NewTitle') # new main title
      expect(updated.title).to include('Respond')     # partName preserved
      expect(updated.title).to include('Episode')     # partNumber preserved
      expect(updated.description).to eq('NewAbstract')
      expect(subject).to redirect_to action: :show, id: work.id
    end

    it 'rejects a save with no keywords (keywords are mandatory)' do
      patch :update_metadata, params: { id: work.id, work: { title: 'NewTitle', description: 'NewAbstract' } }

      expect(flash[:alert]).to be_present
      expect(AtlasRb::Work.find(work.id, nuid: '000000004').title).not_to start_with('NewTitle')
    end

    describe 'opt-in download sizes' do
      include ActiveJob::TestHelper

      let(:descriptive) { { title: 'Sized', description: 'D', keywords: %w[alpha] } }

      before do
        allow(StagedImageProbe).to receive(:call).with(work_id: work.id)
                                                 .and_return(StagedImageProbe::Result.new(path: '/x', width: 441, height: 588))
      end

      it 'enqueues DepositDerivativesJob with the chosen integer widths and still saves the metadata' do
        expect do
          patch :update_metadata, params: { id: work.id, work: descriptive,
                                            derivative_widths: { small: '149', large: '503' } }
        end.to have_enqueued_job(DepositDerivativesJob).with(work.id, { small: 149, large: 503 })

        expect(AtlasRb::Work.find(work.id, nuid: '000000004').title).to start_with('Sized')
      end

      it 'skips invalid sizes with a flash but saves the metadata (derivatives never bounce the form)' do
        expect do
          patch :update_metadata, params: { id: work.id, work: descriptive,
                                            derivative_widths: { small: '500', large: '100' } }
        end.not_to have_enqueued_job(DepositDerivativesJob)

        expect(flash[:alert]).to include('Sizes must increase from small to medium to large.')
        expect(AtlasRb::Work.find(work.id, nuid: '000000004').title).to start_with('Sized')
      end

      it 'does nothing when the section was not submitted' do
        expect do
          patch :update_metadata, params: { id: work.id, work: descriptive }
        end.not_to have_enqueued_job(DepositDerivativesJob)
        expect(flash[:alert]).to be_nil
      end

      it 'skips with a flash when no staged image can be probed at save time' do
        allow(StagedImageProbe).to receive(:call).and_return(nil)

        expect do
          patch :update_metadata, params: { id: work.id, work: descriptive,
                                            derivative_widths: { small: '149' } }
        end.not_to have_enqueued_job(DepositDerivativesJob)
        expect(flash[:alert]).to include('no staged image')
      end
    end
  end

  describe 'update (Advanced tab)' do
    let(:user) { User.new(email: 'test@example.com', nuid: '000000004', groups: ['editors']) }

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'edit' => ['editors'] } }, nuid: '000000004')
      sign_in user
    end

    it 'adds a plain personal creator, preserving the authority-controlled names' do
      patch :update, params: { id:   work.id,
                               work: { form: 'advanced', personal_creators: [{ first: 'Jenny', last: 'Smith' }] } }

      doc = NEU::MODS::Document.parse(AtlasRb::Work.mods(work.id, 'xml', nuid: '000000004'))
      expect(doc.editable_personal_creators).to eq([{ given: 'Jenny', family: 'Smith' }])
      expect(doc.preserved_names.size).to eq(3) # Cohen, NU, Flynn untouched
      expect(subject).to redirect_to action: :show, id: work.id
    end

    it 'edits a structured title part (subtitle) in place, leaving the bare title' do
      patch :update, params: { id: work.id, work: { form: 'advanced', subtitle: 'A New Subtitle' } }

      doc = NEU::MODS::Document.parse(AtlasRb::Work.mods(work.id, 'xml', nuid: '000000004'))
      expect(doc.title_parts[:subtitle]).to eq('A New Subtitle')
      expect(doc.title_parts[:title]).to eq("What's New")
    end
  end

  describe 'tombstone' do
    let(:user) do
      User.new(email: 'staff@example.com', nuid: '000000002',
               groups: [Permissions::STAFF_EDIT_GROUP])
    end

    before do
      AtlasRb::Work.metadata(work.id,
                             { 'permissions' => { 'edit' => [Permissions::STAFF_EDIT_GROUP] } }, nuid: '000000004')
      sign_in user
    end

    it 'calls AtlasRb::Work.tombstone with the acting user nuid and redirects' do
      allow(AtlasRb::Work).to receive(:tombstone)
      post :tombstone, params: { id: work.id }
      expect(AtlasRb::Work).to have_received(:tombstone).with(work.id)
      expect(subject).to redirect_to(root_path)
    end
  end

  describe 'show on a tombstoned work' do
    render_views

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
      tombstoned = AtlasRb::Work.find(work.id, nuid: '000000004')
      tombstoned['tombstoned'] = true
      allow(AtlasRb::Work).to receive(:find).with(work.id).and_return(tombstoned)
    end

    it 'renders the gone template with status 410' do
      get :show, params: { id: work.id }
      expect(response).to render_template('errors/gone')
      expect(response).to have_http_status(:gone)
    end
  end

  describe 'show on a nonexistent work id' do
    render_views

    it 'renders the not_found template with status 404 instead of bubbling a Rails 500' do
      get :show, params: { id: 'does-not-exist-1234' }
      expect(response).to have_http_status(:not_found)
      expect(response).to render_template('errors/not_found')
      expect(CGI.unescapeHTML(response.body)).to include('404')
      expect(CGI.unescapeHTML(response.body)).to include('Not Found')
      # obj_type local picks up the controller name, so the prose is
      # resource-aware rather than the generic "page" default.
      expect(CGI.unescapeHTML(response.body)).to include('the work you requested was not found')
    end
  end

  # The personal-root trail is isolated on the private seam (the show stack makes
  # many Atlas calls; here we stub the two reads work_breadcrumbs makes and assert
  # which crumbs it builds).
  describe '#work_breadcrumbs (private)' do
    def work_result(parent_noid:, chain:)
      item = OpenStruct.new(id: 'wnoid', title: 'Coastal Survey', ancestor_chain: chain)
      allow(AtlasRb::Resource).to receive(:find).with('wnoid').and_return(OpenStruct.new(resource: item, klass: 'Work'))
      controller.instance_variable_set(:@work, AtlasRb::Mash.new('depositor' => '000000007'))
      parent_noid # documents intent; the chain's last node carries it
    end

    it 'trails community / Person / work for a work homed in the depositor Person root' do
      work_result(parent_noid: 'jane-root',
                  chain:       [{ 'noid' => 'people', 'klass' => 'Community', 'title' => 'People' },
                                { 'noid' => 'jane-root', 'klass' => 'Collection', 'title' => 'Personal Root' }])
      person = AtlasRb::Mash.new('id' => 'janenoid', 'display_name' => 'Jane Doe',
                                 'personal_root_id' => 'jane-root', 'affiliated_community_ids' => ['libnoid'])
      allow(AtlasRb::Person).to receive(:resolve).with(['000000007']).and_return([person])

      expect(controller).to receive(:breadcrumbs).with('libnoid', match: :exact)
      expect(controller).to receive(:breadcrumb).with('Faculty & Staff', community_people_path('libnoid'))
      expect(controller).to receive(:breadcrumb).with('Jane Doe', person_path('janenoid'))
      expect(controller).to receive(:add_breadcrumb_for).with('wnoid', 'Work', 'Coastal Survey')

      controller.send(:work_breadcrumbs, 'wnoid')
    end

    it 'keeps the plain structural trail for a workspace work (not in a personal root)' do
      work_result(parent_noid: 'col',
                  chain:       [{ 'noid' => 'col', 'klass' => 'Collection', 'title' => 'My Collection' }])
      # Depositor has a Person, but its root is not this work's parent.
      person = AtlasRb::Mash.new('id' => 'janenoid', 'personal_root_id' => 'jane-root',
                                 'affiliated_community_ids' => ['libnoid'])
      allow(AtlasRb::Person).to receive(:resolve).and_return([person])

      expect(controller).not_to receive(:breadcrumbs)
      expect(controller).to receive(:add_breadcrumb_for).with('col', 'Collection', 'My Collection')
      expect(controller).to receive(:add_breadcrumb_for).with('wnoid', 'Work', 'Coastal Survey')

      controller.send(:work_breadcrumbs, 'wnoid')
    end
  end
end
