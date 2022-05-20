# frozen_string_literal: true

class CommunityChangeSet < Valkyrie::ChangeSet
  property :title
  property :description
  validates :title, presence: true
end
