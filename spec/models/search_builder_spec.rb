# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SearchBuilder do
  # SearchBuilder reads its scope for blacklight_config + current_user. A light
  # double is enough to exercise the gated-discovery processor in isolation.
  # Plain double, not instance_double: Devise's current_user is a dynamically
  # mixed-in helper, so verifying doubles can't see it as an instance method.
  let(:scope) do
    double('scope',
           blacklight_config: CatalogController.blacklight_config,
           current_user:      user)
  end
  subject(:builder) { described_class.new(scope) }

  # Run just the gated-discovery processor against a fresh params hash and
  # return the fq fragments it produced.
  def gated_fq
    params = {}
    builder.apply_gated_discovery(params)
    Array(params[:fq])
  end

  context 'when the user is an admin' do
    let(:user) { User.new(nuid: '000000004', name: 'User, Admin', role: 'admin') }

    it 'appends no read-access filter — admins discover every resource' do
      expect(gated_fq).to be_empty
    end
  end

  context 'when the user is a non-admin with groups' do
    let(:user) do
      User.new(nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
               groups: ['northeastern:drs:repository:staff'])
    end

    it 'gates discovery to public + the user\'s groups' do
      expect(gated_fq.size).to eq(1)
      expect(gated_fq.first).to include('read_access_group_ssim', 'public',
                                        'northeastern:drs:repository:staff')
    end
  end

  context 'when there is no authenticated user' do
    let(:user) { nil }

    it 'gates discovery to public only' do
      expect(gated_fq.first).to include('read_access_group_ssim', 'public')
      expect(gated_fq.first).not_to include('northeastern')
    end
  end

  # View-as: the scope exposes effective_user (the target) alongside the real
  # current_user (the admin). Gating must follow the target, or an admin in a
  # view-as session silently discovers everything.
  context 'when a view-as session exposes an effective_user' do
    let(:admin) { User.new(nuid: '000000004', name: 'User, Admin', role: 'admin') }
    let(:scope) do
      double('scope',
             blacklight_config: CatalogController.blacklight_config,
             current_user:      admin,
             effective_user:    target)
    end

    context 'and the target is a restricted non-admin' do
      let(:target) do
        User.new(nuid: '000000002', role: 'privileged',
                 groups: ['northeastern:drs:repository:staff'])
      end

      it 'gates as the target, not the admin (no short-circuit)' do
        expect(gated_fq.size).to eq(1)
        expect(gated_fq.first).to include('read_access_group_ssim', 'public',
                                          'northeastern:drs:repository:staff')
      end
    end

    context 'and the target is a public-only user' do
      let(:target) { User.new(nuid: '000000001', role: 'guest', groups: []) }

      it 'gates to public only despite the admin current_user' do
        expect(gated_fq.first).to include('read_access_group_ssim', 'public')
        expect(gated_fq.first).not_to include('northeastern')
      end
    end
  end
end
