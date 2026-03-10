# frozen_string_literal: true

module Blacklight
  module Gallery
    class DocumentTitleComponent < Blacklight::DocumentTitleComponent
      def initialize(title = nil, as: :h5, classes: 'index_title document-title-heading col gallery-title', **kwargs)
        super
      end
    end
  end
end
