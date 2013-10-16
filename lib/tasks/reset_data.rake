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

  engDept = Department.new(department_parent: 'neu:1', title: 'English Department')
  engDept.rightsMetadata.permissions({group: 'public'}, 'read')
  engDept.rightsMetadata.permissions({person: "#{x.nuid}"}, 'edit')
  engDept.save!

  sciDept = Department.new(department_parent: 'neu:1', title: 'Science Department')
  sciDept.rightsMetadata.permissions({group: 'public'}, 'read')    
  sciDept.rightsMetadata.permissions({person: "#{x.nuid}"}, 'edit')
  sciDept.save!

  litCol = NuCollection.new(department_parent: "#{engDept.id}", title: 'Literature')
  litCol.rightsMetadata.permissions({group: 'public'}, 'read')
  litCol.rightsMetadata.permissions({person: "#{x.nuid}"}, 'edit')
  litCol.save!

  roCol = NuCollection.new(department_parent: "#{engDept.id}", title: 'Random Objects')
  roCol.rightsMetadata.permissions({group: 'public'}, 'read')
  roCol.rightsMetadata.permissions({person: "#{x.nuid}"}, 'edit')
  roCol.save!

  rusNovCol = NuCollection.new(parent: "#{litCol.id}", title: 'Russian Novels')
  rusNovCol.rightsMetadata.permissions({group: 'public'}, 'read')
  rusNovCol.rightsMetadata.permissions({person: "#{x.nuid}"}, 'edit')
  rusNovCol.save!

  img = ImageMasterFile.new
  pdf = PdfFile.new
  msWord = MswordFile.new
  

  img.core_record = NuCoreFile.create(depositor: "#{x.nuid}", title: "test_pic")
  img.core_record.set_parent(roCol, x)
  img.core_record.save!

  file = File.open("#{Rails.root}/spec/fixtures/files/test_pic.jpeg")
  img.add_file(file, "content", "test_pic.jpeg")
  img.save! 
  
  pdf.core_record = NuCoreFile.create(depositor: "#{x.nuid}", title: "test_pdf")
  pdf.core_record.set_parent(roCol, x)
  pdf.core_record.save!

  file = File.open("#{Rails.root}/spec/fixtures/files/test.pdf")
  pdf.add_file(file, "content", "test.pdf")
  pdf.save!
  
  msWord.core_record = NuCoreFile.create(depositor: "#{x.nuid}", title: "test_word_docx")
  msWord.core_record.set_parent(roCol, x)
  msWord.core_record.save!
  
  file = File.open("#{Rails.root}/spec/fixtures/files/test_docx.docx")
  msWord.add_file(file, "content", "test_docx.docx")
  msWord.save!

  puts "Reset to stock object complete."

end