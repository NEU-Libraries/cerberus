# frozen_string_literal: true

# My DRS — the depositor's workspace and published spaces. See
# docs/discovery.md.
#
# Every panel is a gated Solr query through `search_service.search_builder`, and
# the work panels narrow to this depositor with `depositor_ssi`. Both halves
# matter: drop either one and a depositor is shown rows that are not theirs.
class MyDrsController < CatalogController
  include DepositorContext

  def index
    return redirect_to(root_path, alert: 'Sign in to see your DRS.') unless current_user&.nuid

    @accounts = account_list
    @workspace_collections = workspace_collections
    @published = published_by_category
    @unfinished = unfinished_deposits
    @incomplete = incomplete_works
    @personal_root_id = deposit_person&.[]('personal_root_id').presence
  end

  private

    # An Atlas fault degrades to an empty list rather than a broken My DRS.
    def account_list
      AtlasRb::User.accounts(current_user.nuid, nuid: current_user.nuid)['accounts']
    rescue Faraday::Error, JSON::ParserError => e
      Rails.logger.error("My DRS account lookup failed for #{current_user.nuid}: #{e.class} #{e.message}")
      []
    end

    def published_by_category
      person = deposit_person
      communities = person ? Array(person['affiliated_community_ids']) : []
      return [] if communities.empty?

      grouped = showcase_docs(communities).filter_map do |showcase|
        works = works_published_into(showcase.id)
        [Array(showcase['title_tsim']).first, works] if works.present?
      end
      grouped.sort_by { |label, _works| FeaturedContent.genre_labels.index(label) || FeaturedContent::GENRES.size }
    end

    # Returns documents, not ids: callers need both the NOID (routing) and the
    # uuid (membership).
    def showcase_docs(community_noids)
      builder = search_service.search_builder.with({}).with_filters(
        'internal_resource_tesim:Collection', 'featured_bsi:true', '-tombstoned_bsi:true',
        MembershipQuery.descendants_fq(community_noids)
      ).merge(rows: 100)
      Blacklight.default_index.search(params: builder).documents
    end

    # The gated search's own unfinished-deposit filter already holds a depositor
    # to their own rows, so this composes with it rather than working around it.
    def unfinished_deposits
      own_works('in_progress_bsi:true')
    end

    # `-in_progress_bsi:true` is not redundant here: it keeps the two panels
    # disjoint, so an unfinished deposit stays under "Deposits to finish".
    def incomplete_works
      own_works('incomplete_bsi:true', '-in_progress_bsi:true')
    end

    def own_works(*filters)
      builder = search_service.search_builder.with({}).with_filters(
        'internal_resource_tesim:Work',
        %(depositor_ssi:"#{depositor_phrase}"),
        '-tombstoned_bsi:true',
        *filters
      ).merge(rows: 50)
      Blacklight.default_index.search(params: builder).documents
    end

    # Publish writes a linked-member edge, so the membership fq has to include
    # linked members or a published work never appears here.
    def works_published_into(showcase_uuid)
      builder = search_service.search_builder.with({}).with_filters(
        'internal_resource_tesim:Work',
        %(depositor_ssi:"#{depositor_phrase}"),
        MembershipQuery.members_fq([showcase_uuid], include_linked: true),
        '-tombstoned_bsi:true'
      ).merge(rows: 50)
      Blacklight.default_index.search(params: builder).documents
    end
end
