FactoryGirl.define do 
  factory :bookmarks, class: BookmarkSet do 
    sequence(:title) { |n| "Bookmark #{n}" } 

    trait :identifier do
      after(:create) do |bookmark|
        bookmark.identifier = bookmark.pid
      end
    end

    trait :deposited_by_bill do 
      depositor "bill@example.com"

      after(:create) do |bookmark| 
        bookmark.rightsMetadata.permissions({person: "bill@example.com"}, 'edit') 
      end 
    end

    factory :bills_bookmarks do
      deposited_by_bill  
      identifier 
    end
  end
end