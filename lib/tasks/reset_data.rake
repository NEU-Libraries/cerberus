require "#{Rails.root}/lib/helpers/handle_helper"
include HandleHelper

def mint_unique_pid
  Cerberus::Noid.namespaceize(Cerberus::IdService.mint)
end

def create_collection(klass, parent_str, title_str, description = "Lorem ipsum dolor sit amet, consectetur adipisicing elit. Recusandae, minima, cum sit iste at mollitia voluptatem error perspiciatis excepturi ut voluptatibus placeat esse architecto ea voluptate assumenda repudiandae quod commodi.")
  newPid = mint_unique_pid
  col = klass.new(parent: parent_str, pid: newPid, identifier: newPid, title: title_str, description: description)

  col.rightsMetadata.permissions({group: 'public'}, 'read')
  col.identifier = make_handle("#{Rails.configuration.persistent_collection_path}#{col.pid}")
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

  set_edit_permissions(core)
end

def set_edit_permissions(obj)
  obj.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  obj.save!
end

task :reset_data => :environment do

  require 'factory_girl_rails'

  Hydra::Derivatives.fits_path = Cerberus::Application.config.fits_path

  ActiveFedora::Base.find(:all).each do |file|
    file.destroy
  end

  User.find(:all).each do |user|
    user.destroy
  end

  root_dept = Community.new(pid: 'neu:1', identifier: 'neu:1', title: 'Northeastern University', description: "Founded in 1898, Northeastern is a global, experiential, research university built on a tradition of engagement with the world, creating a distinctive approach to education and research. The university offers a comprehensive range of undergraduate and graduate programs leading to degrees through the doctorate in nine colleges and schools, and select advanced degrees at graduate campuses in Charlotte, North Carolina, and Seattle.")
  root_dept.save!

  # Add marcom structure for loader testing
  marcom_dept = Community.new(mass_permissions: 'public', pid: 'neu:353', identifier: 'neu:353', title: 'Office of Marketing and Communications')
  marcom_dept.parent = "neu:1"
  marcom_dept.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  marcom_dept.save!

  # Parent collection
  p_c = Collection.new(mass_permissions: 'public', parent: marcom_dept, pid: 'neu:6240', title: 'Marketing and Communications Photo Archive')
  p_c.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  p_c.save!

  # Marcom children collections
  p_1 = Collection.create(mass_permissions: 'public', parent: p_c, pid: 'neu:6241', title: 'Alumni (Photographs)')
  p_1.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  p_1.save!

  # Add COE structure for loader testing
  coe_dept = Community.new(mass_permissions: 'public', pid: 'neu:103', identifier: 'neu:103', title: 'College of Engineering')
  coe_dept.parent = "neu:1"
  coe_dept.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  coe_dept.save!

  # Parent collections
  p_c = Collection.new(mass_permissions: 'public', parent: coe_dept, pid: 'neu:5m60qz04j', title: 'College of Engineering Office of the Dean')
  p_c.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  p_c.save!

  p_c2 = Collection.new(mass_permissions: 'public', parent: p_c, pid: 'neu:5m60qz05t', title: 'Photographs')
  p_c2.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  p_c2.save!

  # COE children collections
  p_1 = Collection.create(mass_permissions: 'public', parent: p_c2, pid: 'neu:5m60qz063', title: 'Capstone Projects')
  p_1.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  p_1.save!

  # Add CPS structure for loader testing
  cps_dept = Community.new(mass_permissions: 'public', pid: 'neu:108', identifier: 'neu:108', title: 'College of Professional Studies')
  cps_dept.parent = "neu:1"
  cps_dept.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  cps_dept.save!

  # Parent collections
  p_c = Collection.new(mass_permissions: 'public', parent: cps_dept, pid: 'neu:5m60qz152', title: 'College of Professional Studies Office of the Dean')
  p_c.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  p_c.save!

  p_c2 = Collection.new(mass_permissions: 'public', parent: p_c, pid: 'neu:5m60qz16b', title: 'Photographs')
  p_c2.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  p_c2.save!

  # CPS children collections
  p_1 = Collection.create(mass_permissions: 'public', parent: p_c2, pid: 'neu:5m60qz23r', title: 'Graduation and Other Events')
  p_1.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  p_1.save!

  p_2 = Collection.create(mass_permissions: 'public', parent: p_1, pid: 'neu:5m60qz35j', title: 'Ambassador Meet and Greet')
  p_2.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  p_2.save!

  # Add EMSA structure for loader testing
  emsa_dept = Community.new(mass_permissions: 'public', pid: 'neu:5m60qx98m', title: 'Enrollment Management and Student Affairs')
  emsa_dept.parent = "neu:1"
  emsa_dept.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  emsa_dept.save!

  # Parent collection
  p_c = Community.new(mass_permissions: 'public', pid: 'neu:rx915867k', title: 'Enrollment Marketing and Communications')
  p_c.parent = "neu:5m60qx98m"
  p_c.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  p_c.save!

  # EMSA children Collections
  p_1 = Collection.create(mass_permissions: 'public', parent: p_c, pid: 'neu:5m60qx99w', title: 'Enrollment Marketing and Communications Media')
  p_1.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  p_1.save!

  p_2 = Collection.create(mass_permissions: 'public', parent: p_1, pid: 'neu:rx915x94d', title: 'Photographs')
  p_2.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  p_2.save!

  # Add Bouve structure for loader testing
  bouve_dept = Community.new(mass_permissions: 'public', pid: 'neu:38', title: 'Bouvé College of Health Sciences')
  bouve_dept.parent = "neu:1"
  bouve_dept.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  bouve_dept.save!

  # Bouve dean's office community
  p_c = Community.new(mass_permissions: 'public', pid: 'neu:rx917k98s', title: 'Bouvé College of Health Sciences Office of the Dean')
  p_c.parent = "neu:38"
  p_c.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  p_c.save!

  # Bouve children collections
  p_1 = Collection.create(mass_permissions: 'public', parent: p_c, pid: 'neu:rx917k992', title: 'Media')
  p_1.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  p_1.save!

  p_2 = Collection.create(mass_permissions: 'public', parent: p_1, pid: 'neu:rx917m00m', title: 'Photographs')
  p_2.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  p_2.save!

  # Add D'Amore Mckim structure for loader testing
  damore_comm = Community.new(mass_permissions: 'public', pid: 'neu:77', title: "D'Amore-McKim School of Business")
  damore_comm.parent = "neu:1"
  damore_comm.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  damore_comm.save!

  # Damore marcom community
  p_c = Community.new(mass_permissions: 'public', pid: 'neu:rx913r53s', title: "D'Amore-McKim Marketing and Communications Office")
  p_c.parent = "neu:77"
  p_c.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  p_c.save!

  # Damore children collections
  p_1 = Collection.create(mass_permissions: 'private', parent: p_c, pid: 'neu:rx913r57w', title: 'Photographs')
  p_1.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  p_1.rightsMetadata.permissions({group: "northeastern:drs:all"}, 'read')
  p_1.save!

  p_2 = Collection.create(mass_permissions: 'private', parent: p_1, pid: 'neu:cj82mw96w', title: '2016 Photos')
  p_2.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  p_2.save!

  p_3 = Collection.create(mass_permissions: 'private', parent: p_1, pid: 'neu:cj82mw95m', title: 'Private and Sensitive Photography')
  p_3.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, 'edit')
  p_3.save!

  root_dept.rightsMetadata.permissions({group: 'public'}, 'read')
  set_edit_permissions(root_dept)

  tmp_user = User.create(:password => "drs12345", :password_confirmation => "drs12345", full_name:"Temp User", nuid:"000000000")
  tmp_user.email = "drsadmin@neu.edu"
  tmp_user.role = "admin"
  tmp_user.role = "developer"
  tmp_user.view_pref = "list"
  tmp_user.save!

  # Add David, Eli Pat Sarah Joey Julio and Brooks

  sarah = User.create(:password => "password", :password_confirmation => "password", full_name:"Sweeney, Sarah Jean", nuid:"001126975")
  sarah.email = "sj.sweeney@neu.edu"
  sarah.role = "admin"
  sarah.role = "developer"
  sarah.save!

  pat = User.create(:password => "password", :password_confirmation => "password", full_name:"Yott, Patrick", nuid:"000572965")
  pat.email = "p.yott@neu.edu"
  pat.role = "admin"
  pat.save!

  brooks = User.create(:password => "password", :password_confirmation => "password", full_name:"Canaday, Brooks Harwood", nuid:"001980907")
  brooks.email = "b.canaday@neu.edu"
  brooks.save!

  matt = User.create(:password => "password", :password_confirmation => "password", full_name:"Modoono, Matt", nuid:"001795872")
  matt.email = "m.modoono@neu.edu"
  matt.save!

  joey = User.create(:password => "password", :password_confirmation => "password", full_name:"Heinen, Joey", nuid:"001670214")
  joey.email = "j.heinen@neu.edu"
  joey.save!

  julio = User.create(:password => "password", :password_confirmation => "password", full_name:"Chuy, Julio", nuid:"000000111")
  julio.email = "j.chuy@neu.edu"
  julio.save!

  eli = User.create(:password => "password", :password_confirmation => "password", full_name:"Zoller, Eli Scott", nuid:"001790966")
  eli.email = "e.zoller@neu.edu"
  eli.role = "admin"
  eli.role = "developer"
  eli.save!

  david = User.create(:password => "password", :password_confirmation => "password", full_name:"Cliff, David", nuid:"001905497")
  david.email = "d.cliff@neu.edu"
  david.role = "admin"
  david.role = "developer"
  david.save!

  sarah.add_group("northeastern:drs:repository:loaders:marcom")
  pat.add_group("northeastern:drs:repository:loaders:marcom")
  brooks.add_group("northeastern:drs:repository:loaders:marcom")
  matt.add_group("northeastern:drs:repository:loaders:marcom")
  joey.add_group("northeastern:drs:repository:loaders:marcom")
  eli.add_group("northeastern:drs:repository:loaders:marcom")
  david.add_group("northeastern:drs:repository:loaders:marcom")

  sarah.add_group("northeastern:drs:repository:loaders:coe")
  pat.add_group("northeastern:drs:repository:loaders:coe")
  joey.add_group("northeastern:drs:repository:loaders:coe")
  eli.add_group("northeastern:drs:repository:loaders:coe")
  david.add_group("northeastern:drs:repository:loaders:coe")

  sarah.add_group("northeastern:drs:repository:loaders:cps")
  pat.add_group("northeastern:drs:repository:loaders:cps")
  joey.add_group("northeastern:drs:repository:loaders:cps")
  eli.add_group("northeastern:drs:repository:loaders:cps")
  david.add_group("northeastern:drs:repository:loaders:cps")

  sarah.add_group("northeastern:drs:repository:loaders:emsa_emc")
  pat.add_group("northeastern:drs:repository:loaders:emsa_emc")
  joey.add_group("northeastern:drs:repository:loaders:emsa_emc")
  eli.add_group("northeastern:drs:repository:loaders:emsa_emc")
  david.add_group("northeastern:drs:repository:loaders:emsa_emc")
  julio.add_group("northeastern:drs:repository:loaders:emsa_emc")

  sarah.add_group("northeastern:drs:enrollment_management:emc:emc_admin")
  pat.add_group("northeastern:drs:enrollment_management:emc:emc_admin")
  joey.add_group("northeastern:drs:enrollment_management:emc:emc_admin")
  eli.add_group("northeastern:drs:enrollment_management:emc:emc_admin")
  david.add_group("northeastern:drs:enrollment_management:emc:emc_admin")
  julio.add_group("northeastern:drs:enrollment_management:emc:emc_admin")

  sarah.add_group("northeastern:drs:repository:loaders:bouve_dean")
  pat.add_group("northeastern:drs:repository:loaders:bouve_dean")
  joey.add_group("northeastern:drs:repository:loaders:bouve_dean")
  eli.add_group("northeastern:drs:repository:loaders:bouve_dean")
  david.add_group("northeastern:drs:repository:loaders:bouve_dean")

  sarah.add_group("northeastern:drs:repository:loaders:damore_mckim")
  pat.add_group("northeastern:drs:repository:loaders:damore_mckim")
  joey.add_group("northeastern:drs:repository:loaders:damore_mckim")
  eli.add_group("northeastern:drs:repository:loaders:damore_mckim")
  david.add_group("northeastern:drs:repository:loaders:damore_mckim")

  sarah.add_group("northeastern:drs:repository:staff")
  pat.add_group("northeastern:drs:repository:staff")
  joey.add_group("northeastern:drs:repository:staff")
  eli.add_group("northeastern:drs:repository:staff")
  david.add_group("northeastern:drs:repository:staff")

  tmp_user.add_group("northeastern:drs:repository:loaders:multipage")
  sarah.add_group("northeastern:drs:repository:loaders:multipage")
  eli.add_group("northeastern:drs:repository:loaders:multipage")
  david.add_group("northeastern:drs:repository:loaders:multipage")

  tmp_user.add_group("northeastern:drs:repository:loaders:spreadsheet")
  sarah.add_group("northeastern:drs:repository:loaders:spreadsheet")
  eli.add_group("northeastern:drs:repository:loaders:spreadsheet")
  david.add_group("northeastern:drs:repository:loaders:spreadsheet")

  sarah.add_group("northeastern:drs:staff")
  pat.add_group("northeastern:drs:staff")
  joey.add_group("northeastern:drs:staff")
  eli.add_group("northeastern:drs:staff")
  david.add_group("northeastern:drs:staff")
  matt.add_group("northeastern:drs:staff")
  brooks.add_group("northeastern:drs:staff")

  Cerberus::Application::Queue.push(EmployeeCreateJob.new(sarah.nuid, sarah.full_name))
  Cerberus::Application::Queue.push(EmployeeCreateJob.new(pat.nuid, pat.full_name))
  Cerberus::Application::Queue.push(EmployeeCreateJob.new(brooks.nuid, brooks.full_name))
  Cerberus::Application::Queue.push(EmployeeCreateJob.new(joey.nuid, joey.full_name))
  Cerberus::Application::Queue.push(EmployeeCreateJob.new(julio.nuid, julio.full_name))
  Cerberus::Application::Queue.push(EmployeeCreateJob.new(eli.nuid, eli.full_name))
  Cerberus::Application::Queue.push(EmployeeCreateJob.new(david.nuid, david.full_name))

  Cerberus::Application::Queue.push(EmployeeCreateJob.new(tmp_user.nuid, tmp_user.full_name))

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
