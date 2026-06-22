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
end
