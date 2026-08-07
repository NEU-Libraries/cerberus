# frozen_string_literal: true

# Re-projects the Solr docs a Set names, driving the Set's recipe rather than
# its resolved contents.
#
# That distinction is the point of the job. SetResolver answers "what is in
# this Set" out of Solr, so a resource whose Solr doc is missing is invisible
# to it — which is precisely the resource most in need of a reindex. Atlas's
# subtree walk reads the authoritative store instead, so it has no such blind
# spot. Driving the recipe also sidesteps the resolver's export row cap and its
# need for a request-bound, gated search service, and a job has no request.
#
# The trade is deliberate over-reach: walking the recipe also reindexes the
# included containers themselves and any Work the Set has set aside. A reindex
# is Solr-only and idempotent, so that costs time, not correctness.
class SetReindexJob < ApplicationJob
  queue_as :default

  # atlas_rb sets no Faraday timeout on the system connection, so a large
  # included collection can hold this thread for a while. A timeout is
  # transient and the walk is idempotent, so re-running the whole recipe only
  # repeats work that has already converged.
  retry_on Faraday::TimeoutError, wait: :polynomially_longer, attempts: 3

  # @param set_noid [String] the Compilation's NOID.
  def perform(set_noid)
    actor = Current.nuid
    # Re-read rather than carry the recipe through the queue, so a recipe
    # edited between the click and the run is the one that gets honoured.
    compilation = AtlasRb::Compilation.find(set_noid)
    return if compilation.nil?

    result = { count: 0, failures: [] }
    Array(compilation['included_collections']).each { |noid| reindex_subtree(noid, result) }
    Array(compilation['included_works']).each { |noid| reindex_one(noid, result) }

    report(actor: actor, set_noid: set_noid, title: compilation['title'], result: result)
  end

  private

    # One included collection and everything Atlas gathers beneath it. A
    # failure here is recorded and the walk continues — one unreachable branch
    # must not abandon the rest of the recipe.
    def reindex_subtree(noid, result)
      count = AtlasRb::System.reindex_subtree(noid)
      if count.nil?
        result[:failures] << "Collection #{noid}: no resource found."
      else
        result[:count] += count
      end
    rescue Faraday::TimeoutError
      raise
    rescue Faraday::Error, JSON::ParserError => e
      result[:failures] << "Collection #{noid}: #{failure_reason(e)}"
    end

    # One directly-added Work.
    def reindex_one(noid, result)
      status = AtlasRb::System.reindex(noid).status
      if status == 204
        result[:count] += 1
      else
        result[:failures] << "Work #{noid}: Atlas returned #{status}."
      end
    rescue Faraday::TimeoutError
      raise
    rescue Faraday::Error => e
      result[:failures] << "Work #{noid}: #{e.message}"
    end

    # atlas_rb does not translate a 404 on the subtree path — the empty body
    # surfaces as a parse error instead. Report what it means, not what it
    # raised.
    def failure_reason(error)
      error.is_a?(JSON::ParserError) ? 'no resource found.' : error.message
    end

    # Whoever clicked has moved on by now, and a partial run is the one outcome
    # they must not have to discover for themselves — a branch that failed to
    # reindex is still stale, so failures are named rather than counted.
    def report(actor:, set_noid:, title:, result:)
      return if actor.blank?

      SystemMessage.deliver(
        to_nuid: actor,
        subject: result[:failures].any? ? 'Set reindex finished with problems' : 'Set reindex finished',
        body:    body_for(set_noid, title, result)
      )
    end

    def body_for(set_noid, title, result)
      count = result[:count]
      lines = ["“#{title}”: #{count} resource#{'s' unless count == 1} reindexed."]
      lines += ['', 'These were not reindexed and may still be stale:', *result[:failures]] if result[:failures].any?
      # A path, not a _url: a job has no request to take a host from, and the
      # inbox renders these in-app anyway.
      lines += ['', Rails.application.routes.url_helpers.set_path(set_noid)]
      lines.join("\n")
    end
end
