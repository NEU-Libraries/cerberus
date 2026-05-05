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

  FILE_TYPE_ICONS = {
    %r{\Aimage/} => 'fa-file-image',
    %r{\Aaudio/} => 'fa-file-audio',
    %r{\Avideo/} => 'fa-file-video',
    %r{\Aapplication/pdf\z} => 'fa-file-pdf',
    %r{\Atext/} => 'fa-file-lines',
    /word|officedocument\.wordprocessingml/ => 'fa-file-word',
    /excel|spreadsheetml/ => 'fa-file-excel',
    /powerpoint|presentationml/ => 'fa-file-powerpoint',
    /zip|tar|gzip|compressed/ => 'fa-file-zipper',
    /json|xml|javascript|ruby|python|sh\z/ => 'fa-file-code'
  }.freeze

  def file_type_icon(mime_type)
    mime = mime_type.to_s
    FILE_TYPE_ICONS.find { |pattern, _| pattern.match?(mime) }&.last || 'fa-file'
  end

  def javascript_inline_importmap_tag(importmap_json = Rails.application.importmap.to_json(resolver: self))
    tag.script importmap_json.html_safe,
               type: 'importmap',
               'data-turbo-track': 'reload',
               'data-turbo-eval': 'false',
               nonce: request&.content_security_policy_nonce
  end

  def report_a_problem_url(resource_url)
    query = { queue_id: 5581, resource: resource_url }.to_query
    "https://northeastern.libanswers.com/form?#{query}"
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
