# frozen_string_literal: true

class CollectionChangeSet < Valkyrie::ChangeSet
  include MODSAssignment

  property :title, virtual: true
  property :description, virtual: true
  validates :title, presence: true
end
