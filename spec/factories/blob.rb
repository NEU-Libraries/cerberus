# frozen_string_literal: true

FactoryBot.define do
  factory :blob do
    file_identifiers { ["disk://#{Rails.root.join('spec/fixtures/files/image.png')}"] }
    original_filename { 'image.png' }
    to_create do |instance|
      Valkyrie.config.metadata_adapter.persister.save(resource: instance)
    end

    trait :pdf do
      file_identifiers { ["disk://#{Rails.root.join('spec/fixtures/files/example.pdf')}"] }
      original_filename { 'example.pdf' }
    end

    trait :png do
      file_identifiers { ["disk://#{Rails.root.join('spec/fixtures/files/image.png')}"] }
      original_filename { 'image.png' }
    end
  end
end
