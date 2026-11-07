# frozen_string_literal: true

# Whether a results page offers "Add page to set", and which Works it would add.
# Search, collection, community and genre pages all inherit it from
# CatalogController. See docs/sets.md ("Adding a page of results").
module PageSetAddable
  extend ActiveSupport::Concern

  included do
    helper_method :add_page_to_set?, :page_work_noids, :page_collection_count
  end

  private

    # Never on a Set's own page: its Works are already in a set, and offering
    # them to a set from there invites a set fed into itself.
    def add_page_to_set?
      effective_user&.curates_sets? && controller_name != 'sets' && page_work_noids.any?
    end

    def page_work_noids
      @page_work_noids ||= page_documents.select { |doc| doc.klass_type == 'Work' }.map(&:to_param)
    end

    def page_collection_count
      page_documents.count { |doc| doc.klass_type == 'Collection' }
    end

    def page_documents
      Array(@response&.documents)
    end
end
