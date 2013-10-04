require 'rake/task'

task :push_all do
  Rake::Task['smoke_test'].invoke or exit!(1)
  system('push -n origin develop')
  system('push -n repdev develop')
end