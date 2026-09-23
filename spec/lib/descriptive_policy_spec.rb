# frozen_string_literal: true

require 'rails_helper'

describe DescriptivePolicy do
  describe '.keywords_required?' do
    it 'requires a keyword on a Work' do
      expect(described_class.keywords_required?(AtlasRb::Work)).to be true
    end

    # The container forms carry no Keywords box, so requiring one would make a
    # title-only edit unsaveable.
    it 'requires none on a Collection or a Community' do
      expect(described_class.keywords_required?(AtlasRb::Collection)).to be false
      expect(described_class.keywords_required?(AtlasRb::Community)).to be false
    end

    it 'requires none on a type it has not been taught' do
      expect(described_class.keywords_required?(AtlasRb::Compilation)).to be false
    end
  end
end
