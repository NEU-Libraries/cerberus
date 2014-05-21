FactoryGirl.define do
  factory :employee do

    before :create do |e|
      e.nuid = "000000001"
      e.name = "bill"
    end
  end
end
