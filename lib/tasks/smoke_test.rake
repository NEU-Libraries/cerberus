require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs = ["spec"]
  t.name = "smoke_test"
  t.warning = true
  t.verbose = true
  t.test_files = FileList['spec/models/*', 'spec/controllers/*', 'spec/features/*', 'spec/lib/drs/rights/*', 'spec/lib/drs/metadata_assignment_spec.rb']
end