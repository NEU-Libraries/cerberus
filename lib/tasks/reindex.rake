# frozen_string_literal: true

# On-demand Solr re-projection of repository resources, via Atlas's
# :system-gated reindex endpoints (AtlasRb::System.reindex / reindex_subtree).
# These re-derive a resource's Solr doc from Atlas's current Postgres/OCFL
# state — Solr-only, no lifecycle transition, no audit/minting side effects —
# the purpose-built lever for refreshing a stale projection after an indexer
# ships or changes (e.g. the catalog's classification_ssim "Content" facet),
# replacing the old hack of nudging Solr via Work.complete's finalize path.
#
# Idempotent: re-running converges to the same result. Bulk orchestration lives
# here (the consumer), not in Atlas — the subtree task drives Atlas's batched,
# synchronous SubtreeReindexer one HTTP call at a time.
namespace :reindex do
  desc 'Re-project one resource\'s Solr doc. Usage: rake reindex:resource[<noid>]'
  task :resource, [:noid] => :environment do |_task, args|
    noid = args[:noid].presence || abort('Usage: rake reindex:resource[<noid>]')

    response = AtlasRb::System.reindex(noid)
    case response.status
    when 204 then puts "Reindexed #{noid}."
    when 404 then abort("No resource found for #{noid}.")
    else          abort("Reindex of #{noid} failed: HTTP #{response.status}.")
    end
  rescue Faraday::Error => e
    abort("Reindex of #{noid} failed: #{e.class} — #{e.message}")
  end

  desc 'Re-project a resource + its full descendant subtree (Works included). ' \
       'Rooted at a top-level Community this backfills the whole repository. ' \
       'Usage: rake reindex:subtree[<noid>]'
  task :subtree, [:noid] => :environment do |_task, args|
    noid = args[:noid].presence || abort('Usage: rake reindex:subtree[<noid>]')

    count = AtlasRb::System.reindex_subtree(noid)
    abort("Subtree reindex for #{noid} failed or resolved no resources.") if count.nil?
    puts "Reindexed #{count} resource(s) at and under #{noid}."
  rescue Faraday::Error => e
    abort("Subtree reindex for #{noid} failed: #{e.class} — #{e.message}")
  end
end
