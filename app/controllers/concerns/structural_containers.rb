# frozen_string_literal: true

# The People Community and each personal root: Atlas keeps both in every
# ancestor chain beneath them, and neither is a page anyone should land on.
# Trails replace them with the owner's profile trail, and their show pages
# redirect. See docs/people-and-routing.md.
module StructuralContainers
  extend ActiveSupport::Concern

  PERSON_FIELDS = 'noid_ssi,display_name_ssi,affiliated_community_ids_ssim'

  private

    # +item+ is the resource the trail ends on. It matters only when the item
    # is itself a personal root, which has no root entry among its ancestors.
    # A failed owner lookup still drops the structural entries: the raw chain
    # is exactly the trail this exists to avoid.
    def ancestor_trail(ancestors, item: nil, match: :inclusive)
      chain = Array(ancestors)
      root_at = chain.rindex { |node| node['personal_root'] }
      owner_trail(root_at ? chain[root_at]['noid'] : own_root_noid(item))

      below = root_at ? chain.drop(root_at + 1) : chain
      below.reject { |node| structural?(node) }.each do |node|
        add_breadcrumb_for(node['noid'], node['klass'], node['title'], match: match)
      end
    end

    def own_root_noid(item)
      item.id if item&.[]('personal_root')
    end

    def structural?(node)
      node['system_container'] || node['personal_root']
    end

    def owner_trail(root_noid)
      owner = personal_root_owner(root_noid)
      return unless owner

      person_trail(Array(owner['affiliated_community_ids_ssim']).first, owner['display_name_ssi'], owner['noid_ssi'])
    end

    # The profile trail, shared with PeopleController so a Work's trail extends
    # its owner's profile trail exactly. `match: :exact`: /communities/:id is a
    # prefix of /communities/:id/people. The find inside #breadcrumbs runs
    # before any crumb is added, so the rescue rebuilds from nothing.
    def person_trail(community_noid, name, person_noid)
      if community_noid.present?
        breadcrumbs(community_noid, match: :exact)
        breadcrumb('Faculty & Staff', community_people_path(community_noid))
      else
        breadcrumb('People', people_path)
      end
      breadcrumb(name, person_path(person_noid))
    rescue Faraday::Error, JSON::ParserError
      breadcrumb('People', people_path)
      breadcrumb(name, person_path(person_noid))
    end

    # Keyed on the root rather than on the item's depositor, because a proxy or
    # a seed can deposit into someone else's workspace.
    def personal_root_owner(root_noid)
      return nil if root_noid.blank?

      Blacklight.default_index.search(
        q: '*:*', rows: 1, fl: PERSON_FIELDS,
        fq: ['internal_resource_tesim:Person', %(personal_root_id_ssi:"#{solr_safe(root_noid)}")]
      ).documents.first
    end

    def personal_root_home(root_noid)
      owner = personal_root_owner(root_noid)
      owner ? person_path(owner['noid_ssi']) : people_path
    end

    # Deliberately ungated. Atlas refuses the People Community to everyone but
    # full admins, so a gated read would hide the flag from exactly the
    # visitors the redirect is for. It answers one boolean about a known id.
    def system_container?(noid)
      Blacklight.default_index.search(
        q: '*:*', rows: 0,
        fq: ['system_container_bsi:true', "alternate_ids_tesim:#{solr_safe(noid)}"]
      ).total.positive?
    end

    def solr_safe(value)
      value.to_s.gsub(/["\\:]/, '')
    end
end
