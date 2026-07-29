# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativesHelper, type: :helper do
  def tier(gated:, permission:)
    AtlasRb::Mash.new(use: 'large_image', uri: 'https://g/x.jp2/full/pct:75/0/default.jpg',
                      gated: gated, permission: permission)
  end
  let(:blob) { AtlasRb::Mash.new(noid: 'b1') }
  let(:gated_blob) { AtlasRb::Mash.new(noid: 'b2', gated: true, permission: nil) }
  let(:future_embargo) { (Date.current + 30).to_s }
  let(:past_embargo) { (Date.current - 1).to_s }

  # effective_user is a helper_method registered by ImpersonationSession, which
  # ApplicationController includes but the bare test controller behind a
  # type: :helper spec does not — so it isn't on the double's class at all, and
  # verifying partial doubles rejects `allow(...).to receive(:effective_user)`.
  # Defining a real singleton method sidesteps that check.
  def stub_effective_user(user)
    helper.define_singleton_method(:effective_user) { user }
  end

  before do
    allow(helper).to receive(:current_ability).and_return(Ability.new(user))
    stub_effective_user(user)
  end

  describe '#derivative_readable?' do
    context 'as a guest' do
      let(:user) { nil }

      it 'allows an ungated blob (public by default)' do
        expect(helper.derivative_readable?(blob)).to be(true)
      end

      it 'denies a gated blob (permission withheld from guests)' do
        expect(helper.derivative_readable?(gated_blob)).to be(false)
      end

      it 'allows a public tier' do
        expect(helper.derivative_readable?(tier(gated: false, permission: ['public']))).to be(true)
      end

      it 'denies a gated tier (permission withheld from guests)' do
        expect(helper.derivative_readable?(tier(gated: true, permission: nil))).to be(false)
      end

      it 'denies an otherwise-public tier while an active embargo withholds it' do
        expect(helper.derivative_readable?(blob, embargo_date: future_embargo)).to be(false)
      end

      it 'allows an otherwise-public tier once the embargo has lapsed' do
        expect(helper.derivative_readable?(blob, embargo_date: past_embargo)).to be(true)
      end
    end

    context 'as a group member' do
      let(:user) { User.new(nuid: '000000004', groups: ['g:arch']) }

      it 'allows a tier gated to a group they belong to' do
        expect(helper.derivative_readable?(tier(gated: true, permission: ['g:arch']))).to be(true)
      end

      it 'denies a tier gated to a group they lack' do
        expect(helper.derivative_readable?(tier(gated: true, permission: ['g:other']))).to be(false)
      end

      it 'is still withheld by an active embargo (not staff/admin)' do
        expect(helper.derivative_readable?(tier(gated: true, permission: ['g:arch']), embargo_date: future_embargo))
          .to be(false)
      end
    end

    context 'as a staff (grouper) member' do
      let(:user) { User.new(nuid: '000000002', groups: [Permissions::STAFF_EDIT_GROUP]) }

      it 'bypasses an active embargo' do
        expect(helper.derivative_readable?(blob, embargo_date: future_embargo)).to be(true)
      end
    end

    context 'as an Admin' do
      let(:user) { User.new(nuid: '000000004', groups: [], role: 'admin') }

      it 'bypasses an active embargo' do
        expect(helper.derivative_readable?(blob, embargo_date: future_embargo)).to be(true)
      end
    end
  end

  describe '#downloadable_files' do
    let(:user) { nil }

    it 'keeps ungated blobs and public tiers, drops inaccessible gated assets' do
      public_tier = tier(gated: false, permission: ['public'])
      gated_tier = tier(gated: true, permission: nil)

      expect(helper.downloadable_files([blob, gated_blob, public_tier, gated_tier]))
        .to contain_exactly(blob, public_tier)
    end

    it 'drops every file while an active embargo withholds them all' do
      public_tier = tier(gated: false, permission: ['public'])

      expect(helper.downloadable_files([blob, public_tier], embargo_date: future_embargo)).to eq([])
    end
  end

  describe '#embargo_withholds?' do
    context 'as a guest' do
      let(:user) { nil }

      it 'is true under an active embargo' do
        expect(helper.embargo_withholds?(future_embargo)).to be(true)
      end

      it 'is false once the embargo has lapsed' do
        expect(helper.embargo_withholds?(past_embargo)).to be(false)
      end

      it 'is false with no embargo date' do
        expect(helper.embargo_withholds?(nil)).to be(false)
      end
    end

    context 'as staff or Admin' do
      let(:user) { nil } # placeholder for the top-level before; each example overrides effective_user directly

      it 'is false for a staff (grouper) member even under an active embargo' do
        stub_effective_user(User.new(nuid: '000000002', groups: [Permissions::STAFF_EDIT_GROUP]))
        expect(helper.embargo_withholds?(future_embargo)).to be(false)
      end

      it 'is false for an Admin even under an active embargo' do
        stub_effective_user(User.new(nuid: '000000004', groups: [], role: 'admin'))
        expect(helper.embargo_withholds?(future_embargo)).to be(false)
      end
    end
  end
end
