FactoryGirl.define do 
  factory :compilation do 
    sequence(:title) { |n| "Bookmark #{n}" } 

    trait :identifier do
      after(:create) do |bookmark|
        bookmark.identifier = bookmark.pid
      end
    end

    trait :deposited_by_bill do 
      depositor "bill@example.com"
    end

    factory :bills_compilation do
      deposited_by_bill  
      identifier 
    end
  end
end