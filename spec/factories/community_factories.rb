FactoryGirl.define do

  factory :community, class: Community do
    sequence(:title) { |n| "Community #{n}" }

    trait :assigned_identifier do
      after(:create) do |community|
        community.identifier = community.pid
      end
    end

    trait :public_read do
      mass_permissions 'public'
    end

    trait :owned_by_bill do
      depositor 'bill@example.com'
      mass_permissions 'public'
    end

    trait :owned_by_admin do
      depositor 'admin@example.com'
      mass_permissions 'public'
    end

    factory :root_community do
      title "New Community"
      description "Factory created"
      assigned_identifier
      public_read
      owned_by_admin
    end

    factory :test_community do
      title "Test Community"
      description "Factory created, test object"
      assigned_identifier
      public_read
      owned_by_admin
    end
  end
end
