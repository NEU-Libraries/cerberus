FactoryGirl.define do
  factory :employee do
    nuid "000000001"
    name "bill"

    factory :sequenced_employee do
      sequence(:nuid) { |n| "#{n}" }
      sequence(:name) { |n| "user #{n}" }
      mass_permissions "public"
    end
  end
end
