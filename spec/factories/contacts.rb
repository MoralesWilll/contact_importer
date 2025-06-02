# spec/factories/contacts.rb
FactoryBot.define do
  factory :contact do
    name { "John Doe" }
    email { Faker::Internet.unique.email }
    phone { "1234567890" }
    date_of_birth { "1990-01-01" }
    address { "123 Main St, City, State 12345" }
    credit_card_number { "4111111111111111" }
    card_network { "Visa" }

    association :user
    association :contact_import
  end
end
