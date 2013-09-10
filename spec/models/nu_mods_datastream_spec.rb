require 'spec_helper' 

describe NuModsDatastream do 
  let(:basic_mods) { FactoryGirl.build(:mods) } 

  subject { basic_mods } 

  it { should respond_to(:to_xml) }
  it { should respond_to(:assign_creator_personal_names) } 
  it { should respond_to(:assign_corporate_names) } 

  describe "Simple setters" do 
    before do 
      basic_mods.mods_title = "My title" 
      basic_mods.mods_abstract = "This is a test object created for testing" 
      basic_mods.mods_identifier = "neu:123abc" 
      basic_mods.mods_date_issued = "2013-05-05"
    end

    it "Has set the title correctly" do 
      basic_mods.mods_title_info(0).mods_title.first.should == "My title" 
    end

    it "Has the abstract set correctly" do 
      basic_mods.mods_abstract(0).first.should == "This is a test object created for testing" 
    end

    it "Has the identifier set correctly" do 
      basic_mods.mods_identifier(0).first.should == "neu:123abc" 
    end

    it "Has the mods issuance date set correctly" do 
      basic_mods.mods_origin_info(0).mods_date_issued.first.should == '2013-05-05' 
    end
  end

  # Note that factories which create more or less equivalent objects do exist.
  # But are not used here to avoid obfuscating the tests.  They should prove useful
  # when we're writing request specs however.  
  describe "Multiple entry setters" do

    describe "With valid information" do  
      let(:valid_mods) { NuModsDatastream.new } 
      let(:corp_names) { ["Corp One", "Corp Two", "Corp Three"] } 
      let(:first_names) { ["Will", "William", "Bill"] } 
      let(:last_names) { ["Jack", "Jackson", "Back"] } 

      before do 
        valid_mods.keywords = ["One", "Two", "Three"]
        valid_mods.assign_corporate_names(corp_names)
        valid_mods.assign_creator_personal_names(first_names, last_names) 
      end 

      it "Has set all provided keywords correctly" do 
        valid_mods.mods_subject.mods_keyword(0).should == ["One"] 
        valid_mods.mods_subject.mods_keyword(1).should == ["Two"] 
        valid_mods.mods_subject.mods_keyword(2).should == ["Three"] 
      end

      it "Has set all provided corporate names correctly" do
        valid_mods.corporate_creators.should == ["Corp One", "Corp Two", "Corp Three"] 

        valid_mods.mods_corporate_name(0).mods_full_corporate_name.should == ["Corp One"] 
        valid_mods.mods_corporate_name(1).mods_full_corporate_name.should == ["Corp Two"] 
        valid_mods.mods_corporate_name(2).mods_full_corporate_name.should == ["Corp Three"] 
      end

      it "Hasn't compressed any corporate names into the same parent node" do 
        valid_mods.mods_corporate_name(0).mods_full_corporate_name.length.should == 1
        valid_mods.mods_corporate_name(1).mods_full_corporate_name.length.should == 1
        valid_mods.mods_corporate_name(2).mods_full_corporate_name.length.should == 1 
      end

      it "Has set all provided name entries correctly" do
        valid_mods.personal_creators.should == [{first: "Will", last: "Jack"}, {first: "William", last: "Jackson"},
                                                {first: "Bill", last: "Back"}]

        valid_mods.mods_personal_name(0).mods_first_name.should == ["Will"]
        valid_mods.mods_personal_name(0).mods_last_name.should == ["Jack"]

        valid_mods.mods_personal_name(1).mods_first_name.should == ["William"]
        valid_mods.mods_personal_name(1).mods_last_name.should == ["Jackson"] 

        valid_mods.mods_personal_name(2).mods_first_name.should == ["Bill"]
        valid_mods.mods_personal_name(2).mods_last_name.should == ["Back"]
      end

      it "Hasn't compressed any names into the same parent node" do 
        valid_mods.mods_personal_name(0).mods_first_name.length.should == 1 
        valid_mods.mods_personal_name(0).mods_last_name.length.should == 1

        valid_mods.mods_personal_name(1).mods_first_name.length.should == 1
        valid_mods.mods_personal_name(1).mods_last_name.length.should == 1

        valid_mods.mods_personal_name(2).mods_first_name.length.should == 1
        valid_mods.mods_personal_name(2).mods_last_name.length.should == 1
      end
    end

    describe "With invalid information" do 
      let(:invalid_mods) { NuModsDatastream.new }
      let(:crap_keywords) { ["", " ", ""] }  
      let(:crap_corps) { ["", " ", ""] }
      let(:crap_first_names) { ["", " ", "Will", "", " "] } 
      let(:crap_last_names) { [" ", "", "Jackson", "", " "] }

      let(:uneven_mods) { NuModsDatastream.new } 
      let(:uneven_firsts) { ["Will", "Chris"] } 
      let(:uneven_lasts) { ["Jackson", "Tucker", "Chan"] } 

      before do 
        invalid_mods.mods_subject.mods_keyword = crap_keywords 
        invalid_mods.assign_corporate_names(crap_corps)
        invalid_mods.assign_creator_personal_names(crap_first_names, crap_last_names) 
      end

      it "Throws an error when unequal first and last name arrays are passed" do 
        expect{ uneven_mods.assign_creator_personal_names(uneven_firsts, uneven_lasts) }.to raise_error 
      end

      it "Assigns no corporate creators" do 
        invalid_mods.mods_corporate_name(0).mods_full_corporate_name.should == [] 
        invalid_mods.mods_corporate_name.length.should == 1 
      end

      it "Assigns a single first and last name" do 
        invalid_mods.mods_personal_name.length.should == 1
        invalid_mods.mods_personal_name(0).should == ["WillJackson"] 
      end
    end
  end
end