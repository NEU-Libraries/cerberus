FactoryGirl.define do
  factory :employee do

    before :create do |e| 
      e.nuid = (Employee.all.length + 1).to_s
      e.name = (Employee.all.length + 1).to_s
    end 
  end
end