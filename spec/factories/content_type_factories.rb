FactoryGirl.define do

  trait :dad do
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

  trait :canon do 
    before :create do |file| 
      file.canonize 
    end
  end

  trait :has_jpeg do
    before :create do |imf| 
      file = File.open("#{Rails.root}/spec/fixtures/test_pic.jpeg")

      imf.add_file(file, "content", "test_pic.jpeg") 
    end
  end

  trait :has_different_jpeg do 
    before :create do |imf| 
      file = File.open("#{Rails.root}/spec/fixtures/test_pic_two.jpeg") 

      imf.add_file(file, "content", "test_pic_two.jpeg") 
    end
  end

  trait :has_pdf do 
    before :create do |imf| 
      file = File.open("#{Rails.root}/spec/fixtures/test.pdf") 

      imf.add_file(file, "content", "test.pdf") 
    end
  end

  trait :has_docx do 
    before :create do |doc| 
      file = File.open("#{Rails.root}/spec/fixtures/test_docx.docx") 

      doc.add_file(file, 'content', 'test_docx.docx') 
    end
  end

  factory :master_file, class: ImageMasterFile do 
    dad
    keywords
    canon
    identifier 

    factory :image_master_file, class: ImageMasterFile do 
      title "image_master_file.jpeg" 
      has_jpeg 
    end

    factory :pdf_file, class: PdfFile do 
      title "pdf_file.pdf" 
      has_pdf 
    end

    factory :docx_file, class: MswordFile do
      title "docx_file.docx" 
      has_docx
    end
  end

  factory :previous_thumbnail_file, class: ImageThumbnailFile do 
    title "Previous Thumbnail" 
    identifier
    has_different_jpeg
  end
end