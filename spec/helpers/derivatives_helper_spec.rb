# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativesHelper, type: :helper do
  def tier(gated:, permission:)
    AtlasRb::Mash.new(use: 'large_image', uri: 'https://g/x.jp2/full/pct:75/0/default.jpg',
                      gated: gated, permission: permission)
  end
  let(:blob) { AtlasRb::Mash.new(noid: 'b1') }
  let(:gated_blob) { AtlasRb::Mash.new(noid: 'b2', gated: true, permission: nil) }

  before { allow(helper).to receive(:current_ability).and_return(Ability.new(user)) }

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
    end

    context 'as a group member' do
      let(:user) { User.new(nuid: '000000004', groups: ['g:arch']) }

      it 'allows a tier gated to a group they belong to' do
        expect(helper.derivative_readable?(tier(gated: true, permission: ['g:arch']))).to be(true)
      end

      it 'denies a tier gated to a group they lack' do
        expect(helper.derivative_readable?(tier(gated: true, permission: ['g:other']))).to be(false)
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
  end
end
