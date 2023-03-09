# frozen_string_literal: true

class FileSet < Resource
  attribute :type, Valkyrie::Types::String
  attribute :member_ids, Valkyrie::Types::Set.of(Valkyrie::Types::ID)
  attribute :a_member_of, Valkyrie::Types::ID

  # idempotency
  attribute :derivative_for, Valkyrie::Types::ID.optional

  def files
    @files ||= member_ids.map { |id| Blob.find(id) }
  end

  def original_file?
    files.each do |f|
      return true if f.use&.include? Valkyrie::Vocab::PCDMUse.OriginalFile
    end
    false
  end
end
