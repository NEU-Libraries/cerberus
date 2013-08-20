require 'spec_helper' 

class ModsTest < ActiveFedora::Base 
  has_metadata name: 'mods', type: NuModsDatastream

  include ModsSetterHelpers 
end

describe ModsSetterHelpers do 

  let(:wrapper) { ModsTest.new }

  it "Sets the title correctly" do 
    wrapper.mods_title = "My title" 
    wrapper.mods_title.should == "My title"
    wrapper.mods.mods_title_info.mods_title.should == ["My title"]  
  end

  it "Sets the abstract correctly" do 
    wrapper.mods_abstract = "An abstract" 
    wrapper.mods_abstract.should == "An abstract" 
    wrapper.mods.mods_abstract.should == ["An abstract"] 
  end

  it "Sets the identifier correctly" do 
    wrapper.mods_identifier = 'neu:whatever'
    wrapper.mods_identifier.should == 'neu:whatever' 
    wrapper.mods.mods_identifier.should == ['neu:whatever'] 
  end

  it "Sets collection type correctly" do 
    wrapper.mods_collection = 'yes' 
    wrapper.mods_is_collection?.should be true 
    wrapper.mods.mods_type_of_resource.mods_collection.should == ['yes'] 
  end

  it "Sets the date of issuance correctly" do 
    wrapper.mods_date_issued = '2000-01-01'
    wrapper.mods_date_issued.should == '2000-01-01' 
    wrapper.mods.mods_origin_info.mods_date_issued == ['2001-01-01'] 
  end

  describe "Setting keywords" do 
    let(:kw_one) { ['One', 'Two', 'Three'] } 
    let(:kw_two) { ['Four', 'Five', 'Six'] } 
    let(:kw_blank) { ['  ', 'Valid', '', '  '] } 

    it "Performs a basic set correctly" do 
      wrapper.mods_keyword = kw_one 
      wrapper.mods_keyword.should == kw_one 

      wrapper.mods.mods_subject.mods_keyword(0).should == ['One'] 
      wrapper.mods.mods_subject.mods_keyword(1).should == ['Two'] 
      wrapper.mods.mods_subject.mods_keyword(2).should == ['Three'] 
    end

    it "Overrides on new data entry" do 
      wrapper.mods_keyword = kw_one 
      wrapper.mods_keyword.should == kw_one 
      wrapper.mods_keyword = kw_two 

      wrapper.mods.mods_subject.mods_keyword.length.should == 3 
      wrapper.mods.mods_subject.mods_keyword(0).should == ['Four'] 
      wrapper.mods.mods_subject.mods_keyword(1).should == ['Five'] 
      wrapper.mods.mods_subject.mods_keyword(2).should == ['Six']
    end

    it "Ignores whitespace entries" do 
      wrapper.mods_keyword = kw_blank 
      wrapper.mods_keyword.should == ['Valid'] 

      wrapper.mods.mods_subject.mods_keyword.length.should == 1 
    end
  end

  describe "Setting corporate creators" do 

    it "Performs a basic set correctly" do 
      cns = ["corp one", "corp two", "corp three"] 
      wrapper.mods_corporate_creators = cns 
      wrapper.mods_corporate_creators.should == ["corp one", "corp two", "corp three"]

      wrapper.mods.mods_corporate_name(0).mods_full_corporate_name(0).should == ["corp one"] 
      wrapper.mods.mods_corporate_name(1).mods_full_corporate_name(0).should == ["corp two"] 
      wrapper.mods.mods_corporate_name(2).mods_full_corporate_name(0).should == ["corp three"] 

      wrapper.mods.mods_corporate_name(0).mods_full_corporate_name.length.should == 1
      wrapper.mods.mods_corporate_name(1).mods_full_corporate_name.length.should == 1 
      wrapper.mods.mods_corporate_name(2).mods_full_corporate_name.length.should == 1 
    end

    it "Overrides on new data input" do 
      cns = ["c_one", "c_two"] 
      wrapper.mods_corporate_creators = cns 
      wrapper.mods_corporate_creators.should == ['c_one', 'c_two'] 

      cns_two = ['c_three', 'c_four'] 
      wrapper.mods_corporate_creators = cns_two 
      wrapper.mods_corporate_creators.should == ['c_three', 'c_four'] 
    end

    it "Ignores garbage input" do 
      cns = ["     ", "c_two"]
      wrapper.mods_corporate_creators = cns 
      wrapper.mods_corporate_creators.should == ['c_two']

      wrapper.mods.mods_corporate_name(0).mods_full_corporate_name(0).should == ['c_two'] 
    end 
  end

  describe "Setting personal creators" do
    let(:fns) { ['Will', 'Chris'] }
    let(:lns) { ['Jackson', 'Tucker'] } 
    let(:fns_2) { ['Jackie', 'William'] } 
    let(:lns_2) { ['Chan', 'Robert'] } 
    let(:fns_mismatch) { ['Jack'] }
    let(:lns_mismatch) { ['Johnson', 'Gray', '  '] }
    let(:fns_blanks) { ["  ", "Bob"] } 
    let(:lns_blanks) { [" ", "Alice"] } 

    it "Performs a basic set correctly" do 
      name_one_hashed = { first: 'Will', last: 'Jackson' }
      name_two_hashed = { first: 'Chris', last: 'Tucker' }  
      wrapper.set_mods_personal_creators(fns, lns)
      wrapper.mods_personal_creators.should == [name_one_hashed, name_two_hashed]

      wrapper.mods.mods_personal_name(0).mods_first_name(0).should == ["Will"] 
      wrapper.mods.mods_personal_name(0).mods_last_name(0).should == ["Jackson"] 

      wrapper.mods.mods_personal_name(1).mods_first_name(0).should == ["Chris"]
      wrapper.mods.mods_personal_name(1).mods_last_name(0).should == ["Tucker"] 
    end

    it "Overrides when new data is passed" do 
      wrapper.set_mods_personal_creators(fns, lns) 
      wrapper.set_mods_personal_creators(fns_2, lns_2) 

      wrapper.mods.mods_personal_name(0).mods_first_name(0).should == ["Jackie"] 
      wrapper.mods.mods_personal_name(0).mods_last_name(0).should == ["Chan"] 

      wrapper.mods.mods_personal_name(1).mods_first_name(0).should == ["William"] 
      wrapper.mods.mods_personal_name(1).mods_last_name(0).should == ["Robert"] 
    end

    it "Disallows mismatched entries" do 
      expect { wrapper.set_mods_personal_creators(fns_mismatch, lns_mismatch) }.to raise_error 
    end

    it "Ignores whitespace entries" do
      wrapper.set_mods_personal_creators(fns_blanks, lns_blanks)

      wrapper.mods.mods_personal_name(0).mods_first_name(0).should == ['Bob'] 
      wrapper.mods.mods_personal_name(0).mods_last_name(0).should == ['Alice'] 
    end 
  end 
end