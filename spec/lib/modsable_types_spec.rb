# frozen_string_literal: true

require 'rails_helper'

describe ModsableTypes do
  describe '.include?' do
    it 'accepts the three types that carry an editable MODS document' do
      expect(described_class).to include('Work')
      expect(described_class).to include('Collection')
      expect(described_class).to include('Community')
    end

    # atlas_rb defines Resource.mods on the base class, so a FileSet answers a
    # MODS read. Answering one is not the same as having one to edit.
    it 'refuses a type that answers a MODS read but cannot take a MODS write' do
      expect(described_class).not_to include('FileSet')
      expect(described_class).not_to include('Blob')
      expect(described_class).not_to include('Delegate')
      expect(described_class).not_to include('Person')
    end

    it 'accepts every spelling atlas_rb maps, so a caller need not know which it holds' do
      expect(described_class).to include('work')
      expect(described_class).to include(:Work)
    end

    # class_for raises on an unmapped type. A gate cannot act on an exception,
    # and a type the gem does not model is not Modsable either.
    it 'answers false for a type atlas_rb does not map, rather than raising' do
      expect { described_class.include?('Sprocket') }.not_to raise_error
      expect(described_class).not_to include('Sprocket')
    end
  end
end
