# This module provides a core_file xml validation. We'll want to keep an eye on this as time goes on
# to ensure it's meeting the expectations of drs staff, and the front end as well.

module XmlValidator

  def xml_valid?(xml_str)
    # Never trust the user
    errors = []
    # Nokogiri xml validation, catch errors
    doc = Nokogiri::XML(xml_str)
    if doc.errors != []
      errors = doc.errors
      return errors
    end

    # Dummy corefile for testing
    doc = CoreFile.new
    doc.mods.content = xml_str

    # Try rendering html with mods display, catch errors
    begin
      CoreFilesController.new.render_mods_display(doc).to_html
    rescue Exception => error
      errors << error
    end

    if errors != []
      return errors
    end

    # Does it have a title?
    if doc.title == nil
      errors << "No valid title in xml"
      return errors
    end

    # Does it have at least one keyword?
    if doc.keywords == []
      errors << "No valid keywords in xml"
      return errors
    end

    # Can we solrize the core_file if we use this xml?
    begin
      doc.to_solr
    rescue Exception => error
      errors << error
    end

    if errors != []
      return errors
    end

    # If we've gotten this far, we should be able to return mods_display html
    return CoreFilesController.new.render_mods_display(doc).to_html
  end
end
