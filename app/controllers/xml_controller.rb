# frozen_string_literal: true

class XmlController < ApplicationController
  def editor
    @work = Work.find(params[:id])
    @raw_xml = @work.mods_xml
  end

  def validate
    # puts "DGC DEBUG " + params.inspect
    @work = Work.new
    @work.mods_json = File.read('/home/cerberus/web/test/fixtures/files/community-mods.xml')
    respond_to do |format|
      format.turbo_stream
   end
  end

  def update
  end
end
