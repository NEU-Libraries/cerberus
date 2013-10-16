task :reset_data => environment do
  
  Rake::Task["jetty:stop"].invoke
  Rake::Task["jetty:stop"].enable

  Rake::Task["jetty:clean"].invoke
  Rake::Task["jetty:clean"].enable

  Rake::Task["jetty:start"].invoke
  Rake::Task["jetty:start"].enable    

  rootDept = Department.new(pid: 'neu:1', identifier: 'neu:1', title: 'Root Department')
  rootDept.rightsMetadata.permissions({group: 'public'}, 'read')

  begin
    tries ||=10
    rootDept.save!
  rescue Errno::ECONNREFUSED => e
    sleep 10
    puts "Waiting for jetty..."
    retry unless (tries -= 1).zero?
  else
    puts "Connected to Jetty."
  end



end