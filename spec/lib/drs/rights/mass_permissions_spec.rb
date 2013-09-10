require 'spec_helper' 

describe Drs::Rights::MassPermissions do 
  let(:core_file) { NuCoreFile.new } 

  describe "Setting to public" do 
    it "eliminates the registered group" do 
      core_file.mass_permissions = 'registered' 
      core_file.mass_permissions = 'public' 

      core_file.mass_permissions.should == 'public' 
      core_file.rightsMetadata.permissions({group: 'registered'}).should == 'none' 
    end
  end

  describe "Setting to registered" do 
    it "eliminates the public group" do 
      core_file.mass_permissions = 'public' 
      core_file.mass_permissions = 'registered' 

      core_file.mass_permissions.should == 'registered' 
      core_file.rightsMetadata.permissions({group: 'public'}).should == 'none' 
    end
  end

  describe "Setting to private" do 
    it "eliminates the public group" do 
      core_file.mass_permissions = 'public' 
      core_file.mass_permissions = 'private' 

      core_file.mass_permissions.should == 'private' 
      core_file.rightsMetadata.permissions({group: 'public'}).should == 'none' 
    end

    it "eliminates the registered group" do 
      core_file.mass_permissions = 'registered' 
      core_file.mass_permissions = 'private' 

      core_file.mass_permissions.should == 'private' 
      core_file.rightsMetadata.permissions({group: 'registered'}).should == 'none' 
    end
  end
end