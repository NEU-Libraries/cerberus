# frozen_string_literal: true

# Which of a community's genre showcases its browse lists. See
# docs/discovery.md ("Hiding empty showcases").
module CommunityShowcases
  extend ActiveSupport::Concern

  MEMBERSHIP_FIELDS = [MembershipQuery::STRUCTURAL_FIELD, MembershipQuery::LINKED_FIELD].freeze

  included do
    helper_method :current_sort_field
  end

  private

    # The Sort dropdown marks Blacklight's current_sort_field, which matches the
    # sort Solr ran. Floating the showcases runs a sort no field declares, which
    # would mark "relevance"; the search state still names the field in force.
    def current_sort_field
      search_state.sort_field
    end

    # The community's own showcases first, in FeaturedContent::GENRES order, then
    # everything by title, as v1 floated its genre rows. Only for a plain browse
    # or an empty search: a keyword, a facet or a picked sort each take the
    # listing over. nil leaves the search state's sort alone.
    def showcases_first_sort(showcase_uuids)
      @floated_showcase_uuids = []
      return if showcase_uuids.empty? || params[:q].present? || params[:sort].present? || search_state.filters.any?

      @floated_showcase_uuids = showcase_uuids
      weights = showcase_uuids.reverse.each_with_index.map do |uuid, i|
        "mul(#{i + 1},query({!term f=id v=#{uuid}},0))"
      end
      "sum(0,#{weights.join(',')}) desc, title_ssi asc"
    end

    # How many rows at the top of this page are floated showcases.
    def floated_showcase_count
      @response.documents.take_while { |doc| @floated_showcase_uuids.to_a.include?(doc.id) }.size
    end

    # The people who load into a showcase must be able to find it before it
    # has anything in it: an XML load into a new community's Theses &
    # Dissertations asks for its PID. Everyone else gets the tidy listing.
    def hidden_showcase_uuids(empty_uuids)
      showcase_manager? ? [] : empty_uuids
    end

    def showcase_manager?
      effective_user&.admin? || effective_user&.admin_delegate? || false
    end

    # SolrDocument#empty_showcase? reads the flag, so the row's pill says why a
    # showcase has nothing to browse. A response document is frozen, so the
    # flagged row is a copy put in its place.
    def mark_empty_showcases(empty_uuids)
      return if empty_uuids.empty?

      @response.documents.map! do |doc|
        next doc unless empty_uuids.include?(doc.id)

        SolrDocument.new(doc.to_h.merge('empty_showcase_bsi' => true), @response)
      end
    end

    # Exclude the empty showcases at query time, as an fq on find_children, and
    # never as a Ruby post-filter on the returned documents: a post-filter leaves
    # Solr's Type facet counting the rows it hid.
    def empty_showcase_uuids(showcase_uuids)
      showcase_uuids - populated_showcase_ids(showcase_uuids).to_a
    end

    # In FeaturedContent::GENRES order; a title outside the genre list goes last.
    def featured_showcase_uuids(community_uuid)
      builder = search_service.search_builder.with({}).with_filters(
        'internal_resource_tesim:Collection', 'featured_bsi:true', '-tombstoned_bsi:true',
        MembershipQuery.members_fq([community_uuid], include_linked: false)
      ).merge(rows: 100, fl: 'id,title_tsim')
      genres = FeaturedContent.genre_labels
      Blacklight.default_index.search(params: builder).documents
                .sort_by { |doc| genres.index(Array(doc['title_tsim']).first) || genres.size }
                .map(&:id)
    end

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
      Blacklight.default_index.search(params: builder).dig('facet_counts', 'facet_fields') || {}
    end

    # Solr returns facet_fields as a flat [value, hits, value, hits, ...] array.
    def each_positive_facet(pairs)
      Array(pairs).each_slice(2) { |value, hits| yield value.to_s if hits.to_i.positive? }
    end
end
