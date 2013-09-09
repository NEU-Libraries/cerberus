FactoryGirl.define do 
  factory :collection, class: NuCollection do
    sequence(:title) { |n| "Collection #{n}" } 

    trait :assigned_identifier do 
      after(:create) do |collection|
        collection.identifier = collection.pid 
      end
    end

    trait :with_keywords do 
      keywords ['kw one', 'kw two', 'kw three'] 
    end

    trait :not_embargoed do 
      embargo_release_date  { Date.yesterday.to_s } 
    end

    trait :embargoed do 
      embargo_release_date { Date.tomorrow.to_s } 
    end

    trait :issued_yesterday do 
      date_of_issue { Date.yesterday.to_s } 
    end

    trait :with_description do 
      sequence(:description) { |n| "This is collection #{n}." } 
    end

    trait :with_corporate_creators do 
      corporate_creators ['Corp One', 'Corp Two', 'Corp Three'] 
    end

    trait :with_personal_creators do 
      personal_creators {{ 'creator_first_names' => ["David", "Steven", "Will"], 
                          'creator_last_names' => ["Cliff", "Bassett", "Jackson"]}}
    end

    trait :public_read do 
      mass_permissions 'public'
    end

    trait :registered_read do 
      mass_permissions 'registered' 
    end

    trait :with_two_edit_perms do
      permissions { { 'permissions0' => { 'identity_type' => 'person', 'identity' => 'ident one', 'permission_type' => 'edit' }, 
                      'permissions1' => { 'identity_type' => 'group', 'identity' => 'faculty', 'permission_type' => 'edit' } } }
    end

    trait :owned_by_bill do 
      depositor 'bill@example.com' 
      permissions {{ 'permissions0' => { 'identity_type' => 'person', 'identity' => 'bill@example.com', 'permission_type' => 'edit' },
                      'permissions1' => {'identity_type' => 'person', 'identity' => 'billsfriend@example.com', 'permission_type' => 'read' }}}
    end

    factory :valid_not_embargoed do 
      with_keywords 
      not_embargoed 
      issued_yesterday 
      with_description 
      with_corporate_creators 
      with_personal_creators 
      public_read 
      with_two_edit_perms
      assigned_identifier

        factory :valid_owned_by_bill do
          title "Bills Collection"
          description "Bills new collection" 
          owned_by_bill
        end
    end

    factory :root_collection do 
      title "Root Collection"
      assigned_identifier  
    end
  end
end