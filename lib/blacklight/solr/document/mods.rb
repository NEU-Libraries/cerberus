# -*- encoding : utf-8 -*-
require 'builder'

# This module provides Mods export based on the document's semantic values
module Blacklight::Solr::Document::Mods
  def self.extended(document)
    # Register our exportable formats
    Blacklight::Solr::Document::Mods.register_export_formats( document )
  end

  def self.register_export_formats(document)
    document.will_export_as(:xml)
    document.will_export_as(:mods_xml, "text/xml")
  end

  def export_as_mods_xml
    cf = ActiveFedora::Base.find(self.pid, cast: true)
    return Nokogiri::XML(cf.mods.content).to_xml  {|config| config.no_declaration}.strip
  end

  alias_method :export_as_xml, :export_as_mods_xml

end
