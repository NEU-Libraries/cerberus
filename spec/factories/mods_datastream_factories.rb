FactoryGirl.define do 
  factory :mods, class: NuModsDatastream do 
    sequence(:title) { |n| "Datastream #{n}" } 
    sequence(:identifier) { |n| "neu:#{n}#{n}#{n}" } 

    trait :with_keywords_valid do
      after(:build) do |mods|  
        mods.topics = ["Keyword One", "Keyword Two", "Keyword Three"]
      end
    end

    trait :with_invalid_keywords do
      after(:build) do |mods|   
        mods.topics = [" ", "", "Keyword Three"]
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