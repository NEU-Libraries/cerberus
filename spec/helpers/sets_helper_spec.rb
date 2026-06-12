# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SetsHelper do
  def chip(live, total)
    SetResolver::Chip.new(noid: 'abc1234', uuid: 'u-1', live: live, total: total)
  end

  describe '#set_inverted_chips' do
    it 'flags a chip with most of the collection set aside' do
      expect(helper.set_inverted_chips([chip(100, 1000)])).to contain_exactly(
        an_object_having_attributes(total: 1000)
      )
    end

    it 'ignores modest divergence' do
      expect(helper.set_inverted_chips([chip(600, 1000)])).to be_empty
    end

    it 'never nudges tiny collections, even fully inverted' do
      expect(helper.set_inverted_chips([chip(1, 4)])).to be_empty
    end

    it 'ignores undiverged chips' do
      expect(helper.set_inverted_chips([chip(50, 50)])).to be_empty
    end
  end

  describe '#set_picker_state' do
    let(:set) do
      { 'included_collections' => ['col1234'],
        'included_works'       => ['wrk1111'],
        'excluded_works'       => ['wrk2222'] }
    end

    it 'distinguishes included, aside, and addable per kind' do
      expect(helper.set_picker_state(set, 'collection', 'col1234')).to eq(:included)
      expect(helper.set_picker_state(set, 'collection', 'col9999')).to eq(:addable)
      expect(helper.set_picker_state(set, 'work', 'wrk1111')).to eq(:included)
      expect(helper.set_picker_state(set, 'work', 'wrk2222')).to eq(:aside)
      expect(helper.set_picker_state(set, 'work', 'wrk9999')).to eq(:addable)
    end
  end
end
