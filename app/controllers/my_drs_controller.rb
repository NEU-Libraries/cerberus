# frozen_string_literal: true

# My DRS — the depositor's two-space home. The left space is their **workspace**
# (the Collections they own; drafts and working files, discoverable by their own
# visibility but never promoted). The right space is **published**: the works
# they've promoted into their community's genre showcases, grouped by category.
# The split makes the curation boundary legible — workspace vs the professional
# tier — which is the whole point of the weighted deposit fork.
#
# Inherits CatalogController for the gated search_service / SearchBuilder; the
# depositor context (their Person + owned Collections) comes from
# DepositorContext, shared with the deposit fork.
class MyDrsController < CatalogController
  include DepositorContext

  def index
    return redirect_to(root_path, alert: 'Sign in to see your DRS.') unless current_user&.nuid

    # The accounts sharing this person's NUID — drives the switcher panel, which
    # the view renders only when there's more than one.
    @accounts = account_list
    @workspace_collections = workspace_collections
    @published = published_by_category
    # Drives the "New collection" affordance — present only for a depositor with
    # a personal root to create the collection under.
    @personal_root_id = deposit_person&.[]('personal_root_id').presence
  end

  private

    # A person's staff/student logins under one NUID. An Atlas hiccup degrades to
    # an empty list (no panel) rather than a broken My DRS.
    def account_list
      AtlasRb::User.accounts(current_user.nuid, nuid: current_user.nuid)['accounts']
    rescue Faraday::Error, JSON::ParserError => e
      Rails.logger.error("My DRS account lookup failed for #{current_user.nuid}: #{e.class} #{e.message}")
      []
    end

    # The depositor's published works grouped by showcase category, as
    # [[label, [work_docs]], ...] in the shared genre vocabulary's order. Only
    # categories with at least one published work are included — an all-empty
    # result yields [], which the view renders as the column-level empty state.
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

    # The featured showcase Collections across the depositor's affiliated
    # communities (one gated query over their subtrees). Returned as documents
    # so callers get both the NOID (routing) and the uuid (membership).
    def showcase_docs(community_noids)
      builder = search_service.search_builder.with({}).with_filters(
        'internal_resource_tesim:Collection', 'featured_bsi:true', '-tombstoned_bsi:true',
        MembershipQuery.descendants_fq(community_noids)
      ).merge(rows: 100)
      Blacklight.default_index.search(builder).documents
    end

    # The depositor's own works surfaced into one showcase (the linked-member
    # edge the publish branch writes). Gated — published works are public, so
    # the depositor sees them here.
    def works_published_into(showcase_uuid)
      builder = search_service.search_builder.with({}).with_filters(
        'internal_resource_tesim:Work',
        %(depositor_ssi:"#{depositor_phrase}"),
        MembershipQuery.members_fq([showcase_uuid], include_linked: true),
        '-tombstoned_bsi:true'
      ).merge(rows: 50)
      Blacklight.default_index.search(builder).documents
    end
end
