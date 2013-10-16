def mint_unique_pid 
  Sufia::Noid.namespaceize(Sufia::IdService.mint)
end

def create_collection(klass, parentStr, titleStr, user)
  newPid = mint_unique_pid
  
  x = ActiveFedora::Base.find(parentStr, :cast => true)

  if x.class == NuCollection
    obj = klass.new(parent: parentStr, pid: newPid, identifier: newPid, title: titleStr)
  elsif x.class == Department
    obj = klass.new(department_parent: parentStr, pid: newPid, identifier: newPid, title: titleStr)
  end

  obj.rightsMetadata.permissions({group: 'public'}, 'read')
  obj.rightsMetadata.permissions({person: "#{user.nuid}"}, 'edit')
  obj.save!

  return obj
end

task :reset_data => :environment do

  #Stopping jetty and emptying the db
  
  Rake::Task["jetty:stop"].reenable
  Rake::Task["jetty:stop"].invoke

  Rake::Task["jetty:clean"].reenable
  Rake::Task["jetty:clean"].invoke

  Rake::Task["jetty:start"].reenable
  Rake::Task["jetty:start"].invoke    

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

  engDept = create_collection(Department, 'neu:1', 'English Department', x)
  sciDept = create_collection(Department, 'neu:1', 'Science Department', x)
  litCol = create_collection(NuCollection, engDept.id, 'Literature', x)
  roCol = create_collection(NuCollection, engDept.id, 'Random Objects', x)
  rusNovCol = create_collection(NuCollection, litCol.id, 'Russian Novels', x) 

  img = ImageMasterFile.new
  pdf = PdfFile.new
  msWord = MswordFile.new
  
  newPid = mint_unique_pid
  img.core_record = NuCoreFile.create(depositor: "#{x.nuid}", title: "test_pic", pid: newPid, identifier: newPid)
  img.core_record.set_parent(roCol, x)
  img.core_record.save!

  file = File.open("#{Rails.root}/spec/fixtures/files/test_pic.jpeg")
  img.add_file(file, "content", "test_pic.jpeg")
  img.save! 
  
  newPid = mint_unique_pid
  pdf.core_record = NuCoreFile.create(depositor: "#{x.nuid}", title: "test_pdf", pid: newPid, identifier: newPid)
  pdf.core_record.set_parent(roCol, x)
  pdf.core_record.save!

  file = File.open("#{Rails.root}/spec/fixtures/files/test.pdf")
  pdf.add_file(file, "content", "test.pdf")
  pdf.save!
  
  newPid = mint_unique_pid
  msWord.core_record = NuCoreFile.create(depositor: "#{x.nuid}", title: "test_word_docx", pid: newPid, identifier: newPid)
  msWord.core_record.set_parent(roCol, x)
  msWord.core_record.save!
  
  file = File.open("#{Rails.root}/spec/fixtures/files/test_docx.docx")
  msWord.add_file(file, "content", "test_docx.docx")
  msWord.save!

  puts "Reset to stock objects complete."

end