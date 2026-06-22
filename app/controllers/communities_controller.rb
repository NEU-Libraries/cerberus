# frozen_string_literal: true

class CommunitiesController < CatalogController
  include Thumbable
  include Transformable
  include ShowScopedSearch

  before_action :authorize_edit!, only: [:edit]
  before_action :authorize_tombstone!, only: [:tombstone]

  # Solr membership fields faceted to decide whether a showcase has content
  # (structural children + linked-member edges). See #populated_showcase_ids.
  MEMBERSHIP_FIELDS = [MembershipQuery::STRUCTURAL_FIELD, MembershipQuery::LINKED_FIELD].freeze

  def show
    @community = AtlasRb::Community.find(params[:id])
    return render_gone(@community) if @community.tombstoned

    authorize_show!
    @response = find_children(@community.valkyrie_id, params[:id])
    hide_empty_showcases
    prepend_faculty_staff_entry(params[:id])
    @can_tombstone = current_ability.can?(:tombstone,
                                          solr_doc_from_permissions(@permissions, klass: 'Community'))
    breadcrumbs(params[:id])
  end

  def tombstone
    AtlasRb::Community.tombstone(params[:id])
    redirect_to root_path, notice: 'Community deleted.'
  end

  def new
    @community = OpenStruct.new
  end

  def edit
    @community = AtlasRb::Community.find(params[:id])
    form_preparation(@permissions)
    load_descriptive!('Community')
    breadcrumbs(params[:id], editing: true)
  end

  def create
    permitted = params.require(:community).permit(:title, :description).to_h

    c = AtlasRb::Community.create(params[:parent_id])
    save_descriptive!('Community', c.id, title: permitted['title'], description: permitted['description'])
    provision_showcases(c.id)
    redirect_to community_path(c.id)
  end

  def update
    handle_metadata_update(klass: 'Community', resource_key: :community, keywords: false)
  end

  private

    # Provision the genre "showcase" Collections a community publishes into.
    # Each is an ordinary Collection flagged `featured` (so it carries the
    # Featured pill and is a valid target for the deposit fork's publish edge),
    # titled after the shared scholarly vocabulary. Runs once, right after the
    # community is created — mirroring CollectionsController#create's single
    # create + save_descriptive! idiom, looped. A per-showcase failure is logged
    # and skipped rather than aborting: the community already exists by this
    # point, and a missing showcase can be re-created later, but a raised error
    # here would 500 an otherwise-successful create. Empty showcases stay hidden
    # from the browse until populated (see #hide_empty_showcases).
    def provision_showcases(community_id)
      FeaturedContent.genre_labels.each do |label|
        showcase = AtlasRb::Collection.create(community_id, featured: true)
        save_descriptive!('Collection', showcase.id, title:       label,
                                                     description: "Featured #{label.downcase} for this community.")
      rescue Faraday::Error, JSON::ParserError => e
        Rails.logger.warn("[showcase provisioning] #{label} under #{community_id} failed: #{e.message}")
      end
    end

    # v1-faithful: only show Featured Collections that have content. Provisioning
    # seeds every community with the full genre showcase set, so without this the
    # browse would be littered with empty showcase rows. Drop featured-showcase
    # documents with zero members (structural or linked) from the response, in a
    # single gated facet query (no N+1). Ordinary empty user/workspace Collections
    # are left alone — showing an empty collection one created is intentional;
    # this gate is scoped to `featured?` showcases, pairing with the Faculty &
    # Staff node so both curated affordances appear only when populated.
    def hide_empty_showcases
      showcases = @response.documents.select { |doc| showcase?(doc) }
      return if showcases.empty?

      populated = populated_showcase_ids(showcases.map(&:id))
      empties   = showcases.reject { |doc| populated.include?(doc.id) }
      drop_documents(empties) if empties.any?
    end

    def showcase?(doc)
      doc.respond_to?(:featured?) && doc.featured?
    end

    # Remove +docs+ from the rendered response and keep "Displaying N" honest by
    # discounting them from numFound (a synthetic count adjustment, since the
    # docs are real Solr hits we're choosing to suppress).
    def drop_documents(docs)
      @response.documents.delete_if { |doc| docs.include?(doc) }
      @response.response['numFound'] = [@response.total - docs.size, 0].max
    end

    # The subset of +showcase_uuids+ (Solr uniqueKeys) that have >=1 member,
    # structural or linked. One gated, rows-0 facet query over the membership
    # fields restricted to those showcases; the raw facet_counts (value/hits
    # pairs, values in `id-<uuid>` form) are read directly so we don't depend on
    # a configured Blacklight facet. Returns a Set of bare uuids.
    def populated_showcase_ids(showcase_uuids)
      return Set.new if showcase_uuids.empty?

      counts = showcase_member_counts(showcase_uuids)
      MEMBERSHIP_FIELDS.each_with_object(Set.new) do |field, ids|
        each_positive_facet(counts[field]) { |value| ids << value.delete_prefix('id-') }
      end
    end

    def showcase_member_counts(showcase_uuids)
      members = MembershipQuery.members_fq(showcase_uuids, include_linked: true)
      builder = search_service.search_builder.with({}).with_filters(members)
                              .merge(rows: 0, facet: true, 'facet.mincount': 1, 'facet.field': MEMBERSHIP_FIELDS)
      Blacklight.default_index.search(builder).dig('facet_counts', 'facet_fields') || {}
    end

    # Yield each Solr facet value (an `id-<uuid>` string) with a positive count
    # from a flat [value, hits, value, hits, ...] facet_fields array.
    def each_positive_facet(pairs)
      Array(pairs).each_slice(2) { |value, hits| yield value.to_s if hits.to_i.positive? }
    end

    # Surface a synthetic "Faculty & Staff" row as the first entry of a community's
    # browse, rendered through the normal Blacklight pipeline so it matches the
    # list/gallery rows exactly. Only when there are affiliated People to browse,
    # and only on the unfiltered first page (mirrors v1's current_page == 1 && no
    # constraints) so it drops out once the visitor searches-within or facets.
    # The synthetic isn't in Solr, so we also bump the response total by one to
    # keep "Displaying N entries" matching the rows actually shown.
    def prepend_faculty_staff_entry(community_noid)
      return if params[:page].present? && params[:page].to_i > 1
      return if params[:q].present? || params[:f].present?
      return unless affiliated_people_count(community_noid).positive?

      @response.documents.unshift(faculty_staff_stub(community_noid))
      @response.response['numFound'] = @response.total + 1
    end

    # A non-Solr SolrDocument styled as a Person result row (fa-user icon, type
    # pill), titled "Faculty & Staff", carrying its own nav_url to the listing.
    def faculty_staff_stub(community_noid)
      SolrDocument.new(
        'id'                      => "faculty-staff-#{community_noid}",
        'internal_resource_tesim' => ['Person'],
        'title_tsim'              => ['Faculty & Staff'],
        'description_tsim'        => ['Browse faculty and staff by name'],
        'nav_url_ssi'             => community_people_path(community_noid),
        # Public directory affordance — keeps document_status_icons from flagging
        # this synthetic row as private (a lock).
        'read_access_group_ssim'  => ['public']
      )
    end

    # Gated count of Person docs affiliated with this community. Affiliations
    # index as community NOIDs in affiliated_community_ids_ssim.
    def affiliated_people_count(community_noid)
      builder = search_service.search_builder.with({}).with_filters(
        'internal_resource_tesim:Person',
        %(affiliated_community_ids_ssim:"#{community_noid.to_s.gsub(/["\\]/, '')}")
      ).merge(rows: 0)
      Blacklight.default_index.search(builder).total
    end
end
