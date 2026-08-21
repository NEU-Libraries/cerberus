# frozen_string_literal: true

# The result-row presenter for every index view (list and gallery alike).
class EnhancedIndexPresenter < Blacklight::IndexPresenter
  include EnhancedHeading
end
