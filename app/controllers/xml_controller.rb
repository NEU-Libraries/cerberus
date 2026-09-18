# frozen_string_literal: true

# The raw-XML metadata editor. See docs/people-and-routing.md.
class XmlController < ApplicationController
  include DepositorContext
  include CollectionBreadcrumbs

  # A sibling of the Metadata and Permissions edit tabs, and gated the same way:
  # authenticate first, then the :edit ability keyed on the resource.
  before_action :authenticate_user!
  before_action :authorize_xml_edit!
  before_action :require_modsable_resource!

  def editor
    item = resolved_resource
    @resource = item.resource
    @klass = item.klass
    resource_mods
    @double_escapes = Metadata::DoubleEscapes.report(@raw_xml)
    editor_breadcrumbs(item.klass, params[:id])
  end

  def validate
    item = resolved_resource
    @resource = item.resource

    @errors = XmlValidator.call(xml: params[:raw_xml])
    @repairable = Metadata::ControlCharacters.any?(params[:raw_xml])
    @double_escapes = Metadata::DoubleEscapes.report(params[:raw_xml])
    @mods = AtlasRb::Resource.preview(create_temp_xml) if @errors.empty?
  end

  # Offers the repair; does not apply it. Nothing is written until the curator
  # presses Save, and nothing re-validates, so the preview pane keeps its last
  # render rather than one taken from the changed buffer.
  def repair
    @resource = resolved_resource.resource
    @repaired = repair_kind
    @raw_xml = apply_repair(@repaired, params[:raw_xml])
    @double_escapes = Metadata::DoubleEscapes.report(@raw_xml)
  end

  # Re-runs the same validation Validate does, and refuses on failure. Atlas
  # stores malformed MODS truncated at the parse error, discarding every element
  # after it, with no error and an ordinary-looking audit entry.
  def update
    item = resolved_resource
    klass = item.klass

    @errors = XmlValidator.call(xml: params[:raw_xml])
    return render_invalid(item) if @errors.any?

    AtlasRb::Resource.put_mods(params[:resource_id], create_temp_xml, origin: 'xml_editor')
    redirect_to resource_path(klass, params[:resource_id])
  end

  private

    # "the xml you requested" / "the history you requested" would both name the
    # surface rather than the thing looked up, which is a resource either way.
    def not_found_label = 'resource'

    def repair_kind
      params[:kind] == 'double_escapes' ? :double_escapes : :control_characters
    end

    def apply_repair(kind, xml)
      case kind
      when :double_escapes then Metadata::DoubleEscapes.decode(xml)
      else Metadata::ControlCharacters.clean_text(xml)
      end
    end

    # Re-render holding the curator's OWN submission, not the stored document:
    # reverting the textarea throws away the work that prompted the save.
    def render_invalid(item)
      @resource = item.resource
      @klass = item.klass
      @raw_xml = params[:raw_xml]
      @repairable = Metadata::ControlCharacters.any?(params[:raw_xml])
      @double_escapes = Metadata::DoubleEscapes.report(params[:raw_xml])
      @mods = AtlasRb::Resource.mods(params[:resource_id], 'html')
      editor_breadcrumbs(item.klass, params[:resource_id])
      render :editor, status: :unprocessable_content
    end

    def authorize_xml_edit!
      authorize_edit_for!(xml_resource_id)
    end

    # Refuse a type that has no MODS editing surface, before anything reads or
    # renders it. Atlas answers /resources/:id/permissions for every type, so
    # the :edit gate above passes on a FileSet, Blob, Delegate or Person, and
    # the MODS read then succeeds too because atlas_rb defines it on the base
    # class. Without this the editor opens on a resource it could never save and
    # dies in the breadcrumb builder, which has no route for those types.
    def require_modsable_resource!
      resource = require_resource!(resolved_resource)
      raise ResourceNotFound unless ModsableTypes.include?(resource.klass)
    end

    # One Resource.find per request. The type gate needs the payload before any
    # action runs and every action needs it again, so this must not re-read.
    def resolved_resource
      @resolved_resource ||= AtlasRb::Resource.find(xml_resource_id)
    end

    # editor carries :id; validate, repair and update carry :resource_id.
    def xml_resource_id
      params[:id] || params[:resource_id]
    end

    # Takes the id rather than reading params, because the two actions that render
    # this view carry it under different names.
    def editor_breadcrumbs(klass, id)
      if klass == 'Collection'
        collection_breadcrumbs(id, editing: true)
      else
        breadcrumbs(id, editing: true)
      end
    end

    def resource_mods
      @mods = AtlasRb::Resource.mods(params[:id], 'html')
      @raw_xml = AtlasRb::Resource.mods(params[:id], 'xml')
    end

    def create_temp_xml
      tmp_path = Rails.root.join("/tmp/#{Time.now.to_f.to_s.gsub!('.', '')}.xml")
      File.write(tmp_path, params[:raw_xml])
      tmp_path
    end
end
