require 'rake/task'

task :push_all do
  Rake::Task['smoke_test'].invoke or exit!(1)
  system('git push --no-verify origin develop')
  system('git push --no-verify repdev develop')
end