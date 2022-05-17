# frozen_string_literal: true

class XmlController < ApplicationController
  def editor
    @work = Work.find(params[:id])
    @raw_xml = @work.mods_xml
  end

  def validate
    if !params[:commit].blank? && params[:commit] == "Save"
      work = Work.find(params[:work_id])
      work.mods_xml = params[:raw_xml]
      flash[:success] = "XML updated"
      redirect_to work
    else # preview
      @work = Work.new(alternate_ids: ["#{Time.now.to_f.to_s.gsub!('.', '')}"])
      @work.mods_json = params[:raw_xml]
    end
    respond_to do |format|
      format.turbo_stream
   end
  end

  def update
  end
end
