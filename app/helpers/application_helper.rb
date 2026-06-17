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
    %r{\Aimage/}                            => 'fa-file-image',
    %r{\Aaudio/}                            => 'fa-file-audio',
    %r{\Avideo/}                            => 'fa-file-video',
    %r{\Aapplication/pdf\z}                 => 'fa-file-pdf',
    %r{\Atext/}                             => 'fa-file-lines',
    /word|officedocument\.wordprocessingml/ => 'fa-file-word',
    /excel|spreadsheetml/                   => 'fa-file-excel',
    /powerpoint|presentationml/             => 'fa-file-powerpoint',
    /zip|tar|gzip|compressed/               => 'fa-file-zipper',
    /json|xml|javascript|ruby|python|sh\z/  => 'fa-file-code'
  }.freeze

  def file_type_icon(mime_type)
    mime = mime_type.to_s
    FILE_TYPE_ICONS.find { |pattern, _| pattern.match?(mime) }&.last || 'fa-file'
  end

  def javascript_inline_importmap_tag(importmap_json = Rails.application.importmap.to_json(resolver: self))
    tag.script importmap_json.html_safe,
               type:               'importmap',
               'data-turbo-track': 'reload',
               'data-turbo-eval':  'false',
               nonce:              request&.content_security_policy_nonce
  end

  def report_a_problem_url(document)
    query = { queue_id: 5581, resource: document_url(document) }.to_query
    "https://northeastern.libanswers.com/form?#{query}"
  end

  def document_url(document)
    if document.respond_to?(:klass) && document.klass.present?
      model_str = ActiveModel::Naming.singular_route_key(document.klass)
      send("#{model_str}_url", document)
    else
      polymorphic_url(document)
    end
  end

  # Muted, informational status icons for a search-result row. A lock when the
  # item isn't public — so someone who sees it only because they have
  # permission understands others may not (the recurring v1 "it doesn't exist"
  # confusion when a private item was shared). A link when the item is a linked
  # member of the container being viewed (its structural home is elsewhere).
  # Both carry a terse Bootstrap tooltip and read fields already on the Solr
  # doc — no extra queries.
  def document_status_icons(document)
    icons = []
    unless Array(document['read_access_group_ssim']).include?('public')
      icons << result_status_icon('fa-lock', 'Not public — only people with permission can see this')
    end
    if linked_member_here?(document)
      icons << result_status_icon('fa-link', 'Linked here — its home is another collection')
    end
    safe_join(icons) if icons.any?
  end

  # True when the document is a linked member of the container currently being
  # viewed (collection / community show). `a_linked_member_of_ssim` stores the
  # `id-<uuid>` of each collection a Work is linked into; there is no container
  # context on the catalog index, so this is false there.
  # The container is request-scoped controller state already loaded (with its
  # valkyrie_id in hand); re-deriving it from params[:id] would be a noid and
  # need a noid→uuid Solr lookup, defeating the zero-query design — so reading
  # the ivar is deliberate here.
  # rubocop:disable Rails/HelperInstanceVariable
  def linked_member_here?(document)
    container = (@collection || @community)&.valkyrie_id
    container.present? && Array(document['a_linked_member_of_ssim']).include?("id-#{container}")
  end
  # rubocop:enable Rails/HelperInstanceVariable

  def result_status_icon(icon_class, title)
    content_tag(:span, class: 'text-body-tertiary align-middle me-2', tabindex: '0',
                       data: { controller: 'tooltip', 'bs-title': title }) do
      content_tag(:i, '', class: "fa-solid #{icon_class} fa-sm", 'aria-hidden': 'true') +
        content_tag(:span, title, class: 'visually-hidden')
    end
  end
end
