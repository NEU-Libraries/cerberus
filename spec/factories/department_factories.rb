FactoryGirl.define do 
  factory :department do 
    sequence(:title) { |n| "Department #{n}" } 
    sequence(:description) { |n| "This is the home page for department #{n}" }
  end
end    