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
      # Edit-equivalence grants read as well: anyone entitled to change an
      # object is entitled to look at it. Without this the read ACL alone
      # decides, and two ordinary states lock a person out of their own
      # material — a depositor who sets their collection Private with no group
      # rows, and a group granted Manage but not View. Both kept the Edit page
      # and got a 403 on the object itself. This can't widen disclosure: it only
      # admits people who could already alter the thing. Atlas says the same of
      # Sets ("edit implies read") and its read floor admits any authenticated
      # principal, so nothing here outruns what the backend will serve.
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

    # An ACL match OR ownership. Ownership has to count separately because it
    # isn't represented in the ACL: a personal root and everything beneath it
    # carries `edit: [repository:staff]` with the owner recorded only as
    # `depositor`, so a non-staff depositor would otherwise be locked out of
    # their own workspace. Mirrors Atlas's edit-equivalent grant — divergence
    # here means Cerberus hides an Edit link for a write Atlas would allow.
    # :restore is deliberately not one of these verbs; reversing a tombstone is
    # an operator action, not an owner one.
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

    # Not Work-scoped: a depositor owns their Collections too, and the whole
    # workspace subtree inherits their NUID (creators copy parent.permissions,
    # which carries depositor). A Collection they own is theirs to edit and,
    # once empty, to withdraw — Atlas refuses the tombstone while live children
    # remain, so emptiness needs no check here.
    def depositor?(doc, user)
      return false if user.nuid.blank?

      doc['depositor_ssi'].present? && doc['depositor_ssi'] == user.nuid
    end

    # A librarian who proxied a deposit retains tombstone rights on it — the
    # recorded proxy_uploader keeps authority, not just the on-behalf depositor.
    def proxy_uploader?(doc, user)
      return false unless doc['internal_resource_tesim'].to_s == 'Work'
      return false if user.nuid.blank?

      doc['proxy_uploader_ssi'].present? && doc['proxy_uploader_ssi'] == user.nuid
    end
end
