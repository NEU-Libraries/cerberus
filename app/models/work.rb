# frozen_string_literal: true

class Work < Resource
  attribute :title, Valkyrie::Types::String
  attribute :a_member_of, Valkyrie::Types::Set.of(Valkyrie::Types::ID).meta(ordered: true)
  attribute :thumbnail, Valkyrie::Types::ID
end
