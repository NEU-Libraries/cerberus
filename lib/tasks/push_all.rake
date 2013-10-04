require 'rake/task'

task :push_all do
  Rake::Task['smoke_test'].invoke or exit!(1)
  system('git push -n origin develop')
  system('git push -n repdev develop')
end