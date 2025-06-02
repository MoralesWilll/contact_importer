FactoryBot.define do
  factory :contact_import do
    association :user
    filename { 'test.csv' }
    status { 'on_hold' }
    total_rows { 0 }
    successful_imports { 0 }
  end
end
