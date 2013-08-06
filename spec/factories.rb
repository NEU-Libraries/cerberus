FactoryGirl.define do 
  factory :user do 
    sequence(:email) { |n| "person_#{n}@example.com" } 
    password "password"

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