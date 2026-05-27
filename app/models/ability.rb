# frozen_string_literal: true

class Ability
  include CanCan::Ability

  # Admin wildcard short-circuit mirrors Atlas's `can :manage, :all` for
  # `:admin`. Honouring the role here means Atlas admins don't need every
  # grouper group stuffed onto their record to drive admin-only UI — the
  # role itself is the grant. See plan_atlas_ability_layer.md ("admin
  # wildcard | Both — Atlas has `can :manage, :all`; Cerberus's Ability
  # has the matching short-circuit").
  def initialize(user)
    if user.blank?
      can :read, SolrDocument, &method(:public_document?)
    elsif user.admin?
      can :manage, :all
    else
      apply_group_abilities(user)
    end
  end

  private

    def apply_group_abilities(user)
      can :read, SolrDocument do |doc|
        public_document?(doc) || groups_can_read?(doc, user)
      end
      can :edit, SolrDocument do |doc|
        groups_can_edit?(doc, user)
      end
      can :tombstone, SolrDocument do |doc|
        groups_can_edit?(doc, user) ||
          depositor_for_work?(doc, user) ||
          proxy_uploader_for_work?(doc, user)
      end
    end

    def public_document?(doc)
      Array(doc['read_access_group_ssim']).include?('public')
    end

    def groups_can_read?(doc, user)
      Array(doc['read_access_group_ssim']).intersect?(Array(user.groups))
    end

    def groups_can_edit?(doc, user)
      Array(doc['edit_access_group_ssim']).intersect?(Array(user.groups))
    end

    def depositor_for_work?(doc, user)
      return false unless doc['internal_resource_tesim'].to_s == 'Work'
      return false if user.nuid.blank?

      doc['depositor_ssi'].present? && doc['depositor_ssi'] == user.nuid
    end

    # Q6 lean: the librarian who proxied the deposit retains tombstone
    # rights, matching v1's `true_depositor` semantics.
    def proxy_uploader_for_work?(doc, user)
      return false unless doc['internal_resource_tesim'].to_s == 'Work'
      return false if user.nuid.blank?

      doc['proxy_uploader_ssi'].present? && doc['proxy_uploader_ssi'] == user.nuid
    end
end
