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
  # The editor OFFERS the repair rather than applying it. A surface labelled "Edit
  # raw XML" that rewrote bytes on their way to storage would be lying about what
  # it stores, so the cleaned document comes back for the curator to read and save
  # themselves. Codepoints, not literals, so this file stays ASCII.
  describe 'repair' do
    def cp(*codepoints) = codepoints.pack('U*')

    let(:dirty_xml) { "<mods><titleInfo><title>Simple#{cp(0x000B)}form</title></titleInfo></mods>" }
    let(:clean_xml) { "<mods><titleInfo><title>Simple\nform</title></titleInfo></mods>" }

    it 'cleans the submitted buffer' do
      put :repair, params: { resource_id: work.id, raw_xml: dirty_xml }, xhr: true

      expect(assigns(:raw_xml)).to eq(clean_xml)
    end

    it 'writes nothing to Atlas -- the curator still has to press Save' do
      resource_id = work.id
      allow(AtlasRb::Work).to receive(:update)

      put :repair, params: { resource_id: resource_id, raw_xml: dirty_xml }, xhr: true

      expect(AtlasRb::Work).not_to have_received(:update)
    end

    context 'what the curator sees' do
      render_views

      it 'says the text changed and that nothing was saved' do
        put :repair, params: { resource_id: work.id, raw_xml: dirty_xml }, xhr: true

        expect(response.body).to include('target="save_refusal"')
        expect(response.body).to include('Control characters replaced')
        expect(response.body).to include('nothing saved yet')
      end

      # Ace owns a virtual DOM over #editor, so replacing markup cannot move the
      # buffer -- the stream has to set the session value. The cleaned document
      # rides in as a JSON string literal, which is also what escapes it.
      it 'sets the Ace buffer to the cleaned document' do
        put :repair, params: { resource_id: work.id, raw_xml: dirty_xml }, xhr: true

        expect(response.body).to include('ace.edit("editor").getSession().setValue(')
        expect(response.body).to include(clean_xml.to_json.gsub('"', '&quot;'))
          .or include(clean_xml.to_json)
      end

      it 'takes the offer away, since there is nothing left to repair' do
        put :repair, params: { resource_id: work.id, raw_xml: dirty_xml }, xhr: true

        expect(response.body).not_to include('Replace the control characters')
      end
    end
  end

  # The offer only appears where the validator has just named a control
  # character -- on a refused Save above the form, and beside a failed Validate in
  # the preview pane. Both render the same button, and both submit the CURRENT
  # editor buffer, not the stored document.
  describe 'the repair offer' do
    render_views

    def cp(*codepoints) = codepoints.pack('U*')

    let(:dirty_xml) { "<mods><titleInfo><title>Simple#{cp(0x000B)}form</title></titleInfo></mods>" }

    it 'appears in the refusal banner when a Save is refused over one' do
      put :update, params: { resource_id: work.id, raw_xml: dirty_xml }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Replace the control characters')
      expect(response.body).to include(xml_repair_path(kind: 'control_characters'))
    end

    it 'appears beside a failed Validate' do
      put :validate, params: { resource_id: work.id, raw_xml: dirty_xml }, xhr: true

      expect(response.body).to include('XML validation failed')
      expect(response.body).to include('Replace the control characters')
    end

    # Load-bearing, and silent when it breaks. Per-form CSRF tokens bind the
    # form's token to the form's own action, so this button authenticates on the
    # global token Turbo puts in a header. Opting the submission out of Turbo --
    # or giving the button a form of its own -- earns a 422 instead.
    it 'stays a Turbo submission of the editor form' do
      put :update, params: { resource_id: work.id, raw_xml: dirty_xml }

      formaction = ERB::Util.html_escape(xml_repair_path(kind: 'control_characters'))
      button = response.body[/<button[^>]*formaction="#{Regexp.escape(formaction)}"[^>]*>/]
      expect(button).to be_present
      expect(button).to include('form="raw_xml_form"')
      expect(button).not_to include('data-turbo')
    end

    it 'is absent when the document is refused for some other reason' do
      allow(XmlValidator).to receive(:call).and_return(['Opening and ending tag mismatch'])

      put :update, params: { resource_id: work.id, raw_xml: '<mods><titleInfo></oops>' }

      expect(response.body).to include('Not saved')
      expect(response.body).not_to include('Replace the control characters')
    end
  end

  # A reference escaped twice is well-formed XML, so no validator can refuse it
  # and no renderer can tell it from a record that means the escape. The editor is
  # the one surface that can name it: it shows the source the curator has to read,
  # and it can offer the one-level decode without writing anything.
  describe 'the double-escape advisory' do
    render_views

    let(:escaped_xml) do
      '<mods:mods xmlns:mods="http://www.loc.gov/mods/v3">' \
        '<mods:titleInfo><mods:title>XM&lt;LGBT/&gt;</mods:title></mods:titleInfo>' \
        '<mods:abstract>called XM&amp;lt;LGBT/&amp;gt;.</mods:abstract></mods:mods>'
    end
    let(:decoded_xml) { escaped_xml.sub('XM&amp;lt;LGBT/&amp;gt;', 'XM&lt;LGBT/&gt;') }

    def stub_stored_xml(xml)
      allow(AtlasRb::Work).to receive(:mods).with(work.id, 'html').and_return('<div>preview</div>')
      allow(AtlasRb::Work).to receive(:mods).with(work.id, 'xml').and_return(xml)
    end

    # The record displays wrong on its show page, so the curator arrives here
    # already looking for the cause. Making them press Validate first would hide
    # the answer behind a step they have no reason to take.
    it 'appears on a plain page load, before anything is validated' do
      stub_stored_xml(escaped_xml)

      get :editor, params: { id: work.id }

      expect(response.body).to include('This will display as an escape, not a character')
      expect(response.body).to include('Decode the double escapes')
    end

    it 'names the reference and the line, so the curator can find it in the buffer' do
      stub_stored_xml(escaped_xml)

      get :editor, params: { id: work.id }

      expect(CGI.unescapeHTML(response.body))
        .to include('escapes characters twice: &amp;lt; on line 1, &amp;gt; on line 1')
    end

    it 'stays away from a document that escapes correctly' do
      stub_stored_xml(decoded_xml)

      get :editor, params: { id: work.id }

      expect(response.body).not_to include('Decode the double escapes')
    end

    it 'refreshes on a Validate, which has the submitted buffer in hand' do
      put :validate, params: { resource_id: work.id, raw_xml: escaped_xml }, xhr: true

      expect(response.body).to include('target="escape_advisory"')
      expect(response.body).to include('Decode the double escapes')
    end

    # The refusal banner is deliberately left standing by a failed Validate, so
    # the advisory needs a target of its own to stay true to the buffer.
    it 'refreshes even when that Validate fails' do
      allow(XmlValidator).to receive(:call).and_return(['xmlns:mods missing'])

      put :validate, params: { resource_id: work.id, raw_xml: escaped_xml }, xhr: true

      expect(response.body).to include('target="escape_advisory"')
      expect(response.body).to include('Decode the double escapes')
    end
  end

  describe 'the decode repair' do
    let(:escaped_xml) { '<mods><abstract>XM&amp;lt;LGBT/&amp;gt;</abstract></mods>' }
    let(:decoded_xml) { '<mods><abstract>XM&lt;LGBT/&gt;</abstract></mods>' }

    it 'takes one level off the submitted buffer' do
      put :repair, params: { resource_id: work.id, raw_xml: escaped_xml, kind: 'double_escapes' }, xhr: true

      expect(assigns(:raw_xml)).to eq(decoded_xml)
    end

    it 'writes nothing to Atlas -- the curator still has to press Save' do
      resource_id = work.id
      allow(AtlasRb::Work).to receive(:update)

      put :repair, params: { resource_id: resource_id, raw_xml: escaped_xml, kind: 'double_escapes' }, xhr: true

      expect(AtlasRb::Work).not_to have_received(:update)
    end

    # Two repairs share the action, so the wrong confirmation would describe a
    # change the curator cannot find in the buffer.
    context 'what the curator sees' do
      render_views

      it 'names the change it made, not the other repair' do
        put :repair, params: { resource_id: work.id, raw_xml: escaped_xml, kind: 'double_escapes' }, xhr: true

        expect(response.body).to include('Double escapes decoded')
        expect(response.body).to include('nothing saved yet')
        expect(response.body).not_to include('Control characters replaced')
      end

      it 'takes the offer away, since the buffer is now clean' do
        put :repair, params: { resource_id: work.id, raw_xml: escaped_xml, kind: 'double_escapes' }, xhr: true

        expect(response.body).to include('target="escape_advisory"')
        expect(response.body).not_to include('Decode the double escapes')
      end

      # One level per press. A document deeper than one level gets the offer back
      # rather than a claim that it is finished.
      it 'offers the next level of a document escaped deeper than one' do
        put :repair, params: { resource_id: work.id, raw_xml: '<r>&amp;amp;lt;</r>', kind: 'double_escapes' }, xhr: true

        expect(assigns(:raw_xml)).to eq('<r>&amp;lt;</r>')
        expect(response.body).to include('Decode the double escapes')
      end
    end

    it 'still replaces control characters when that is the offer pressed' do
      dirty = "<mods><title>Simple#{0x000B.chr(Encoding::UTF_8)}form</title></mods>"

      put :repair, params: { resource_id: work.id, raw_xml: dirty, kind: 'control_characters' }, xhr: true

      expect(assigns(:raw_xml)).to eq("<mods><title>Simple\nform</title></mods>")
    end
  end

  # The document is well-formed, so refusing it would be the editor inventing a
  # rule XML does not have. The advisory is advice; Save stays the curator's call.
  describe 'saving a document that escapes twice' do
    let(:escaped_xml) { '<mods><abstract>XM&amp;lt;LGBT/&amp;gt;</abstract></mods>' }

    before { allow(XmlValidator).to receive(:call).and_return([]) }

    it 'is accepted, not refused' do
      put :update, params: { resource_id: work.id, raw_xml: escaped_xml }

      expect(response).to redirect_to(work_path(work.id))
    end
  end

  # Both slots can have something to say at once: the refusal is about the last
  # Save, the advisory about the buffer. Each keeps its own offer.
  describe 'a document with both problems' do
    render_views

    let(:both) { "<mods><title>Simple#{0x000B.chr(Encoding::UTF_8)}form</title><abstract>&amp;lt;</abstract></mods>" }

    it 'refuses the Save over the control character and still advises on the escape' do
      put :update, params: { resource_id: work.id, raw_xml: both }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Replace the control characters')
      expect(response.body).to include('Decode the double escapes')
    end
  end

  # This file leaves Works waiting on a depositor, which the admin triage registry
  # lists. Purging them keeps that registry's own specs measuring its filter rather
  # than the size of the suite (see spec/support/work_cleanup.rb).
  after(:all) { purge_stuck_works! }
end
