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

FactoryGirl.define do 
  factory :mods, class: NuModsDatastream do 
    sequence(:mods_title) { |n| "Datastream #{n}" } 
    sequence(:mods_identifier) { |n| "neu:#{n}#{n}#{n}" } 

    trait :with_keywords_valid do
      after(:build) do |mods|  
        mods.mods_subject.mods_keyword = ["Keyword One", "Keyword Two", "Keyword Three"]
      end
    end

    trait :with_invalid_keywords do
      after(:build) do |mods|   
        mods.mods_subject.mods_keyword = [" ", "", "Keyword Three"]
      end
    end

    trait :with_corporate_creator_valid do 
      after(:build) do |mods| 
        mods.assign_corporate_names(["Corp One", "Corp Two", "Corp Three"]) 
      end
    end

    trait :with_corporate_creator_invalid do 
      after(:build) do |mods| 
        mods.assign_corporate_names(["", " ", "Corp Three"])
      end
    end

    factory :valid_mods do 
      with_keywords_valid 
      with_corporate_creator_valid 
    end
  end
end

