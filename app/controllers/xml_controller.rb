# frozen_string_literal: true

class XmlController < ApplicationController
  include DepositorContext
  include CollectionBreadcrumbs

  # The raw-XML editor is a sibling of the Metadata/Permissions edit tabs and
  # must gate the same way they do — it was the lone ungated hole in the edit
  # surface (authorization audit G1). authenticate first, then the :edit
  # ability keyed on the resource. editor carries params[:id]; validate/update
  # carry params[:resource_id], so authorize_xml_edit! reads whichever is set.
  before_action :authenticate_user!
  before_action :authorize_xml_edit!

  def editor
    item = AtlasRb::Resource.find(params[:id])
    @resource = item.resource
    @klass = item.klass
    resource_mods(item.klass)
    editor_breadcrumbs(item.klass, params[:id])
  end

  def validate
    item = AtlasRb::Resource.find(params[:resource_id])
    @resource = item.resource

    @errors = XmlValidator.call(xml: params[:raw_xml])
    @mods = AtlasRb::Resource.preview(create_temp_xml) if @errors.empty?
  end

  # Save re-runs the same validation Validate + Preview does, and refuses on
  # failure. It used to write whatever it was given: malformed MODS was accepted
  # with no error and no flash, and stored truncated at the parse error —
  # silently discarding every element after it. The audit log recorded that as
  # an ordinary metadata update, so the loss was invisible afterwards.
  #
  # Nothing forces a curator through Validate first, and nothing should have to:
  # the destructive path is the one that must check.
  def update
    item = AtlasRb::Resource.find(params[:resource_id])
    klass = item.klass

    @errors = XmlValidator.call(xml: params[:raw_xml])
    return render_invalid(item) if @errors.any?

    AtlasRb.const_get(klass).update(params[:resource_id], create_temp_xml)
    redirect_to public_send("#{klass.downcase}_path", params[:resource_id])
  end

  private

    # Re-render the editor holding the curator's OWN submission, not the stored
    # document. A rejected save that reverts the textarea to what is on the
    # server throws away the work that prompted the save — nearly as bad as the
    # truncation it is protecting against. The preview pane keeps the last good
    # render, since there is nothing valid to draw from the rejected text.
    def render_invalid(item)
      @resource = item.resource
      @klass = item.klass
      @raw_xml = params[:raw_xml]
      @mods = AtlasRb.const_get(item.klass).mods(params[:resource_id], 'html')
      editor_breadcrumbs(item.klass, params[:resource_id])
      render :editor, status: :unprocessable_content
    end

    # :edit gate for whichever id param this action carries (editor → :id,
    # validate/update → :resource_id), mirroring the resource controllers'
    # authorize_edit!.
    def authorize_xml_edit!
      authorize_edit_for!(params[:id] || params[:resource_id])
    end

    # The XML editor is a sub-tab of the resource's edit page, so its trail mirrors
    # that edit page: a Collection reuses the personal-root-aware trail (My DRS / …
    # for the owner), while a Work uses the structural edit trail — matching
    # WorksController#edit and CollectionsController#edit respectively.
    # Takes the id rather than reading params, because the two actions that
    # render this view carry it under different names — `editor` as :id, a
    # rejected `update` as :resource_id.
    def editor_breadcrumbs(klass, id)
      if klass == 'Collection'
        collection_breadcrumbs(id, editing: true)
      else
        breadcrumbs(id, editing: true)
      end
    end

    def resource_mods(klass)
      @mods = AtlasRb.const_get(klass).mods(params[:id], 'html')
      @raw_xml = AtlasRb.const_get(klass).mods(params[:id], 'xml')
    end

    def create_temp_xml
      tmp_path = Rails.root.join("/tmp/#{Time.now.to_f.to_s.gsub!('.', '')}.xml")
      File.write(tmp_path, params[:raw_xml])
      tmp_path
    end
end
