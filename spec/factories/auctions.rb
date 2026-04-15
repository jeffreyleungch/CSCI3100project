
FactoryBot.define do
  factory :auction do
    association :community
    status { :running }
    ends_at { AuctionConfig::AUCTION_DURATION_MINUTES.from_now }
  end
end
