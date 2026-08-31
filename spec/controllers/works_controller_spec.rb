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

  # Widen the containers above the Work before making it public — see
  # VisibilityFixtures (spec/support).
  def publicize_chain! = publicize_ancestry!(community: community, collection: collection)

  def stub_work_in_progress(work)
    in_progress = AtlasRb::Work.find(work.id, nuid: '000000004')
    in_progress['in_progress'] = true
    allow(AtlasRb::Work).to receive(:find).with(work.id).and_return(in_progress)
  end

  describe 'show' do
    render_views

    before do
      publicize_chain!
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
    end

    it 'renders the show partial' do
      expect(work.title).to eq("What's New - How We Respond to Disaster, Episode 1")

      get :show, params: { id: work.id }
      expect(response).to render_template('works/show')
      expect(CGI.unescapeHTML(response.body)).to include(work.title)
    end

    # The preview is the largest thing on the page and carried no alt at all,
    # so a screen reader announced an unlabelled image. Nothing in the
    # repository describes what a preview depicts, so it is named by its work.
    context 'the preview image' do
      it 'names the work it previews' do
        AtlasRb::Work.set_thumbnails(work.id, thumbnail: 't', thumbnail_2x: 't2',
                                              preview: 'http://example.com/preview.jpg')

        get :show, params: { id: work.id }

        # The fixture title carries an apostrophe, which HAML escapes.
        expect(CGI.unescapeHTML(response.body)).to include(%(alt="Preview of #{work.title}"))
      end

      # The no-preview placeholder is a decorative icon, already aria-hidden —
      # it must not gain an announced label in its place.
      it 'renders the placeholder with nothing to announce when there is no preview' do
        get :show, params: { id: work.id }

        expect(response.body).not_to include('alt="Preview of')
        expect(response.body).to include('fa-regular fa-image')
      end
    end

    context 'Edit affordance is gated on the :edit ability' do
      it 'is hidden from a signed-in user who cannot edit' do
        sign_in User.new(email: 'viewer@example.com', nuid: '000000005', role: 'standard', groups: [])
        get :show, params: { id: work.id }
        expect(response.body).not_to include(%(href="#{edit_work_path(work.id)}"))
      end

      it 'is shown to a user who can edit' do
        AtlasRb::Work.metadata(work.id, { 'permissions' => { 'read' => ['public'], 'edit' => ['editors'] } },
                               nuid: '000000004')
        sign_in User.new(email: 'ed@example.com', nuid: '000000002', groups: ['editors'])
        get :show, params: { id: work.id }
        expect(response.body).to include(%(href="#{edit_work_path(work.id)}"))
      end
    end

    context 'when the work is still in_progress' do
      render_views

      before { stub_work_in_progress(work) }

      # Signed in as staff: an unfinished deposit is refused outright to everyone
      # but its depositor, staff and admins, so the notice is only ever read by
      # someone who can act on it.
      it 'flashes the in-progress notice and hides the Edit link' do
        sign_in User.new(email: 'staff@example.com', nuid: '000000002', groups: [Permissions::STAFF_EDIT_GROUP])

        get :show, params: { id: work.id }

        expect(flash.now[:alert]).to eq(WorksController::IN_PROGRESS_NOTICE)
        expect(response.body).not_to match(%r{>\s*Edit\s*</a>})
      end

      it '404s a visitor who may not see an unfinished deposit' do
        get :show, params: { id: work.id }
        expect(response).to have_http_status(:not_found)
      end
    end

    it 'does not show the embargo banner when there is no embargo' do
      get :show, params: { id: work.id }
      expect(response.body).not_to include('under embargo')
    end

    context 'when the work is under an active embargo' do
      before do
        AtlasRb::Work.metadata(work.id,
                               { 'permissions' => { 'read' => ['public'], 'embargo' => (Date.current + 30).to_s } },
                               nuid: '000000004')
      end

      it 'shows the embargo banner with the release date, for any viewer' do
        get :show, params: { id: work.id }
        expect(response.body).to include('under embargo')
        expect(response.body).to include((Date.current + 30).strftime('%B %-d, %Y'))
      end
    end
  end

  describe 'downloads' do
    render_views

    before do
      publicize_chain!
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'read' => ['public'] } }, nuid: '000000004')
    end

    it 'renders the downloads turbo-frame without the layout' do
      get :downloads, params: { id: work.id }
      expect(response).to render_template('works/downloads')
      expect(response).not_to render_template(layout: 'application')
      expect(response.body).to include('downloads-modal-frame')
    end

    context 'when the work is under an active embargo' do
      before do
        AtlasRb::Work.metadata(work.id,
                               { 'permissions' => { 'read' => ['public'], 'embargo' => (Date.current + 30).to_s } },
                               nuid: '000000004')
        AtlasRb::Blob.create(work.id, '/home/cerberus/web/spec/fixtures/files/image.png', 'image.png', nuid: '000000004')
      end

      it 'withholds downloads from a guest' do
        get :downloads, params: { id: work.id }
        expect(response.body).to include('No downloads available.')
      end

      it 'withholds downloads from a signed-in non-staff user' do
        sign_in User.new(email: 'viewer@example.com', nuid: '000000005', role: 'standard', groups: ['editors'])
        get :downloads, params: { id: work.id }
        expect(response.body).to include('No downloads available.')
      end

      it 'allows downloads for a staff (grouper) member' do
        sign_in User.new(email: 'staff@example.com', nuid: '000000002', groups: [Permissions::STAFF_EDIT_GROUP])
        get :downloads, params: { id: work.id }
        expect(response.body).not_to include('No downloads available.')
      end

      it 'allows downloads for an Admin' do
        sign_in User.new(email: 'admin@example.com', nuid: '000000004', groups: [], role: 'admin')
        get :downloads, params: { id: work.id }
        expect(response.body).not_to include('No downloads available.')
      end
    end
  end

  describe 'create' do
    include ActiveJob::TestHelper

    let(:uuid_re) { /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/ }
    let(:user) { User.new(email: 'depositor@example.com', nuid: '000000004', groups: ['editors']) }

    before { sign_in user }

    it 'enqueues both jobs and redirects to the metadata page' do
      expect do
        post :create, params: { binary:        fixture_file_upload('image.png', 'image/png'),
                                collection_id: collection.id }
      end.to have_enqueued_job(IiifAssetsJob)
        .and have_enqueued_job(ContentCreationJob)
        .with(anything, anything, 'image.png', a_string_matching(uuid_re), complete_work: false)

      expect(subject).to redirect_to action: :metadata, id: assigns(:work).id
    end

    # complete_work: false is what keeps the deposit in_progress until its
    # depositor saves the metadata page — and hidden from the public until then.
    it 'leaves the work for its depositor to complete rather than completing on ingest' do
      post :create, params: { binary:        fixture_file_upload('image.png', 'image/png'),
                              collection_id: collection.id }

      expect(ContentCreationJob).to have_been_enqueued.with(anything, anything, anything, anything,
                                                            complete_work: false)
    end

    it 'does not enqueue any enrichment job for unenriched uploads' do
      expect do
        post :create, params: { binary:        fixture_file_upload('plain.txt', 'text/plain'),
                                collection_id: collection.id }
      end.to have_enqueued_job(ContentCreationJob)
        .with(anything, anything, 'plain.txt', a_string_matching(uuid_re), complete_work: false)
        .and not_have_enqueued_job(IiifAssetsJob)
        .and not_have_enqueued_job(PdfRenditionJob)
    end

    it 'routes PDF uploads to IiifAssetsJob for first-page thumbnails' do
      expect do
        post :create, params: { binary:        fixture_file_upload('example.pdf', 'application/pdf'),
                                collection_id: collection.id }
      end.to have_enqueued_job(IiifAssetsJob)
        .and have_enqueued_job(ContentCreationJob)
        .and not_have_enqueued_job(PdfRenditionJob)
    end

    it 'routes Word uploads to PdfRenditionJob with a derived rendition key' do
      docx_mime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      expect do
        post :create, params: { binary:        fixture_file_upload('example.docx', docx_mime),
                                collection_id: collection.id }
      end.to have_enqueued_job(PdfRenditionJob)
        .with(anything, anything, a_string_matching(uuid_re))
        .and have_enqueued_job(ContentCreationJob)
        .and not_have_enqueued_job(IiifAssetsJob)
    end

    it 'rejects an A/V upload outside the safe codec set without creating a work' do
      allow(Ffprobe).to receive(:available?).and_return(true)
      allow(Ffprobe).to receive(:safe?).and_return(false)
      allow(Marcel::MimeType).to receive(:for).and_return('video/quicktime')

      expect(AtlasRb::Work).not_to receive(:create)
      post :create, params: { binary:        fixture_file_upload('image.png', 'video/quicktime'),
                              collection_id: collection.id }

      expect(response).to redirect_to(new_collection_work_path(collection.id))
      expect(flash[:alert]).to eq(described_class::UNSUPPORTED_AV)
    end

    it 'seeds the work title from the uploaded filename via the structure-safe MODS path' do
      post :create, params: { binary:        fixture_file_upload('image.png', 'image/png'),
                              collection_id: collection.id }
      work_id = assigns(:work).id
      expect(AtlasRb::Work.find(work_id).title).to eq('image.png')
    ensure
      AtlasRb::Work.tombstone(work_id) if work_id
    end

    context 'depositor attribution' do
      it 'explicitly attributes to the acting user when upload_as is missing (default)' do
        allow(AtlasRb::Work).to receive(:create).and_call_original

        post :create, params: { binary:        fixture_file_upload('image.png', 'image/png'),
                                collection_id: collection.id }

        expect(AtlasRb::Work).to have_received(:create).with(collection.id, depositor: user.nuid)
      end

      it 'explicitly attributes to the acting user when upload_as is "myself"' do
        allow(AtlasRb::Work).to receive(:create).and_call_original

        post :create, params: { binary:        fixture_file_upload('image.png', 'image/png'),
                                collection_id: collection.id,
                                upload_as:     'myself' }

        expect(AtlasRb::Work).to have_received(:create).with(collection.id, depositor: user.nuid)
      end

      it 'forwards the parent collection depositor when upload_as is "proxy"' do
        allow(AtlasRb::Work).to receive(:create).and_call_original

        post :create, params: { binary:        fixture_file_upload('image.png', 'image/png'),
                                collection_id: collection.id,
                                upload_as:     'proxy' }

        expect(AtlasRb::Work).to have_received(:create)
          .with(collection.id, depositor: collection['depositor'])
      end

      it 'attributes wholly to the acting-as target during an impersonation session' do
        # Pure impersonation: even with the radio defaulting to "myself", an
        # active acting-as session overrides — depositor is the target, never
        # the operating admin. (proxy_uploader-empty is enforced Atlas-side.)
        allow(AtlasRb::Work).to receive(:create).and_call_original

        post :create, params:  { binary:        fixture_file_upload('image.png', 'image/png'),
                                 collection_id: collection.id,
                                 upload_as:     'myself' },
                      session: { acting_as_nuid: '000000002' }

        expect(AtlasRb::Work).to have_received(:create).with(collection.id, depositor: '000000002')
      end
    end

    # Placement comes from the route; promotion is an orthogonal flag on top of
    # it. The Work therefore lands in the destination either way — promotion
    # never relocates it, and a promotion that can't be honoured leaves the
    # deposit standing.
    context 'promotion to a community showcase' do
      # publish_offered? requires the destination to BE the depositor's own root.
      def stub_person_rooted_at(collection_id)
        person = AtlasRb::Mash.new('nuid' => user.nuid, 'personal_root_id' => collection_id,
                                   'affiliated_community_ids' => ['comm1'])
        allow(AtlasRb::Person).to receive(:resolve).and_return([person])
      end

      it 'links the work into the showcase while leaving it in the destination' do
        stub_person_rooted_at(collection.id)
        allow(ShowcaseFinder).to receive(:call).and_return('showcasenoid')
        allow(AtlasRb::System::Work).to receive(:add_linked_member)
        allow(AtlasRb::Work).to receive(:create).and_call_original

        post :create, params: { binary: fixture_file_upload('image.png', 'image/png'),
                                collection_id: collection.id, publish: '1',
                                publish_community_id: 'comm1', publish_genre: 'Datasets' }

        expect(AtlasRb::Work).to have_received(:create).with(collection.id, depositor: user.nuid)
        expect(AtlasRb::System::Work).to have_received(:add_linked_member)
          .with(assigns(:work).id, 'showcasenoid', on_behalf_of: user.nuid)
        expect(response).to redirect_to(metadata_work_path(assigns(:work).id))
      ensure
        AtlasRb::Work.tombstone(assigns(:work).id) if assigns(:work)
      end

      it 'still saves the work when Atlas forbids the showcase link (scoping safety net)' do
        stub_person_rooted_at(collection.id)
        allow(ShowcaseFinder).to receive(:call).and_return('showcasenoid')
        allow(AtlasRb::System::Work).to receive(:add_linked_member).and_raise(AtlasRb::ForbiddenError.new('forbidden'))
        allow(AtlasRb::Work).to receive(:create).and_call_original

        post :create, params: { binary: fixture_file_upload('image.png', 'image/png'),
                                collection_id: collection.id, publish: '1',
                                publish_community_id: 'comm1', publish_genre: 'Datasets' }

        expect(AtlasRb::Work).to have_received(:create).with(collection.id, depositor: user.nuid)
        expect(response).to redirect_to(metadata_work_path(assigns(:work).id))
        expect(flash[:notice]).to eq(described_class::PUBLISH_LINK_FAILED)
      ensure
        AtlasRb::Work.tombstone(assigns(:work).id) if assigns(:work)
      end

      # Atlas refuses a derivative tier more visible than its Work. The collection
      # form and the visibility cascade both keep the default within its
      # collection, so this is a backstop — but it used to reach the Rails error
      # page, abandoning a Work and a staged file with nothing said to anyone.
      it 'still saves the work when Atlas refuses the collection’s derivative default' do
        allow(Sentinel).to receive(:apply_default)
          .and_raise(AtlasRb::DerivativePermissionsError.new('a derivative tier cannot be more visible than the Work'))

        post :create, params: { binary:        fixture_file_upload('image.png', 'image/png'),
                                collection_id: collection.id }

        expect(response).to redirect_to(metadata_work_path(assigns(:work).id))
        expect(flash[:notice]).to eq(described_class::DERIVATIVE_DEFAULT_FAILED)
      ensure
        AtlasRb::Work.tombstone(assigns(:work).id) if assigns(:work)
      end

      # Promotion is only on offer from the depositor's own root, so a forged
      # request from anywhere else deposits normally and promotes nothing —
      # that is what stops a Work being promoted out of a collection that
      # isn't the depositor's.
      it 'deposits but does not promote when the destination is not the depositor’s root' do
        stub_person_rooted_at('some-other-root')
        allow(AtlasRb::System::Work).to receive(:add_linked_member)
        allow(AtlasRb::Work).to receive(:create).and_call_original

        post :create, params: { binary: fixture_file_upload('image.png', 'image/png'),
                                collection_id: collection.id, publish: '1',
                                publish_community_id: 'comm1', publish_genre: 'Datasets' }

        expect(AtlasRb::Work).to have_received(:create).with(collection.id, depositor: user.nuid)
        expect(AtlasRb::System::Work).not_to have_received(:add_linked_member)
        expect(flash[:notice]).to eq(described_class::PUBLISH_LINK_FAILED)
      ensure
        AtlasRb::Work.tombstone(assigns(:work).id) if assigns(:work)
      end

      it 'deposits without promoting when the box is unticked' do
        stub_person_rooted_at(collection.id)
        allow(AtlasRb::System::Work).to receive(:add_linked_member)
        allow(AtlasRb::Work).to receive(:create).and_call_original

        post :create, params: { binary:        fixture_file_upload('image.png', 'image/png'),
                                collection_id: collection.id }

        expect(AtlasRb::Work).to have_received(:create).with(collection.id, depositor: user.nuid)
        expect(AtlasRb::System::Work).not_to have_received(:add_linked_member)
        expect(flash[:notice]).to eq('File uploaded — please review the metadata.')
      ensure
        AtlasRb::Work.tombstone(assigns(:work).id) if assigns(:work)
      end
    end

    # Nobody approves a work onto a showcase, so staff read the list afterwards
    # to catch one that belongs on no showcase or sits under the wrong genre.
    # The refusals matter most: they are invisible to everyone but the depositor,
    # who sees one flash and moves on.
    context 'the showcase-promotion ledger' do
      def stub_person_rooted_at(collection_id)
        person = AtlasRb::Mash.new('nuid' => user.nuid, 'personal_root_id' => collection_id,
                                   'affiliated_community_ids' => ['comm1'])
        allow(AtlasRb::Person).to receive(:resolve).and_return([person])
      end

      before do
        # Scoped to the one noid: a blanket stub also intercepts the lookup that
        # builds the fixture community, which then has no id to parent under.
        allow(AtlasRb::Community).to receive(:find).and_call_original
        allow(AtlasRb::Community).to receive(:find).with('comm1')
                                                   .and_return(AtlasRb::Mash.new('id'    => 'comm1',
                                                                                 'title' => 'Marine Science'))
        allow(AtlasRb::Work).to receive(:create).and_call_original
      end

      def deposit(**overrides)
        post :create, params: { binary: fixture_file_upload('image.png', 'image/png'),
                                collection_id: collection.id, publish: '1',
                                publish_community_id: 'comm1', publish_genre: 'Datasets' }.merge(overrides)
      end

      it 'records a promotion with the community, the genre and the uploaded filename' do
        stub_person_rooted_at(collection.id)
        allow(ShowcaseFinder).to receive(:call).and_return('showcasenoid')
        allow(AtlasRb::System::Work).to receive(:add_linked_member)

        expect { deposit }.to change(AdminNotice, :count).by(1)

        notice = AdminNotice.last
        expect(notice.kind).to eq('showcase_promotion')
        expect(notice.subject).to include('Datasets')
        expect(notice.actor_nuid).to eq(user.nuid)
        expect(notice.subject_noid).to eq(assigns(:work).id)
        expect(notice.detail(:outcome)).to eq('promoted')
        expect(notice.detail(:community_name)).to eq('Marine Science')
        expect(notice.detail(:showcase_noid)).to eq('showcasenoid')
        # The filename is the wrong-genre signal — a .pptx under "Datasets"
        # reads wrong at a glance.
        expect(notice.detail(:work_title)).to eq('image.png')
      ensure
        AtlasRb::Work.tombstone(assigns(:work).id) if assigns(:work)
      end

      it 'records a refusal when Atlas forbids the link' do
        stub_person_rooted_at(collection.id)
        allow(ShowcaseFinder).to receive(:call).and_return('showcasenoid')
        allow(AtlasRb::System::Work).to receive(:add_linked_member).and_raise(AtlasRb::ForbiddenError.new('nope'))

        expect { deposit }.to change(AdminNotice, :count).by(1)

        expect(AdminNotice.last.detail(:outcome)).to eq('refused')
        expect(AdminNotice.last.detail(:reason)).to eq('atlas_forbidden')
      ensure
        AtlasRb::Work.tombstone(assigns(:work).id) if assigns(:work)
      end

      it 'records a refusal when the destination is not the depositor’s root' do
        stub_person_rooted_at('some-other-root')
        allow(AtlasRb::System::Work).to receive(:add_linked_member)

        expect { deposit }.to change(AdminNotice, :count).by(1)

        expect(AdminNotice.last.detail(:reason)).to eq('not_personal_root')
      ensure
        AtlasRb::Work.tombstone(assigns(:work).id) if assigns(:work)
      end

      it 'records a refusal when the genre has no showcase the depositor can see' do
        stub_person_rooted_at(collection.id)
        allow(ShowcaseFinder).to receive(:call).and_return(nil)
        allow(AtlasRb::System::Work).to receive(:add_linked_member)

        expect { deposit }.to change(AdminNotice, :count).by(1)

        expect(AdminNotice.last.detail(:reason)).to eq('no_showcase')
        expect(AdminNotice.last.detail(:genre)).to eq('Datasets')
      ensure
        AtlasRb::Work.tombstone(assigns(:work).id) if assigns(:work)
      end

      it 'records nothing when the deposit asked for no promotion' do
        stub_person_rooted_at(collection.id)

        expect { deposit(publish: '0') }.not_to change(AdminNotice, :count)
      ensure
        AtlasRb::Work.tombstone(assigns(:work).id) if assigns(:work)
      end
    end
  end

  describe 'new' do
    # #new now requires authentication (audit G3, deny-by-default macro).
    let(:user) { User.new(email: 'dep@example.com', nuid: '000000004', role: 'standard', groups: []) }

    before { sign_in user }

    it 'presents the interface to upload a file' do
      get :new, params: { collection_id: collection.id }
      expect(response).to render_template('works/new')
    end

    context 'promotion offer' do
      render_views

      let(:user) { User.new(email: 'dep@example.com', nuid: '000000004', role: 'standard', groups: []) }

      before do
        sign_in user
        allow(ShowcaseFinder).to receive(:call).and_return('Datasets' => 'dsnoid')
        # Pass through by default: the fixture chain looks up real containers,
        # and a purely `.with`-constrained stub would reject those calls.
        allow(AtlasRb::Community).to receive(:find).and_call_original
        allow(AtlasRb::Community).to receive(:find).with('comm1')
                                                   .and_return(AtlasRb::Mash.new('title' => 'My Community'))
        allow(AtlasRb::Community).to receive(:find).with('comm2')
                                                   .and_return(AtlasRb::Mash.new('title' => 'Other Community'))
      end

      def stub_person_rooted_at(collection_id)
        person = AtlasRb::Mash.new('nuid' => '000000004', 'personal_root_id' => collection_id,
                                   'affiliated_community_ids' => %w[comm1 comm2])
        allow(AtlasRb::Person).to receive(:resolve).and_return([person])
      end

      it 'offers promotion with the community picker and genres from the depositor’s own root' do
        stub_person_rooted_at(collection.id)

        get :new, params: { collection_id: collection.id }

        expect(response.body).to include('Also promote to a community showcase')
        expect(response.body).to include('My Community') # community picker (size > 1)
        expect(response.body).to include('Other Community')
        expect(response.body).to include('Datasets') # showcase genre option
      end

      # Anywhere but the depositor's own root, promotion isn't on the table —
      # that restriction is what keeps a promoted Work in their own space.
      it 'does not offer promotion from a collection that is not the depositor’s root' do
        stub_person_rooted_at('some-other-root')

        get :new, params: { collection_id: collection.id }

        expect(response.body).not_to include('Also promote to a community showcase')
      end
    end
  end

  describe 'edit' do
    render_views

    let(:user) { User.new(email: 'test@example.com', password: 'password', groups: ['editors']) }

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'edit' => ['editors'] } }, nuid: '000000004')
      # Readable as well as editable. Atlas gates reads on the resource's own ACL,
      # and this fixture user carries no NUID, so the ACL read is made as the
      # guest — a private resource comes back as nothing and the page 404s before
      # the edit gate runs. Publicizing after the edit write, because
      # publicize_resource! reads the current envelope and carries the grant
      # through; the reverse order would drop it.
      publicize_chain!
      publicize_resource!(AtlasRb::Work, work, '000000004')
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

    # The in-progress gate is a before_action and the action needs the same
    # payload, so the read is memoized rather than made twice.
    it 'reads the Work from Atlas once' do
      loaded = AtlasRb::Work.find(work.id, nuid: '000000004')
      expect(AtlasRb::Work).to receive(:find).once.with(work.id).and_return(loaded)

      get :edit, params: { id: work.id }

      expect(response).to have_http_status(:ok)
    end

    # The Metadata and Advanced tabs parse the same document — one for the bare
    # title, the other for its structured parts — and #edit loads both.
    it 'reads the MODS from Atlas once' do
      xml = AtlasRb::Work.mods(work.id, 'xml', nuid: '000000004')
      expect(AtlasRb::Work).to receive(:mods).once.with(work.id, 'xml').and_return(xml)

      get :edit, params: { id: work.id }

      expect(response).to have_http_status(:ok)
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
      # Readable as well as editable — see the note in #edit above. This fixture
      # user carries no NUID, so the ACL read is made as the guest.
      publicize_chain!
      publicize_resource!(AtlasRb::Work, work, '000000004')
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

    # A Word manual line break (U+000B) has no XML 1.0 representation, so it used
    # to vanish when Nokogiri serialized the text node and run the words either
    # side of it together -- HTTP 200, no warning, and the merge propagated into
    # the index. Asserted end to end against the stored MODS, because the whole
    # defect lived between the form post and what Atlas kept. Built from the
    # codepoint so this file stays ASCII.
    it 'separates the words a pasted Word line break sat between, in the stored title' do
      patch :update_metadata, params: { id: work.id, work: { title: "Simple#{[0x000B].pack('U')}form",
                                                             description: 'D', keywords: %w[alpha] } }

      doc = NEU::MODS::Document.parse(AtlasRb::Work.mods(work.id, 'xml', nuid: '000000004'))
      expect(doc.title_parts[:title]).to eq('Simple form')
    end

    it 'keeps the break as a line break in the stored abstract, which a textarea round-trips' do
      patch :update_metadata, params: { id: work.id, work: { title: 'T', keywords: %w[alpha],
                                                             description: "Para one#{[0x000B].pack('U')}Para two" } }

      doc = NEU::MODS::Document.parse(AtlasRb::Work.mods(work.id, 'xml', nuid: '000000004'))
      expect(doc.abstract_nodes.first.text).to eq("Para one\nPara two")
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

    it 'separates a title part where a pasted Word line break was' do
      patch :update, params: { id: work.id, work: { form: 'advanced', subtitle: "a#{[0x000B].pack('U')}b" } }

      doc = NEU::MODS::Document.parse(AtlasRb::Work.mods(work.id, 'xml', nuid: '000000004'))
      expect(doc.title_parts[:subtitle]).to eq('a b')
    end

    it 'edits a structured title part (subtitle) in place, leaving the bare title' do
      patch :update, params: { id: work.id, work: { form: 'advanced', subtitle: 'A New Subtitle' } }

      doc = NEU::MODS::Document.parse(AtlasRb::Work.mods(work.id, 'xml', nuid: '000000004'))
      expect(doc.title_parts[:subtitle]).to eq('A New Subtitle')
      expect(doc.title_parts[:title]).to eq("What's New")
    end
  end

  describe 'update — poster upload (Thumbable)' do
    let(:user) { User.new(email: 'test@example.com', nuid: '000000004', groups: ['editors']) }

    before do
      AtlasRb::Work.metadata(work.id, { 'permissions' => { 'edit' => ['editors'] } }, nuid: '000000004')
      sign_in user
    end

    # The prior thumbnail path (ThumbnailCreator.call(path:) vs base:) was masked
    # by a stub and never ran; drive the real update flow so a poster upload
    # genuinely reaches set_thumbnails. Only MasterJp2's vips/JP2 minting is stubbed.
    it 'mints the uploaded poster and persists it via set_thumbnails' do
      allow(MasterJp2).to receive(:call).and_return(MasterJp2::Result.new(open_base: 'BASE', gated_base: 'G'))
      urls = { thumbnail: 't', thumbnail_2x: 't2', preview: 'p' }
      allow(ThumbnailCreator).to receive(:call).with(base: 'BASE').and_return(urls)
      allow(AtlasRb::Work).to receive(:set_thumbnails)

      patch :update, params: { id:        work.id,
                               work:      { title: work.title },
                               thumbnail: fixture_file_upload('image.png', 'image/png') }

      expect(AtlasRb::Work).to have_received(:set_thumbnails).with(work.id, **urls)
    end

    it 'does not touch set_thumbnails when no poster file is attached' do
      allow(AtlasRb::Work).to receive(:set_thumbnails)

      patch :update, params: { id: work.id, work: { title: work.title } }

      expect(AtlasRb::Work).not_to have_received(:set_thumbnails)
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

    it 'calls AtlasRb::Work.tombstone and reports success on a 2xx' do
      allow(AtlasRb::Work).to receive(:tombstone)
        .and_return(instance_double(Faraday::Response, success?: true))
      post :tombstone, params: { id: work.id }
      expect(AtlasRb::Work).to have_received(:tombstone).with(work.id)
      expect(subject).to redirect_to(root_path)
      expect(flash[:notice]).to eq('Work deleted.')
    end

    it 'reports a 422 live-members refusal without claiming success' do
      allow(AtlasRb::Work).to receive(:tombstone)
        .and_return(instance_double(Faraday::Response, success?: false, status: 422))
      request.env['HTTP_REFERER'] = work_path(work.id)
      post :tombstone, params: { id: work.id }
      expect(flash[:notice]).to be_nil
      expect(flash[:alert]).to match(/live members/)
    end
  end

  describe 'show on a tombstoned work' do
    render_views

    before do
      publicize_chain!
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

    # A read against a missing id comes back nil; a WRITE raises
    # AtlasRb::NotFoundError instead, because a caller that asked to change
    # something and silently got nil is the worse outcome. Both belong on the
    # same 404 page — without the write shape in the rescue list it renders a
    # Rails 500, params dump and all.
    it 'renders the same 404 when a write raises AtlasRb::NotFoundError' do
      allow(AtlasRb::Work).to receive(:find).and_raise(AtlasRb::NotFoundError, 'GET /works/x → 404')

      get :show, params: { id: 'does-not-exist-1234' }

      expect(response).to have_http_status(:not_found)
      expect(response).to render_template('errors/not_found')
    end
  end

  # The personal-root trail is isolated on the private seam. work_breadcrumbs reads
  # the already-loaded @work (it makes no Atlas fetch of its own) plus one
  # Person.resolve; here we set @work and stub the resolve, then assert the crumbs.
  describe '#work_breadcrumbs (private)' do
    def work_result(parent_noid:, ancestors:)
      controller.instance_variable_set(:@work,
                                       AtlasRb::Mash.new('id' => 'wnoid', 'title' => 'Coastal Survey',
                                                         'depositor' => '000000007', 'ancestors' => ancestors))
      parent_noid # documents intent; the last ancestor node carries it
    end

    it 'trails community / Person / work for a work homed in the depositor Person root' do
      work_result(parent_noid: 'jane-root',
                  ancestors:   [{ 'noid' => 'people', 'klass' => 'Community', 'title' => 'People' },
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
                  ancestors:   [{ 'noid' => 'col', 'klass' => 'Collection', 'title' => 'My Collection' }])
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

  describe '#workspace_collections (private)' do
    it "scopes to the depositor Person's personal-root subtree, not all owned collections" do
      allow(controller).to receive(:deposit_person).and_return(AtlasRb::Mash.new('personal_root_id' => 'janeroot'))
      response = instance_double(Blacklight::Solr::Response, documents: [SolrDocument.new('id' => 'c1')])
      index = instance_double(Blacklight::Solr::Repository)
      allow(Blacklight).to receive(:default_index).and_return(index)
      expect(index).to receive(:search)
        .with(hash_including(fq: array_including('ancestor_ids_ssim:"janeroot"',
                                                 'internal_resource_tesim:Collection',
                                                 '-featured_bsi:true')))
        .and_return(response)

      expect(controller.send(:workspace_collections).pluck('id')).to eq(['c1'])
    end

    it 'returns [] when the depositor has no personal root' do
      allow(controller).to receive(:deposit_person).and_return(nil)
      expect(controller.send(:workspace_collections)).to eq([])
    end
  end
end
