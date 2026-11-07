# frozen_string_literal: true

# One page of a load report's ingest rows, and the pager for it. A multipage
# report pages by Work, so a Work's pages never split across a page break.
# See docs/ingest.md.
class LoadReportRows
  PER_PAGE = 50

  Page = Struct.new(:rows, :pager)

  # `relation` is the report's ingest rows, already in display order.
  def self.call(relation:, multipage:, page:)
    multipage ? by_work(relation, page) : by_row(relation, page)
  end

  def self.by_row(relation, page)
    pager = clamp(relation.page(page).per(PER_PAGE)) { |last| relation.page(last).per(PER_PAGE) }
    Page.new(pager.to_a, pager)
  end

  # Each page is a pack of whole Works, holding at most PER_PAGE rows unless one
  # Work alone is longer. The pager runs over the packs, one pack per page. A
  # structural-failure row has no item, so nil is a Work of its own and sorts
  # first, as the table does.
  def self.by_work(relation, page)
    sizes = relation.reorder(nil).group(:item_index).count
    packs = pack(sizes.keys.sort_by { |item| item.nil? ? -1 : item }, sizes)
    pager = clamp(Kaminari.paginate_array(packs).page(page).per(1)) do |last|
      Kaminari.paginate_array(packs).page(last).per(1)
    end
    Page.new(relation.where(item_index: pager.first || []).to_a, pager)
  end

  def self.pack(items, sizes)
    items.each_with_object([[]]) do |item, packs|
      packs << [] if packs.last.any? && packs.last.sum { |i| sizes[i] } + sizes[item] > PER_PAGE
      packs.last << item
    end.reject(&:empty?)
  end

  # A page past the end shows the last page, so a load that has rows never
  # renders its empty state.
  def self.clamp(pager)
    pager.out_of_range? && pager.total_pages.positive? ? yield(pager.total_pages) : pager
  end

  private_class_method :by_row, :by_work, :pack, :clamp
end
