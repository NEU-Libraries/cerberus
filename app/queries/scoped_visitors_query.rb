# frozen_string_literal: true

# Live per-day distinct-visitor count for a specific noid set + date range,
# read straight from raw `impressions` rows. Exists because
# ImpressionDailyVisitor (the repo-wide rollup) has no noid dimension at
# all — distinct IPs can't be derived from a noid subset of an already-summed
# repo-wide total, so a scoped Usage Analytics view (an item and/or a facet)
# can't reuse it and has to read raw. Only ever asked for one scope at a time
# (a single dashboard render), so the extra cost over the persisted rollup is
# fine here in a way it wouldn't be for the repo-wide case.
class ScopedVisitorsQuery
  # @param range [Range<Date>] inclusive date range.
  # @param segment [:human, :all, String] :human applies the same bot/volume
  #   rules as the rollup (via HumanImpressionsQuery); :all is raw distinct IPs.
  # @param noids [Array<String>] the noid set to restrict to.
  def initialize(range:, segment:, noids:)
    @range = range
    @segment = segment.to_s == 'all' ? :all : :human
    @noids = noids
    @conn = ActiveRecord::Base.connection
  end

  # @return [Hash{Date => Integer}] chartkick-ready { day => unique_visitors }.
  def series
    return {} if @noids.empty?

    @conn.select_rows(sql).to_h { |day, count| [Date.parse(day.to_s), count.to_i] }
  end

  private

    def window_start
      @range.begin.beginning_of_day
    end

    # Exclusive upper bound — the day after range.end, so the last day is
    # fully included.
    def range_end
      (@range.end + 1).beginning_of_day
    end

    def sql
      @segment == :all ? all_traffic_sql : human_sql
    end

    def human_sql
      from_where = HumanImpressionsQuery.new(conn: @conn, window_start:, range_end:, noids: @noids).from_where_sql
      <<~SQL.squish
        SELECT i.created_at::date AS day, count(DISTINCT i.ip_address) AS unique_visitors
        #{from_where}
        GROUP BY i.created_at::date
      SQL
    end

    def all_traffic_sql
      <<~SQL.squish
        SELECT created_at::date AS day, count(DISTINCT ip_address) AS unique_visitors
        FROM impressions
        WHERE created_at >= #{@conn.quote(window_start)} AND created_at < #{@conn.quote(range_end)}
          AND noid IN (#{@noids.map { |n| @conn.quote(n) }.join(', ')})
        GROUP BY created_at::date
      SQL
    end
end
