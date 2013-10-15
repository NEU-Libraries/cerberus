task :reset_data => :environment do
  
  Rake::Task["jetty:stop"].reenable
  Rake::Task["jetty:stop"].invoke

  Rake::Task["jetty:clean"].reenable
  Rake::Task["jetty:clean"].invoke

  Rake::Task["jetty:start"].reenable
  Rake::Task["jetty:start"].invoke

  rootDepartment = Department.new(pid: 'neu:1', identifier: 'neu:1', title: 'Root Department')
  rootDepartment.rightsMetadata.permissions({group: 'public'}, 'read') 

  begin
    tries ||= 10
    rootDepartment.save!
  rescue Errno::ECONNREFUSED => e
    sleep 10
    puts "Waiting for jetty..."
    retry unless (tries -= 1).zero?
  else
    puts "Reset db to stock objects"
  end 

  # Now that jetty is sorted, it's much easier to structure the data

  User.destroy_all

  x = User.find_by_email("drsadmin@neu.edu")

  if !x.nil?
    x.destroy
  end

  x = User.new({email: 'drsadmin@neu.edu', :password => "drs12345", :password_confirmation => "drs12345"})   
  x.save!

  rootDepartment.rightsMetadata.permissions({person: "#{x.nuid}"}, 'edit')
  rootDepartment.save!

  engDept = Department.new(department_parent: 'neu:1', title: 'English Department')
  engDept.rightsMetadata.permissions({group: 'public'}, 'read')
  engDept.rightsMetadata.permissions({person: "#{x.nuid}"}, 'edit')

  engDept.save!
  
  litColl = NuCollection.new(department_parent: "#{engDept.id}", title: 'Literature')
  litColl.rightsMetadata.permissions({group: 'public'}, 'read')
  litColl.rightsMetadata.permissions({person: "#{x.nuid}"}, 'edit')

  litColl.save!

  sciDept = Department.new(department_parent: 'neu:1', title: 'Science Department')
  sciDept.rightsMetadata.permissions({group: 'public'}, 'read')
  sciDept.rightsMetadata.permissions({person: "#{x.nuid}"}, 'edit')

  sciDept.save!

  physDept = Department.new(department_parent: "#{sciDept.id}", title: 'Physics Department')
  physDept.rightsMetadata.permissions({group: 'public'}, 'read')
  physDept.rightsMetadata.permissions({person: "#{x.nuid}"}, 'edit')

  physDept.save!

  puts "Complete."
    
end
