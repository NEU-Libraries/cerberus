require "#{Rails.root}/lib/helpers/handle_helper"
include HandleHelper

def mint_unique_pid
  Cerberus::Noid.namespaceize(Cerberus::IdService.mint)
end

def create_collection(klass, parent_str, title_str, description = "Lorem ipsum dolor sit amet, consectetur adipisicing elit. Recusandae, minima, cum sit iste at mollitia voluptatem error perspiciatis excepturi ut voluptatibus placeat esse architecto ea voluptate assumenda repudiandae quod commodi.")
  newPid = mint_unique_pid
  col = klass.new(parent: parent_str, pid: newPid, identifier: newPid, title: title_str, description: description)

  col.rightsMetadata.permissions({group: 'public'}, 'read')
  col.save!

  set_edit_permissions(col)

  return col
end

def create_content_file(factory_sym, user, parent)
  master = FactoryGirl.create(factory_sym)

  master.mass_permissions = 'public'
  master.depositor = user.nuid
  DerivativeCreator.new(master.pid).generate_derivatives
  master.save!

  # Add non garbage metadata to core record.
  core = CoreFile.find(master.core_record.pid)
  core.parent = ActiveFedora::Base.find(parent.pid, cast: true)
  core.properties.parent_id = parent.pid
  core.title = "#{master.content.label}"
  core.description = "Lorem Ipsum Lorem Ipsum Lorem Ipsum"
  core.date = Date.today.to_s
  core.depositor = user.nuid
  core.mass_permissions = 'public'
  core.keywords = ["#{master.class}", "content"]
  core.mods.subject(0).topic = "a"
  core.identifier = make_handle(core.persistent_url)

  core.save!
end

def set_edit_permissions(obj)
  admin_users = ["001967405", "001905497", "000513515", "000000000"]

  admin_users.each do |nuid|
    obj.rightsMetadata.permissions({person: nuid}, 'edit')
    obj.save!
  end
end

task :reset_data => :environment do

  require 'factory_girl_rails'

  Hydra::Derivatives.fits_path = Cerberus::Application.config.fits_path

  ActiveFedora::Base.find(:all).each do |file|
    file.destroy
  end

  Rake::Task["db:reset"].reenable
  Rake::Task["db:reset"].invoke

  Rake::Task["db:test:prepare"].reenable
  Rake::Task["db:test:prepare"].invoke  

  # User.find(:all).each do |user|
  #   user.destroy
  # end

  root_dept = Community.new(pid: 'neu:1', identifier: 'neu:1', title: 'Northeastern University', description: "Founded in 1898, Northeastern is a global, experiential, research university built on a tradition of engagement with the world, creating a distinctive approach to education and research. The university offers a comprehensive range of undergraduate and graduate programs leading to degrees through the doctorate in nine colleges and schools, and select advanced degrees at graduate campuses in Charlotte, North Carolina, and Seattle.")
  root_dept.save!

  # Add marcom structure for loader testing
  marcom_dept = Community.new(mass_permissions: 'public', pid: 'neu:353', identifier: 'neu:353', title: 'Office of Marketing and Communications')
  marcom_dept.parent = "neu:1"
  marcom_dept.save!

  # Parent collection
  p_c = Collection.new(mass_permissions: 'public', parent: marcom_dept, pid: 'neu:6240', title: 'Marketing and Communications Photo Archive')
  p_c.save!

  # Marcom children collections - 12
  p_1 = Collection.create(mass_permissions: 'public', parent: p_c, pid: 'neu:6241', title: 'Alumni (Photographs)')
  p_2 = Collection.create(mass_permissions: 'public', parent: p_c, pid: 'neu:6242', title: 'Athletics (Photographs)')
  p_3 = Collection.create(mass_permissions: 'public', parent: p_c, pid: 'neu:6243', title: 'Campus (Photographs)')
  p_4 = Collection.create(mass_permissions: 'public', parent: p_c, pid: 'neu:6244', title: 'Campus Life (Photographs)')
  p_5 = Collection.create(mass_permissions: 'public', parent: p_c, pid: 'neu:6245', title: 'Classroom (Photographs)')
  p_6 = Collection.create(mass_permissions: 'public', parent: p_c, pid: 'neu:6246', title: 'Community Outreach (Photographs)')
  p_7 = Collection.create(mass_permissions: 'public', parent: p_c, pid: 'neu:6247', title: 'Experiential Learning (Photographs)')
  p_8 = Collection.create(mass_permissions: 'public', parent: p_c, pid: 'neu:6248', title: 'Graduation (Photographs)')
  p_9 = Collection.create(mass_permissions: 'public', parent: p_c, pid: 'neu:6249', title: 'Headshot (Photographs)')
  p_10 = Collection.create(mass_permissions: 'public', parent: p_c, pid: 'neu:6250', title: 'Potrait (Photographs)')
  p_11 = Collection.create(mass_permissions: 'public', parent: p_c, pid: 'neu:6251', title: 'President (Photographs)')
  p_12 = Collection.create(mass_permissions: 'public', parent: p_c, pid: 'neu:6252', title: 'Research (Photographs)')

  root_dept.rightsMetadata.permissions({group: 'public'}, 'read')

  tmp_user = User.find_by_email("drsadmin@neu.edu")

  if !tmp_user.nil?
    tmp_user.destroy
  end

  tmp_user = User.create(:password => "drs12345", :password_confirmation => "drs12345", full_name:"Temp User", nuid:"000000000")
  tmp_user.email = "drsadmin@neu.edu"
  tmp_user.role = "admin"
  tmp_user.view_pref = "list"
  tmp_user.save!

  Cerberus::Application::Queue.push(EmployeeCreateJob.new(tmp_user.nuid, tmp_user.full_name))

  set_edit_permissions(root_dept)

  engDept = create_collection(Community, 'neu:1', 'English Department')
  sciDept = create_collection(Community, 'neu:1', 'Science Department')
  litCol = create_collection(Collection, engDept.id, 'Literature')
  roCol = create_collection(Collection, engDept.id, 'Random Objects')
  rusNovCol = create_collection(Collection, litCol.id, 'Russian Novels')

  create_content_file(:image_master_file, tmp_user, roCol)
  create_content_file(:pdf_file, tmp_user, roCol)
  create_content_file(:docx_file, tmp_user, roCol)

  puts "Reset to stock objects complete."

end
