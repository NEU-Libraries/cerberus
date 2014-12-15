FactoryGirl.define do
  factory :employee do
    nuid "000000001"
    name "bill baggins"

    factory :sequenced_employee do
      sequence(:nuid) { |n| "#{n}" }
      sequence(:name) { |n| "firstname lastname" }
      mass_permissions "public"
    end
  end
end
