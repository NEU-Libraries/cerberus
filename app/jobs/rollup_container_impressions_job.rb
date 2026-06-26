# frozen_string_literal: true

# Materializes the container-level rollup by deriving DOWN the structural-home
# tree (§8): for each Community/Collection, sum the leaf ImpressionDailyCount
# over its descendant noid set. Re-parenting just changes which leaves resolve
# next run — there are no historical rows to rewrite (v1's move/delete tax is
# gone). Re-derives a trailing window each run. Scheduled daily, off-peak.
class RollupContainerImpressionsJob < ApplicationJob
  queue_as :background

  WINDOW = 90.days

  def perform(window: WINDOW)
    window_start = window.ago.to_date
    conn = ActiveRecord::Base.connection

    conn.transaction do
      conn.execute(
        "DELETE FROM impression_container_daily_counts WHERE day >= #{conn.quote(window_start)}::date"
      )
      each_container do |noid, uuid|
        rows = container_totals(noid, uuid, window_start)
        next if rows.empty?

        ImpressionContainerDailyCount.insert_all(rows) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end

  private

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
