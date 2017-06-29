include MimeHelper
include ChecksumHelper

  FactoryGirl.define do

  trait :dad do
    depositor "nosuch@example.com"
    before :create do |imf|
      c = Collection.create(mass_permissions: 'public', pid: 'neu:12345', title: 'Test Parent Collection')
      imf.core_record = CoreFile.create(mass_permissions: 'public', depositor: "nosuch@example.com", parent: c)
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
      path = "#{Rails.root}/spec/fixtures/files/test_pic.jpeg"
      file = File.open(path)

      imf.add_file(file, "content", "test_pic.jpeg")
      imf.core_record.instantiate_appropriate_content_object(path)
    end
  end

  trait :has_tif do
    before :create do |imf|
      path = "#{Rails.root}/spec/fixtures/files/image.tif"
      file = File.open(path)

      imf.add_file(file, "content", "image.tif")
      imf.core_record.instantiate_appropriate_content_object(path)
    end
  end

  trait :has_16bit_tif do
    before :create do |imf|
      path = "#{Rails.root}/spec/fixtures/files/16bit.tif"
      file = File.open(path)

      imf.add_file(file, "content", "16bit.tif")
      imf.core_record.instantiate_appropriate_content_object(path)
    end
  end

  trait :has_different_jpeg do
    before :create do |imf|
      path = "#{Rails.root}/spec/fixtures/files/test_pic_two.jpeg"
      file = File.open(path)

      imf.add_file(file, "content", "test_pic_two.jpeg")
      imf.core_record.instantiate_appropriate_content_object(path)
    end
  end

  trait :has_pdf do
    before :create do |imf|
      path = "#{Rails.root}/spec/fixtures/files/test.pdf"
      file = File.open(path)

      imf.add_file(file, "content", "test.pdf")
      imf.core_record.instantiate_appropriate_content_object(path)
    end
  end

  trait :has_docx do
    before :create do |doc|
      path = "#{Rails.root}/spec/fixtures/files/test_docx.docx"
      file = File.open(path)

      doc.add_file(file, "content", "test_docx.docx")
      doc.core_record.instantiate_appropriate_content_object(path)
    end
  end

  trait :public_read do
    mass_permissions 'public'
  end

  factory :master_file, class: ImageMasterFile do
    dad
    keywords
    canon
    identifier
    public_read

    factory :image_master_file, class: ImageMasterFile do
      title "test_pic.jpeg"
      original_filename "test_pic.jpeg"
      has_jpeg
    end

    factory :pdf_file, class: PdfFile do
      title "test.pdf"
      original_filename "test.pdf"
      has_pdf
    end

    factory :docx_file, class: MswordFile do
      title "test_docx.docx"
      original_filename "test_docx.docx"
      has_docx
    end

    factory :tif_master_file, class: ImageMasterFile do
      title "image.tif"
      original_filename "image.tif"
      has_tif
    end

    factory :tif_16bit_master_file, class: ImageMasterFile do
      title "16bit.tif"
      original_filename "16bit.tif"
      has_16bit_tif
    end
  end

  factory :previous_thumbnail_file, class: ImageThumbnailFile do
    title "Previous Thumbnail"
    identifier
    has_different_jpeg
  end
end