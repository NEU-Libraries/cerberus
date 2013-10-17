def mint_unique_pid 
  Sufia::Noid.namespaceize(Sufia::IdService.mint)
end

def create_collection(klass, parent_str, title_str, user)
  newPid = mint_unique_pid
  
  x = ActiveFedora::Base.find(parent_str, :cast => true)

  if x.class == NuCollection
    obj = klass.new(parent: parent_str, pid: newPid, identifier: newPid, title: title_str)
  elsif x.class == Department
    obj = klass.new(department_parent: parent_str, pid: newPid, identifier: newPid, title: title_str)
  end

  obj.rightsMetadata.permissions({group: 'public'}, 'read')
  obj.rightsMetadata.permissions({person: "#{user.nuid}"}, 'edit')
  obj.save!

  set_edit_permissions(obj)

  return obj
end 

def create_file(klass, file_name, user, parent)
  newPid = mint_unique_pid
  obj = klass.new
  obj.core_record = NuCoreFile.create(depositor: "#{user.nuid}", pid: newPid, identifier: newPid, title: file_name)
  obj.core_record.set_parent(parent, user)
  obj.core_record.save!

  file_path = "#{Rails.root}/spec/fixtures/files/#{file_name}"
  obj.save!

  set_edit_permissions(obj)

  Sufia.queue.push(ContentCreationJob.new(newPid, file_path, file_name, user.id, false))  

  return obj  
end

def set_edit_permissions(obj)
  admin_users = ["drsadmin@neu.edu", "d.cliff@neu.edu", "wi.jackson@neu.edu", "p.yott@neu.edu", "s.bassett@neu.edu"]

  admin_users.each do |email_str|
    obj.rightsMetadata.permissions({person: email_str}, 'edit')
    obj.save!
  end
end

task :reset_data => :environment do

  #Stopping jetty and emptying the db
  
  Rake::Task["jetty:stop"].reenable
  Rake::Task["jetty:stop"].invoke

  Rake::Task["jetty:clean"].reenable
  Rake::Task["jetty:clean"].invoke

  Rake::Task["jetty:start"].reenable
  Rake::Task["jetty:start"].invoke    

  root_dept = Department.new(pid: 'neu:1', identifier: 'neu:1', title: 'Root Department')
  root_dept.rightsMetadata.permissions({group: 'public'}, 'read')

  begin
    tries ||=10
    root_dept.save!
  rescue Errno::ECONNREFUSED => e
    sleep 10
    puts "Waiting for jetty..."
    retry unless (tries -= 1).zero?
  else
    puts "Connected to Jetty."
  end

  #Now that jetty is definitely started, we can start to cram in our new objects
  drs_admin_user = User.find_by_email("drsadmin@neu.edu")

  if !drs_admin_user.nil?
    drs_admin_user.destroy
  end

  drs_admin_user = User.new({:email => "drsadmin@neu.edu", :password => "drs12345", :password_confirmation => "drs12345"})
  drs_admin_user.save!
  
  set_edit_permissions(root_dept)

  engDept = create_collection(Department, 'neu:1', 'English Department', drs_admin_user)
  sciDept = create_collection(Department, 'neu:1', 'Science Department', drs_admin_user)
  litCol = create_collection(NuCollection, engDept.id, 'Literature', drs_admin_user)
  roCol = create_collection(NuCollection, engDept.id, 'Random Objects', drs_admin_user)
  rusNovCol = create_collection(NuCollection, litCol.id, 'Russian Novels', drs_admin_user) 

  msWord = create_file(MswordFile, "test_docx.docx", drs_admin_user, roCol)
  img = create_file(ImageMasterFile, "test_pic.jpeg", drs_admin_user, roCol)
  pdf = create_file(PdfFile, "test.pdf", drs_admin_user, roCol)

  puts "Reset to stock objects complete."

end