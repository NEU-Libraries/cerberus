# frozen_string_literal: true

class CollectionChangeSet < Valkyrie::ChangeSet
  property :title
  property :description
  validates :title, presence: true
end
