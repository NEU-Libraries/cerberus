# frozen_string_literal: true

require 'rails_helper'

describe XmlController do
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml', nuid: '000000004') }
  let(:collection) { AtlasRb::Collection.create(community.id, '/home/cerberus/web/spec/fixtures/files/collection-mods.xml', nuid: '000000004') }
  let(:work) { AtlasRb::Work.create(collection.id, '/home/cerberus/web/spec/fixtures/files/work-mods.xml', nuid: '000000004') }
  let(:raw_xml) { '<mods><titleInfo><title>Test Title</title></titleInfo></mods>' }

  # The raw-XML editor is now authenticate + edit-gated (audit G1); sign in as
  # the admin who owns the fixtures so every example passes the gate and
  # exercises the editor behaviour as before.
  let(:admin) do
    User.new(email: 'admin@example.com', nuid: '000000004', name: 'Admin, User', role: 'admin', groups: [])
  end

  before { sign_in admin }

  describe 'editor' do
    render_views
    it 'renders the editor partial' do
      get :editor, params: { id: work.id }
      expect(response).to render_template('xml/editor')
    end

    it 'assigns the correct variables' do
      get :editor, params: { id: work.id }
      expect(assigns(:resource)).to eq(work)
      expect(assigns(:klass)).to eq('Work')
      expect(assigns(:mods)).to be_present
      expect(assigns(:raw_xml)).to be_present
    end

    it 'renders the refusal container empty, so Validate has a node to replace' do
      get :editor, params: { id: work.id }
      expect(response.body).to include('id="save_refusal"')
      expect(response.body).not_to include('Not saved')
    end

    it 'renders a breadcrumb trail ending in the resource and "Edit Work"' do
      get :editor, params: { id: work.id }
      expect(response.body).to include('aria-label="breadcrumb"')
      expect(CGI.unescapeHTML(response.body)).to include(work.title)
      expect(response.body).to include('Edit Work')
    end

    it 'shows the Advanced tab for a Work (links to the edit page advanced pane)' do
      get :editor, params: { id: work.id }
      expect(response.body).to include("#{edit_work_path(work.id)}#advanced")
      expect(response.body).to match(/nav-link[^>]*>\s*Advanced/)
    end

    it 'omits the Advanced tab for a Collection (collections have no advanced fields)' do
      get :editor, params: { id: collection.id }
      expect(response.body).to include('aria-label="breadcrumb"')
      expect(response.body).not_to include('#advanced')
    end

    it 'builds the personal-root-aware trail for a Collection via collection_breadcrumbs' do
      expect(controller).to receive(:collection_breadcrumbs).with(collection.id, editing: true)
      get :editor, params: { id: collection.id }
    end

    it 'uses the structural edit trail for a Work via #breadcrumbs' do
      expect(controller).to receive(:breadcrumbs).with(work.id, editing: true)
      get :editor, params: { id: work.id }
    end
  end

  describe 'validate' do
    let(:preview_result) { "<div class='mods-preview'><h1>Test Title</h1></div>" }

    before do
      allow(AtlasRb::Resource).to receive(:preview).and_return(preview_result)
    end

    context 'when XmlValidator passes' do
      before { allow(XmlValidator).to receive(:call).and_return([]) }

      it 'assigns @errors empty and @mods to the Atlas preview' do
        put :validate, params: { resource_id: work.id, raw_xml: raw_xml }, xhr: true
        expect(assigns(:resource)).to eq(work)
        expect(assigns(:errors)).to eq([])
        expect(assigns(:mods)).to eq(preview_result)
      end
    end

    context 'when XmlValidator returns errors' do
      before { allow(XmlValidator).to receive(:call).and_return(['xmlns:mods missing']) }

      it 'assigns @errors and does not call Atlas preview' do
        put :validate, params: { resource_id: work.id, raw_xml: raw_xml }, xhr: true
        expect(assigns(:errors)).to eq(['xmlns:mods missing'])
        expect(assigns(:mods)).to be_nil
        expect(AtlasRb::Resource).not_to have_received(:preview)
      end
    end

    # The refusal banner sits above the form, outside the #mods node the preview
    # replaces, so clearing it needs a replace of its own. Asserted on the stream
    # body rather than on assigns, since the bug was entirely in what got sent.
    context 'the refusal banner left by an earlier refused Save' do
      render_views

      it 'clears it when validation passes' do
        allow(XmlValidator).to receive(:call).and_return([])
        put :validate, params: { resource_id: work.id, raw_xml: raw_xml }, xhr: true

        expect(response.body).to include('target="save_refusal"')
        expect(response.body).not_to include('Not saved')
      end

      it 'leaves it when validation fails' do
        allow(XmlValidator).to receive(:call).and_return(['xmlns:mods missing'])
        put :validate, params: { resource_id: work.id, raw_xml: raw_xml }, xhr: true

        # Nothing was written, so a refusal from an earlier Save is still true.
        # The current errors render in the preview pane instead of twice at once.
        expect(response.body).not_to include('target="save_refusal"')
        expect(response.body).to include('XML validation failed')
      end
    end
  end

  # Save re-runs the validator and refuses on failure. It used to write whatever
  # it was handed: malformed MODS was accepted with no error and no flash, and
  # stored TRUNCATED at the parse error — every element after it silently
  # discarded, and recorded in the audit log as an ordinary metadata update.
  # Nothing forces a curator through Validate first, so the destructive path has
  # to check for itself.
  #
  # `raw_xml` is a minimal stub rather than schema-valid MODS, so these examples
  # stub the validator, as the `validate` examples above do.
  describe 'update' do
    let(:malformed_xml) { '<mods><titleInfo></oops>' }

    context 'when the submitted XML is valid' do
      before { allow(XmlValidator).to receive(:call).and_return([]) }

      it 'redirects' do
        put :update, params: { resource_id: work.id, raw_xml: raw_xml }
        expect(response).to redirect_to(work_path(work.id))
      end
    end

    context 'when the submitted XML is invalid' do
      # Render for real: the point of the refusal is that the curator SEES why,
      # and a template-name assertion alone would pass on an unrendered alert.
      render_views

      before { allow(XmlValidator).to receive(:call).and_return(['Opening and ending tag mismatch']) }

      it 'does not write anything to Atlas' do
        # Reference the fixture before the stub: AtlasRb::Work.create issues its
        # own update to attach the MODS, which the stub would otherwise absorb.
        resource_id = work.id
        allow(AtlasRb::Work).to receive(:update)

        put :update, params: { resource_id: resource_id, raw_xml: malformed_xml }

        expect(AtlasRb::Work).not_to have_received(:update)
      end

      it 're-renders the editor with the errors, and refuses the request' do
        put :update, params: { resource_id: work.id, raw_xml: malformed_xml }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template(:editor)
        expect(response.body).to include('Not saved')
        expect(response.body).to include('Opening and ending tag mismatch')
      end

      # A refusal that reverts the textarea to the stored document throws away
      # the work that prompted the save — nearly as bad as the truncation.
      it "keeps the curator's own submission in the editor" do
        put :update, params: { resource_id: work.id, raw_xml: malformed_xml }

        expect(assigns(:raw_xml)).to eq(malformed_xml)
      end
    end
  end
end
