FactoryGirl.define do
  factory :xml_alert, class: XmlAlert do
    sequence(:title)            { |n| "Upload #{n}" }
    sequence(:email)            { |n| "#{n}@example.com" }
    sequence(:name)             { |n| "Person #{n}" }
    sequence(:pid)              { |n| "000#{n}" }
    sequence(:old_file_str)     { |n| "<note><to>Tove</to><from>Jani</from><heading>Reminder</heading><body>Don't forget me this weekend!</body></note>" }
    sequence(:new_file_str)     { |n| "<note><to>Tove</to><from>George</from><heading>Reminder</heading><body>Don't forget me this weekend!</body></note>" }
  end
end
