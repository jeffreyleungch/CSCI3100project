# Auction Configuration Constants
# Centralizes all auction timing and duration settings

module AuctionConfig
  # Auction duration settings
  AUCTION_DURATION_MINUTES = 30.minutes
  REMINDER_MINUTES_BEFORE_END = 15.minutes

  # Derived values for convenience
  AUCTION_DURATION_SECONDS = AUCTION_DURATION_MINUTES.to_i
  REMINDER_SECONDS_BEFORE_END = REMINDER_MINUTES_BEFORE_END.to_i
end