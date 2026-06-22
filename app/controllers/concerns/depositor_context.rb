# frozen_string_literal: true

# Shared depositor context for the curation surfaces — the weighted deposit
# fork (WorksController) and the My DRS two-space page (MyDrsController). Both
# need the signed-in depositor's curated Person (for affiliations + the personal
# root that homes published works) and the list of Collections they own (their
# workspace).
module DepositorContext
  extend ActiveSupport::Concern

  private

    # The depositor's curated Person — authoritative display name, affiliations,
    # and personal_root_id — resolved from their NUID and memoised for the
    # request. nil for anyone without a Person (most depositors), which simply
    # means no publish branch. Resolution failures degrade to nil rather than
    # blocking a workspace deposit.
    def deposit_person
      return @deposit_person if defined?(@deposit_person)

      @deposit_person = (AtlasRb::Person.resolve([current_user.nuid]).first if current_user&.nuid)
    rescue Faraday::Error, JSON::ParserError
      @deposit_person = nil
    end

    # The depositor's own Collections — the workspace. Deliberately UNGATED: a
    # depositor must see every collection they own, public or private, to work
    # with it (gated discovery would hide their own private collections).
    # Featured showcases are excluded — those are publish targets, not workspace
    # homes.
    def workspace_collections(rows: 200)
      return [] unless current_user&.nuid

      Blacklight.default_index.search(
        q: '*:*', rows: rows, sort: 'system_create_dtsi desc',
        fq: ['internal_resource_tesim:Collection',
             %(depositor_ssi:"#{depositor_phrase}"),
             '-featured_bsi:true', '-tombstoned_bsi:true']
      ).documents
    end

    # The signed-in depositor's NUID, escaped for a quoted Solr phrase.
    def depositor_phrase
      current_user.nuid.to_s.gsub(/["\\]/, '')
    end

    # Publish destinations for the deposit fork, keyed by community NOID:
    # { noid => { name:, genres: { label => showcase_noid } } }. Only the
    # depositor's affiliated communities that actually have showcases appear, and
    # only when the Person carries a personal_root_id to home published works in.
    # Empty (publish branch hidden) for anyone without a qualifying Person — the
    # whole branch is gated behind this being present.
    def publish_targets
      person = deposit_person
      return {} unless person && person['personal_root_id'].present?

      Array(person['affiliated_community_ids']).each_with_object({}) do |noid, targets|
        genres = ShowcaseFinder.call(scope: self, community_noid: noid)
        next if genres.blank?

        targets[noid.to_s] = { name: community_name(noid), genres: genres }
      end
    end

    # Resolve the publish destination from the submitted community + genre:
    # { root_id:, showcase_id: }, or nil when it can't be honoured. Guards every
    # leg — the depositor must have a Person with a personal_root_id, the chosen
    # community must be one they're affiliated with, and a showcase must exist
    # for the chosen genre there (gated, so a showcase they can't see is nil).
    def publish_target
      person = deposit_person
      root_id = person && person['personal_root_id'].presence
      return nil if root_id.blank?

      community_noid = params[:publish_community_id].to_s
      return nil unless Array(person['affiliated_community_ids']).map(&:to_s).include?(community_noid)

      showcase_id = ShowcaseFinder.call(scope: self, community_noid: community_noid,
                                        genre_label: params[:publish_genre])
      return nil if showcase_id.blank?

      { root_id: root_id, showcase_id: showcase_id }
    end

    # A community's title for the publish picker, degrading to its NOID if the
    # lookup fails (a stale affiliation shouldn't break the deposit form).
    def community_name(noid)
      AtlasRb::Community.find(noid)['title'].presence || noid.to_s
    rescue Faraday::Error, JSON::ParserError
      noid.to_s
    end
end
