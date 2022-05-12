# frozen_string_literal: true

class XmlController < ApplicationController
  def editor
    @raw_xml = Work.find("fn2z4gd").mods_xml
  end

  def validate
  end

  def update
  end
end
