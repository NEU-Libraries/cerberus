FactoryGirl.define do 
  factory :nu_core_file, class: NuCoreFile do 
    sequence(:title) { |n| "Core File #{n}" } 

    trait :deposited_by_bill do 
      depositor "bill@example.com"
    end

    trait :incomplete do 
      before(:create) do |file| 
        file.tag_as_in_progress 
      end
    end

    trait :complete do 
      before(:create) do |file| 
        file.tag_as_completed 
      end
    end

    factory :complete_file do 
      ignore do 
        depositor false 
      end

      after(:build) do |u, evaluator|
        u.depositor = evaluator.depositor if evaluator.depositor
      end
    end

    factory :bills_complete_file do 
      deposited_by_bill
      complete 
    end

    factory :bills_incomplete_file do 
      deposited_by_bill 
      incomplete 
    end
  end
end