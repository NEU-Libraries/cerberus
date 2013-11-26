require 'spec_helper' 

describe NuModsDatastream do 
  let(:basic_mods) { FactoryGirl.build(:mods) } 

  subject { basic_mods } 

  it { should respond_to(:to_xml) }
  it { should respond_to(:assign_creator_personal_names) } 
  it { should respond_to(:assign_corporate_names) } 

  describe "Simple setters" do 
    before do 
      basic_mods.title = "My title" 
      basic_mods.abstract = "This is a test object created for testing" 
      basic_mods.mods_identifier = "neu:123abc" 
      basic_mods.mods_date_issued = "2013-05-05"
    end

    it "Has set the title correctly" do 
      basic_mods.title_info(0).title.first.should == "My title" 
    end

    it "Has the abstract set correctly" do 
      basic_mods.abstract(0).first.should == "This is a test object created for testing" 
    end

    it "Has the identifier set correctly" do 
      basic_mods.mods_identifier(0).first.should == "neu:123abc" 
    end

    it "Has the mods issuance date set correctly" do 
      basic_mods.mods_origin_info(0).mods_date_issued.first.should == '2013-05-05' 
    end
  end

  # Note that factories which create more or less equivalent objects do exist.
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
        valid_mods.mods_subject(0).mods_keyword.should == ["One"] 
        valid_mods.mods_subject(1).mods_keyword.should == ["Two"] 
        valid_mods.mods_subject(2).mods_keyword.should == ["Three"] 
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

        valid_mods.personal_name(0).name_part_given.should == ["Will"]
        valid_mods.personal_name(0).name_part_family.should == ["Jack"]

        valid_mods.personal_name(1).name_part_given.should == ["William"]
        valid_mods.personal_name(1).name_part_family.should == ["Jackson"] 

        valid_mods.personal_name(2).name_part_given.should == ["Bill"]
        valid_mods.personal_name(2).name_part_family.should == ["Back"]
      end

      it "Hasn't compressed any names into the same parent node" do 
        valid_mods.personal_name(0).name_part_given.length.should == 1 
        valid_mods.personal_name(0).name_part_family.length.should == 1

        valid_mods.personal_name(1).name_part_given.length.should == 1
        valid_mods.personal_name(1).name_part_family.length.should == 1

        valid_mods.personal_name(2).name_part_given.length.should == 1
        valid_mods.personal_name(2).name_part_family.length.should == 1
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
        invalid_mods.personal_name.length.should == 1
        invalid_mods.personal_name(0).should == ["WillJackson"] 
      end
    end
  end

  describe "Solrization" do 
    let(:mods) { NuModsDatastream.new } 
    let(:result) { mods.to_solr }

    it "Gives back ssi and tesim fields for the title entry" do 
      mods.title_info.title = "Test Title" 
      
      result["title_ssi"].should == "Test Title"
      result["title_tesim"].should == ["Test Title"]
    end

    it "Gives back tesim fields for all role entries" do 
      mods.mods_note = ["one", "two", "three"]

      result["mods_note_tesim"].should == ["one", "two", "three"]
    end

    it "Gives back a tesim field for all abstract entries" do 
      mods.abstract = ["A test", "That tests"] 

      result["abstract_tesim"].should == ["A test", "That tests"]
    end

    it "creates a tesim field for all identifier entries" do 
      mods.mods_identifier = ["neu:123", "ISBN 000"]

      result["mods_identifier_tesim"].should == ["neu:123", "ISBN 000"]
    end

    it "creates tesim, ssim, and faceted fields for all genre entries" do 
      arry = ["Non-fiction", "Science", "Monkeys"]
      mods.mods_genre = arry

      result["mods_genre_tesim"].should == arry
      result["mods_genre_sim"].should == arry 
      result["mods_genre_ssim"].should == arry
    end

    it "creates tesim, ssim, and faceted fields for genre entries in a related item entry" do 
      arry = ["Non-fiction", "Science", "Monkeys"]
      mods.mods_related_item = ['']
      mods.mods_related_item.genre = arry 

      result["mods_genre_tesim"].should == arry 
      result["mods_genre_sim"].should == arry 
      result["mods_genre_ssim"].should == arry
    end

    it "creates a tesim field for all publisher entries" do 
      mods.mods_origin_info = [""]
      mods.mods_origin_info.mods_publisher = ["WB", "Clearing House"]

      result["mods_origin_info_mods_publisher_tesim"].should == ["WB", "Clearing House"]
    end

    it "creates a tesim field for all origin place entries" do 
      mods.mods_origin_info = [""]
      mods.mods_origin_info.mods_place = "New York City" 

      result["mods_origin_info_mods_place_tesim"].should == ["New York City"]
    end

    it "indexes publisher information stored within a related item entry" do 
      mods.mods_related_item = ['']
      mods.mods_related_item.origin_info.place = "New York City" 

      result["mods_origin_info_mods_place_tesim"].should == ["New York City"]
    end

    it "creates a tesim field for all role entries" do 
      mods.personal_name = ["", ""]
      mods.personal_name(0).role = "Author" 
      mods.personal_name(1).role = "Editor" 

      result["personal_name_role_tesim"].should == ["Author", "Editor"]
    end

    it "creates a creation_year_sim field" do 
      mods.mods_origin_info.mods_date_issued = "2013-01-01"

      result["mods_creation_year_sim"].should == ["2013"]
    end

    it "creates a separate mods_keyword_sim entry for authorized topic entries" do 
      mods.mods_subject = ["", "", ""]
      mods.mods_subject(0).mods_keyword = "One" 
      mods.mods_subject(1).mods_keyword = "Two" 
      mods.mods_subject(1).mods_keyword.authority = "ABC" 

      result["mods_keyword_sim"].should == ["Two"]
    end

    it "creates tesim/sim fields for corporate creators" do 
      mods.assign_corporate_names(["NEU", "BC", "BU"])

      result["mods_corporate_name_mods_full_corporate_name_tesim"].should == ["NEU", "BC", "BU"]
      result["mods_corporate_name_mods_full_corporate_name_sim"].should == ["NEU", "BC", "BU"]
    end

    it "creates tesim/sim fields for untyped creators" do 
      mods.name = ["", "", ""]
      mods.name(0).name_part = "Will Jackson" 
      mods.name(2).name_part = "Bill Jackson" 

      result["name_name_part_tesim"].should == ["Will Jackson", "Bill Jackson"] 
      result["name_name_part_sim"].should == ["Will Jackson", "Bill Jackson"]
    end

    it "creates tesim/sim fields for personal creators" do 
      mods.assign_creator_personal_names(["Will", "Jim"], ["Jackson", "Jones"])

      result["personal_creators_sim"].should == ["Will Jackson", "Jim Jones"]
      result["personal_creators_tesim"].should == ["Will Jackson", "Jim Jones"]
    end
  end
end