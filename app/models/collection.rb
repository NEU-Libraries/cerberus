# frozen_string_literal: true

class Collection < Resource
  attribute :a_member_of, Valkyrie::Types::Set.of(Valkyrie::Types::ID).meta(ordered: true)
end
