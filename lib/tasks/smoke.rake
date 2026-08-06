# frozen_string_literal: true

# One canonical command for the environment smoke test, so the worktree gate
# and a person at a terminal run exactly the same thing.
#
# SMOKE is set here rather than in the spec: it has to be visible to SimpleCov
# at the moment rails_helper loads, which is before any example runs. It lifts
# the whole-suite coverage floor, which a four-example subset could never meet.
desc 'Run the environment smoke test (wiring, not correctness — CI owns the full suite)'
# No :environment prerequisite, against the usual convention: this task only
# shells out, and rspec boots the app itself. Depending on :environment would
# load Rails twice — once in development here, once in test in the child — for
# a task whose whole purpose is to be quick.
task :smoke do # rubocop:disable Rails/RakeEnvironment
  sh({ 'SMOKE' => '1' }, 'bundle exec rspec --tag smoke')
end
