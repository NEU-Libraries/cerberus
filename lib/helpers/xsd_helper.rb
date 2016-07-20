# This module provides a way to download xsd file's and their dependencies so to avoid
# on reliance of external hosting. LOC has historically low reliability, and these
# external URIs for schemaLocation cause XML validation to fail due to timeouts

module XsdHelper

  def download_xsd(xsd_uri_array)
    new_xsd_uris = []
    file_paths = []

    # Download files
    xsd_uri_array.each do |xsd_uri|
      uri_md5 = Digest::MD5.hexdigest(xsd_uri)

      dir_name = "#{Rails.application.config.tmp_path}/xsd_files"

      # Make dir if needed
      unless File.directory?(dir_name)
        FileUtils.mkdir_p(dir_name)
      end

      file_path = "#{dir_name}/#{uri_md5}.xsd"
      file_paths << file_path
      open(file_path, "wb+") do |file|
        file.write(open(xsd_uri).read)
      end
    end

    # Search inside for other schemaLocations
    file_paths.each do |file_path|
      new_xsd_uris = find_schemas(file_path)
    end

    if !new_xsd_uris.blank?
      download_xsd(new_xsd_uris)
    end
  end

  def find_schemas(xml_file_path)
    xsd_uri_array = []

    # Open XML file
    doc = File.open(xml_file_path) { |f| Nokogiri::XML(f) }
    # search for schemaLocations
    doc.xpath("//@schemaLocation").each do |node|
      if !node.value.blank?
        # Add to array
        xsd_uri_array << node.value
        # Get MD5
        uri_md5 = Digest::MD5.hexdigest(node.value)
        # Reassign attribute value
        node.value = "#{uri_md5}.xsd"
      end
    end

    # Overwrite with md5'd doc
    File.write(xml_file_path, doc.to_xml)

    return xsd_uri_array
  end

  def fetch_schema(xsd_uri)
    uri_md5 = Digest::MD5.hexdigest(xsd_uri)
    dir_path = "#{Rails.application.config.tmp_path}/xsd_files"
    xsd_path = "#{dir_path}/#{uri_md5}.xsd"

    # Does the offline version exist already?
    if !(File.exists?(xsd_path))
      # If not, go download
      xsd_array = []
      xsd_array << xsd_uri
      download_xsd(xsd_array)
    end

    # Validate and return Nokogiri schema
    Dir.chdir(dir_path) do
      return Nokogiri::XML::Schema(IO.read(xsd_path))
    end
  end

end
