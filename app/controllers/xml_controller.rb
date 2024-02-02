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

    tmp_path = Rails.root.join("/tmp/#{Time.now.to_f.to_s.gsub!('.', '')}.xml")
    File.write(tmp_path, params[:raw_xml])

    @mods = AtlasRb::Resource.preview(tmp_path)
  end

  def update
    # work = Work.find(params[:work_id])
    # work.mods_xml = params[:raw_xml]
    # flash[:success] = 'XML updated'
    # redirect_to work
  end

  private

    def resource_mods(klass)
      @mods = AtlasRb.const_get(klass).mods(params[:id], 'html')
      @raw_xml = AtlasRb.const_get(klass).mods(params[:id], 'xml')
    end
end
