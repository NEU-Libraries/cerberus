# frozen_string_literal: true

require 'rails_helper'
require 'cancan/matchers'

describe Ability do
  let(:user) { User.new(email: 'u@example.com', nuid: '000000002', groups: ['editors']) }
  subject(:ability) { described_class.new(user) }

  describe ':edit' do
    it 'allows users with edit-group access' do
      doc = SolrDocument.new('edit_access_group_ssim' => ['editors'])
      expect(ability).to be_able_to(:edit, doc)
    end

    # The workspace case: a personal root and everything under it carries
    # `edit: [repository:staff]` with the owner recorded only as depositor, so
    # a non-staff depositor has no ACL match on their own material. Atlas grants
    # this; if Cerberus didn't, it would hide an Edit link for a write Atlas
    # would allow.
    it 'allows the depositor even with no edit-group match' do
      doc = SolrDocument.new('internal_resource_tesim' => 'Work',
                             'edit_access_group_ssim'  => ['northeastern:drs:repository:staff'],
                             'depositor_ssi'           => '000000002')
      expect(ability).to be_able_to(:edit, doc)
    end

    it 'allows the depositor of a Collection' do
      doc = SolrDocument.new('internal_resource_tesim' => 'Collection',
                             'depositor_ssi'           => '000000002')
      expect(ability).to be_able_to(:edit, doc)
    end

    it 'denies a stranger with neither an ACL match nor ownership' do
      doc = SolrDocument.new('internal_resource_tesim' => 'Work',
                             'edit_access_group_ssim'  => ['others'],
                             'depositor_ssi'           => '999999999')
      expect(ability).not_to be_able_to(:edit, doc)
    end

    # Proxy uploading carries tombstone rights, not edit rights.
    it 'denies a proxy_uploader who is not the depositor' do
      doc = SolrDocument.new('internal_resource_tesim' => 'Work',
                             'proxy_uploader_ssi'      => '000000002',
                             'depositor_ssi'           => '999999999')
      expect(ability).not_to be_able_to(:edit, doc)
    end
  end

  describe ':tombstone' do
    it 'allows users with edit-group access' do
      doc = SolrDocument.new('edit_access_group_ssim' => ['editors'])
      expect(ability).to be_able_to(:tombstone, doc)
    end

    it 'allows the depositor of a Work' do
      doc = SolrDocument.new('internal_resource_tesim' => 'Work',
                             'depositor_ssi'           => '000000002')
      expect(ability).to be_able_to(:tombstone, doc)
    end

    it 'denies a non-depositor on a Work' do
      doc = SolrDocument.new('internal_resource_tesim' => 'Work',
                             'depositor_ssi'           => '999999999')
      expect(ability).not_to be_able_to(:tombstone, doc)
    end

    it 'allows the proxy_uploader of a Work' do
      doc = SolrDocument.new('internal_resource_tesim' => 'Work',
                             'proxy_uploader_ssi'      => '000000002')
      expect(ability).to be_able_to(:tombstone, doc)
    end

    it 'denies a stranger when proxy_uploader_ssi belongs to someone else' do
      doc = SolrDocument.new('internal_resource_tesim' => 'Work',
                             'proxy_uploader_ssi'      => '999999999')
      expect(ability).not_to be_able_to(:tombstone, doc)
    end

    it 'ignores proxy_uploader matches on Communities and Collections' do
      doc = SolrDocument.new('internal_resource_tesim' => 'Collection',
                             'proxy_uploader_ssi'      => '000000002')
      expect(ability).not_to be_able_to(:tombstone, doc)
    end

    # Depositor ownership is not Work-scoped: the whole workspace subtree
    # inherits the owner's NUID, so a Collection they deposited is theirs to
    # withdraw. Atlas refuses the tombstone while live children remain, which
    # is where "only if empty" is enforced.
    it 'honours depositor matches on Collections' do
      doc = SolrDocument.new('internal_resource_tesim' => 'Collection',
                             'depositor_ssi'           => '000000002')
      expect(ability).to be_able_to(:tombstone, doc)
    end

    it 'denies anonymous users' do
      anon_ability = described_class.new(nil)
      doc = SolrDocument.new('edit_access_group_ssim' => ['editors'])
      expect(anon_ability).not_to be_able_to(:tombstone, doc)
    end
  end

  describe ':read' do
    it 'allows public documents (signed-in user)' do
      doc = SolrDocument.new('read_access_group_ssim' => ['public'])
      expect(ability).to be_able_to(:read, doc)
    end

    it 'allows non-public documents when the user shares a read group' do
      doc = SolrDocument.new('read_access_group_ssim' => ['editors'])
      expect(ability).to be_able_to(:read, doc)
    end

    it 'denies non-public documents when no read group overlaps' do
      doc = SolrDocument.new('read_access_group_ssim' => ['curators'])
      expect(ability).not_to be_able_to(:read, doc)
    end

    # Edit-equivalence grants read. Both cases below are reachable from the
    # permissions form in one save, and both used to leave the person holding
    # the Edit page while the object itself returned 403.
    it 'allows the depositor of a private document with no group rows at all' do
      doc = SolrDocument.new('depositor_ssi' => '000000002')
      expect(ability).to be_able_to(:read, doc)
    end

    it 'allows a group granted edit but not read' do
      doc = SolrDocument.new('read_access_group_ssim' => ['curators'],
                             'edit_access_group_ssim' => ['editors'])
      expect(ability).to be_able_to(:read, doc)
    end

    it 'still denies a stranger with neither ownership nor any group match' do
      doc = SolrDocument.new('read_access_group_ssim' => ['curators'],
                             'edit_access_group_ssim' => ['curators'],
                             'depositor_ssi'          => '000000099')
      expect(ability).not_to be_able_to(:read, doc)
    end

    it 'still denies anonymous users a private document' do
      anon = described_class.new(nil)
      expect(anon).not_to be_able_to(:read, SolrDocument.new('depositor_ssi' => '000000002'))
    end
  end

  # Admin wildcard short-circuit — mirrors Atlas's `can :manage, :all` for
  # `:admin`. Honouring the role here means Atlas admins don't need every
  # grouper group stuffed onto their record to drive admin-only UI.
  context 'when the user is an Atlas :admin' do
    let(:admin) { User.new(nuid: '000000004', groups: [], role: 'admin') }
    subject(:admin_ability) { described_class.new(admin) }

    it 'grants :manage, :all (the wildcard)' do
      expect(admin_ability.can?(:manage, :all)).to be true
    end

    it 'can :read :audit_event without any group membership' do
      expect(admin_ability).to be_able_to(:read, :audit_event)
    end

    it 'can :read a private document the admin shares no read-group with' do
      doc = SolrDocument.new('read_access_group_ssim' => ['curators'])
      expect(admin_ability).to be_able_to(:read, doc)
    end

    it 'can :edit and :tombstone regardless of edit_access groups' do
      doc = SolrDocument.new('edit_access_group_ssim'  => ['curators'],
                             'internal_resource_tesim' => 'Work')
      expect(admin_ability).to be_able_to(:edit, doc)
      expect(admin_ability).to be_able_to(:tombstone, doc)
    end
  end

  context 'when the user is not an Atlas :admin' do
    it 'cannot :read :audit_event regardless of group memberships' do
      non_admin = User.new(nuid:   '000000002',
                           groups: ['editors', Permissions::STAFF_EDIT_GROUP],
                           role:   'privileged')
      expect(described_class.new(non_admin)).not_to be_able_to(:read, :audit_event)
    end
  end
end
