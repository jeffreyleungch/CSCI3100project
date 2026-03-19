
FactoryBot.define do
  factory :bid do
    association :auction
    association :user
    amount_cents { 1000 }
  end
end
