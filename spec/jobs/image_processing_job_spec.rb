require 'spec_helper'
describe ImageProcessingJob do
    before(:all) do
      # set file path to marcom.jpeg (copy it to tmp dir first)
      # set parent pid to marcom collection
      # set copyright to string
      # create factory load_report
      # run image processing job ImageProcessingJob.new(fpath, parent, copyright, load_report.id).run
      # do we need to get the core_file that the job creates here so it can be passed in to all the tests?
    end

    it 'creates core file' do
      # should create core file
    end

    it 'sets core_file.depositor to 000000000' do
      #core_file.depositor should == '000000000'
    end

    it 'sets correct parent' do
      #core_file.parent should == parent pid for marcom collection
      #core_file.properties.parent should == parent pid from marcom collection
    end

    it 'be tagged as in_progress' do
      #core_file should be_in_progress
    end

    it 'sets tmp_path as path to file in tmp dir' do
      #core_file.tmp_path should == 'tmp/marcom.jpeg'
      #check for replacement of spaces and parens in file name?
    end

    it 'sets original_filename to basename of file in tmp dir' do
      #core_file.original_filename should == 'marcom.jpeg'
      #check for replacement of spaces and parens in file name?
    end

    #for iptc values would we just hard code the values we know they should be from the fixture file?
    it 'sets title to iptc headline' do
      #core_file.title should == "Blizzard Juno"
    end

    it 'sets mods classification to iptc category + supp category' do
      #core_file.mods.classification should == "campus life -- students -- cargill hall"
    end

    it 'sets mods personal name and role to iptc byline' do
      #core_file.creators should == "[Maria Amasanti]"
      #core_file.mods.personal_name.role.role_term should == Photographer
    end

    it 'sets description to iptc description' do
      #core_file.description should == "January 27, 2015 - A Northeastern University student fights the wind during a blizzard."
    end

    it 'sets publisher to iptc source' do
      #core_file.mods.origin_info.publisher should == ["Northeastern University"]
    end

    it 'sets date and copyright date to iptc date time original' do
      # core_file.mods.origin_info.copyright should == ["2015-01-27"]
      # core_file.date should == "2015-01-27"
    end

    it 'sets keywords to iptc keywords' do
      # core_file.keywords should == ["blizzard", "juno", "campus", "campus life"]
    end

    it 'sets city to iptc city' do
      #core_file.mods.origin_info.place.city_term should == "Boston"
    end

    it 'sets state to iptc state' do
      #core_file.mods.origin_info.place.state_term should == "mau"
    end

    it 'sets static values' do
      # core_file.mods.genre should == "photographs"
      # core_file.mods.physical_description.digital_origin should == "born digital"
      # core_file.mods.physical_description.extent should == "1 photograph"
      # core_file.mods.access_condition should == copyright string
    end

    it 'creates success report' do
      #Loaders::ImageReport.find_all(validity = ?, true).count should == 1
    end

    it 'creates handle' do
      # core_file.identifier should == make_handle(core_file.persistent_url)
    end

    it 'removes tmp file' do
      #file should not exist as tmp/marcom.jpeg
    end

    # THIS SECTION WOULD CHECK FOR THE ERROR REPORTS BEING CREATE - not sure how to set up to keep from repeating tests with different files being passed in
    #context not ImageMasterFile
      #pass in a different file like word doc
      it 'creates error report if not ImageMasterFile' do
        #Loaders::ImageReport.find_all(validity = ?, false).count should == 1
      end
      it 'destroy core_file' do
        #created core_file should raise ActiveFedora::ObjectNotFound
      end
    #end context

    #context not JPEG
      #pass in a different image file like tif
      #same tests as not ImageMasterFile
    #end context

    #context JPEG w/ non-ascii chars in iptc
      #pass in a bad jpeg w/ smart quotes or emdash or ellipsis char
      #same tests as not ImageMasterFile
    #end context

    #context JPEG w/ incorrect class object in iptc
      #pass in bad jpeg w/ weird value in iptc like ruby object?
      #same tests as not ImageMasterFile
    #end context

    after(:all) do
      # clears out load reports and image reports
      # deletes core_file
    end

  end

end
