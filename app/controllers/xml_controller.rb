# frozen_string_literal: true

class XmlController < ApplicationController
  def editor
    @work = Work.find(params[:id])
    @raw_xml = @work.mods_xml
  end

  def validate
    @work = Work.new(alternate_ids: [Time.now.to_f.to_s.gsub!('.', '').to_s])
    @work.mods_json = params[:raw_xml]
  end

  def update
    puts "DGC DEBUG: " + params.inspect
    work = Work.find(params[:work_id])
    work.mods_xml = params[:raw_xml]
    flash[:success] = 'XML updated'
    redirect_to work
  end
end
