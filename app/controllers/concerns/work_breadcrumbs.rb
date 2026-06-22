# frozen_string_literal: true

# Breadcrumb trail for a Work show page. A *published* work is structurally homed
# in its depositor's Person personal-root collection; rather than exposing that
# as a generic "Personal Root" container, it's trailed through the Person
# (linking /people/:noid) and that person's affiliated community + ancestors —
# mirroring the profile / Faculty & Staff trails. An ordinary (workspace) work
# keeps the plain structural trail. Leans on ApplicationController's #breadcrumbs
# / #breadcrumb / #add_breadcrumb_for and the controller's @work.
module WorkBreadcrumbs
  extend ActiveSupport::Concern

  private

    # Both branches share the single AtlasRb::Resource.find that yields the
    # ancestor chain.
    def work_breadcrumbs(id)
      result = AtlasRb::Resource.find(id)
      item = result.resource
      person = personal_root_owner(item)

      if person
        build_personal_work_breadcrumbs(item, result.klass, person)
      else
        Array(item.ancestor_chain).each { |node| add_breadcrumb_for(node['noid'], node['klass'], node['title']) }
        add_breadcrumb_for(item.id, result.klass, item.title)
      end
    end

    # The depositor's curated Person, but only when this work is homed in that
    # person's personal root (immediate structural parent == personal_root_id) —
    # i.e. a published/personal work, not a workspace deposit. nil otherwise, so
    # the caller falls back to the structural trail. A resolution failure also
    # degrades to nil (never break the show page over a breadcrumb).
    def personal_root_owner(item)
      nuid = @work['depositor'].presence
      return nil unless nuid

      person = AtlasRb::Person.resolve([nuid]).first
      return nil unless person && person['personal_root_id'].present?

      parent_noid = Array(item.ancestor_chain).last&.dig('noid')
      person if person['personal_root_id'] == parent_noid
    rescue Faraday::Error, JSON::ParserError
      nil
    end

    # NEU / … / <affiliated community> / <Person → /people/:noid> / <work>.
    def build_personal_work_breadcrumbs(item, klass, person)
      community_noid = Array(person['affiliated_community_ids']).first.presence
      if community_noid
        breadcrumbs(community_noid, match: :exact)
      else
        breadcrumb('People', people_path)
      end
      breadcrumb(person['display_name'], person_path(person['id']))
      add_breadcrumb_for(item.id, klass, item.title)
    rescue Faraday::Error, JSON::ParserError
      breadcrumb('People', people_path)
      add_breadcrumb_for(item.id, klass, item.title)
    end
end
