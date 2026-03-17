# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    if user.present?
      can :read, SolrDocument do |doc|
        public_document?(doc) || groups_can_read?(doc, user)
      end
      can :edit, SolrDocument do |doc|
        groups_can_edit?(doc, user)
      end
    else
      can :read, SolrDocument, &method(:public_document?)
    end
  end

  private

    def public_document?(doc)
      Array(doc['read_access_group_ssim']).include?('public')
    end

    def groups_can_read?(doc, user)
      (Array(doc['read_access_group_ssim']) & Array(user.groups)).any?
    end

    def groups_can_edit?(doc, user)
      (Array(doc['edit_access_group_ssim']) & Array(user.groups)).any?
    end
end
