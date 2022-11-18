# frozen_string_literal: true

class CommunityChangeSet < Valkyrie::ChangeSet
  property :title, virtual: true
  property :description, virtual: true
  validates :title, presence: true

  def title
    model.plain_title
  end

  def description
    model.plain_description
  end
end
