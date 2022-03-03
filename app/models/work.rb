# frozen_string_literal: true

class Work < Resource
  attribute :a_member_of, Valkyrie::Types::Set.of(Valkyrie::Types::ID).meta(ordered: true)
  attribute :mods_id, Valkyrie::Types::Integer
end
