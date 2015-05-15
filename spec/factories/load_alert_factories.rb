FactoryGirl.define do
  factory :load_alert, class: LoadAlert do
    sequence(:nuid)             { |n| "000000000" }
    sequence(:collection)       { |n| "#{n}" }
    sequence(:loader_name)      { |n| "#{n}" }
    sequence(:number_of_files)  { |n| "#{n}" }
    sequence(:success_count)    { |n| "#{n}" }
    sequence(:fail_count)       { |n| "#{n}" }

    factory :marcom_load do
      loader_name "Marketing and Communications"
      collection "neu:6240"
      success_count "1"
      fail_count "1"
      number_of_files "2"
    end
  end
end
