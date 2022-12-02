# frozen_string_literal: true

FactoryBot.define do
  factory :file_set do
    transient do
      work { nil }
    end

    member_ids { FactoryBot.create_for_repository(:blob).id }

    to_create do |instance|
      Valkyrie.config.metadata_adapter.persister.save(resource: instance)
    end

    trait :metadata do
      member_ids { FactoryBot.create_for_repository(:blob, descriptive_metadata_for: work.id).id }
    end

    trait :blank do
      member_ids { [] }
    end

    trait :pdf do
      member_ids { FactoryBot.create_for_repository(:blob, :pdf).id }
    end

    trait :png do
      member_ids { FactoryBot.create_for_repository(:blob, :png).id }
    end
  end
end
