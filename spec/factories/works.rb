FactoryGirl.define do
  factory :work, class: Works::Work do

    after(:create) do |work|
      file_set = Hydra::Works::FileSet.create
      file_set.publicize!
      work.members << file_set
      work.save!
    end

    factory :png_master_file do
      title "test_pic.png"
      topics ["test", "png"]
      publicized
      has_png
      has_thumbnail
    end

    factory :jpg_master_file do
      title "test_pic.jpg"
      topics ["test", "jpg"]
      publicized
      has_jpg
      has_thumbnail
    end

    factory :docx_master_file do
      title "test_docx.docx"
      topics ["test", "docx"]
      publicized
      has_docx
      has_thumbnail
    end

    factory :doc_master_file do
      title "test_doc.doc"
      topics ["test", "doc"]
      publicized
      has_doc
      has_thumbnail
    end

  end

  trait :publicized do
    after(:create) do |work|
      work.publicize!
    end
  end

  trait :privatized do
    after(:create) do |work|
      work.privatize!
    end
  end

  trait :has_png do
    after :create do |work|
      path = "#{Rails.root}/spec/fixtures/files/test_pic.png"
      file = File.new(path)
      file_set = work.file_sets.first

      Hydra::Works::UploadFileToFileSet.call(file_set, file)
      file_set.save!
    end
  end

  trait :has_jpg do
    after :create do |work|
      path = "#{Rails.root}/spec/fixtures/files/test_pic.jpeg"
      file = File.new(path)
      file_set = work.file_sets.first

      Hydra::Works::UploadFileToFileSet.call(file_set, file)
      file_set.save!
    end
  end

  trait :has_docx do
    after :create do |work|
      path = "#{Rails.root}/spec/fixtures/files/test_docx.docx"
      file = File.new(path)
      file_set = work.file_sets.first

      Hydra::Works::UploadFileToFileSet.call(file_set, file)
      file_set.save!
    end
  end

  trait :has_doc do
    after :create do |work|
      path = "#{Rails.root}/spec/fixtures/files/test_doc.doc"
      file = File.new(path)
      file_set = work.file_sets.first

      Hydra::Works::UploadFileToFileSet.call(file_set, file)
      file_set.save!
    end
  end

  trait :has_thumbnail do
    after :create do |work|
      file_set = work.file_sets.first
      file_set.create_derivatives
      work.update_index #not sure why this is necessary...
    end
  end

end
