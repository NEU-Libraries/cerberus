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

    # Edit implies read at the tier gate. See docs/downloads.md.
    context 'as the depositor of a private Work, outside every group' do
      let(:user) { User.new(nuid: '000000123', groups: []) }
      let(:private_file) { tier(gated: true, permission: []) }
      let(:editors) { { 'depositor_ssi' => '000000123' } }

      it 'allows the file through the edit grant' do
        expect(helper.derivative_readable?(private_file, editors: editors)).to be(true)
      end

      it 'allows a tier reserved to a group they lack' do
        expect(helper.derivative_readable?(tier(gated: true, permission: ['g:arch']), editors: editors)).to be(true)
      end

      it 'denies the file when the caller passes no edit fields' do
        expect(helper.derivative_readable?(private_file)).to be(false)
      end

      it 'is still withheld by an active embargo' do
        expect(helper.derivative_readable?(private_file, embargo_date: future_embargo, editors: editors)).to be(false)
      end
    end

    context 'as staff, through the staff edit group' do
      let(:user) { User.new(nuid: '000000002', groups: [Permissions::STAFF_EDIT_GROUP]) }
      let(:editors) { { 'edit_access_group_ssim' => [Permissions::STAFF_EDIT_GROUP] } }

      it 'allows a tier reserved to a group they lack' do
        expect(helper.derivative_readable?(tier(gated: true, permission: ['g:arch']), editors: editors)).to be(true)
      end
    end

    context 'as a reader outside the reserved group' do
      let(:user) { User.new(nuid: '000000123', groups: ['g:other']) }
      let(:editors) { { 'edit_access_group_ssim' => [Permissions::STAFF_EDIT_GROUP], 'depositor_ssi' => '000000999' } }

      it 'is still refused' do
        expect(helper.derivative_readable?(tier(gated: true, permission: ['g:arch']), editors: editors)).to be(false)
      end
    end
  end

  describe '#work_editors' do
    let(:user) { nil }

    it 'maps the Work permissions onto the fields Ability reads' do
      permissions = AtlasRb::Mash.new(edit: ['g:ed'], edit_users: ['000000123'], depositor: '000000456')

      expect(helper.work_editors(permissions)).to eq('edit_access_group_ssim'  => ['g:ed'],
                                                     'edit_access_person_ssim' => ['000000123'],
                                                     'depositor_ssi'           => '000000456')
    end

    it 'is empty without permissions' do
      expect(helper.work_editors(nil)).to eq({})
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

  # The results row's Downloads button, decided from the row's Solr doc alone.
  # See docs/downloads.md.
  describe '#offer_downloads?' do
    def work_doc(**fields)
      SolrDocument.new({ 'id' => 'w1', 'internal_resource_tesim' => ['Work'] }.merge(fields.transform_keys(&:to_s)))
    end

    let(:user) { nil }
    let(:staff) { User.new(nuid: '000000006', groups: [Permissions::STAFF_EDIT_GROUP]) }
    let(:admin) { User.new(nuid: '000000004', groups: [], role: 'admin') }

    def as(user)
      allow(helper).to receive(:current_ability).and_return(Ability.new(user))
      stub_effective_user(user)
    end

    context 'as a guest' do
      it 'offers a Work with a public file' do
        expect(helper.offer_downloads?(work_doc(has_downloads_bsi:         true,
                                                download_read_groups_ssim: %w[public]))).to be(true)
      end

      it 'does not offer a Work with no downloadable file' do
        expect(helper.offer_downloads?(work_doc(has_downloads_bsi: false))).to be(false)
      end

      it 'does not offer a Work whose files are all gated to groups the guest is not in' do
        expect(helper.offer_downloads?(work_doc(has_downloads_bsi:         true,
                                                download_read_groups_ssim: %w[northeastern:drs:staff]))).to be(false)
      end

      it 'does not offer a Work whose files resolve to no audience at all' do
        expect(helper.offer_downloads?(work_doc(has_downloads_bsi: true, download_read_groups_ssim: []))).to be(false)
      end

      it 'does not offer an embargoed Work, whatever its files' do
        doc = work_doc(has_downloads_bsi: true, download_read_groups_ssim: %w[public],
                       embargo_release_date_dtsi: future_embargo)
        expect(helper.offer_downloads?(doc)).to be(false)
      end

      it 'keeps the button on a doc indexed before Atlas rolled the fields up' do
        expect(helper.offer_downloads?(work_doc)).to be(true)
      end

      it 'never offers anything but a Work' do
        doc = SolrDocument.new('id' => 'c1', 'internal_resource_tesim' => ['Collection'], 'has_downloads_bsi' => true,
                               'download_read_groups_ssim' => %w[public])
        expect(helper.offer_downloads?(doc)).to be(false)
      end
    end

    context 'as a member of a gate group' do
      it 'offers a Work whose only file is gated to that group' do
        as(staff)
        expect(helper.offer_downloads?(work_doc(has_downloads_bsi:         true,
                                                download_read_groups_ssim: [Permissions::STAFF_EDIT_GROUP]))).to be(true)
      end
    end

    context 'as an editor of a private Work' do
      it 'offers it to the depositor, from the row alone' do
        as(User.new(nuid: '000000123', groups: []))
        expect(helper.offer_downloads?(work_doc(has_downloads_bsi: true, download_read_groups_ssim: [],
                                                depositor_ssi: '000000123'))).to be(true)
      end

      it 'offers it to staff, through the staff edit group' do
        as(staff)
        expect(helper.offer_downloads?(work_doc(has_downloads_bsi: true, download_read_groups_ssim: [],
                                                edit_access_group_ssim: [Permissions::STAFF_EDIT_GROUP]))).to be(true)
      end

      it 'does not offer it to the depositor while it is embargoed' do
        as(User.new(nuid: '000000123', groups: []))
        expect(helper.offer_downloads?(work_doc(has_downloads_bsi: true, download_read_groups_ssim: [],
                                                depositor_ssi: '000000123',
                                                embargo_release_date_dtsi: future_embargo))).to be(false)
      end
    end

    context 'as an admin' do
      before { as(admin) }

      it 'offers a Work whose files are gated to any group' do
        expect(helper.offer_downloads?(work_doc(has_downloads_bsi:         true,
                                                download_read_groups_ssim: %w[some:other:group]))).to be(true)
      end

      it 'offers an embargoed Work, since an admin bypasses the embargo' do
        doc = work_doc(has_downloads_bsi: true, download_read_groups_ssim: %w[public],
                       embargo_release_date_dtsi: future_embargo)
        expect(helper.offer_downloads?(doc)).to be(true)
      end

      it 'does not offer a Work with no downloadable file, whose modal would be empty for an admin too' do
        expect(helper.offer_downloads?(work_doc(has_downloads_bsi: false))).to be(false)
      end
    end

    it 'reads nothing from Atlas' do
      allow(AtlasRb::Work).to receive(:assets)
      allow(AtlasRb::Resource).to receive(:permissions)

      helper.offer_downloads?(work_doc(has_downloads_bsi: true, download_read_groups_ssim: %w[public]))

      expect(AtlasRb::Work).not_to have_received(:assets)
      expect(AtlasRb::Resource).not_to have_received(:permissions)
    end
  end
end
