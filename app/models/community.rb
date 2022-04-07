# frozen_string_literal: true

class Community < Resource
  attribute :a_member_of, Valkyrie::Types::Set.of(Valkyrie::Types::ID).meta(ordered: true)
end
