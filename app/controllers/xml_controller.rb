# frozen_string_literal: true

class XmlController < ApplicationController
  def editor
    item = AtlasRb::Resource.find(params[:id])
    @resource = item['resource']
    resource_mods(item['klass'])
  end

  def validate
    # Need to ask Atlas to convert raw xml to mods html for preview
    # curl -F 'binary=@work-mods.xml' http://atlas:3000/resources/xml.html
    # AtlasRb::Resource.preview('/home/cerberus/web/spec/fixtures/files/work-mods.xml')
    item = AtlasRb::Resource.find(params[:resource_id])
    @resource = item['resource']

    tmp_path = "#{Rails.root}/tmp/#{Time.now.to_f.to_s.gsub!('.', '').to_s}.xml"

    File.open(tmp_path, "w+") do |f|
      f.write(params[:raw_xml])
    end

    @mods = AtlasRb::Resource.preview(tmp_path)

    # @work = Work.new(alternate_ids: [Time.now.to_f.to_s.gsub!('.', '').to_s])
    # @work.mods_json = params[:raw_xml]
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
