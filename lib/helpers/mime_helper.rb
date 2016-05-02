module MimeHelper

  def extract_mime_type(file_location)
    # given a files location at the system level
    # use file to extract it's mime type - to be used in
    # assign_type, but we may have more use for this
    result = `#{Cerberus::Application.config.file_path} --mime-type #{file_location}`
    #removing newlines and whitespace
    result.strip!
    mime_type = result.slice(result.index(":")+1..-1).strip
    return mime_type
  end

  def extract_extension(mime_type, original_extension="")
    result = `grep "#{mime_type}" /etc/mime.types | awk '{print $2}'`.gsub(/\n/," ").strip
    multiple = `grep "#{mime_type}" /etc/mime.types | awk '{$1=""; print $0}'`.strip.split(" ")

    if !original_extension.blank?
      if multiple.include? original_extension
        return original_extension
      end
    elsif result.blank?
      return original_extension
    elsif !result.match(/\s/).nil?
      return result.slice(0..(result.index(' ')-1)).gsub(/[^0-9a-z ]/i, '') #stip non alphanumeric characters
    end

    # Catch all
    return result
  end

end
