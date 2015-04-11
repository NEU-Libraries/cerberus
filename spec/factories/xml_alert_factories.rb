FactoryGirl.define do
  factory :xml_alert, class: XmlAlert do
    sequence(:title)            { |n| "Upload #{n}" }
    sequence(:email)            { |n| "#{n}@example.com" }
    sequence(:name)             { |n| "Person #{n}" }
    sequence(:pid)              { |n| "000#{n}" }
    sequence(:old_file_str)     { |n| "<note><to>Tove</to><from>Jani</from><heading>Reminder</heading><body>Don't forget me this weekend!</body></note>" }
    sequence(:new_file_str)     { |n| "<note><to>Tove</to><from>George</from><heading>Reminder</heading><body>Don't forget me this weekend!</body></note>" }


    trait :diff_made do
      after(:create) do |upload_alert|
        upload_alert.diff = Diffy::Diff.new(upload_alert.old_file_str, upload_alert.new_file_str, :include_plus_and_minus_in_html => true, :context => 1).to_s(:html)
        upload_alert.save!
      end
    end

    factory :updated_xml do
      diff_made
    end
  end
end
