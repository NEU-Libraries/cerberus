task :smoke_test do
  system('rspec spec/models spec/controllers spec/features 
          spec/lib/drs/metadata_assignment_spec.rb spec/lib/drs/rights/') 
end