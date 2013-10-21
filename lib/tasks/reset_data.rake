def mint_unique_pid 
  Sufia::Noid.namespaceize(Sufia::IdService.mint)
end

def create_collection(klass, parent_str, title_str, user)
  newPid = mint_unique_pid
  col = klass.new(parent: parent_str, pid: newPid, identifier: newPid, title: title_str)

  col.rightsMetadata.permissions({group: 'public'}, 'read')
  col.rightsMetadata.permissions({person: "#{user.nuid}"}, 'edit')
  col.save!

  set_edit_permissions(col)

  return col
end 

def create_file(file_name, user, parent)
  newPid = mint_unique_pid

  core_record = NuCoreFile.new(depositor: "#{user.nuid}", pid: newPid, identifier: newPid, title: file_name)
  core_record.set_parent(parent, user)
  core_record.save!

  file_path = "#{Rails.root}/spec/fixtures/files/#{file_name}"

  Sufia.queue.push(ContentCreationJob.new(newPid, file_path, file_name, user.id, false))  
end

def set_edit_permissions(col)
  admin_users = ["drsadmin@neu.edu", "d.cliff@neu.edu", "wi.jackson@neu.edu", "p.yott@neu.edu", "s.bassett@neu.edu"]

  admin_users.each do |email_str|
    col.rightsMetadata.permissions({person: email_str}, 'edit')
    col.save!
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

  root_dept = Community.new(pid: 'neu:1', identifier: 'neu:1', title: 'Root Community')
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

  engDept = create_collection(Community, 'neu:1', 'English Community', drs_admin_user)
  sciDept = create_collection(Community, 'neu:1', 'Science Community', drs_admin_user)
  litCol = create_collection(NuCollection, engDept.id, 'Literature', drs_admin_user)
  roCol = create_collection(NuCollection, engDept.id, 'Random Objects', drs_admin_user)
  rusNovCol = create_collection(NuCollection, litCol.id, 'Russian Novels', drs_admin_user) 

  create_file("test_docx.docx", drs_admin_user, roCol)
  create_file("test_pic.jpeg", drs_admin_user, roCol)
  create_file("test.pdf", drs_admin_user, roCol)

  puts "Reset to stock objects complete."

end