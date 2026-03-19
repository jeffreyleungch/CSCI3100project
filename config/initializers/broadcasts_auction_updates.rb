
Rails.application.config.to_prepare do
  if defined?(Bid) && defined?(BroadcastsAuctionUpdates)
    Bid.include(BroadcastsAuctionUpdates) unless Bid.included_modules.include?(BroadcastsAuctionUpdates)
  end
end
