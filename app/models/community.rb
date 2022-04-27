# frozen_string_literal: true

class Community < Resource
  include Modsable

  attribute :title, Valkyrie::Types::String
  attribute :description, Valkyrie::Types::String
  attribute :a_member_of, Valkyrie::Types::Set.of(Valkyrie::Types::ID).meta(ordered: true)
end
