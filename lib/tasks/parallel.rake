# frozen_string_literal: true

# One canonical command for the sharded spec run, so a person at a terminal and
# any future CI job invoke exactly the same thing.
#
# The shard is bounded by the compose topology, not by this task: each worker
# talks to its own atlas-test-N service, and only workers 2..4 exist (behind the
# `parallel` compose profile). Asking for more workers than there are Atlas
# instances would point several of them at the same one, and a run resets
# whichever Atlas it points at — so the ceiling is checked here rather than
# discovered as a cluster of unattributable failures.
#
# Prerequisites, both cheap and both idempotent:
#
#   docker compose --profile parallel up -d   # the extra Atlas instances
#   bin/parallel-solr-cores                   # the core each of them indexes to
#
# Split by recorded runtime rather than by file count. This suite's cost is
# extremely concentrated — a handful of controller and request files carry most
# of it — so an even split of *files* leaves one worker running long after the
# others have finished.
namespace :parallel do
  # Matches the atlas-test-2..4 services in docker-compose.yml.
  MAX_WORKERS = 4

  desc "Run the whole suite across N workers (default #{MAX_WORKERS})"
  # No :environment prerequisite, matching :smoke and :browser — this task only
  # shells out, and each worker boots the app itself.
  task :spec do # rubocop:disable Rails/RakeEnvironment
    workers = Integer(ENV.fetch('WORKERS', MAX_WORKERS))

    if workers > MAX_WORKERS
      abort <<~MSG
        Asked for #{workers} workers, but only #{MAX_WORKERS} Atlas instances exist.

        Workers beyond #{MAX_WORKERS} would share an atlas-test service with a lower-numbered
        worker, and a run wipes whichever Atlas it points at — so they would delete
        each other's fixtures mid-run.

        Add an atlas-test-#{MAX_WORKERS + 1} service (and its Solr core) to raise the ceiling.
      MSG
    end

    Rake::Task['parallel:prepare'].invoke(workers)
    sh "bundle exec parallel_rspec -n #{workers} --group-by runtime --verbose"
  end

  desc 'Create and migrate the per-worker Cerberus databases'
  task :prepare, [:workers] do |_t, args| # rubocop:disable Rails/RakeEnvironment
    workers = Integer(args[:workers] || ENV.fetch('WORKERS', MAX_WORKERS))

    # Rails' own task rather than parallel_tests' database helpers, because this
    # app has two test databases (primary and queue) and db:test:prepare is what
    # knows to load the schema into both.
    workers.times do |i|
      number = i.zero? ? '' : (i + 1).to_s
      sh({ 'TEST_ENV_NUMBER' => number, 'RAILS_ENV' => 'test' },
         'bundle exec rails db:test:prepare')
    end
  end
end
