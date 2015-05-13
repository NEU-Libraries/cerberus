FactoryGirl.define do
  factory :user do
    sequence(:email) { |n| "person_#{n}@example.com" }
    sequence(:nuid) { |n| "#{n}" }
    password "password1"

    after(:build) { |user| user.class.skip_callback(:save, :after) }

    factory :admin do
      after(:build) { |u| u.role = 'admin' }
      email 'admin@example.com'
      nuid "000000000"
    end

    factory :bill do
      email 'bill@example.com'
      nuid "000000001"
    end

    factory :proxier do
      group_list ["northeastern:drs:repository:proxystaff"]
    end

    factory :bo do
      email 'bo@example.com'
      nuid "000000002"
    end

    factory :gone do
      email 'gone@example.com'
      group_list ['group_one']
      nuid "000000003"
    end

    factory :gtwo do
      email 'gtwo@example.com'
      group_list ['group_two']
      nuid "000000004"
    end

    factory :brooks do
      email 'b@blah.com'
      group_list ['northeastern:drs:repository:loaders:marcom', 'northeastern:drs:repository:staff']
      nuid "000000005"
    end
  end
end
