# frozen_string_literal: true

# One canonical command for the environment smoke test, so the worktree gate
# and a person at a terminal run exactly the same thing.
#
# SMOKE is set here rather than in the spec: it has to be visible to SimpleCov
# at the moment rails_helper loads, which is before any example runs. It lifts
# the whole-suite coverage floor, which a four-example subset could never meet.
desc 'Run the environment smoke test (wiring, not correctness — CI owns the full suite)'
task :smoke do
  sh({ 'SMOKE' => '1' }, 'bundle exec rspec --tag smoke')
end
