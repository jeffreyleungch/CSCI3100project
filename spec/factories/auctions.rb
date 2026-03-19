
FactoryBot.define do
  factory :auction do
    association :community
    status { :running }
    ends_at { 30.minutes.from_now }
  end
end
