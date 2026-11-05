# frozen_string_literal: true

# Depositor context shared by the deposit fork and My DRS: the effective
# depositor's curated Person and their workspace. See docs/identity.md.
module DepositorContext
  extend ActiveSupport::Concern

  private

    def deposit_person
      return @deposit_person if defined?(@deposit_person)

      @deposit_person = (Array(AtlasRb::Person.resolve([effective_user.nuid])).first if effective_user&.nuid)
    rescue AtlasRb::Error, Faraday::Error, JSON::ParserError
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
      effective_user.nuid.to_s.gsub(/["\\]/, '')
    end

    # The Person whose workspace the destination is in: the depositor's own, or
    # another person's that staff are depositing into for them. Nil anywhere
    # outside a workspace, which is what keeps promotion to workspaces. See
    # docs/deposit.md ("Publishing for someone else").
    def workspace_owner
      return @workspace_owner if defined?(@workspace_owner)

      @workspace_owner = own_workspace_owner || other_workspace_owner
    end

    # The depositor's Person names its root, so no flag is needed here.
    def own_workspace_owner
      own = deposit_person
      root_id = own&.[]('personal_root_id').to_s
      own if root_id.present? && within?(root_id)
    end

    # The root itself answers without reading the destination.
    def within?(root_id)
      root_id == @destination_id.to_s ||
        Array(destination_collection&.[]('ancestors')).any? { |node| node['noid'].to_s == root_id }
    end

    # The destination itself when it is a personal root, else the personal root
    # among its ancestors. Atlas flags each ancestor, so this costs no read
    # beyond the destination's own.
    def workspace_root_id
      collection = destination_collection
      return nil if collection.nil?
      return @destination_id.to_s if collection['personal_root']

      Array(collection['ancestors']).find { |node| node['personal_root'] }&.dig('noid')&.to_s
    end

    # True when the workspace is someone else's, so a promotion has to be made
    # as a proxy deposit for them.
    def publishing_for_someone_else?
      workspace_owner.present? && workspace_owner['nuid'].to_s != effective_user&.nuid.to_s
    end

    # Empty hides the publish branch entirely, so the owner check is the gate on
    # publishing, not a display detail.
    def publish_targets
      person = workspace_owner
      return {} unless person

      Array(person['affiliated_community_ids']).each_with_object({}) do |noid, targets|
        genres = ShowcaseFinder.call(scope: self, community_noid: noid).except(*FeaturedContent::STAFF_ONLY)
        next if genres.blank?

        # The hash order is the option order, both in the no-JS fallback and in
        # the list the Stimulus controller rebuilds, so the sort happens here.
        genres = genres.slice(*FeaturedContent.picker_order(genres.keys))
        targets[noid.to_s] = { name: community_name(noid), genres: genres }
      end
    end

    # Resolves a showcase in one of the workspace owner's communities only. The
    # caller must confirm separately that the Work's depositor is that owner.
    def publish_showcase_id
      person = workspace_owner
      return nil if person.blank?

      community_noid = params[:publish_community_id].to_s
      return nil unless Array(person['affiliated_community_ids']).map(&:to_s).include?(community_noid)
      return nil if FeaturedContent::STAFF_ONLY.include?(params[:publish_genre])

      ShowcaseFinder.call(scope: self, community_noid: community_noid,
                          genre_label: params[:publish_genre])
    end

    # Atlas mints a personal root with its owner as depositor, and the owner's
    # Person names it back as personal_root_id. Both have to agree. Read off the
    # root, not the destination: a collection inside the workspace may have
    # been made by staff, so its own depositor proves nothing.
    def other_workspace_owner
      root_id = workspace_root_id
      root = workspace_root(root_id)
      return nil unless root && root['personal_root'] && root['depositor'].present?

      person = Array(AtlasRb::Person.resolve([root['depositor']])).first
      person if person && person['personal_root_id'].to_s == root_id
    rescue AtlasRb::Error, Faraday::Error, JSON::ParserError
      nil
    end

    def workspace_root(root_id)
      return nil if root_id.nil?

      root_id == @destination_id.to_s ? destination_collection : AtlasRb::Collection.find(root_id)
    end

    def destination_collection
      return @destination_collection if defined?(@destination_collection)

      @destination_collection = (AtlasRb::Collection.find(@destination_id) if @destination_id.present?)
    end

    def community_name(noid)
      AtlasRb::Community.find(noid)&.[]('title').presence || noid.to_s
    rescue AtlasRb::Error, Faraday::Error, JSON::ParserError
      noid.to_s
    end
end
