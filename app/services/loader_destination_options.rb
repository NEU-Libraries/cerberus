# frozen_string_literal: true

# The XML and multipage destination typeahead's `[{ value:, label: }]` rows.
class LoaderDestinationOptions < ApplicationService
  def initialize(documents:)
    @documents = Array(documents)
    super()
  end

  def call
    parents = StructuralParents.call(documents: @documents.select(&:featured?))
    @documents.map { |doc| { value: doc.to_param, label: label(doc, parents) } }
  end

  private

    # Every community's showcases share the genre titles, so a showcase names
    # its community or seven "Theses & Dissertations" rows look the same.
    def label(doc, parents)
      title = Array(doc['title_tsim']).first.presence || '(untitled)'
      community = parents[StructuralParents.parent_uuid(doc)]
      return title unless doc.featured? && community

      "#{title} · #{Array(community['title_tsim']).first}"
    end
end
