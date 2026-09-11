# frozen_string_literal: true

# Independent, read-only Atlas calls run at once. See docs/deposit.md.
module ParallelAtlasReads
  extend ActiveSupport::Concern

  # Raise this on the CALLER thread, never inside a worker: ServerTiming's
  # collection lives in ActiveSupport::IsolatedExecutionState, which is
  # per-thread, so an event from a worker is dropped without a word. See
  # docs/deposit.md.
  INSTRUMENTATION_EVENT = 'parallel_reads.cerberus'

  private

    # A task MUST be a pure Atlas read: a worker checks out no database
    # connection, so anything DB-backed has to be resolved here and closed over.
    # No spec catches a breach — it passes under test and fails under load.
    def parallel_atlas_reads(tasks)
      return {} if tasks.empty?
      # A single task needs no thread — run it inline for identical semantics,
      # and uninstrumented, because atlas_rb's own event already covers it.
      return { tasks.keys.first => tasks.values.first.call } if tasks.size == 1

      ActiveSupport::Notifications.instrument(INSTRUMENTATION_EVENT, count: tasks.size) do
        run_atlas_reads(tasks)
      end
    end

    def run_atlas_reads(tasks)
      context = Current.attributes
      threads = tasks.transform_values { |task| spawn_atlas_read(task, context) }
      results = threads.transform_values(&:value)
      # Join every worker before raising anything, or a failing task orphans a
      # sibling mid-flight. Raising from inside the collection above is shorter
      # and does exactly that.
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
