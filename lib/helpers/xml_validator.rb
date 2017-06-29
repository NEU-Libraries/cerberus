# This module provides a core_file xml validation. We'll want to keep an eye on this as time goes on
# to ensure it's meeting the expectations of drs staff, and the front end as well.

module XmlValidator

  def xml_valid?(xml_str, handle_check = false)
    # Never trust the user
    results = Hash.new
    results[:errors] = []

    # Nokogiri xml validation, catch errors
    begin
      doc = Nokogiri::XML(xml_str)

      if doc.errors != []
        results[:errors] = doc.errors
        return results
      end
    rescue => exception
      results[:errors] << exception
      return results
    end

    if doc.encoding != "UTF-8"
      results[:errors] << Exceptions::XmlEncodingError.new
    end

    # Nokogiri schema validation
    begin
      schemata_by_ns = Hash[ doc.root.attributes['schemaLocation'].value.scan(/(\S+)\s+(\S+)/) ]
      schemata_by_ns.each do |ns,xsd_uri|

        xsd = Kataba.fetch_schema(xsd_uri)

        xsd.validate(doc).each do |error|
          results[:errors] << error
        end
      end
    rescue Errno::ETIMEDOUT => exception
      # Email devs - online and offline failed
      ExceptionNotifier.notify_exception(exception)
    rescue Nokogiri::XML::SyntaxError => exception
      # Email devs - most likely an unfortunate poor response from xsd provider
      ExceptionNotifier.notify_exception(exception)
    rescue NoMethodError
      # Rescue NoMethodError - this will occur if there is no schemaLocation provided
      results[:errors] << Exceptions::MissingMetadata.new("schemaLocation")
    end

    if results[:errors] != []
      return results
    end

    # Dummy corefile for testing
    doc = CoreFile.new
    doc.mods.content = xml_str

    if results[:errors] != []
      return results
    end

    if handle_check
      # Does it have a handle?
      if doc.mods.identifier.blank?
        results[:errors] << Exceptions::MissingHandle.new
        return results
      end
    end

    # Does it have a title?
    if doc.title.blank?
      results[:errors] << Exceptions::MissingMetadata.new("title")
      return results
    end

    # Does it have at least one keyword?
    keywords = doc.mods.subject
    keywords.collect!(&:strip)

    if !(keywords.any? {|kw| !kw.blank?})
      results[:errors] << Exceptions::MissingMetadata.new("keywords")
      return results
    end

    # Does it have a properly formatted date created
    date_created = doc.mods.origin_info.date_created + doc.mods.origin_info.date_created_end
    date_created.each do |dc|
      if !dc.blank?
        if !/^\d{4}((-\d{2}-\d{2})|(-\d{2})|())$/.match(dc)
          results[:errors] << Exceptions::MalformedDate.new("date created")
          return results
        end
      end
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