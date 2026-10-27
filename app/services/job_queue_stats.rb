# frozen_string_literal: true

# A snapshot of the Solid Queue tables for the admin health page: how much is
# waiting, how long the oldest has waited, and what is running or stuck.
# Mission Control at /jobs has the per-job detail. See docs/outages.md.
class JobQueueStats
  Snapshot = Data.define(:waiting_by_queue, :oldest_waiting_at, :running, :scheduled, :blocked, :failed, :workers) do
    def waiting = waiting_by_queue.values.sum
  end

  class << self
    # nil when the queue database does not answer; /health/jobs reports that.
    def call
      counts = read_tables
      Snapshot.new(**counts, waiting_by_queue: counts[:waiting_by_queue].sort.to_h)
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.warn("[job queue stats] #{e.class}: #{e.message}")
      nil
    end

    private

      def read_tables
        {
          waiting_by_queue:  SolidQueue::ReadyExecution.group(:queue_name).count,
          oldest_waiting_at: SolidQueue::ReadyExecution.minimum(:created_at),
          running:           SolidQueue::ClaimedExecution.count,
          scheduled:         SolidQueue::ScheduledExecution.count,
          blocked:           SolidQueue::BlockedExecution.count,
          failed:            SolidQueue::FailedExecution.count,
          workers:           live_workers
        }
      end

      # Two heartbeats rather than Solid Queue's five-minute alive threshold: a
      # worker killed without deregistering keeps its row until the supervisor
      # prunes it, and would otherwise count as live for five minutes.
      def live_workers
        since = (SolidQueue.process_heartbeat_interval * 2).ago
        SolidQueue::Process.where(kind: 'Worker', last_heartbeat_at: since..).count
      end
  end
end
