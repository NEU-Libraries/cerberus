# frozen_string_literal: true

class Blob < Resource
  attribute :mime_type, Valkyrie::Types::String
  attribute :original_filename, Valkyrie::Types::String
  attribute :file_identifiers, Valkyrie::Types::Set.of(Valkyrie::Types::ID).meta(ordered: true)
  attribute :use, Valkyrie::Types::String
  attribute :label, Valkyrie::Types::String # Classification Enumeration

  # fast lookup for MODS
  attribute :descriptive_metadata_for, Valkyrie::Types::ID.optional

  def latest_revision
    return nil if file_identifiers.blank?
    file_identifiers.last.id
  end

  def file
    return nil if latest_revision.blank?
    Valkyrie.config.storage_adapter.find_by(id: latest_revision)
  end

  def extension
    original_filename.split('.').last
  end
end
