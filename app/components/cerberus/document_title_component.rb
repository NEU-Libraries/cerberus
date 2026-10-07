# frozen_string_literal: true

module Cerberus
  # A result title that also carries the thumbnail's type pill as text.
  #
  # The pill sits inside the thumbnail link, which Blacklight marks aria-hidden
  # so screen readers do not hear every result's link twice. That hides the
  # pill too, so its text goes into the heading instead, visually hidden. Only
  # a linked title is a result row; a single-document page has no pill.
  class DocumentTitleComponent < Blacklight::DocumentTitleComponent
    def before_render
      super
      return unless @link_to_document

      with_after_title do
        tag.span(", #{helpers.pill_label(presenter.document)}", class: 'visually-hidden')
      end
    end
  end
end
