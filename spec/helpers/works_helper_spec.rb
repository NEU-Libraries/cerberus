# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorksHelper do
  # Drives whether the deposit page's Advanced metadata disclosure starts open.
  describe '#advanced_metadata_present?' do
    it 'is false for the ordinary deposit — a filename title and nothing else' do
      expect(helper).not_to be_advanced_metadata_present({ subtitle: nil, part_name: '',
                                                           personal_creators: [], corporate_creators: [] })
    end

    it 'is true when the record carries a title part' do
      expect(helper).to be_advanced_metadata_present({ part_number: 'Episode 1' })
    end

    it 'is true when the record carries an editable creator' do
      expect(helper).to be_advanced_metadata_present({ personal_creators: [{ given: 'Jenny', family: 'Smith' }] })
    end

    it 'is true when the record carries a corporate creator' do
      expect(helper).to be_advanced_metadata_present({ corporate_creators: ['Northeastern University'] })
    end

    # load_advanced! always populates every key, but a caller holding a partial
    # hash must not blow up on a missing one.
    it 'tolerates an empty hash' do
      expect(helper).not_to be_advanced_metadata_present({})
    end
  end
end
