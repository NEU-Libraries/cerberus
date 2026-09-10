# frozen_string_literal: true

# CanCan rules over SolrDocument. See docs/identity.md.
class Ability
  include CanCan::Ability

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
      # Edit-equivalence has to grant read too. Without it a depositor who sets
      # their own collection Private with no group rows, and a group granted
      # Manage but not View, both keep the Edit page and get a 403 on the object.
      can :read, SolrDocument do |doc|
        public_document?(doc) || groups_can_read?(doc, user) || edit_equivalent?(doc, user)
      end
      can :edit, SolrDocument do |doc|
        edit_equivalent?(doc, user)
      end
      can :tombstone, SolrDocument do |doc|
        edit_equivalent?(doc, user) || proxy_uploader?(doc, user)
      end
    end

    # Ownership must be checked separately: a personal root carries
    # `edit: [repository:staff]` with the owner recorded only as `depositor`, so
    # an ACL-only test locks a non-staff depositor out of their own workspace.
    # Do not add :restore to these verbs — reversing a tombstone is an operator
    # action, not an owner one.
    def edit_equivalent?(doc, user)
      groups_can_edit?(doc, user) || depositor?(doc, user)
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

    # Deliberately not Work-scoped, and deliberately has no emptiness check:
    # Atlas refuses a tombstone while live children remain.
    def depositor?(doc, user)
      return false if user.nuid.blank?

      doc['depositor_ssi'].present? && doc['depositor_ssi'] == user.nuid
    end

    def proxy_uploader?(doc, user)
      return false unless doc['internal_resource_tesim'].to_s == 'Work'
      return false if user.nuid.blank?

      doc['proxy_uploader_ssi'].present? && doc['proxy_uploader_ssi'] == user.nuid
    end
end
