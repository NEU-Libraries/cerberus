require 'spec_helper'

describe ModsDatastream do
  let(:basic_mods) { FactoryGirl.build(:mods) }

  subject { basic_mods }

  it { should respond_to(:to_xml) }
  it { should respond_to(:assign_creator_personal_names) }
  it { should respond_to(:assign_corporate_names) }

  describe "Simple setters" do
    before do
      basic_mods.title = "My title"
      basic_mods.abstract = "This is a test object created for testing"
      basic_mods.identifier = "neu:123abc"
      basic_mods.date = "2013-05-05"
    end

    it "Has set the title correctly" do
      basic_mods.title_info(0).title.first.should == "My title"
    end

    it "Has the abstract set correctly" do
      basic_mods.abstract(0).first.should == "This is a test object created for testing"
    end

    it "Has the identifier set correctly" do
      basic_mods.identifier(0).first.should == "neu:123abc"
    end

    it "Has the mods issuance date set correctly" do
      basic_mods.origin_info(0).date_created.first.should == '2013-05-05'
    end
  end

  # Note that factories which create more or less equivalent objects do exist.
  describe "Multiple entry setters" do

    describe "With valid information" do
      let(:valid_mods) { ModsDatastream.new }
      let(:corp_names) { ["Corp One", "Corp Two", "Corp Three"] }
      let(:first_names) { ["Will", "William", "Bill"] }
      let(:last_names) { ["Jack", "Jackson", "Back"] }

      before do
        valid_mods.topics = ["One", "Two", "Three"]
        valid_mods.names = ["Will Jackson", "Northeastern", "Library"]
        valid_mods.assign_corporate_names(corp_names)
        valid_mods.assign_creator_personal_names(first_names, last_names)
      end

      it "Has set all unscoped names correctly" do
        valid_mods.name(0).name_part.should == ["Will Jackson"]
        valid_mods.name(1).name_part.should == ["Northeastern"]
        valid_mods.name(2).name_part.should == ["Library"]
      end

      it "Has set all provided keywords correctly" do
        valid_mods.subject(0).topic.should == ["One"]
        valid_mods.subject(1).topic.should == ["Two"]
        valid_mods.subject(2).topic.should == ["Three"]
      end

      it "Has set all provided corporate names correctly" do
        valid_mods.corporate_creators.should == ["Corp One", "Corp Two", "Corp Three"]

        valid_mods.corporate_name(0).name_part.should == ["Corp One"]
        valid_mods.corporate_name(1).name_part.should == ["Corp Two"]
        valid_mods.corporate_name(2).name_part.should == ["Corp Three"]
      end

      it "Hasn't compressed any corporate names into the same parent node" do
        valid_mods.corporate_name(0).name_part.length.should == 1
        valid_mods.corporate_name(1).name_part.length.should == 1
        valid_mods.corporate_name(2).name_part.length.should == 1
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
      let(:invalid_mods) { ModsDatastream.new }
      let(:crap_keywords) { ["", " ", ""] }
      let(:crap_corps) { ["", " ", ""] }
      let(:crap_first_names) { ["", " ", "Will", "", " "] }
      let(:crap_last_names) { [" ", "", "Jackson", "", " "] }

      let(:uneven_mods) { ModsDatastream.new }
      let(:uneven_firsts) { ["Will", "Chris"] }
      let(:uneven_lasts) { ["Jackson", "Tucker", "Chan"] }

      before do
        invalid_mods.subject.topic = crap_keywords
        invalid_mods.assign_corporate_names(crap_corps)
        invalid_mods.assign_creator_personal_names(crap_first_names, crap_last_names)
      end

      it "Throws an error when unequal first and last name arrays are passed" do
        expect{ uneven_mods.assign_creator_personal_names(uneven_firsts, uneven_lasts) }.to raise_error
      end

      it "Assigns no corporate creators" do
        invalid_mods.corporate_name(0).name_part.should == []
        invalid_mods.corporate_name.length.should == 1
      end

      it "Assigns a single first and last name" do
        invalid_mods.personal_name.length.should == 1
        invalid_mods.personal_name(0).should == ["WillJackson"]
      end
    end
  end

  describe "Solrization" do
    let(:mods) { ModsDatastream.new }
    let(:result) { mods.to_solr }

    it "Gives back ssi and tesim fields for the title entry" do
      mods.title_info.title = "Test Title"

      result["title_ssi"].should == "test title"
      result["title_tesim"].should == "Test Title"
    end

    it "Gives back tesim fields for all role entries" do
      mods.note = ["one", "two", "three"]

      result["note_tesim"].should == ["one", "two", "three"]
    end

    it "Gives back a tesim field for abstract" do
      mods.abstract = ["A test"]

      result["abstract_tesim"].should == "A test"
    end

    it "creates a tesim field for all identifier entries" do
      mods.identifier = ["neu:123", "ISBN 000"]

      result["identifier_tesim"].should == ["neu:123", "ISBN 000"]
    end

    it "creates tesim, ssim, and faceted fields for all genre entries" do
      arry = ["Non-fiction", "Science", "Monkeys"]
      mods.genre = arry

      result["genre_tesim"].should == arry
      result["genre_sim"].should == arry
    end

    it "creates tesim, ssim, and faceted fields for genre entries in a related item entry" do
      arry = ["Non-fiction", "Science", "Monkeys"]
      mods.related_item = ['']
      mods.related_item.genre = arry

      result["genre_tesim"].should == arry
      result["genre_sim"].should == arry
    end

    it "creates a tesim field for all publisher entries" do
      mods.origin_info = [""]
      mods.origin_info.publisher = ["WB", "Clearing House"]

      result["origin_info_publisher_tesim"].should == ["WB", "Clearing House"]
    end

    it "creates a tesim field for all origin place entries" do
      mods.origin_info = [""]
      mods.origin_info.place.city_term = "New York City"
      result["origin_info_place_tesim"].should == ["New York City"]
    end

    it "indexes publisher information stored within a related item entry" do
      mods.related_item = ['']
      mods.related_item.origin_info.place.city_term = "New York City"

      result["origin_info_place_tesim"].should == ["New York City"]
    end

    it "creates a tesim field for all role entries" do
      mods.assign_creator_personal_names(["John", "Joe"], ["Smith", "Adams"])
      mods.personal_name(0).role = "Author"
      mods.personal_name(1).role = "Editor"

      result["personal_name_role_tesim"].should == ["Author", "Editor"]
    end

    it "creates a creation_year_sim field" do
      mods.origin_info.date_created = "2013-01-01"

      result["creation_year_sim"].should == ["2013"]
    end

    it "creates a separate mods_keyword_sim entry for authorized topic entries" do
      mods.topics = ["One", "Two", "ABC"]
      mods.subject(1).topic.authority = "ISF"

      result["subject_sim"].should == ["Two"]
    end

    it "creates tesim/sim fields for corporate creators" do
      mods.assign_corporate_names(["NEU", "BC", "BU"])

      result["corporate_name_name_part_tesim"].should == ["NEU", "BC", "BU"]
      result["corporate_name_name_part_sim"].should == ["NEU", "BC", "BU"]
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

      result["personal_creators_sim"].should == ["Jackson, Will", "Jones, Jim"]
      result["personal_creators_tesim"].should == ["Jackson, Will", "Jones, Jim"]
    end

    it "creates an aggregate creator sim field" do
      mods.assign_creator_personal_names(["Will"], ["Jackson"])
      mods.assign_corporate_names(["NEU"])
      mods.names = ["ABC DEF", "GHI"]

      result["creator_sim"].should == ["Jackson, Will", "NEU", "ABC DEF", "GHI"]
    end

    it "creates an aggregate creator tesim field" do
      mods.assign_creator_personal_names(["Will"], ["Jackson"])
      mods.assign_corporate_names(["NEU"])
      mods.names = ["ABC DEF", "GHI"]

      result["creator_tesim"].should == ["Jackson, Will", "NEU", "ABC DEF", "GHI"]
    end

    it "creates ssim fields for scholarly_object category" do
      mods.category = "Theses"
      result["drs_category_ssim"].should == "Theses"
    end

    it "creates ssim fields for scholarly_object department" do
      mods.department = "English dept"
      result["drs_department_ssim"].should == "English dept"
    end

    it "creates ssim fields for scholarly_object degree" do
      mods.degree = "Masters"
      result["drs_degree_ssim"].should == "Masters"
    end

    it "creates ssim fields for scholarly_object course number" do
      mods.course_number = "MGMT001"
      result["drs_course_number_ssim"].should == "MGMT001"
    end

    it "creates ssim fields for scholarly_object course title" do
      mods.course_title = "Management Class"
      result["drs_course_title_ssim"].should == "Management Class"
    end
  end
end
