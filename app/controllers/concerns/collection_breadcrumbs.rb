# frozen_string_literal: true

# Breadcrumb trail for a Collection (show, edit, and the raw-XML sub-tab). A
# personal workspace collection (one under a Person's personal root) is trailed
# away from the structural "People / Personal Root" prefix:
#   * the owner sees "My DRS / <collection>" — their personal home;
#   * everyone else (incl. logged-out) sees "People / <Person> / <collection>"
#     — the public, person-rooted trail.
# Any other collection gets the plain structural trail (sharing the one
# AtlasRb::Resource.find via the result: hand-off).
#
# Extracted from CollectionsController so the XML editor (XmlController) can build
# the same trail: clicking the XML tab from an edit page must keep the personal-
# root prefix instead of falling back to the structural "People / Personal Root"
# trail. Leans on ApplicationController's #breadcrumbs / #breadcrumb /
# #add_breadcrumb_for / #edit_breadcrumb_tail and DepositorContext's #deposit_person.
module CollectionBreadcrumbs
  extend ActiveSupport::Concern

  private

    # +editing+ swaps the show tail (collection = you-are-here crumb) for the edit
    # tail (collection as a link back to its show page + "Edit Collection" current
    # crumb), so an edit/XML page keeps the same prefix as the show page.
    def collection_breadcrumbs(id, editing: false)
      result = AtlasRb::Resource.find(id)
      parent_noid = Array(result.resource.ancestor_chain).last&.dig('noid')

      if owner_workspace?(parent_noid)
        breadcrumb('My DRS', my_drs_path)
        workspace_collection_tail(result, editing: editing)
      elsif (owner = personal_root_owner(parent_noid))
        breadcrumb('People', people_path)
        breadcrumb(owner['display_name'], person_path(owner['id']))
        workspace_collection_tail(result, editing: editing)
      else
        breadcrumbs(id, editing: editing, result: result)
      end
    end

    # The viewer is looking at a collection in their own personal-root workspace.
    def owner_workspace?(parent_noid)
      parent_noid.present? && parent_noid == deposit_person&.[]('personal_root_id')
    end

    # The trail tail after the personal-root prefix: on a show page the collection
    # is the you-are-here crumb; on an edit/XML page it becomes a link back to the
    # show page followed by the "Edit Collection" current crumb (shared edit_breadcrumb_tail).
    def workspace_collection_tail(result, editing:)
      if editing
        edit_breadcrumb_tail(result.resource, result.klass)
      else
        add_breadcrumb_for(result.resource.id, result.klass, result.resource.title)
      end
    end

    # The Person who owns +parent_noid+ when it's a personal root (flagged
    # personal_root_bsi), else nil. The owning Person is resolved from the root's
    # depositor (Atlas mints the root with depositor = the person's NUID — more
    # reliable than the item's own depositor, which a proxy/seed may set to
    # someone else). A lookup failure degrades to nil → structural trail.
    def personal_root_owner(parent_noid)
      return nil if parent_noid.blank?

      root = collection_doc(parent_noid)
      return nil unless root&.personal_root?

      AtlasRb::Person.resolve([root['depositor_ssi']]).first
    rescue Faraday::Error, JSON::ParserError
      nil
    end

    # The Solr document for a Collection addressed by NOID (carries
    # personal_root_bsi + depositor_ssi), or nil.
    def collection_doc(noid)
      Blacklight.default_index.search(
        q: '*:*', rows: 1,
        fq: ['internal_resource_tesim:Collection', "alternate_ids_tesim:#{noid.to_s.gsub(/["\\:]/, '')}"]
      ).documents.first
    end
end
