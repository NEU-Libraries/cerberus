# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MembershipQuery do
  describe '.descendants_fq' do
    it 'builds a {!terms} reverse-ancestry fq on ancestor_ids_ssim (bare noids)' do
      expect(described_class.descendants_fq('66t1gnk'))
        .to eq('{!terms f=ancestor_ids_ssim}66t1gnk')
    end

    it 'tolerates and strips a leading id- prefix on the noid' do
      expect(described_class.descendants_fq('id-66t1gnk'))
        .to eq('{!terms f=ancestor_ids_ssim}66t1gnk')
    end
  end

  describe '.members_fq' do
    let(:uuids) { %w[aaaa bbbb] }

    it 'builds a structural {!terms} fq on the untokenized a_member_of_ssi field' do
      expect(described_class.members_fq(uuids))
        .to eq('{!terms f=a_member_of_ssi}id-aaaa,id-bbbb')
    end

    it 'ORs the linked overlay via a {!bool} of two {!terms} when include_linked' do
      expect(described_class.members_fq(uuids, include_linked: true)).to eq(
        '{!bool should="{!terms f=a_member_of_ssi}id-aaaa,id-bbbb" ' \
        'should="{!terms f=a_linked_member_of_ssim}id-aaaa,id-bbbb"}'
      )
    end

    it 'yields a no-match fq for an empty container set' do
      expect(described_class.members_fq([])).to eq('{!terms f=a_member_of_ssi}')
    end
  end

  # Guard for the edismax mm trap documented at the top of MembershipQuery: every
  # fragment must target the untokenized string fields, never the tokenized _tesim,
  # and must be intended for :fq (where the lucene parser, not edismax, runs them).
  describe 'trap invariants' do
    it 'never targets a tokenized _tesim field' do
      fragments = [
        described_class.descendants_fq('x'),
        described_class.members_fq(%w[a b]),
        described_class.members_fq(%w[a b], include_linked: true)
      ]
      fragments.each { |fq| expect(fq).not_to include('_tesim') }
    end
  end
end
