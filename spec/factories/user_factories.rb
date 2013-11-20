FactoryGirl.define do 
  factory :user do 
    sequence(:email) { |n| "person_#{n}@example.com" } 
    password "password1"

    after(:build) { |user| user.class.skip_callback(:save, :after, :link_to_drs) } 

    factory :admin do 
      after(:build) { |u| u.role = 'admin' }
      email 'admin@example.com' 
    end

    factory :bill do 
      email 'bill@example.com'
    end

    factory :bo do 
      email 'bo@example.com'  
    end

    factory :gone do 
      email 'gone@example.com' 
      group_list ['group_one'] 
    end

    factory :gtwo do 
      email 'gtwo@example.com' 
      group_list ['group_two'] 
    end
  end
end