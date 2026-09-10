# frozen_string_literal: true

# Re-projects the Solr docs a Set names, driving the Set's recipe rather than
# its resolved contents. See docs/people-and-routing.md and docs/sets.md.
class SetReindexJob < ApplicationJob
  queue_as :default

  # atlas_rb sets no Faraday timeout on the system connection, so a large included
  # collection can hold this thread for a while. A timeout is transient and the
  # walk is idempotent, so re-running the recipe only repeats converged work.
  retry_on Faraday::TimeoutError, wait: :polynomially_longer, attempts: 3

  def perform(set_noid)
    actor = Current.nuid
    # Re-read rather than carried through the queue, so a recipe edited between
    # the click and the run is the one that gets honoured.
    compilation = AtlasRb::Compilation.find(set_noid)
    return if compilation.nil?

    result = { count: 0, failures: [] }
    Array(compilation['included_collections']).each { |noid| reindex_subtree(noid, result) }
    Array(compilation['included_works']).each { |noid| reindex_one(noid, result) }

    report(actor: actor, set_noid: set_noid, title: compilation['title'], result: result)
  end

  private

    # A failure is recorded and the walk continues. The TimeoutError re-raise has
    # to stay above the Faraday::Error rescue here and in reindex_one, or retry_on
    # never sees it.
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
    # surfaces as a parse error instead. Report what it means, not what it raised.
    def failure_reason(error)
      error.is_a?(JSON::ParserError) ? 'no resource found.' : error.message
    end

    # A run with no actor (a rake task) has nobody to tell, and is recorded anyway.
    def report(actor:, set_noid:, title:, result:)
      CompletionNotice.deliver(
        kind:         'set_reindex',
        to_nuid:      actor,
        subject:      result[:failures].any? ? 'Set reindex finished with problems' : 'Set reindex finished',
        body:         body_for(set_noid, title, result),
        subject_noid: set_noid,
        payload:      { title: title, count: result[:count], failures: result[:failures] }
      )
    end

    def body_for(set_noid, title, result)
      count = result[:count]
      lines = ["“#{title}”: #{count} resource#{'s' unless count == 1} reindexed."]
      lines += ['', 'These were not reindexed and may still be stale:', *result[:failures]] if result[:failures].any?
      # A path, not a _url: a job has no request to take a host from.
      lines += ['', Rails.application.routes.url_helpers.set_path(set_noid)]
      lines.join("\n")
    end
end
