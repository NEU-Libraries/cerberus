# frozen_string_literal: true

include FileHelper

FactoryBot.define do
  factory :blob do
    to_create do |instance|
      Valkyrie.config.metadata_adapter.persister.save(resource: instance)
    end

    trait :pdf do
      original_filename { 'example.pdf' }
      after(:create) do |b, _evaluator|
        b.file_identifiers += [create_file("#{Rails.root.join('spec/fixtures/files/example.pdf')}", b).id]
        Valkyrie.config.metadata_adapter.persister.save(resource: b)
      end
    end

    trait :word do
      original_filename { 'example.docx' }
      after(:create) do |b, _evaluator|
        b.file_identifiers += [create_file("#{Rails.root.join('spec/fixtures/files/example.docx')}", b).id]
        Valkyrie.config.metadata_adapter.persister.save(resource: b)
      end
    end

    trait :png do
      original_filename { 'image.png' }
      after(:create) do |b, _evaluator|
        b.file_identifiers += [create_file("#{Rails.root.join('spec/fixtures/files/image.png')}", b).id]
        Valkyrie.config.metadata_adapter.persister.save(resource: b)
      end
    end
  end
end
