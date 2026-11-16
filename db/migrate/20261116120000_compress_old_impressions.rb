# frozen_string_literal: true

# Compresses raw impression chunks once they pass the rollup window. The hourly
# rollups and the throttle never read a chunk that old, so only a full refresh
# of the aggregate ever decompresses one. See docs/analytics.md.
class CompressOldImpressions < ActiveRecord::Migration[8.1]
  def up
    add_compression_policy :impressions,
                           segmentby:      'action',
                           orderby:        'noid, created_at DESC',
                           compress_after: '120 days'
  end

  def down
    execute "SELECT remove_compression_policy('impressions', if_exists => true)"
    execute "SELECT decompress_chunk(c, if_compressed => true) FROM show_chunks('impressions') c"
    execute 'ALTER TABLE impressions SET (timescaledb.compress = false)'
  end
end
