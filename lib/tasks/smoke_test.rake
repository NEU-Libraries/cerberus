require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs = ["spec"]
  t.name = "smoke_test"
  t.warning = false
  t.verbose = false
  t.test_files = FileList['spec/models/*/**', 'spec/controllers/*/**', 'spec/lib/drs/rights/*', 'spec/lib/drs/metadata_assignment_spec.rb'].exclude(/spec\/models\/services/)
end
