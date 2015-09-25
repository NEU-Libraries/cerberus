module UrlHelper

  def convert_urls(string)
    # return string + "yup yup"
    url = /(?i)\b(?:https?:\/\/|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}\/)(?:[^\s()<>]+|\([^\s()<>]+|\([^\s()<>]+\)*\))+(?:\([^\s()<>]+|\([^\s()<>]+\)*\)|[^\s`!()\[\]{};:'".,<>?«»“”‘’])/i
    matches = [string.scan(url)].flatten
    unless string =~ /<a/ # we'll assume that linking has already occured and we don't want to double link
      matches.each do |match|
        string = string.gsub(match, "<a href='#{match}' target='_blank'>#{match}</a>")
      end
    end
    return string.html_safe
  end

end
