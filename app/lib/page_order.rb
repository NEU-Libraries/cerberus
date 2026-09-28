# frozen_string_literal: true

# Orders a Work's downloadable files by the page they belong to. The assets
# listing comes back in creation order, so a multipage Work's page files could
# list page 2 above page 1. The file_sets listing is in page order and names
# each page's assets by the same noid, which is what this matches on.
module PageOrder
  # Files outside any page (a Work-level asset) follow the paged ones in their
  # original order; the sort is stable, so files on one page keep theirs too.
  def self.sort(files, pages)
    rank = ranks(pages)
    return files if files.nil? || rank.empty?

    files.each_with_index.sort_by { |file, index| [rank.fetch(file['noid'], rank.size), index] }.map(&:first)
  end

  # { asset noid => index of the page holding it }.
  def self.ranks(pages)
    Array(pages).each_with_index.with_object({}) do |(page, index), rank|
      Array(page['assets']).each { |asset| rank[asset['noid']] ||= index }
    end
  end
  private_class_method :ranks
end
