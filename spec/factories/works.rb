FactoryGirl.define do
  factory :work, class: Works::Work do
    after(:create) do |work|
      file_set = Hydra::Works::FileSet.create
      work.members << file_set
      work.save!
    end

    factory :image_master_file do
      title "test_pic.png"
      publicized
      has_png
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

  trait :has_thumbnail do
    after :create do |work|
      file_set = work.file_sets.first
      GenerateDerivativesJob.new.perform(file_set.id)
    end
  end

end
