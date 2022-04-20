# frozen_string_literal: true

class Blob < Resource
  attribute :mime_type, Valkyrie::Types::Set
  attribute :original_filename, Valkyrie::Types::Set
  attribute :file_identifier, Valkyrie::Types::ID
  attribute :use, Valkyrie::Types::Set
  attribute :label, Valkyrie::Types::String # Classification Enumeration

  # fast lookup for MODS
  attribute :descriptive_metadata_for, Valkyrie::Types::ID.optional

  def file_path
    file_identifier.id.split('disk://')[1]
  end

  def extension
    original_filename[0].split('.').last
  end
end
