# frozen_string_literal: true

# Depositor context shared by the deposit fork and My DRS: the signed-in
# depositor's curated Person and their workspace. See docs/identity.md.
module DepositorContext
  extend ActiveSupport::Concern

  private

    def deposit_person
      return @deposit_person if defined?(@deposit_person)

      @deposit_person = (AtlasRb::Person.resolve([current_user.nuid]).first if current_user&.nuid)
    rescue Faraday::Error, JSON::ParserError
      @deposit_person = nil
    end

    # Scope to the Person's personal-root subtree, NOT to every collection this
    # depositor has deposited into: without the ancestor filter an admin who
    # seeded the institutional tree "owns" all of it. The query is deliberately
    # ungated — a depositor's own private collections must stay visible here.
    def workspace_collections(rows: 200)
      root = deposit_person&.[]('personal_root_id').presence
      return [] unless root

      Blacklight.default_index.search(
        q: '*:*', rows: rows, sort: 'created_at_dtsi desc',
        fq: ['internal_resource_tesim:Collection',
             %(ancestor_ids_ssim:"#{root.to_s.gsub(/["\\]/, '')}"),
             '-featured_bsi:true', '-tombstoned_bsi:true']
      ).documents
    end

    # Escaped for a quoted Solr phrase.
    def depositor_phrase
      current_user.nuid.to_s.gsub(/["\\]/, '')
    end

    # Empty hides the publish branch entirely, so the personal_root_id check is
    # the gate on publishing, not a display detail.
    def publish_targets
      person = deposit_person
      return {} unless person && person['personal_root_id'].present?

      Array(person['affiliated_community_ids']).each_with_object({}) do |noid, targets|
        genres = ShowcaseFinder.call(scope: self, community_noid: noid)
        next if genres.blank?

        targets[noid.to_s] = { name: community_name(noid), genres: genres }
      end
    end

    # Resolves a showcase only — it does NOT check where the Work is going. The
    # caller must confirm separately that the destination is the depositor's own
    # root before offering promotion.
    def publish_showcase_id
      person = deposit_person
      return nil if person.blank?

      community_noid = params[:publish_community_id].to_s
      return nil unless Array(person['affiliated_community_ids']).map(&:to_s).include?(community_noid)

      ShowcaseFinder.call(scope: self, community_noid: community_noid,
                          genre_label: params[:publish_genre])
    end

    def community_name(noid)
      AtlasRb::Community.find(noid)['title'].presence || noid.to_s
    rescue Faraday::Error, JSON::ParserError
      noid.to_s
    end
end
