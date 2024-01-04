class CommunityForm < Reform::Form
  property :title
  property :description
  validates :title, presence: true
end
