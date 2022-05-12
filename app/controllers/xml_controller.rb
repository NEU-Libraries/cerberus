# frozen_string_literal: true

class XmlController < ApplicationController
  def editor
    @raw_xml = Work.find(params[:id]).mods_xml
  end

  def validate
  end

  def update
  end
end
