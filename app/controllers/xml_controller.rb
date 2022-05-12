# frozen_string_literal: true

class XmlController < ApplicationController
  def editor
    @work = Work.find(params[:id])
    @raw_xml = @work.mods_xml
  end

  def validate
  end

  def update
  end
end
