FactoryGirl.define do
  factory :imf, class: ImageMasterFile do 
    title "test_pic.jpeg" 

    trait :dad do 
      NuCoreFile.create(depositor: "nosuch@example.com") 

      depositor "nosuch@example.com"
      before :create do |imf| 
        imf.core_record = NuCoreFile.create(depositor: "nosuch@example.com") 
      end
    end

    trait :identifier do 
      after :create do |file| 
        file.identifier = file.pid 
        file.save!
      end
    end

    trait :described do
      description "An Image Master File" 
      keywords ["Kay One", "Kay Two"]
    end

    trait :file_bearing do
      before :create do |imf| 
        file = File.open("#{Rails.root}/spec/fixtures/test_pic.jpeg")

        imf.add_file(file, "content", "test_pic.jpeg") 
      end
    end

    factory :image_master_file do 
      dad
      described
      identifier
      file_bearing 
    end
  end
end

