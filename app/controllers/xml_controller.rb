# frozen_string_literal: true

class XmlController < ApplicationController
  include DepositorContext
  include CollectionBreadcrumbs

  # The raw-XML editor is a sibling of the Metadata/Permissions edit tabs and
  # must gate the same way they do — it was the lone ungated hole in the edit
  # surface (authorization audit G1). authenticate first, then the :edit
  # ability keyed on the resource. editor carries params[:id]; validate, repair
  # and update carry params[:resource_id], so authorize_xml_edit! reads whichever
  # is set.
  before_action :authenticate_user!
  before_action :authorize_xml_edit!

  def editor
    item = AtlasRb::Resource.find(params[:id])
    @resource = item.resource
    @klass = item.klass
    resource_mods(item.klass)
    @double_escapes = Metadata::DoubleEscapes.report(@raw_xml)
    editor_breadcrumbs(item.klass, params[:id])
  end

  def validate
    item = AtlasRb::Resource.find(params[:resource_id])
    @resource = item.resource

    @errors = XmlValidator.call(xml: params[:raw_xml])
    @repairable = Metadata::ControlCharacters.any?(params[:raw_xml])
    @double_escapes = Metadata::DoubleEscapes.report(params[:raw_xml])
    @mods = AtlasRb::Resource.preview(create_temp_xml) if @errors.empty?
  end

  # Offer the repair; do not apply it. A surface labelled "Edit raw XML" that
  # rewrote bytes on their way to storage would be lying about what it stores, so
  # the cleaned document comes back into the editor for the curator to read and
  # save for themselves. The simple Metadata form takes the opposite path on
  # purpose: someone who typed a title is not looking at XML and should get their
  # title back without being asked about codepoints.
  #
  # This is a repair, not a save. Nothing is written until the curator presses
  # Save, and nothing re-validates either: the buffer changed, so the preview pane
  # is left showing the last render it was given.
  #
  # Two offers share the action, because they share every part of the answer but
  # one line -- the same buffer arrives, the same stream reseats it, and neither
  # writes anything. `kind` says which was pressed, and an unrecognised one falls
  # back to the control characters rather than doing nothing the curator can see.
  def repair
    @resource = AtlasRb::Resource.find(params[:resource_id]).resource
    @repaired = repair_kind
    @raw_xml = apply_repair(@repaired, params[:raw_xml])
    @double_escapes = Metadata::DoubleEscapes.report(@raw_xml)
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

    def repair_kind
      params[:kind] == 'double_escapes' ? :double_escapes : :control_characters
    end

    def apply_repair(kind, xml)
      case kind
      when :double_escapes then Metadata::DoubleEscapes.decode(xml)
      else Metadata::ControlCharacters.clean_text(xml)
      end
    end

    # Re-render the editor holding the curator's OWN submission, not the stored
    # document. A rejected save that reverts the textarea to what is on the
    # server throws away the work that prompted the save — nearly as bad as the
    # truncation it is protecting against. The preview pane keeps the last good
    # render, since there is nothing valid to draw from the rejected text.
    def render_invalid(item)
      @resource = item.resource
      @klass = item.klass
      @raw_xml = params[:raw_xml]
      @repairable = Metadata::ControlCharacters.any?(params[:raw_xml])
      @double_escapes = Metadata::DoubleEscapes.report(params[:raw_xml])
      @mods = AtlasRb.const_get(item.klass).mods(params[:resource_id], 'html')
      editor_breadcrumbs(item.klass, params[:resource_id])
      render :editor, status: :unprocessable_content
    end

    # :edit gate for whichever id param this action carries (editor → :id,
    # validate/repair/update → :resource_id), mirroring the resource
    # controllers' authorize_edit!.
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
