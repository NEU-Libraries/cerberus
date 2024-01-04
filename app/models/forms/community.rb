# frozen_string_literal: true

module Forms
  class Community < Reform::Form
    model :community
    property :title
    property :description
    validates :title, presence: true
  end
end
