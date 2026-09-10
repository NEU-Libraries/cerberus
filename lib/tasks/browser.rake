# frozen_string_literal: true

# One canonical command for the browser specs, kept apart from :smoke on
# purpose. Both lanes ask "is this wired up?", but :smoke answers in about six
# seconds and gates every worktree, so it has to stay cheap and it has to pass
# on a machine with no browser running. These specs need the `selenium` service
# up and cost real time, which would make that gate both slower and refusable
# for a reason that says nothing about the code.
#
# CI does not run this lane. It would have to pull a browser image on every
# push for a handful of examples, so these specs only run when someone runs
# them — do not read a green pipeline as covering them.
#
# SMOKE lifts the whole-suite coverage floor, which this subset could never
# meet; RUN_BROWSER opts the tagged examples back in. Both are set here because
# SimpleCov and the rspec filters read them as rails_helper loads, before any
# example runs.
desc 'Run the browser specs (needs the selenium service: docker compose --profile test up -d selenium)'
# No :environment prerequisite, matching :smoke — this task only shells out,
# and rspec boots the app itself.
task :browser do # rubocop:disable Rails/RakeEnvironment
  sh({ 'SMOKE' => '1', 'RUN_BROWSER' => '1' }, 'bundle exec rspec --tag browser')
end
