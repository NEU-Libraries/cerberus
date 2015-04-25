module MimeHelper

  def extract_mime_type(file_location)
    # given a files location at the system level
    # use file to extract it's mime type - to be used in
    # assign_type, but we may have more use for this
    result = `file --mime-type #{file_location}`
    #removing newlines and whitespace
    result.strip!
    mime_type = result.slice(result.index(":")+1..-1).strip
    return mime_type
  end

  def extract_extension(mime_type)
    result = `grep "#{mime_type}" /etc/mime.types | awk '{print $2}'`.gsub(/\n/," ").strip

    if !result.match(/\s/).nil?
      return result.slice(0..(result.index(' ')-1))
    else
      return result
    end
  end

end
