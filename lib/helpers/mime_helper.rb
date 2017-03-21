module MimeHelper

  def extract_mime_type(file_location, original_filename="")
    # given a files location at the system level
    # use file to extract it's mime type - to be used in
    # assign_type, but we may have more use for this
    result = `#{Cerberus::Application.config.file_path} --mime-type #{file_location}`
    #removing newlines and whitespace
    result.strip!
    mime_type = result.slice(result.index(":")+1..-1).strip

    if !original_filename.blank? && mime_type == "application/octet-stream"
      # Odds are that it's a poor encoding, and the system is correct in giving a generic
      # mime type. Due to the complexity of the issue however, we're going to punt this
      # down the river and see if JWPlayer can survive whatever the issue may be, and
      # give the extension the benefit of the doubt.
      extension = File.extname(original_filename)

      if !extension.blank?
        return Rack::Mime.mime_type(extension)
      end
    end

    return mime_type
  end

  def extract_extension(mime_type, original_extension="")
    result = `grep "#{mime_type}" /etc/mime.types | awk '{print $2}'`.gsub(/\n/," ").strip.split(" ").first
    multiple = `grep "#{mime_type}" /etc/mime.types | awk '{$1=""; print $0}'`.strip.split(" ")

    if !original_extension.blank?
      if mime_type.start_with?("text") || (multiple.include? original_extension)
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
