require 'spec_helper' 

describe Drs::Rights::MassPermissions do 
  let(:core_file) { NuCoreFile.new } 

  describe "Setting to public" do 
    it "assigns read permissions to the public group" do
      core_file.mass_permissions = 'public' 
      core_file.mass_permissions.should == 'public' 
    end
  end

  describe "Setting to private" do 
    it "eliminates the public group and assigns no mass permissions" do 
      core_file.mass_permissions = 'public' 
      core_file.mass_permissions = 'private' 

      core_file.mass_permissions.should == 'private' 
      core_file.rightsMetadata.permissions({group: 'public'}).should == 'none' 
    end
  end
end