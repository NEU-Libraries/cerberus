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
    # document.will_export_as(:dc_xml, "text/xml")
    # document.will_export_as(:oai_dc_xml, "text/xml")
    document.will_export_as(:mods_xml, "text/xml")
  end

  # def dublin_core_field_names
  #   [:contributor, :coverage, :creator, :date, :description, :format, :identifier, :language, :publisher, :relation, :rights, :source, :subject, :title, :type]
  # end

  # dublin core elements are mapped against the #dublin_core_field_names whitelist.
  def export_as_mods_xml
    cf = ActiveFedora::Base.find(self.pid, cast: true)
    return cf.mods.content
  end

  # alias_method :export_as_xml, :export_as_oai_dc_xml
  # alias_method :export_as_dc_xml, :export_as_oai_dc_xml
  alias_method :export_as_xml, :export_as_mods_xml

end
