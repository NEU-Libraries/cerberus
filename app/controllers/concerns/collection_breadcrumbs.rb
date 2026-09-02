# frozen_string_literal: true

# Breadcrumb trail for a Collection, including the personal-workspace variants.
# Shared by CollectionsController and the XML editor.
# See docs/people-and-routing.md.
module CollectionBreadcrumbs
  extend ActiveSupport::Concern

  private

    def collection_breadcrumbs(id, editing: false)
      result = AtlasRb::Resource.find(id)
      parent_noid = Array(result.resource.ancestors).last&.dig('noid')

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

    def owner_workspace?(parent_noid)
      parent_noid.present? && parent_noid == deposit_person&.[]('personal_root_id')
    end

    def workspace_collection_tail(result, editing:)
      if editing
        edit_breadcrumb_tail(result.resource, result.klass)
      else
        add_breadcrumb_for(result.resource.id, result.klass, result.resource.title)
      end
    end

    # The owning Person is resolved from the personal root's depositor, not the
    # item's own: Atlas mints the root with depositor = the person's NUID, while a
    # proxy or a seed may set an item's depositor to someone else.
    def personal_root_owner(parent_noid)
      return nil if parent_noid.blank?

      root = collection_doc(parent_noid)
      return nil unless root&.personal_root?

      AtlasRb::Person.resolve([root['depositor_ssi']]).first
    rescue Faraday::Error, JSON::ParserError
      nil
    end

    # The noid is stripped of quote, backslash and colon before it is interpolated
    # into the fq.
    def collection_doc(noid)
      Blacklight.default_index.search(
        q: '*:*', rows: 1,
        fq: ['internal_resource_tesim:Collection', "alternate_ids_tesim:#{noid.to_s.gsub(/["\\:]/, '')}"]
      ).documents.first
    end
end
