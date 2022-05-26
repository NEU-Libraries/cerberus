# frozen_string_literal: true

class CollectionChangeSet < Valkyrie::ChangeSet
  property :title, virtual: true
  property :description, virtual: true
  validates :title, presence: true
end
