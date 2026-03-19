
FactoryBot.define do
  factory :community do
    name { "Test Community" }
  end

  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    association :community
  end
end
