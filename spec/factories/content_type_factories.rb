FactoryGirl.define do

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

  trait :keywords do
    keywords ["Kay One", "Kay Two"]
  end

  trait :has_jpeg do
    before :create do |imf| 
      file = File.open("#{Rails.root}/spec/fixtures/test_pic.jpeg")

      imf.add_file(file, "content", "test_pic.jpeg") 
    end
  end

  trait :has_pdf do 
    before :create do |imf| 
      file = File.open("#{Rails.root}/spec/fixtures/test.pdf") 

      imf.add_file(file, "content", "test.pdf") 
    end
  end

  factory :image_master_file, class: ImageMasterFile do
    title "image_master_file.jpeg" 
    dad
    keywords
    identifier
    has_jpeg
  end

  factory :pdf_file, class: PdfFile do 
    title "pdf_file.pdf" 
    dad 
    keywords
    identifier
    has_pdf
  end
end

