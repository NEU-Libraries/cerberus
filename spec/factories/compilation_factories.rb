FactoryGirl.define do
  factory :compilation do
    sequence(:title) { |n| "Bookmark #{n}" }

    trait :identifier do
      after(:create) do |bookmark|
        bookmark.identifier = bookmark.pid
      end
    end

    trait :deposited_by_bill do
      depositor "000000001"
    end

    trait :deposited_by_bo do
      depositor "000000002"
    end

    factory :bills_compilation do
      deposited_by_bill
      identifier
    end

    factory :bos_compilation do
      deposited_by_bo
      identifier
    end
  end
end
