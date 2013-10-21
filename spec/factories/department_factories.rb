FactoryGirl.define do 

  factory :department, class: Community do
    sequence(:title) { |n| "Community #{n}" } 

    trait :assigned_identifier do 
      after(:create) do |department|
        department.identifier = department.pid 
      end
    end

    trait :public_read do 
      mass_permissions 'public'
    end

    trait :owned_by_bill do 
      depositor 'bill@example.com' 
      permissions {{ 'permissions0' => { 'identity_type' => 'person', 'identity' => 'bill@example.com', 'permission_type' => 'edit' },
                      'permissions1' => {'identity_type' => 'person', 'identity' => 'billsfriend@example.com', 'permission_type' => 'read' }}}
    end

    factory :root_department do 
      title "New Community"
      description "Factory created" 
      assigned_identifier
      public_read
      owned_by_bill
    end
  end
end