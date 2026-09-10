# frozen_string_literal: true

module ApplicationHelper
  def application_version
    VERSION
  end

  # Whether the NUID sign-in shim exists in this environment. It stands in for
  # SSO, which is production-only, so dev and staging offer it and production
  # must not — it authenticates on a NUID with no secret.
  #
  # MUST track the matching condition in config/routes.rb: linking to a route that
  # is not mounted raises, so the two moving apart breaks the page rather than
  # degrading it.
  def nuid_sign_in_available?
    !Rails.env.production?
  end

  # Where an unauthenticated visitor is sent to sign in: the NUID shim where it
  # exists, otherwise the ordinary session form (which is where SSO will land).
  def sign_in_path_for_environment
    nuid_sign_in_available? ? atlas_login_path : new_user_session_path
  end

  def document_type_icon(klass_type)
    case klass_type
    when 'Community'  then 'fa-users'
    when 'Collection' then 'fa-folder-open'
    when 'Person'     then 'fa-user'
    else 'fa-file'
    end
  end

  # The thumbnail type-pill text, in priority order.
  #
  # "In progress" outranks even "Embargoed". The only people who see an unfinished
  # deposit are the three who can act on it, and for them "this row is a
  # placeholder awaiting its metadata" governs everything else the pill could say,
  # including an embargo date on a record that is not finished yet.
  #
  # Then "Embargoed", because a viewer needs to know downloads are withheld before
  # anything else — including ahead of "Incomplete", which is a maintenance fact
  # about a record anyone can still read, and which has surfaces of its own.
  #
  # Then "Featured" for curated showcases; "People" for the synthetic Faculty &
  # Staff browse row (a browse-to-many, not an individual); else the document's
  # resource type.
  def pill_label(document)
    return 'In progress' if document.try(:in_progress?)
    return 'Embargoed' if document.try(:embargoed?)
    return 'Incomplete' if document.try(:incomplete?)
    return 'Featured' if document.try(:featured?)
    return 'People' if document.try(:people_browse?)

    document.klass_type
  end

  # "Contents available <date>" — the compact list/gallery-view companion to
  # the show page's embargo banner. Plain (not iconed): the row's status icons
  # already use fa-lock for "not public," a different axis than embargo, so
  # reusing an icon here would blur the two.
  def embargo_notice(document)
    return unless document.try(:embargoed?)

    date = Embargo.release_date(document.try(:embargo_release_date))
    return if date.blank?

    content_tag(:span, "Contents available #{date.strftime('%B %-d, %Y')}", class: 'text-danger small me-2')
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

  # The citable URL for a Work's minted handle. `handle` is the bare identifier
  # ("2047/gq67jr519"), not a URL — a resolver turns it into one, and which
  # resolver is deployment config (config.x.cerberus.handle_resolver_base).
  #
  # Minting is best-effort in Atlas, so a complete Work can carry no handle.
  # That means "not minted yet", not an error: this returns nil and the caller
  # renders nothing rather than a link that goes nowhere.
  def handle_url(handle)
    return if handle.blank?

    "#{Rails.application.config.x.cerberus.handle_resolver_base.chomp('/')}/#{handle}"
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
  def linked_member_here?(document)
    container = (@collection || @community)&.valkyrie_id
    container.present? && Array(document['a_linked_member_of_ssim']).include?("id-#{container}")
  end

  def result_status_icon(icon_class, title)
    content_tag(:span, class: 'text-body-tertiary align-middle me-2', tabindex: '0',
                       data: { controller: 'tooltip', 'bs-title': title }) do
      content_tag(:i, '', class: "fa-solid #{icon_class} fa-sm", 'aria-hidden': 'true') +
        content_tag(:span, title, class: 'visually-hidden')
    end
  end

  # The read-only maintenance window, for the standing banner. Wrapped in
  # helpers rather than called on MaintenanceMode from the template so the
  # cached Atlas read has one entry point from the view layer.
  def maintenance_window? = MaintenanceMode.read_only?

  def maintenance_message = MaintenanceMode.message
end
