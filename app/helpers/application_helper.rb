# frozen_string_literal: true

module ApplicationHelper
  def application_version
    VERSION
  end

  def document_type_icon(klass_type)
    case klass_type
    when 'Community'  then 'fa-users'
    when 'Collection' then 'fa-folder-open'
    else 'fa-file'
    end
  end

  def file_type_icon(mime_type)
    case mime_type.to_s
    when %r{\Aimage/}              then 'fa-file-image'
    when %r{\Aaudio/}              then 'fa-file-audio'
    when %r{\Avideo/}              then 'fa-file-video'
    when 'application/pdf'         then 'fa-file-pdf'
    when %r{\Atext/}               then 'fa-file-lines'
    when /word|officedocument\.wordprocessingml/ then 'fa-file-word'
    when /excel|spreadsheetml/     then 'fa-file-excel'
    when /powerpoint|presentationml/ then 'fa-file-powerpoint'
    when /zip|tar|gzip|compressed/ then 'fa-file-zipper'
    when /json|xml|javascript|ruby|python|sh\z/ then 'fa-file-code'
    else 'fa-file'
    end
  end

  def iiif_url(uuid)
    # Supports staging, production etc.
    # cantaloupe
    if Rails.application.config.iiif_host.present?
      "#{Rails.application.config.iiif_host}/iiif/3/#{uuid}.jp2"
    else
      "http://#{request.host}:8182/iiif/3/#{uuid}.jp2"
    end
  end
end
