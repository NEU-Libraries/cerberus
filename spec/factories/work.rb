# frozen_string_literal: true

FactoryBot.define do
  factory :work do
    to_create do |instance|
      Valkyrie.config.metadata_adapter.persister.save(resource: instance)
    end

    # the after(:create) yields two values; the user instance itself and the
    # evaluator, which stores all values from the factory, including transient
    # attributes
    after(:create) do |work, _evaluator|
      # create_list(:post, evaluator.posts_count, user: user)
      FactoryBot.create_for_repository(:file_set, :metadata, work: work, a_member_of: work.id)
    end
  end
end
