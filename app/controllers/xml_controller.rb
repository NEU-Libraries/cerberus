# frozen_string_literal: true

class XmlController < ApplicationController
  def editor
    item = AtlasRb::Resource.find(params[:id])
    @resource = item['resource']
    resource_mods(item['klass'])
  end

  def validate
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
