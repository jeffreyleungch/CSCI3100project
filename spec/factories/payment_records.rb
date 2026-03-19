
FactoryBot.define do
  factory :payment_record do
    association :auction
    association :user
    amount_cents { 1000 }
    status { :pending }
  end
end
