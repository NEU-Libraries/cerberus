# frozen_string_literal: true

class XmlController < ApplicationController
  def editor
    @work = Work.find(params[:id])
    @raw_xml = @work.mods_xml
  end

  def validate
    @work = Work.new(alternate_ids: ["#{Time.now.to_f.to_s.gsub!('.', '')}"])
    @work.mods_json = params[:raw_xml]
    respond_to do |format|
      format.turbo_stream
   end
  end

  def update
  end
end
