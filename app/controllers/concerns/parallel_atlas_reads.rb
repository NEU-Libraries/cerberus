# frozen_string_literal: true

# Runs a handful of independent, read-only Atlas calls concurrently and returns
# their results keyed the way they were passed in. Used where one request would
# otherwise make several sequential atlas_rb GETs that don't depend on each other
# (e.g. a Work show page's mods + assets + file_sets): the wall time then tracks
# the slowest call instead of their sum.
#
# Two properties make this safe:
#
#   * Per-request context lives in `Current` (ActiveSupport::CurrentAttributes),
#     which is thread-local and does not cross into spawned threads. atlas_rb's
#     auth resolver reads `Current.nuid` / `Current.on_behalf_of`, so a worker
#     with a blank Current would call Atlas as no one. We snapshot Current on the
#     caller thread and re-establish it inside each worker.
#   * A task that raises aborts the batch: every worker is joined first (so a
#     failure never orphans a sibling mid-flight), then the first error in task
#     order is re-raised with its original backtrace — a failing read surfaces
#     exactly as it would have run sequentially.
#
# Tasks MUST be pure Atlas reads (no ActiveRecord): the workers don't check out a
# database connection. Resolve anything DB-backed (e.g. the viewer's nuid) on the
# caller thread and close over the value.
module ParallelAtlasReads
  extend ActiveSupport::Concern

  private

    def parallel_atlas_reads(tasks)
      return {} if tasks.empty?
      # A single task needs no thread — run it inline for identical semantics.
      return { tasks.keys.first => tasks.values.first.call } if tasks.size == 1

      context = Current.attributes
      threads = tasks.transform_values { |task| spawn_atlas_read(task, context) }
      results = threads.transform_values(&:value)
      results.each_value { |value| raise value if value.is_a?(StandardError) }
      results
    end

    # A worker that re-establishes the caller's Current (thread-local, so it does
    # not cross the thread boundary on its own) before running the read. A raised
    # error is carried out as the thread's value and re-raised by the caller.
    def spawn_atlas_read(task, context)
      Thread.new(context.dup) do |attrs|
        Current.attributes = attrs
        task.call
      rescue StandardError => e
        e
      end
    end
end
