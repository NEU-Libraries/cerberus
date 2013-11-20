task :create_drs_admin => :environment do 
  drs_admin_user = User.find_by_email("drsadmin@neu.edu") 
  User.create(email: "drsadmin@neu.edu", password: "drs12345", password_confirmation: "drs12345") unless drs_admin_user
end