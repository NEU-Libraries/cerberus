# frozen_string_literal: true

require 'rails_helper'

# The label table's job is to survive Atlas getting ahead of it. Atlas owns the
# predicate vocabulary and can ship a sixth in a release Cerberus has not caught
# up with, so every lookup here has a fallback, and the fallbacks are the part
# worth testing.
RSpec.describe WorkAssociationsHelper do
  describe '#association_label' do
    it 'reads one stored edge two ways' do
      expect(helper.association_label('is_codebook_for', :outbound)).to eq('Is codebook for')
      expect(helper.association_label('is_codebook_for', :inbound)).to eq('Codebooks')
    end

    it 'humanizes a predicate it has no phrase for, rather than raising' do
      expect(helper.association_label('is_appendix_to', :outbound)).to eq('Is appendix to')
      expect(helper.association_label('is_appendix_to', :inbound)).to eq('Is appendix to')
    end
  end

  describe '#association_icon' do
    it 'gives each known predicate its own icon' do
      expect(helper.association_icon('is_transcription_of')).to eq('fa-file-lines')
    end

    it 'falls back to a generic link icon' do
      expect(helper.association_icon('is_appendix_to')).to eq('fa-link')
    end
  end

  describe '#association_type_options' do
    # Built from Atlas's vocabulary, not from the label table, so the select can
    # only ever offer a predicate the server accepts.
    it 'offers exactly the predicates Atlas accepts' do
      expect(helper.association_type_options.map(&:last)).to eq(AtlasRb::Work::ASSOCIATION_TYPES)
    end

    it 'phrases each one as the tail of “This work is the …”' do
      expect(helper.association_type_options).to include(['codebook for', 'is_codebook_for'],
                                                         ['transcription of', 'is_transcription_of'])
    end

    it 'still offers a predicate the label table has no phrase for' do
      stub_const('AtlasRb::Work::ASSOCIATION_TYPES', %w[is_appendix_to])
      expect(helper.association_type_options).to eq([['is appendix to', 'is_appendix_to']])
    end
  end

  describe '#association_direction_caption' do
    it 'names which end the reader is looking at' do
      expect(helper.association_direction_caption(:outbound)).to eq('What this work says about others')
      expect(helper.association_direction_caption(:inbound)).to eq('What other works say about this one')
    end
  end
end
