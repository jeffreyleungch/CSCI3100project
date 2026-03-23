class Auction < ApplicationRecord
  include AuctionScheduler
  enum :status, { scheduled: 0, running: 1, closed: 2 }
end