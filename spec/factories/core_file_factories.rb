FactoryGirl.define do
  factory :core_file, class: CoreFile do
    sequence(:title) { |n| "Core File #{n}" }
    sequence(:mass_permissions) { 'public' }

    trait :deposited_by_bill do
      depositor "000000001"
    end

    trait :incomplete do
      before(:create) do |file|
        file.tag_as_incomplete
      end
    end

    trait :complete do
      before(:create) do |file|
        file.tag_as_completed
      end
    end

    trait :in_progress do
      before(:create) do |file|
        file.tag_as_in_progress
      end
    end

    trait :private_permissions do
      before(:create) do |file|
        file.mass_permissions = 'private'
      end
    end

    trait :embargoed do
      before(:create) do |file|
        file.embargo_release_date = Date.tomorrow
      end
    end

    factory :featured_content do
      mass_permissions 'public'
      deposited_by_bill

      factory :theses do
       category 'Theses and Dissertations'
      end

      factory :research do
       category 'Research Publications'
      end

      factory :presentation do
        category 'Presentations'
      end

      factory :dataset do
        category 'Datasets'
      end

      factory :learning_object do
        category 'Learning Objects'
      end

      factory :monograph do
       category 'Monographs'
      end
    end

    factory :complete_file do
      ignore do
        depositor false
        parent false
      end

      after(:build) do |u, evaluator|
        u.depositor = evaluator.depositor if evaluator.depositor
        u.parent = evaluator.parent if evaluator.parent
        u.properties.parent_id = evaluator.parent.pid if evaluator.parent
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

    factory :bills_in_progress_file do
      deposited_by_bill
      in_progress
    end

    factory :bills_private_file do
      deposited_by_bill
      complete
      private_permissions
    end

    factory :bills_embargoed_file do
      deposited_by_bill
      complete
      embargoed
    end
  end
end
