# frozen_string_literal: true

require 'rails_helper'
require 'cancan/matchers'

describe Ability do
  let(:user) { User.new(email: 'u@example.com', nuid: '000000002', groups: ['editors']) }
  subject(:ability) { described_class.new(user) }

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

    it 'ignores depositor matches on Communities and Collections' do
      doc = SolrDocument.new('internal_resource_tesim' => 'Collection',
                             'depositor_ssi'           => '000000002')
      expect(ability).not_to be_able_to(:tombstone, doc)
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
