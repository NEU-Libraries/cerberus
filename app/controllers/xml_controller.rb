# frozen_string_literal: true

class XmlController < ApplicationController
  include DepositorContext
  include CollectionBreadcrumbs

  def editor
    item = AtlasRb::Resource.find(params[:id])
    @resource = item.resource
    @klass = item.klass
    resource_mods(item.klass)
    editor_breadcrumbs(item.klass)
  end

  def validate
    item = AtlasRb::Resource.find(params[:resource_id])
    @resource = item.resource

    @errors = XmlValidator.call(xml: params[:raw_xml])
    @mods = AtlasRb::Resource.preview(create_temp_xml) if @errors.empty?
  end

  def update
    item = AtlasRb::Resource.find(params[:resource_id])
    klass = item.klass

    AtlasRb.const_get(klass).update(params[:resource_id], create_temp_xml)
    redirect_to public_send("#{klass.downcase}_path", params[:resource_id])
  end

  private

    # The XML editor is a sub-tab of the resource's edit page, so its trail mirrors
    # that edit page: a Collection reuses the personal-root-aware trail (My DRS / …
    # for the owner), while a Work uses the structural edit trail — matching
    # WorksController#edit and CollectionsController#edit respectively.
    def editor_breadcrumbs(klass)
      if klass == 'Collection'
        collection_breadcrumbs(params[:id], editing: true)
      else
        breadcrumbs(params[:id], editing: true)
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
