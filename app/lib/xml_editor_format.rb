# frozen_string_literal: true

# One metadata format as the raw-XML editor opens it: MODS, which every
# resource holds, or an additional record a Work holds. Each format brings its
# own check, read and write; Atlas renders every format's preview. See
# docs/metadata-records.md.
class XmlEditorFormat
  MODS = 'mods'

  # The additional formats this editor can check and write, by Atlas's token.
  # Atlas may list a format here before Cerberus has a validator for it, so the
  # editor offers only the intersection.
  ADDITIONAL = [DarwinCoreRecord::FORMAT].freeze

  ORIGIN = 'xml_editor'

  attr_reader :token

  # The tokens a resource offers, MODS first. Atlas lists a Work's additional
  # records in its metadata_formats, so asking costs no read.
  def self.offered(resource)
    [MODS] + (Array(resource&.[]('metadata_formats')) & ADDITIONAL)
  end

  # A token the resource does not offer opens MODS, so a hand-edited query
  # string cannot create a record the edit page never showed.
  def self.for(resource, token)
    new(offered(resource).include?(token.to_s) ? token.to_s : MODS)
  end

  def initialize(token)
    @token = token
  end

  def mods? = token == MODS

  def errors(xml, resource_class)
    if mods?
      MODSRecordValidator.call(xml:, keywords: DescriptivePolicy.keywords_required?(resource_class))
    else
      DarwinCoreRecordValidator.call(xml:)
    end
  end

  # kind is 'xml' for the stored document, 'html' for Atlas's display block.
  def read(id, kind)
    mods? ? AtlasRb::Resource.mods(id, kind) : AtlasRb::Work.dwc(id, kind)
  end

  def write(id, path)
    if mods?
      AtlasRb::Resource.put_mods(id, path, origin: ORIGIN)
    else
      AtlasRb::Resource.put_dwc(id, path, origin: ORIGIN)
    end
  end

  def preview(path)
    AtlasRb::Resource.preview(path, metadata_format: token)
  end
end
