# frozen_string_literal: true

module Blacklight
  module Gallery
    class DocumentTitleComponent < Blacklight::DocumentTitleComponent
      # `h5` sizes the heading. Blacklight carries it in the default class
      # list rather than in a stylesheet rule, so a replacement list has to
      # name it too or the title drops to body weight and leading.
      def initialize(title = nil, as: :h5, classes: 'index_title document-title-heading col gallery-title h5', **kwargs)
        super
      end
    end
  end
end
