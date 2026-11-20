# frozen_string_literal: true

# Materializes the container-level rollup by deriving DOWN the structural-home
# tree (§8): for each Community/Collection, sum the leaf ImpressionDailyCount
# over its descendant noid set. Re-parenting just changes which leaves resolve
# next run — there are no historical rows to rewrite (v1's move/delete tax is
# gone). Re-derives a trailing window each run, one container per short
# transaction, so no transaction stays open across the Solr lookups. Scheduled
# daily, off-peak.
class RollupContainerImpressionsJob < ApplicationJob
  queue_as :background

  WINDOW = 90.days

  def perform(window: WINDOW)
    window_start = window.ago.to_date
    seen = []

    each_container do |noid, uuid|
      replace(noid, container_totals(noid, uuid, window_start), window_start)
      seen << noid
    end

    # A container gone from Solr is never visited, so its rows go here.
    ImpressionContainerDailyCount.where(day: window_start..).where.not(noid: seen).delete_all
  end

  private

    # Deletes even when rows is empty: a container whose traffic has aged out
    # of the leaf counts must lose its old totals too.
    def replace(noid, rows, window_start)
      ImpressionContainerDailyCount.transaction do
        ImpressionContainerDailyCount.where(noid:, day: window_start..).delete_all
        ImpressionContainerDailyCount.insert_all(rows) if rows.any?
      end
    end

    # Sum leaf human counts over the container's descendant noid set, grouped by
    # (action, day), as insert rows keyed by the container's noid.
    def container_totals(noid, uuid, window_start)
      descendant_noids = ContainerDescendantsQuery.new(noid:, uuid:).noids
      return [] if descendant_noids.empty?

      ImpressionDailyCount.in_range(window_start..)
                          .where(noid: descendant_noids)
                          .group(:action, :day).sum(:count)
                          .map { |(action, day), total| { noid:, action:, day:, count: total } }
    end

    # Yield [noid, uuid] for every Community/Collection in Solr (system-wide; no
    # gated discovery — analytics counts every container).
    def each_container
      Blacklight.default_index.search(
        q: '*:*', fq: ['internal_resource_tesim:(Collection OR Community)'],
        rows: 100_000, fl: 'id,alternate_ids_ssim'
      ).documents.each do |doc|
        noid = Array(doc['alternate_ids_ssim']).first&.delete_prefix('id-')
        yield(noid, doc.id) if noid.present?
      end
    end
end
