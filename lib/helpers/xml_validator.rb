# This module provides a core_file xml validation. We'll want to keep an eye on this as time goes on
# to ensure it's meeting the expectations of drs staff, and the front end as well.

module XmlValidator

  def xml_valid?(xml_str)
    # Never trust the user
    results = Hash.new
    results[:errors] = []

    # Nokogiri xml validation, catch errors
    doc = Nokogiri::XML(xml_str)
    if doc.errors != []
      results[:errors] = doc.errors
      return results
    end

    # Dummy corefile for testing
    doc = CoreFile.new
    doc.mods.content = xml_str

    if results[:errors] != []
      return results
    end

    # Does it have a title?
    if doc.title == nil
      results[:errors] << Exceptions::MissingMetadata.new("title")
      return results
    end

    # Does it have at least one keyword?
    if doc.keywords == []
      results[:errors] << Exceptions::MissingMetadata.new("keywords")
      return results
    end

    # Can we solrize the core_file if we use this xml?
    begin
      doc.to_solr
    rescue Exception => error
      results[:errors] << error
    end

    if results[:errors] != []
      return results
    end

    results[:mods_html] = nil

    # Try rendering html with mods display, catch errors
    begin
      results[:mods_html] = CoreFilesController.new.render_mods_display(doc).to_html
    rescue Exception => error
      results[:errors] << error
    end

    return results
  end
end
