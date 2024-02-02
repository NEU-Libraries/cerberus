# frozen_string_literal: true

class XmlController < ApplicationController
  def editor
    item = AtlasRb::Resource.find(params[:id])
    @resource = item['resource']
    resource_mods(item['klass'])
  end

  def validate
    item = AtlasRb::Resource.find(params[:resource_id])
    @resource = item['resource']

    @mods = AtlasRb::Resource.preview(create_temp_xml)
  end

  def update
    item = AtlasRb::Resource.find(params[:resource_id])
    klass = item['klass']

    AtlasRb.const_get(klass).update(params[:resource_id], create_temp_xml)
    redirect_to public_send("#{klass.downcase}_path", params[:resource_id])
  end

  private

    def resource_mods(klass)
      @mods = AtlasRb.const_get(klass).mods(params[:id], 'html')
      @raw_xml = AtlasRb.const_get(klass).mods(params[:id], 'xml')
    end

    def create_temp_xml
      tmp_path = Rails.root.join("/tmp/#{Time.now.to_f.to_s.gsub!('.', '')}.xml")
      File.write(tmp_path, params[:raw_xml])
      return tmp_path
    end
end
