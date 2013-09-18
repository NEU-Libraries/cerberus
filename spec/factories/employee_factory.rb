FactoryGirl.define do
  factory :employee do 
    sequence(:nuid) { |n| "Employee_#{n}@example.com" }
    sequence(:name) { |n| "#{n} Employee's Name" } 
  end
end