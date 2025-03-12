module MimeHelper

  def extract_mime_type(file_location, original_filename="")
    # given a files location at the system level
    # use file to extract it's mime type - to be used in
    # assign_type, but we may have more use for this
    result = `#{Cerberus::Application.config.file_path} --mime-type #{file_location.shellescape}`
    #removing newlines and whitespace
    result.strip!
    mime_type = result.slice(result.index(":")+1..-1).strip # magic byte
    raw_type = mime_type.split("/").first.strip

    if !original_filename.blank?
      # Double check against extension
      extension = File.extname(original_filename).split(".").last.downcase
      alternate_mime_type = `grep -v "^#" /etc/mime.types | grep "#{extension}\s" | awk '{print $1}'`.gsub(/\n/," ").strip.split(" ").first

      # if app/zip lets make sure it's not an office file
      if mime_type == "application/zip"
        if alternate_mime_type.include?("office") || alternate_mime_type.include?(".ms-") || alternate_mime_type.include?("/ms")
          return alternate_mime_type
        end
      end

      # m4a audio vs video issue - check raw type disagreement
      rack_based_mime_type = Rack::Mime.mime_type(".#{extension}") # needs . to work effectively

      if !alternate_mime_type.blank?
        alternate_raw = alternate_mime_type.split("/").first.strip
        if (!alternate_raw.start_with?("application")) && (raw_type != alternate_raw)
          return alternate_mime_type
        end
      end

      if !rack_based_mime_type.blank?
        rack_raw = rack_based_mime_type.split("/").first.strip
        if (!rack_raw.start_with?("application")) && (raw_type != rack_raw)
          return rack_based_mime_type
        end
      end

    end

    return mime_type
  end

  def extract_extension(mime_type, original_extension="")
    result = `grep -v "^#" /etc/mime.types | grep "#{mime_type}" | awk '{print $2}'`.gsub(/\n/," ").strip.split(" ").first
    multiple = `grep -v "^#" /etc/mime.types | grep "#{mime_type}" | awk '{$1=""; print $0}'`.strip.split(" ")

    if !original_extension.blank?
      if mime_type == "application/octet-stream" || mime_type.start_with?("text") || (multiple.include? original_extension)
        return original_extension
      end
    end

    if !result.blank?
      if !result.match(/\s/).nil?
        return result.slice(0..(result.index(' ')-1)).gsub(/[^0-9a-z ]/i, '') #strip non alphanumeric characters
      end
      return result
    elsif result.blank? && !original_extension.blank?
      return original_extension
    end

    # Catch all
    return ""
  end

end
