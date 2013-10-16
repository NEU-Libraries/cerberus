task :reset_data => :environment do

  #Stopping jetty and emptying the db
  
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

  #Now that jetty is definitely started, we can start to cram in our new objects
  x = User.find_by_email("drsadmin@neu.edu")

  if !x.nil?
    x.destroy
  end

  x = User.new({:email => "drsadmin@neu.edu", :password => "drs12345", :password_confirmation => "drs12345"})
  x.save!

  rootDept.rightsMetadata.permissions({person: "#{x.nuid}"}, 'edit')
  rootDept.rightsMetadata.permissions({person: "d.cliff@neu.edu"}, 'edit')
  rootDept.rightsMetadata.permissions({person: "wi.jackson@neu.edu"}, 'edit')
  rootDept.rightsMetadata.permissions({person: "p.yott@neu.edu"}, 'edit')
  rootDept.rightsMetadata.permissions({person: "s.bassett@neu.edu"}, 'edit')
  rootDept.save!

  engDept = Department.new(parent_department: 'neu:1', title: 'English Department')
  engDept.rightsMetadata.permissions({group: 'public'}, 'read')
  engDept.rightsMetadata.permissions({person: "#{x.nuid}"}, 'edit')
  engDept.save!

  sciDept = Department.new(parent_department: 'neu:1', title: 'Science Department')
  sciDept.rightsMetadata.permissions({group: 'public'}, 'read')    
  sciDept.rightsMetadata.permissions({person: "#{x.nuid}"}, 'edit')
  sciDept.save!

  litCol = NuCollection.new(parent_department: "#{engDept.id}", title: 'Literature')
  litCol.rightsMetadata.permissions({group: 'public'}, 'read')
  litCol.rightsMetadata.permissions({person: "#{x.nuid}"}, 'edit')
  litCol.save!

  roCol = NuCollection.new(parent_department: "#{engDept.id}", title: 'Random Objects')
  roCol.rightsMetadata.permissions({group: 'public'}, 'read')
  roCol.rightsMetadata.permissions({person: "#{x.nuid}"}, 'edit')
  roCol.save!

  rusNovCol = NuCollection.new(parent: "#{litCol.id}", title: 'Russian Novels')
  rusNovCol.rightsMetadata.permissions({group: 'public'}, 'read')
  rusNovCol.rightsMetadata.permissions({person: "#{x.nuid}"}, 'edit')
  rusNovCol.save!    

end